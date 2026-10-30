#include "cuttext.h"

#include <QFont>
#include <QPainter>
#include <QPainterPathStroker>
#include <QTransform>
#include <QtMath>

#include <algorithm>
#include <functional>
#include <cmath>

namespace {

constexpr qreal kScale = 2.0;
constexpr qreal kTolerance = 0.15;

void decimate(const QPolygonF &in, int a, int b, qreal tol, QList<bool> &keep)
{
    if (b <= a + 1)
        return;
    const QPointF p = in[a];
    const QPointF d = in[b] - p;
    const qreal dl = std::hypot(d.x(), d.y());
    qreal worst = -1;
    int at = -1;
    for (int i = a + 1; i < b; ++i) {
        const QPointF v = in[i] - p;
        const qreal dist = dl > 0 ? std::abs(d.x() * v.y() - d.y() * v.x()) / dl : std::hypot(v.x(), v.y());
        if (dist > worst) {
            worst = dist;
            at = i;
        }
    }
    if (worst > tol) {
        keep[at] = true;
        decimate(in, a, at, tol, keep);
        decimate(in, at, b, tol, keep);
    }
}

QPainterPath lean(const QPainterPath &path, qreal tol)
{
    QPainterPath out;
    out.setFillRule(Qt::OddEvenFill);
    const QList<QPolygonF> polys = path.toSubpathPolygons();
    for (QPolygonF poly : polys) {
        if (poly.size() > 1 && poly.first() == poly.last())
            poly.removeLast();
        const int n = poly.size();
        if (n < 3)
            continue;
        QList<bool> keep(n, false);
        keep[0] = true;
        keep[n - 1] = true;
        decimate(poly, 0, n - 1, tol, keep);
        QPolygonF thin;
        for (int i = 0; i < n; ++i)
            if (keep[i])
                thin.append(poly[i]);
        if (thin.size() >= 3) {
            out.addPolygon(thin);
            out.closeSubpath();
        }
    }
    return out;
}

QPainterPath ringOf(const QPainterPath &p, qreal by)
{
    QPainterPathStroker s;
    s.setWidth(2 * by);
    s.setJoinStyle(Qt::RoundJoin);
    s.setCapStyle(Qt::RoundCap);
    return s.createStroke(p);
}

qreal len(const QPointF &v)
{
    return std::hypot(v.x(), v.y());
}

QPolygonF cleaned(const QPolygonF &in)
{
    QPolygonF out;
    for (const QPointF &p : in)
        if (out.isEmpty() || len(p - out.last()) > 0.05)
            out.append(p);
    while (out.size() > 2 && len(out.first() - out.last()) <= 0.05)
        out.removeLast();
    return out;
}

void addRounded(QPainterPath &path, const QPolygonF &raw, qreal r, const std::function<bool(const QPointF &)> &cutAt)
{
    const QPolygonF poly = cleaned(raw);
    const int n = poly.size();
    if (n < 3)
        return;
    if (r <= 0) {
        path.addPolygon(poly);
        path.closeSubpath();
        return;
    }

    QList<qreal> turn(n);
    QList<qreal> seg(n);
    for (int i = 0; i < n; ++i) {
        const QPointF a = poly[(i + n - 1) % n];
        const QPointF b = poly[i];
        const QPointF c = poly[(i + 1) % n];
        const QPointF u = b - a;
        const QPointF v = c - b;
        seg[i] = len(v);
        turn[i] = std::abs(std::atan2(u.x() * v.y() - u.y() * v.x(), u.x() * v.x() + u.y() * v.y()));
    }

    const qreal minTurn = qDegreesToRadians(25.0);
    QList<int> corners;
    for (int i = 0; i < n; ++i)
        if (turn[i] >= minTurn && turn[i] < qDegreesToRadians(175.0) && cutAt(poly[i]))
            corners.append(i);
    if (corners.isEmpty()) {
        path.addPolygon(poly);
        path.closeSubpath();
        return;
    }

    auto along = [&](int from, int to) {
        qreal d = 0;
        for (int k = from; k != to; k = (k + 1) % n)
            d += seg[k];
        return d;
    };
    auto walk = [&](int i, qreal d, bool back, int &stop) {
        int k = i;
        while (true) {
            const int nb = back ? (k + n - 1) % n : (k + 1) % n;
            const qreal l = len(poly[nb] - poly[k]);
            if (l >= d || nb == i) {
                stop = k;
                const qreal t = l > 0 ? std::min(1.0, d / l) : 0;
                return poly[k] + (poly[nb] - poly[k]) * t;
            }
            d -= l;
            k = nb;
        }
    };

    const int m = corners.size();
    QList<QPointF> inPt(m), outPt(m);
    QList<int> inStop(m), outStop(m);
    for (int c = 0; c < m; ++c) {
        const int i = corners[c];
        const int prev = corners[(c + m - 1) % m];
        const int next = corners[(c + 1) % m];
        const qreal back = m == 1 ? along((i + 1) % n, i) : along(prev, i);
        const qreal fwd = m == 1 ? along(i, (i + n - 1) % n) : along(i, next);
        const qreal d = std::min({ r * std::tan(turn[i] / 2), 0.45 * back, 0.45 * fwd });
        inPt[c] = walk(i, d, true, inStop[c]);
        outPt[c] = walk(i, d, false, outStop[c]);
    }

    path.moveTo(outPt[0]);
    for (int c = 0; c < m; ++c) {
        const int nc = (c + 1) % m;
        for (int k = (outStop[c] + 1) % n; k != inStop[nc] && k != corners[nc]; k = (k + 1) % n)
            path.lineTo(poly[k]);
        path.lineTo(inPt[nc]);
        path.quadTo(poly[corners[nc]], outPt[nc]);
    }
    path.closeSubpath();
}

qreal polyArea(const QPolygonF &poly)
{
    qreal a = 0;
    for (int i = 0, n = poly.size(); i < n; ++i) {
        const QPointF &p = poly[i];
        const QPointF &q = poly[(i + 1) % n];
        a += p.x() * q.y() - q.x() * p.y();
    }
    return std::abs(a) / 2;
}

QPainterPath finish(const QPainterPath &p, qreal ratio, qreal r, const std::function<bool(const QPointF &)> &cutAt)
{
    const QList<QPolygonF> polys = p.toSubpathPolygons();
    const int n = polys.size();
    QList<qreal> area(n);
    for (int i = 0; i < n; ++i)
        area[i] = polyArea(polys[i]);

    QList<int> owner(n, -1);
    for (int i = 0; i < n; ++i) {
        if (polys[i].isEmpty())
            continue;
        int depth = 0;
        int smallest = -1;
        for (int j = 0; j < n; ++j) {
            if (j == i || area[j] <= area[i] || polys[j].isEmpty())
                continue;
            if (polys[j].containsPoint(polys[i].first(), Qt::OddEvenFill)) {
                ++depth;
                if (smallest < 0 || area[j] < area[smallest])
                    smallest = j;
            }
        }
        if (depth % 2 == 1)
            owner[i] = smallest;
    }

    QList<qreal> net(n, 0);
    for (int i = 0; i < n; ++i) {
        if (owner[i] < 0)
            net[i] += area[i];
        else
            net[owner[i]] -= area[i];
    }
    qreal largest = 0;
    for (int i = 0; i < n; ++i)
        if (owner[i] < 0)
            largest = std::max(largest, net[i]);

    QPainterPath out;
    out.setFillRule(Qt::OddEvenFill);
    for (int i = 0; i < n; ++i) {
        int outer = i;
        while (owner[outer] >= 0)
            outer = owner[outer];
        if (net[outer] >= ratio * largest)
            addRounded(out, polys[i], r, cutAt);
    }
    return out;
}

bool sameShape(const QVariantList &a, const QVariantList &b)
{
    if (a.size() != b.size())
        return false;
    for (qsizetype i = 0; i < a.size(); ++i) {
        const QVariantMap x = a[i].toMap();
        const QVariantMap y = b[i].toMap();
        if (x.value("ch") != y.value("ch") || x.value("x") != y.value("x") || x.value("y") != y.value("y"))
            return false;
    }
    return true;
}

}

CutText::CutText(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
}

void CutText::invalidate()
{
    m_dirty = true;
    emit changed();
    update();
}

void CutText::setGlyphs(const QVariantList &v)
{
    if (m_glyphs == v)
        return;
    const bool recolor = !m_dirty && sameShape(m_glyphs, v);
    m_glyphs = v;
    if (!recolor) {
        invalidate();
        return;
    }
    m_colors.clear();
    for (const QVariant &g : std::as_const(m_glyphs))
        m_colors.append(g.toMap().value("color").value<QColor>());
    emit changed();
    update();
}

void CutText::setFamily(const QString &v)
{
    if (m_family == v)
        return;
    m_family = v;
    invalidate();
}

void CutText::setPx(int v)
{
    if (m_px == v)
        return;
    m_px = v;
    invalidate();
}

void CutText::setRing(qreal v)
{
    if (qFuzzyCompare(m_ring, v))
        return;
    m_ring = v;
    invalidate();
}

void CutText::setRound(qreal v)
{
    if (qFuzzyCompare(m_round, v))
        return;
    m_round = v;
    invalidate();
}

void CutText::setIslandRatio(qreal v)
{
    if (qFuzzyCompare(m_islandRatio, v))
        return;
    m_islandRatio = v;
    invalidate();
}

void CutText::setWeight(int v)
{
    if (m_weight == v)
        return;
    m_weight = v;
    invalidate();
}

void CutText::setAxes(const QVariantMap &v)
{
    if (m_axes == v)
        return;
    m_axes = v;
    invalidate();
}

void CutText::rebuild()
{
    m_dirty = false;
    m_paths.clear();
    m_colors.clear();

    QFont font(m_family);
    font.setPixelSize(std::max(1, int(std::lround(m_px * kScale))));
    font.setHintingPreference(QFont::PreferNoHinting);
    font.setKerning(false);
    if (m_weight > 0)
        font.setWeight(QFont::Weight(std::clamp(m_weight, 1, 1000)));
    for (auto it = m_axes.cbegin(); it != m_axes.cend(); ++it) {
        if (const auto tag = QFont::Tag::fromString(it.key()))
            font.setVariableAxis(*tag, it.value().toFloat());
    }

    QList<QPainterPath> shapes;
    for (const QVariant &g : std::as_const(m_glyphs)) {
        const QVariantMap m = g.toMap();
        QPainterPath p;
        p.addText(QPointF(m.value("x").toReal() * kScale, m.value("y").toReal() * kScale), font,
                  m.value("ch").toString());
        p.setFillRule(Qt::WindingFill);
        shapes.append(lean(p.simplified(), kTolerance * kScale));
        m_colors.append(m.value("color").value<QColor>());
    }

    const int n = shapes.size();
    QList<QPainterPath> rings(n);
    QList<QPainterPath> near(n);
    for (int j = 0; j < n; ++j) {
        rings[j] = ringOf(shapes[j], m_ring * kScale);
        near[j] = ringOf(shapes[j], (m_ring + 1.5) * kScale);
    }

    const QTransform down = QTransform::fromScale(1 / kScale, 1 / kScale);
    for (int i = 0; i < n; ++i) {
        QPainterPath piece = shapes[i];
        for (int j = i + 1; j < n; ++j) {
            if (!piece.boundingRect().intersects(rings[j].boundingRect()))
                continue;
            piece = piece.subtracted(shapes[j]).subtracted(rings[j]);
        }
        if (i < n - 1)
            piece = finish(piece, m_islandRatio, m_round * kScale, [&](const QPointF &pt) {
                for (int j = i + 1; j < n; ++j)
                    if (near[j].boundingRect().contains(pt) && near[j].contains(pt))
                        return true;
                return false;
            });
        m_paths.append(down.map(piece));
    }
}

void CutText::paint(QPainter *painter)
{
    if (m_dirty)
        rebuild();
    painter->setRenderHint(QPainter::Antialiasing);
    painter->setPen(Qt::NoPen);
    for (int i = 0; i < m_paths.size(); ++i) {
        painter->setBrush(m_colors.value(i));
        painter->drawPath(m_paths[i]);
    }
}
