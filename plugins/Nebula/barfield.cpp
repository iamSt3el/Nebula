#include "barfield.h"

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
constexpr int kOffFieldCount = 72;
constexpr int kOffMask = 76;
constexpr int kOffFill = 80;
constexpr int kOffEdge = 96;
constexpr int kOffCounts = 112;
constexpr int kOffFrameHole = 128;
constexpr int kOffFrameRad = 144;
constexpr int kOffMap = 160;
constexpr int kOffInfo = kOffMap + 16 * kFieldMax;
constexpr int kOffPill = kOffInfo + 16 * kFieldMax;
constexpr int kOffSeg = kOffPill + 16 * kPillMax * 3;
constexpr int kOffFlare = kOffSeg + 16 * kSegMax * 3;
constexpr int kOffTab = kOffFlare + 16 * kFlareMax;
constexpr int kOffShadow = kOffTab + 16 * kTabMax * 7;
constexpr int kUniformSize = kOffShadow + 32;

class FieldMaterial : public QSGMaterial {
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

    QSharedPointer<FieldPack> pack;
    int mask = 0;
    QColor fill;
    QColor edge;
    float edgeW = 0;
    QColor shadow;
    float shadowSize = 0;
    float shadowStrength = 0;
};

class FieldShader : public QSGMaterialShader {
public:
    FieldShader()
    {
        setShaderFileName(VertexStage, QStringLiteral(":/shaders/barfield.vert.qsb"));
        setShaderFileName(FragmentStage, QStringLiteral(":/shaders/barfield.frag.qsb"));
    }

    bool updateUniformData(RenderState &state, QSGMaterial *newMaterial, QSGMaterial *) override
    {
        auto *m = static_cast<FieldMaterial *>(newMaterial);
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
        const FieldPack *p = m->pack.data();
        if (!p)
            return true;
        std::memcpy(d + kOffEdgeW, &m->edgeW, 4);
        std::memcpy(d + kOffFieldCount, &p->fieldCount, 4);
        std::memcpy(d + kOffMask, &m->mask, 4);
        const float fill[4] = { float(m->fill.redF()), float(m->fill.greenF()), float(m->fill.blueF()), float(m->fill.alphaF()) };
        const float edge[4] = { float(m->edge.redF()), float(m->edge.greenF()), float(m->edge.blueF()), float(m->edge.alphaF()) };
        std::memcpy(d + kOffFill, fill, 16);
        std::memcpy(d + kOffEdge, edge, 16);
        const int counts[4] = { p->pillCount, p->segCount, p->flareCount, p->tabCount };
        std::memcpy(d + kOffCounts, counts, 16);
        std::memcpy(d + kOffFrameHole, &p->frameHole, 16);
        std::memcpy(d + kOffFrameRad, &p->frameRad, 16);
        std::memcpy(d + kOffMap, p->map, 16 * kFieldMax);
        std::memcpy(d + kOffInfo, p->info, 16 * kFieldMax);
        std::memcpy(d + kOffPill, p->pill, 16 * 3 * p->pillCount);
        std::memcpy(d + kOffSeg, p->seg, 16 * 3 * p->segCount);
        std::memcpy(d + kOffFlare, p->flare, 16 * p->flareCount);
        std::memcpy(d + kOffTab, p->tab, 16 * 7 * p->tabCount);
        const float shadow[8] = { float(m->shadow.redF()), float(m->shadow.greenF()), float(m->shadow.blueF()), float(m->shadow.alphaF()),
                                  m->shadowSize, m->shadowStrength, 0.f, 0.f };
        std::memcpy(d + kOffShadow, shadow, 32);
        return true;
    }
};

QSGMaterialShader *FieldMaterial::createShader(QSGRendererInterface::RenderMode) const
{
    return new FieldShader;
}

float num(const QVariantMap &m, const char *key)
{
    const auto it = m.constFind(QLatin1String(key));
    if (it == m.constEnd())
        return 0.f;
    bool ok = false;
    const double v = it->toDouble(&ok);
    return ok && std::isfinite(v) ? float(v) : 0.f;
}

QVector4D v4(const QVariantMap &m, const char *a, const char *b, const char *c, const char *e)
{
    return QVector4D(num(m, a), num(m, b), num(m, c), num(m, e));
}

QRect snapped(const QVariant &v)
{
    QRectF r;
    if (v.canConvert<QRectF>() && v.metaType().id() != QMetaType::QVariantMap) {
        r = v.toRectF();
    } else {
        const QVariantMap m = v.toMap();
        r = QRectF(num(m, "x"), num(m, "y"), num(m, "width"), num(m, "height"));
    }
    if (!(r.width() > 0) || !(r.height() > 0))
        return QRect();
    const int x = int(std::floor(r.x()));
    const int y = int(std::floor(r.y()));
    return QRect(x, y, int(std::ceil(r.x() + r.width())) - x, int(std::ceil(r.y() + r.height())) - y);
}

}

BarField::BarField(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents);
}

void BarField::setFields(const QVariantList &fields)
{
    if (m_fields == fields)
        return;
    m_fields = fields;
    pack();
    emit fieldsChanged();
    update();
}

void BarField::setFrame(const QVariantMap &frame)
{
    if (m_frame == frame)
        return;
    m_frame = frame;
    pack();
    emit frameChanged();
    update();
}

void BarField::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    if (newGeometry.size() != oldGeometry.size()) {
        pack();
        update();
    }
}

void BarField::setFillColor(const QColor &c)
{
    if (m_fill == c)
        return;
    m_fill = c;
    emit fillColorChanged();
    update();
}

void BarField::setEdgeColor(const QColor &c)
{
    if (m_edge == c)
        return;
    m_edge = c;
    emit edgeColorChanged();
    update();
}

void BarField::setEdgeWidth(qreal w)
{
    if (qFuzzyCompare(m_edgeWidth + 1, w + 1))
        return;
    m_edgeWidth = w;
    pack();
    emit edgeWidthChanged();
    update();
}

void BarField::setShadowColor(const QColor &c)
{
    if (m_shadow == c)
        return;
    m_shadow = c;
    emit shadowColorChanged();
    update();
}

void BarField::setShadowSize(qreal s)
{
    s = std::max<qreal>(0, s);
    if (qFuzzyCompare(m_shadowSize + 1, s + 1))
        return;
    m_shadowSize = s;
    pack();
    emit shadowSizeChanged();
    update();
}

void BarField::setShadowStrength(qreal s)
{
    s = std::clamp<qreal>(s, 0, 1);
    if (qFuzzyCompare(m_shadowStrength + 1, s + 1))
        return;
    m_shadowStrength = s;
    pack();
    emit shadowStrengthChanged();
    update();
}

void BarField::pack()
{
    const bool shadowOn = m_shadowSize > 0 && m_shadowStrength > 0;
    const int grow = std::max(shadowOn ? int(std::ceil(m_shadowSize)) : 0,
                              m_edgeWidth > 0 ? int(std::ceil(m_edgeWidth)) + 2 : 0);
    const QRect bounds(0, 0, int(std::ceil(width())), int(std::ceil(height())));
    auto p = QSharedPointer<FieldPack>::create();
    int f = 0;
    int dropped = 0;
    for (const QVariant &fv : m_fields) {
        if (f >= kFieldMax)
            break;
        const QVariantMap fm = fv.toMap();
        if (fm.isEmpty())
            continue;
        p->map[f] = v4(fm, "swap", "flip", "z", "own");
        p->info[f] = v4(fm, "top", "bot", "rMax", "cut");
        p->area[f] = snapped(fm.value(QStringLiteral("area")));
        if (grow > 0 && !p->area[f].isEmpty())
            p->area[f] = p->area[f].adjusted(-grow, -grow, grow, grow).intersected(bounds);
        const float tag = float(f);

        for (const QVariant &qv : fm.value(QStringLiteral("pills")).toList()) {
            if (p->pillCount >= kPillMax) {
                ++dropped;
                continue;
            }
            const QVariantMap q = qv.toMap();
            QVector4D *o = p->pill + 3 * p->pillCount++;
            o[0] = v4(q, "l", "r", "bot", "top");
            o[1] = v4(q, "rtl", "rtr", "rbl", "rbr");
            o[2] = QVector4D(tag, num(q, "clear"), num(q, "tintRgb"), num(q, "tint"));
        }
        for (const QVariant &sv : fm.value(QStringLiteral("segs")).toList()) {
            if (p->segCount >= kSegMax) {
                ++dropped;
                continue;
            }
            const QVariantMap s = sv.toMap();
            QVector4D *o = p->seg + 3 * p->segCount++;
            o[0] = v4(s, "x", "w", "bot", "gap");
            o[1] = v4(s, "lineL", "raL", "lineR", "raR");
            o[2] = QVector4D(num(s, "rl"), num(s, "rr"), tag, 0);
        }
        for (const QVariant &cv : fm.value(QStringLiteral("flares")).toList()) {
            if (p->flareCount >= kFlareMax) {
                ++dropped;
                continue;
            }
            const QVariantMap c = cv.toMap();
            p->flare[p->flareCount++] = QVector4D(num(c, "x"), num(c, "y"), num(c, "r"), num(c, "mode") + 8.f * tag);
        }
        for (const QVariant &tv : fm.value(QStringLiteral("tabs")).toList()) {
            if (p->tabCount >= kTabMax) {
                ++dropped;
                continue;
            }
            const QVariantMap t = tv.toMap();
            QVector4D *o = p->tab + 7 * p->tabCount++;
            const bool goo = num(t, "goo") > 0.f;
            const bool merged = num(t, "merged") > 0.f;
            o[0] = v4(t, "x", "w", "bot", "top");
            o[1] = goo ? QVector4D(num(t, "rtl"), num(t, "k"), num(t, "hostRad"), 0) : v4(t, "rtl", "rtr", "rbl", "rbr");
            o[2] = v4(t, "lineL", "rfL", "lineR", "rfR");
            o[3] = v4(t, "flL", "mL", "flR", "mR");
            o[4] = v4(t, "conL", "onL", "conR", "onR");
            o[5] = merged ? v4(t, "mR0", "mL0", "nb", "e") : goo ? v4(t, "hostL", "hostR", "hostT", "hostB") : QVector4D();
            o[6] = QVector4D(tag, num(t, "sinkL"), num(t, "sinkR"), 0);
        }
        ++f;
    }
    p->fieldCount = f;
    if (dropped > 0 && dropped != m_dropped)
        qWarning("BarField: %d shapes over the limit were not drawn (pills %d/%d, segs %d/%d, flares %d/%d, tabs %d/%d)",
                 dropped, p->pillCount, kPillMax, p->segCount, kSegMax, p->flareCount, kFlareMax, p->tabCount, kTabMax);
    m_dropped = dropped;

    constexpr int kFrameBit = 1 << 8;
    QRegion frameBand;
    if (num(m_frame, "on") > 0.f && width() > 0 && height() > 0) {
        const float l = num(m_frame, "left"), t = num(m_frame, "top");
        const float r = num(m_frame, "right"), b = num(m_frame, "bottom");
        const float x1 = float(width()) - r, y1 = float(height()) - b;
        if (x1 > l && y1 > t) {
            p->frameOn = true;
            p->frameHole = QVector4D(l, t, x1, y1);
            p->frameRad = QVector4D(num(m_frame, "tl"), num(m_frame, "tr"), num(m_frame, "bl"), num(m_frame, "br"));
            const QRect outer(0, 0, int(std::ceil(width())), int(std::ceil(height())));
            const float rad = std::max({ p->frameRad.x(), p->frameRad.y(), p->frameRad.z(), p->frameRad.w() });
            const int il = int(std::ceil(l)) + 2 + grow, it = int(std::ceil(t)) + 2 + grow;
            const int ir = int(std::floor(x1)) - 2 - grow, ib = int(std::floor(y1)) - 2 - grow;
            const int rr = int(std::ceil(rad));
            QRegion inner;
            if (ir - il > 2 * rr && ib - it > 0)
                inner += QRect(QPoint(il + rr, it), QPoint(ir - rr, ib));
            if (ib - it > 2 * rr && ir - il > 0)
                inner += QRect(QPoint(il, it + rr), QPoint(ir, ib - rr));
            frameBand = QRegion(outer).subtracted(inner);
        }
    }

    std::vector<FieldPiece> pieces;
    QRegion covered;
    for (const QRect &r : frameBand) {
        int mask = kFrameBit;
        for (int j = 0; j < f; ++j) {
            if (!p->area[j].isEmpty() && p->area[j].intersects(r))
                mask |= 1 << j;
        }
        pieces.push_back({ r, mask });
    }
    covered = frameBand;
    for (int i = 0; i < f; ++i) {
        const QRect a = p->area[i];
        if (a.isEmpty())
            continue;
        const QRegion fresh = QRegion(a).subtracted(covered);
        covered += a;
        for (const QRect &r : fresh) {
            int mask = 0;
            for (int j = 0; j < f; ++j) {
                if (!p->area[j].isEmpty() && p->area[j].intersects(r))
                    mask |= 1 << j;
            }
            if (!frameBand.isEmpty() && frameBand.intersects(r))
                mask |= kFrameBit;
            pieces.push_back({ r, mask });
        }
    }
    const bool countChanged = pieces.size() != m_pieces.size();
    m_pieces = std::move(pieces);
    m_pack = p;
    if (countChanged)
        emit piecesChanged();
}

QSGNode *BarField::updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *)
{
    QSGNode *root = oldNode ? oldNode : new QSGNode;
    int i = 0;
    QSGNode *child = root->firstChild();
    for (const FieldPiece &piece : m_pieces) {
        auto *node = static_cast<QSGGeometryNode *>(child);
        if (!node) {
            node = new QSGGeometryNode;
            auto *geo = new QSGGeometry(QSGGeometry::defaultAttributes_TexturedPoint2D(), 4);
            geo->setDrawingMode(QSGGeometry::DrawTriangleStrip);
            node->setGeometry(geo);
            node->setFlag(QSGNode::OwnsGeometry);
            auto *mat = new FieldMaterial;
            mat->setFlag(QSGMaterial::Blending);
            node->setMaterial(mat);
            node->setFlag(QSGNode::OwnsMaterial);
            root->appendChildNode(node);
        }
        const QRect &r = piece.rect;
        const float x0 = float(r.x());
        const float y0 = float(r.y());
        const float x1 = float(r.x() + r.width());
        const float y1 = float(r.y() + r.height());
        auto *v = node->geometry()->vertexDataAsTexturedPoint2D();
        v[0].set(x0, y0, x0, y0);
        v[1].set(x1, y0, x1, y0);
        v[2].set(x0, y1, x0, y1);
        v[3].set(x1, y1, x1, y1);
        node->markDirty(QSGNode::DirtyGeometry);
        auto *mat = static_cast<FieldMaterial *>(node->material());
        mat->pack = m_pack;
        mat->mask = piece.mask;
        mat->fill = m_fill;
        mat->edge = m_edge;
        mat->edgeW = float(m_edgeWidth);
        mat->shadow = m_shadow;
        const bool shadowOn = m_shadowSize > 0 && m_shadowStrength > 0;
        mat->shadowSize = shadowOn ? float(m_shadowSize) : 0.f;
        mat->shadowStrength = shadowOn ? float(m_shadowStrength) : 0.f;
        node->markDirty(QSGNode::DirtyMaterial);
        child = node->nextSibling();
        ++i;
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
