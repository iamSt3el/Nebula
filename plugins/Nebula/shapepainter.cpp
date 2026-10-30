#include "shapepainter.h"
#include <QPainterPathStroker>
#include <QTransform>

#include <QPainter>
#include <QPainterPath>

#include <algorithm>
#include <cmath>

ShapePainter::ShapePainter(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
}

template <typename T>
void ShapePainter::setStyle(T &field, const T &value)
{
    if (field == value)
        return;
    field = value;
    emit styleChanged();
    refresh();
}

void ShapePainter::setColor(const QColor &v) { setStyle(m_color, v); }
void ShapePainter::setBorderWidth(qreal v) { setStyle(m_borderWidth, v); }
void ShapePainter::setBorderColor(const QColor &v) { setStyle(m_borderColor, v); }
void ShapePainter::setDebug(bool v) { setStyle(m_debug, v); }
void ShapePainter::setStretchToFill(bool v) { setStyle(m_stretch, v); }
void ShapePainter::setPolygonIsNormalized(bool v) { setStyle(m_normalized, v); }
void ShapePainter::setStrokeProgress(qreal v) { setStyle(m_strokeProgress, v); }
void ShapePainter::setStrokeWidth(qreal v) { setStyle(m_strokeWidth, v); }
void ShapePainter::setTrackGap(qreal v) { setStyle(m_trackGap, v); }
void ShapePainter::setStrokeColor(const QColor &v) { setStyle(m_strokeColor, v); }
void ShapePainter::setStrokeTrackColor(const QColor &v) { setStyle(m_strokeTrackColor, v); }
void ShapePainter::setAngle(qreal v) { setStyle(m_angle, v); }
void ShapePainter::setFillLevel(qreal v) { setStyle(m_fillLevel, v); }
void ShapePainter::setLevelColor(const QColor &v) { setStyle(m_levelColor, v); }
void ShapePainter::setSweepLevel(qreal v) { setStyle(m_sweepLevel, v); }

QTransform ShapePainter::spin(const QPainterPath &shape, qreal pad) const
{
    QTransform t;
    if (std::fmod(m_angle, 360.0) == 0 || shape.isEmpty())
        return t;
    const QPointF c(width() / 2, height() / 2);
    QTransform r;
    r.translate(c.x(), c.y());
    r.rotate(m_angle);
    r.translate(-c.x(), -c.y());
    const QRectF before = shape.boundingRect().adjusted(-pad, -pad, pad, pad);
    const QRectF turned = r.map(shape).boundingRect().adjusted(-pad, -pad, pad, pad);
    const qreal fit = std::min({ 1.0, std::max(before.width(), width()) / turned.width(),
                                 std::max(before.height(), height()) / turned.height() });
    t.translate(c.x(), c.y());
    t.scale(fit, fit);
    t.rotate(m_angle);
    t.translate(-c.x(), -c.y());
    return t;
}

void ShapePainter::setFromShape(const QString &v)
{
    if (m_from == v)
        return;
    m_from = v;
    rebuildMorph();
}

void ShapePainter::setToShape(const QString &v)
{
    if (m_to == v)
        return;
    m_to = v;
    rebuildMorph();
}

void ShapePainter::setProgress(qreal v)
{
    if (m_progress == v)
        return;
    m_progress = v;
    emit progressChanged();
    refresh();
}

void ShapePainter::rebuildMorph()
{
    m_morph = mshape::morph(m_from, m_to);
    m_boundsW = 0;
    m_boundsH = 0;
    if (const mshape::Polygon *p = mshape::shape(m_to)) {
        double b[4];
        p->calculateBounds(b);
        m_boundsW = b[2] - b[0];
        m_boundsH = b[3] - b[1];
    }
    emit shapeChanged();
    refresh();
}

void ShapePainter::refresh()
{
    m_cubics = m_morph ? m_morph->asCubics(m_progress) : std::vector<mshape::Cubic> {};
    m_ring = m_strokeProgress >= 0 ? ring() : std::vector<QPointF> {};
    update();
}

void ShapePainter::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickPaintedItem::geometryChange(newGeometry, oldGeometry);
    if (newGeometry.size() != oldGeometry.size())
        refresh();
}

std::vector<QPointF> ShapePainter::ring() const
{
    if (m_cubics.empty())
        return {};
    return mshape::ringPoints(m_cubics, std::min(width(), height()), m_strokeWidth);
}

qreal ShapePainter::progressAt(qreal px, qreal py) const
{
    return mshape::ringProgressAt(ring(), px, py);
}

QVariant ShapePainter::pointAtProgress(qreal p) const
{
    QPointF out;
    if (!mshape::ringPointAt(ring(), p, out))
        return {};
    return QVariantMap {{QStringLiteral("x"), out.x()}, {QStringLiteral("y"), out.y()}};
}

bool ShapePainter::nearRing(qreal px, qreal py, qreal tolerance) const
{
    return mshape::ringNear(ring(), px, py, tolerance);
}

void ShapePainter::paint(QPainter *painter)
{
    if (m_cubics.empty())
        return;
    painter->setRenderHint(QPainter::Antialiasing, true);

    if (m_strokeProgress >= 0) {
        const std::vector<QPointF> &pts = m_ring;
        if (pts.size() < 3)
            return;
        QPainterPath ringPath;
        ringPath.addPolygon(QPolygonF(QList<QPointF>(pts.begin(), pts.end())));
        painter->setTransform(spin(ringPath, m_strokeWidth / 2), true);
        QPen pen(m_strokeTrackColor, m_strokeWidth, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin);
        painter->setBrush(Qt::NoBrush);

        double total = 0;
        std::vector<double> lengths;
        lengths.reserve(pts.size());
        for (size_t i = 1; i < pts.size(); i++) {
            const double l = std::hypot(pts[i].x() - pts[i - 1].x(), pts[i].y() - pts[i - 1].y());
            lengths.push_back(l);
            total += l;
        }
        if (total <= 0)
            return;

        auto span = [&](double from, double to) {
            const double a = total * from;
            const double b = total * to;
            QPainterPath out;
            double walked = 0;
            bool open = false;
            for (size_t i = 1; i < pts.size(); i++) {
                const double l = lengths[i - 1];
                const double s0 = walked;
                const double s1 = walked + l;
                walked = s1;
                if (s1 < a || l <= 0)
                    continue;
                if (s0 > b)
                    break;
                const QPointF p0 = pts[i - 1] + (pts[i] - pts[i - 1]) * (std::max(a, s0) - s0) / l;
                const QPointF p1 = pts[i - 1] + (pts[i] - pts[i - 1]) * (std::min(b, s1) - s0) / l;
                if (!open) {
                    out.moveTo(p0);
                    open = true;
                }
                out.lineTo(p1);
            }
            return out;
        };

        const double progress = std::max(0.0, std::min(1.0, double(m_strokeProgress)));
        const double gap = m_trackGap >= 0 && progress > 0
            ? std::min(progress, (m_trackGap + m_strokeWidth) / total)
            : 0.0;
        if (progress <= 0) {
            painter->setPen(pen);
            painter->drawPolyline(pts.data(), int(pts.size()));
            return;
        }
        if (progress + gap < 1 - gap) {
            painter->setPen(pen);
            painter->drawPath(span(progress + gap, 1 - gap));
        }
        pen.setColor(m_strokeColor);
        painter->setPen(pen);
        painter->drawPath(span(0, progress));
        return;
    }

    const qreal size = std::min(width(), height());
    QTransform toItem;
    if (m_normalized) {
        if (m_stretch)
            toItem.scale(width(), height());
        else
            toItem.scale(size, size);
    }

    QPainterPath path;
    path.setFillRule(Qt::WindingFill);
    path.moveTo(m_cubics.front().a0x(), m_cubics.front().a0y());
    for (const mshape::Cubic &c : m_cubics)
        path.cubicTo(c.c0x(), c.c0y(), c.c1x(), c.c1y(), c.a1x(), c.a1y());
    path.closeSubpath();
    const QPainterPath flat = toItem.map(path);
    const QPainterPath itemPath = spin(flat, 0).map(flat);
    painter->fillPath(itemPath, m_color);
    if (m_fillLevel > 0) {
        const qreal level = std::min<qreal>(1, m_fillLevel);
        const QRectF b = itemPath.boundingRect();
        painter->save();
        painter->setClipRect(QRectF(b.left(), b.bottom() - b.height() * level, b.width(), b.height() * level));
        painter->fillPath(itemPath, m_levelColor);
        painter->restore();
    }
    if (m_sweepLevel > 0) {
        const qreal level = std::min<qreal>(1, m_sweepLevel);
        const QRectF b = itemPath.boundingRect();
        const QPointF c = b.center();
        const qreal r = std::hypot(b.width(), b.height());
        QPainterPath pie;
        pie.moveTo(c);
        pie.arcTo(QRectF(c.x() - r, c.y() - r, 2 * r, 2 * r), 90, -360 * level);
        pie.closeSubpath();
        painter->save();
        painter->setClipPath(pie, Qt::IntersectClip);
        painter->fillPath(itemPath, m_levelColor);
        painter->restore();
    }

    if (m_borderWidth > 0) {
        QPainterPathStroker stroker;
        stroker.setWidth(m_borderWidth * 2);
        stroker.setJoinStyle(Qt::RoundJoin);
        stroker.setCapStyle(Qt::RoundCap);
        const QPainterPath ring = stroker.createStroke(itemPath).intersected(itemPath);
        painter->fillPath(ring, m_borderColor);
    }

    painter->save();
    painter->setTransform(toItem, true);

    if (m_debug) {
        painter->setPen(Qt::NoPen);
        painter->setBrush(Qt::red);
        for (size_t i = 0; i < m_cubics.size(); ++i) {
            if (i == 0)
                painter->drawEllipse(QPointF(m_cubics[i].a0x(), m_cubics[i].a0y()), 2, 2);
            painter->drawEllipse(QPointF(m_cubics[i].a1x(), m_cubics[i].a1y()), 2, 2);
        }
    }
    painter->restore();
}
