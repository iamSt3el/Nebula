#pragma once

#include <QColor>
#include <QList>
#include <QPainterPath>
#include <QQuickPaintedItem>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqml.h>

class CutText : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList glyphs READ glyphs WRITE setGlyphs NOTIFY changed)
    Q_PROPERTY(QString family READ family WRITE setFamily NOTIFY changed)
    Q_PROPERTY(int px READ px WRITE setPx NOTIFY changed)
    Q_PROPERTY(qreal ring READ ring WRITE setRing NOTIFY changed)
    Q_PROPERTY(qreal round READ round WRITE setRound NOTIFY changed)
    Q_PROPERTY(qreal islandRatio READ islandRatio WRITE setIslandRatio NOTIFY changed)
    Q_PROPERTY(int weight READ weight WRITE setWeight NOTIFY changed)
    Q_PROPERTY(QVariantMap axes READ axes WRITE setAxes NOTIFY changed)

public:
    explicit CutText(QQuickItem *parent = nullptr);

    void paint(QPainter *painter) override;

    QVariantList glyphs() const { return m_glyphs; }
    void setGlyphs(const QVariantList &v);
    QString family() const { return m_family; }
    void setFamily(const QString &v);
    int px() const { return m_px; }
    void setPx(int v);
    qreal ring() const { return m_ring; }
    void setRing(qreal v);
    qreal round() const { return m_round; }
    void setRound(qreal v);
    qreal islandRatio() const { return m_islandRatio; }
    void setIslandRatio(qreal v);
    int weight() const { return m_weight; }
    void setWeight(int v);
    QVariantMap axes() const { return m_axes; }
    void setAxes(const QVariantMap &v);

signals:
    void changed();

private:
    void invalidate();
    void rebuild();

    QVariantList m_glyphs;
    QString m_family = QStringLiteral("Titan One");
    int m_px = 100;
    qreal m_ring = 4;
    qreal m_round = 0;
    qreal m_islandRatio = 0.06;
    int m_weight = 0;
    QVariantMap m_axes;

    bool m_dirty = true;
    QList<QPainterPath> m_paths;
    QList<QColor> m_colors;
};
