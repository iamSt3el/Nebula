#include "blobfield.h"

#include <QRegion>
#include <QSGGeometryNode>
#include <QSGMaterial>
#include <QSGMaterialShader>
#include <QVariantMap>
#include <algorithm>
#include <cmath>
#include <cstring>

namespace nebula {

namespace {

constexpr int kOffOpacity = 64;
constexpr int kOffEdgeW = 68;
constexpr int kOffSmoothing = 72;
constexpr int kOffCount = 76;
constexpr int kOffFill = 80;
constexpr int kOffEdge = 96;
constexpr int kOffShadow = 112;
constexpr int kOffShadowInfo = 128;
constexpr int kOffFrameHole = 144;
constexpr int kOffFrameRad = 160;
constexpr int kOffRect = 176;
constexpr int kOffRadii = kOffRect + 16 * kBlobLocal;
constexpr int kOffExtra = kOffRadii + 16 * kBlobLocal;
constexpr int kOffPaint = kOffExtra + 16 * kBlobLocal;
constexpr int kUniformSize = kOffPaint + 16 * kBlobLocal;

class BlobMaterial : public QSGMaterial {
public:
    QSGMaterialType *type() const override
    {
        static QSGMaterialType t;
        return &t;
    }
    QSGMaterialShader *createShader(QSGRendererInterface::RenderMode) const override;
    int compare(const QSGMaterial *other) const override
    {
        return this < other ? -1 : this > other ? 1 : 0;
    }

    QSharedPointer<BlobPack> pack;
    std::vector<int> blobs;
    bool frame = false;
    QColor fill;
    QColor edge;
    float edgeW = 0;
    QColor shadow;
    float shadowSize = 0;
    float shadowStrength = 0;
};

class BlobShader : public QSGMaterialShader {
public:
    BlobShader()
    {
        setShaderFileName(VertexStage, QStringLiteral(":/shaders/blobfield.vert.qsb"));
        setShaderFileName(FragmentStage, QStringLiteral(":/shaders/blobfield.frag.qsb"));
    }

    bool updateUniformData(RenderState &state, QSGMaterial *newMaterial, QSGMaterial *) override
    {
        auto *m = static_cast<BlobMaterial *>(newMaterial);
        QByteArray *buf = state.uniformData();
        if (buf->size() < kUniformSize)
            return false;
        char *d = buf->data();
        if (state.isMatrixDirty()) {
            const QMatrix4x4 mat = state.combinedMatrix();
            std::memcpy(d, mat.constData(), 64);
        }
        if (state.isOpacityDirty()) {
            const float o = state.opacity();
            std::memcpy(d + kOffOpacity, &o, 4);
        }
        const BlobPack *p = m->pack.data();
        if (!p)
            return true;
        const int count = int(std::min<size_t>(m->blobs.size(), kBlobLocal));
        std::memcpy(d + kOffEdgeW, &m->edgeW, 4);
        std::memcpy(d + kOffSmoothing, &p->smoothing, 4);
        std::memcpy(d + kOffCount, &count, 4);
        const float fill[4] = { float(m->fill.redF()), float(m->fill.greenF()), float(m->fill.blueF()), float(m->fill.alphaF()) };
        const float edge[4] = { float(m->edge.redF()), float(m->edge.greenF()), float(m->edge.blueF()), float(m->edge.alphaF()) };
        const float shadow[4] = { float(m->shadow.redF()), float(m->shadow.greenF()), float(m->shadow.blueF()), float(m->shadow.alphaF()) };
        const float info[4] = { m->shadowSize, m->shadowStrength, m->frame ? 1.f : 0.f, 0.f };
        std::memcpy(d + kOffFill, fill, 16);
        std::memcpy(d + kOffEdge, edge, 16);
        std::memcpy(d + kOffShadow, shadow, 16);
        std::memcpy(d + kOffShadowInfo, info, 16);
        std::memcpy(d + kOffFrameHole, &p->frameHole, 16);
        std::memcpy(d + kOffFrameRad, &p->frameRad, 16);
        for (int i = 0; i < count; ++i) {
            const int b = m->blobs[size_t(i)];
            std::memcpy(d + kOffRect + 16 * i, &p->rect[b], 16);
            std::memcpy(d + kOffRadii + 16 * i, &p->radii[b], 16);
            std::memcpy(d + kOffExtra + 16 * i, &p->extra[b], 16);
            std::memcpy(d + kOffPaint + 16 * i, &p->paint[b], 16);
        }
        return true;
    }
};

QSGMaterialShader *BlobMaterial::createShader(QSGRendererInterface::RenderMode) const
{
    return new BlobShader;
}

float num(const QVariantMap &m, const char *key, float fallback = 0.f)
{
    const auto it = m.constFind(QLatin1String(key));
    if (it == m.constEnd())
        return fallback;
    bool ok = false;
    const double v = it->toDouble(&ok);
    return ok && std::isfinite(v) ? float(v) : fallback;
}

float boxGap(const QRectF &a, const QRectF &b)
{
    const float dx = float(std::max(a.left() - b.right(), b.left() - a.right()));
    const float dy = float(std::max(a.top() - b.bottom(), b.top() - a.bottom()));
    if (dx > 0 && dy > 0)
        return std::hypot(dx, dy);
    return std::max(dx, dy);
}

}

BlobField::BlobField(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents);
}

void BlobField::setBlobs(const QVariantList &blobs)
{
    if (m_blobs == blobs)
        return;
    m_blobs = blobs;
    pack();
    emit blobsChanged();
    update();
}

void BlobField::setFrame(const QVariantMap &frame)
{
    if (m_frame == frame)
        return;
    m_frame = frame;
    pack();
    emit frameChanged();
    update();
}

void BlobField::setSmoothing(qreal k)
{
    k = std::max<qreal>(0, k);
    if (qFuzzyCompare(m_smoothing + 1, k + 1))
        return;
    m_smoothing = k;
    pack();
    emit smoothingChanged();
    update();
}

void BlobField::setFillColor(const QColor &c)
{
    if (m_fill == c)
        return;
    m_fill = c;
    emit fillColorChanged();
    update();
}

void BlobField::setEdgeColor(const QColor &c)
{
    if (m_edge == c)
        return;
    m_edge = c;
    emit edgeColorChanged();
    update();
}

void BlobField::setEdgeWidth(qreal w)
{
    if (qFuzzyCompare(m_edgeWidth + 1, w + 1))
        return;
    m_edgeWidth = w;
    pack();
    emit edgeWidthChanged();
    update();
}

void BlobField::setShadowColor(const QColor &c)
{
    if (m_shadow == c)
        return;
    m_shadow = c;
    emit shadowColorChanged();
    update();
}

void BlobField::setShadowSize(qreal s)
{
    s = std::max<qreal>(0, s);
    if (qFuzzyCompare(m_shadowSize + 1, s + 1))
        return;
    m_shadowSize = s;
    pack();
    emit shadowSizeChanged();
    update();
}

void BlobField::setShadowStrength(qreal s)
{
    s = std::clamp<qreal>(s, 0, 1);
    if (qFuzzyCompare(m_shadowStrength + 1, s + 1))
        return;
    m_shadowStrength = s;
    pack();
    emit shadowStrengthChanged();
    update();
}

void BlobField::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    if (newGeometry.size() != oldGeometry.size()) {
        pack();
        update();
    }
}

qreal BlobField::gapBetween(const QVariantMap &a, const QVariantMap &b) const
{
    const QRectF ra(num(a, "x"), num(a, "y"), num(a, "w"), num(a, "h"));
    const QRectF rb(num(b, "x"), num(b, "y"), num(b, "w"), num(b, "h"));
    return boxGap(ra, rb);
}

void BlobField::pack()
{
    auto p = QSharedPointer<BlobPack>::create();
    const float k = float(m_smoothing);
    p->smoothing = k;
    const bool shadowOn = m_shadowSize > 0 && m_shadowStrength > 0;
    const float pad = k + std::max(shadowOn ? float(m_shadowSize) : 0.f, m_edgeWidth > 0 ? float(m_edgeWidth) + 2.f : 0.f) + 2.f;
    const QRect bounds(0, 0, int(std::ceil(width())), int(std::ceil(height())));
    if (bounds.isEmpty()) {
        m_pack = p;
        m_pieces.clear();
        return;
    }

    int dropped = 0;
    for (const QVariant &bv : m_blobs) {
        const QVariantMap b = bv.toMap();
        const float w = num(b, "w"), h = num(b, "h");
        if (!(w > 0.01f) || !(h > 0.01f))
            continue;
        if (p->count >= kBlobMax) {
            ++dropped;
            continue;
        }
        const float x = num(b, "x"), y = num(b, "y");
        const float r = num(b, "r");
        const int i = p->count++;
        p->rect[i] = QVector4D(x + w / 2, y + h / 2, w / 2, h / 2);
        p->radii[i] = QVector4D(num(b, "rtl", r), num(b, "rtr", r), num(b, "rbl", r), num(b, "rbr", r));
        p->extra[i] = QVector4D(num(b, "merge", 1.f), num(b, "frameMerge", 1.f), std::clamp(num(b, "clear"), 0.f, 1.f), num(b, "goo"));
        const int rgb = int(num(b, "tintRgb"));
        p->paint[i] = QVector4D(float((rgb >> 16) & 255) / 255.f, float((rgb >> 8) & 255) / 255.f, float(rgb & 255) / 255.f,
                                std::clamp(num(b, "tint"), 0.f, 1.f));
        p->bounds[i] = QRectF(x, y, w, h);
    }
    if (dropped > 0 && dropped != m_dropped)
        qWarning("BlobField: %d blobs over the limit of %d were not drawn", dropped, kBlobMax);
    m_dropped = dropped;

    const bool frameOn = num(m_frame, "on") > 0.f;
    const float fl = frameOn ? num(m_frame, "left") : 0.f, ft = frameOn ? num(m_frame, "top") : 0.f;
    const float fr = frameOn ? num(m_frame, "right") : 0.f, fb = frameOn ? num(m_frame, "bottom") : 0.f;
    p->frameOn = frameOn;
    p->frameHole = QVector4D(fl, ft, float(width()) - fr, float(height()) - fb);
    p->frameRad = frameOn ? QVector4D(num(m_frame, "tl"), num(m_frame, "tr"), num(m_frame, "bl"), num(m_frame, "br")) : QVector4D();

    const int rr = int(std::ceil(std::max({ p->frameRad.x(), p->frameRad.y(), p->frameRad.z(), p->frameRad.w() })));
    const auto ring = [&](float inset) {
        const int il = int(std::ceil(fl + inset)), it = int(std::ceil(ft + inset));
        const int ir = int(std::floor(float(width()) - fr - inset)), ib = int(std::floor(float(height()) - fb - inset));
        QRegion inner;
        if (ir - il > 2 * rr && ib - it > 0)
            inner += QRect(QPoint(il + rr, it), QPoint(ir - rr, ib));
        if (ib - it > 2 * rr && ir - il > 0)
            inner += QRect(QPoint(il, it + rr), QPoint(ir, ib - rr));
        return QRegion(bounds).subtracted(inner);
    };
    const QRegion edgeBand = ring(pad);
    const QRegion visibleFrame = frameOn ? ring(2.f + (shadowOn ? float(m_shadowSize) : 0.f)) : QRegion();

    QRegion covered;
    std::vector<QRectF> padded(size_t(p->count));
    for (int i = 0; i < p->count; ++i) {
        padded[size_t(i)] = p->bounds[i].adjusted(-pad, -pad, pad, pad);
        const QRectF &q = padded[size_t(i)];
        const int x0 = int(std::floor(q.left())), y0 = int(std::floor(q.top()));
        covered += QRect(x0, y0, int(std::ceil(q.right())) - x0, int(std::ceil(q.bottom())) - y0).intersected(bounds);
    }
    const QRegion all = covered.united(visibleFrame);

    constexpr int kTile = 160;
    std::vector<QRect> tiles;
    for (const QRect &big : all) {
        for (int ty = big.top(); ty <= big.bottom(); ty += kTile) {
            for (int tx = big.left(); tx <= big.right(); tx += kTile)
                tiles.push_back(QRect(tx, ty, std::min(kTile, big.right() - tx + 1), std::min(kTile, big.bottom() - ty + 1)));
        }
    }

    std::vector<BlobPiece> pieces;
    int overflow = 0;
    for (const QRect &r : tiles) {
        BlobPiece piece;
        piece.rect = r;
        for (int i = 0; i < p->count; ++i) {
            if (padded[size_t(i)].intersects(QRectF(r))) {
                if (int(piece.blobs.size()) >= kBlobLocal) {
                    ++overflow;
                    continue;
                }
                piece.blobs.push_back(i);
            }
        }
        piece.frame = edgeBand.intersects(r);
        if (piece.blobs.empty() && !(piece.frame && frameOn))
            continue;
        pieces.push_back(std::move(piece));
    }
    if (overflow > 0)
        qWarning("BlobField: %d blob references over the per-piece limit of %d were skipped", overflow, kBlobLocal);

    const bool countChanged = pieces.size() != m_pieces.size();
    m_pieces = std::move(pieces);
    m_pack = p;
    if (countChanged)
        emit piecesChanged();
}

QSGNode *BlobField::updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *)
{
    QSGNode *root = oldNode ? oldNode : new QSGNode;
    QSGNode *child = root->firstChild();
    const bool shadowOn = m_shadowSize > 0 && m_shadowStrength > 0;
    for (const BlobPiece &piece : m_pieces) {
        auto *node = static_cast<QSGGeometryNode *>(child);
        if (!node) {
            node = new QSGGeometryNode;
            auto *geo = new QSGGeometry(QSGGeometry::defaultAttributes_TexturedPoint2D(), 4);
            geo->setDrawingMode(QSGGeometry::DrawTriangleStrip);
            node->setGeometry(geo);
            node->setFlag(QSGNode::OwnsGeometry);
            auto *mat = new BlobMaterial;
            mat->setFlag(QSGMaterial::Blending);
            node->setMaterial(mat);
            node->setFlag(QSGNode::OwnsMaterial);
            root->appendChildNode(node);
        }
        const QRect &r = piece.rect;
        const float x0 = float(r.x()), y0 = float(r.y());
        const float x1 = float(r.x() + r.width()), y1 = float(r.y() + r.height());
        auto *v = node->geometry()->vertexDataAsTexturedPoint2D();
        v[0].set(x0, y0, x0, y0);
        v[1].set(x1, y0, x1, y0);
        v[2].set(x0, y1, x0, y1);
        v[3].set(x1, y1, x1, y1);
        node->markDirty(QSGNode::DirtyGeometry);
        auto *mat = static_cast<BlobMaterial *>(node->material());
        mat->pack = m_pack;
        mat->blobs = piece.blobs;
        mat->frame = piece.frame;
        mat->fill = m_fill;
        mat->edge = m_edge;
        mat->edgeW = float(m_edgeWidth);
        mat->shadow = m_shadow;
        mat->shadowSize = shadowOn ? float(m_shadowSize) : 0.f;
        mat->shadowStrength = shadowOn ? float(m_shadowStrength) : 0.f;
        node->markDirty(QSGNode::DirtyMaterial);
        child = node->nextSibling();
    }
    while (child) {
        QSGNode *next = child->nextSibling();
        root->removeChildNode(child);
        delete child;
        child = next;
    }
    return root;
}

}
