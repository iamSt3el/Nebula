#pragma once

#include <QColor>
#include <QQuickItem>
#include <QRect>
#include <QSharedPointer>
#include <QVariantList>
#include <QVector4D>
#include <QtQml/qqmlregistration.h>
#include <vector>

namespace nebula {

inline constexpr int kFieldMax = 8;
inline constexpr int kPillMax = 64;
inline constexpr int kSegMax = 64;
inline constexpr int kFlareMax = 64;
inline constexpr int kTabMax = 24;

struct FieldPack {
    int fieldCount = 0;
    QVector4D map[kFieldMax];
    QVector4D info[kFieldMax];
    QRect area[kFieldMax];
    bool frameOn = false;
    QVector4D frameHole;
    QVector4D frameRad;
    int pillCount = 0;
    int segCount = 0;
    int flareCount = 0;
    int tabCount = 0;
    QVector4D pill[kPillMax * 3];
    QVector4D seg[kSegMax * 3];
    QVector4D flare[kFlareMax];
    QVector4D tab[kTabMax * 7];
};

struct FieldPiece {
    QRect rect;
    int mask = 0;
};

class BarField : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QVariantList fields READ fields WRITE setFields NOTIFY fieldsChanged)
    Q_PROPERTY(QColor fillColor READ fillColor WRITE setFillColor NOTIFY fillColorChanged)
    Q_PROPERTY(QColor edgeColor READ edgeColor WRITE setEdgeColor NOTIFY edgeColorChanged)
    Q_PROPERTY(qreal edgeWidth READ edgeWidth WRITE setEdgeWidth NOTIFY edgeWidthChanged)
    Q_PROPERTY(QColor shadowColor READ shadowColor WRITE setShadowColor NOTIFY shadowColorChanged)
    Q_PROPERTY(qreal shadowSize READ shadowSize WRITE setShadowSize NOTIFY shadowSizeChanged)
    Q_PROPERTY(qreal shadowStrength READ shadowStrength WRITE setShadowStrength NOTIFY shadowStrengthChanged)
    Q_PROPERTY(int pieceCount READ pieceCount NOTIFY piecesChanged)
    Q_PROPERTY(QVariantMap frame READ frame WRITE setFrame NOTIFY frameChanged)

public:
    explicit BarField(QQuickItem *parent = nullptr);

    QVariantList fields() const { return m_fields; }
    void setFields(const QVariantList &fields);

    QColor fillColor() const { return m_fill; }
    void setFillColor(const QColor &c);
    QColor edgeColor() const { return m_edge; }
    void setEdgeColor(const QColor &c);
    qreal edgeWidth() const { return m_edgeWidth; }
    void setEdgeWidth(qreal w);
    QColor shadowColor() const { return m_shadow; }
    void setShadowColor(const QColor &c);
    qreal shadowSize() const { return m_shadowSize; }
    void setShadowSize(qreal s);
    qreal shadowStrength() const { return m_shadowStrength; }
    void setShadowStrength(qreal s);
    int pieceCount() const { return int(m_pieces.size()); }
    QVariantMap frame() const { return m_frame; }
    void setFrame(const QVariantMap &frame);

signals:
    void fieldsChanged();
    void fillColorChanged();
    void edgeColorChanged();
    void edgeWidthChanged();
    void shadowColorChanged();
    void shadowSizeChanged();
    void shadowStrengthChanged();
    void piecesChanged();
    void frameChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *) override;

private:
    void pack();

    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;

    QVariantList m_fields;
    QVariantMap m_frame;
    QColor m_fill = Qt::black;
    QColor m_edge = Qt::transparent;
    qreal m_edgeWidth = 0;
    QColor m_shadow = Qt::black;
    qreal m_shadowSize = 0;
    qreal m_shadowStrength = 0;
    QSharedPointer<FieldPack> m_pack;
    std::vector<FieldPiece> m_pieces;
    int m_dropped = 0;
};

}
