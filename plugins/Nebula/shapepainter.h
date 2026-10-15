#pragma once

#include "shapes.h"

#include <QColor>
#include <QQuickPaintedItem>
#include <QVariant>
#include <QtQml/qqml.h>

#include <memory>
#include <vector>

class ShapePainter : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString fromShape READ fromShape WRITE setFromShape NOTIFY shapeChanged)
    Q_PROPERTY(QString toShape READ toShape WRITE setToShape NOTIFY shapeChanged)
    Q_PROPERTY(qreal progress READ progress WRITE setProgress NOTIFY progressChanged)
    Q_PROPERTY(qreal boundsWidth READ boundsWidth NOTIFY shapeChanged)
    Q_PROPERTY(qreal boundsHeight READ boundsHeight NOTIFY shapeChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY styleChanged)
    Q_PROPERTY(qreal borderWidth READ borderWidth WRITE setBorderWidth NOTIFY styleChanged)
    Q_PROPERTY(QColor borderColor READ borderColor WRITE setBorderColor NOTIFY styleChanged)
    Q_PROPERTY(bool debug READ debug WRITE setDebug NOTIFY styleChanged)
    Q_PROPERTY(bool stretchToFill READ stretchToFill WRITE setStretchToFill NOTIFY styleChanged)
    Q_PROPERTY(bool polygonIsNormalized READ polygonIsNormalized WRITE setPolygonIsNormalized NOTIFY styleChanged)
    Q_PROPERTY(qreal strokeProgress READ strokeProgress WRITE setStrokeProgress NOTIFY styleChanged)
    Q_PROPERTY(qreal strokeWidth READ strokeWidth WRITE setStrokeWidth NOTIFY styleChanged)
    Q_PROPERTY(QColor strokeColor READ strokeColor WRITE setStrokeColor NOTIFY styleChanged)
    Q_PROPERTY(QColor strokeTrackColor READ strokeTrackColor WRITE setStrokeTrackColor NOTIFY styleChanged)
    Q_PROPERTY(qreal angle READ angle WRITE setAngle NOTIFY styleChanged)
    Q_PROPERTY(qreal fillLevel READ fillLevel WRITE setFillLevel NOTIFY styleChanged)
    Q_PROPERTY(QColor levelColor READ levelColor WRITE setLevelColor NOTIFY styleChanged)

public:
    explicit ShapePainter(QQuickItem *parent = nullptr);

    void paint(QPainter *painter) override;

    QString fromShape() const { return m_from; }
    void setFromShape(const QString &v);
    QString toShape() const { return m_to; }
    void setToShape(const QString &v);
    qreal progress() const { return m_progress; }
    void setProgress(qreal v);
    qreal boundsWidth() const { return m_boundsW; }
    qreal boundsHeight() const { return m_boundsH; }

    QColor color() const { return m_color; }
    void setColor(const QColor &v);
    qreal borderWidth() const { return m_borderWidth; }
    void setBorderWidth(qreal v);
    QColor borderColor() const { return m_borderColor; }
    void setBorderColor(const QColor &v);
    bool debug() const { return m_debug; }
    void setDebug(bool v);
    bool stretchToFill() const { return m_stretch; }
    void setStretchToFill(bool v);
    bool polygonIsNormalized() const { return m_normalized; }
    void setPolygonIsNormalized(bool v);
    qreal strokeProgress() const { return m_strokeProgress; }
    void setStrokeProgress(qreal v);
    qreal strokeWidth() const { return m_strokeWidth; }
    void setStrokeWidth(qreal v);
    QColor strokeColor() const { return m_strokeColor; }
    void setStrokeColor(const QColor &v);
    QColor strokeTrackColor() const { return m_strokeTrackColor; }
    void setStrokeTrackColor(const QColor &v);
    qreal angle() const { return m_angle; }
    void setAngle(qreal v);
    qreal fillLevel() const { return m_fillLevel; }
    void setFillLevel(qreal v);
    QColor levelColor() const { return m_levelColor; }
    void setLevelColor(const QColor &v);

    Q_INVOKABLE qreal progressAt(qreal px, qreal py) const;
    Q_INVOKABLE QVariant pointAtProgress(qreal p) const;
    Q_INVOKABLE bool nearRing(qreal px, qreal py, qreal tolerance) const;
    Q_INVOKABLE QStringList shapeNames() const { return mshape::shapeNames(); }

signals:
    void shapeChanged();
    void progressChanged();
    void styleChanged();

protected:
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;

private:
    template <typename T>
    void setStyle(T &field, const T &value);
    void rebuildMorph();
    void refresh();
    std::vector<QPointF> ring() const;

    QString m_from;
    QString m_to;
    qreal m_progress = 1;
    std::shared_ptr<const mshape::Morph> m_morph;
    std::vector<mshape::Cubic> m_cubics;
    std::vector<QPointF> m_ring;
    qreal m_boundsW = 0;
    qreal m_boundsH = 0;

    QColor m_color = QColor(0x68, 0x54, 0x96);
    qreal m_borderWidth = 0;
    QColor m_borderColor = QColor(0x68, 0x54, 0x96);
    bool m_debug = false;
    bool m_stretch = false;
    bool m_normalized = true;
    qreal m_strokeProgress = -1;
    qreal m_strokeWidth = 4;
    QColor m_strokeColor = QColor(0x68, 0x54, 0x96);
    QColor m_strokeTrackColor = Qt::transparent;
    qreal m_angle = 0;
    qreal m_fillLevel = -1;
    QColor m_levelColor = QColor(0x68, 0x54, 0x96);
    QTransform spin(const QPainterPath &shape, qreal pad) const;
};
