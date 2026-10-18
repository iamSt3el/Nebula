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

inline constexpr int kBlobMax = 64;
inline constexpr int kBlobLocal = 16;

struct BlobPack {
    int count = 0;
    QVector4D rect[kBlobMax];
    QVector4D radii[kBlobMax];
    QVector4D extra[kBlobMax];
    QVector4D paint[kBlobMax];
    QRectF bounds[kBlobMax];
    bool frameOn = false;
    QVector4D frameHole;
    QVector4D frameRad;
    float smoothing = 0;
};

struct BlobPiece {
    QRect rect;
    std::vector<int> blobs;
    bool frame = false;
};

class BlobField : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QVariantList blobs READ blobs WRITE setBlobs NOTIFY blobsChanged)
    Q_PROPERTY(QVariantMap frame READ frame WRITE setFrame NOTIFY frameChanged)
    Q_PROPERTY(qreal smoothing READ smoothing WRITE setSmoothing NOTIFY smoothingChanged)
    Q_PROPERTY(QColor fillColor READ fillColor WRITE setFillColor NOTIFY fillColorChanged)
    Q_PROPERTY(QColor edgeColor READ edgeColor WRITE setEdgeColor NOTIFY edgeColorChanged)
    Q_PROPERTY(qreal edgeWidth READ edgeWidth WRITE setEdgeWidth NOTIFY edgeWidthChanged)
    Q_PROPERTY(QColor shadowColor READ shadowColor WRITE setShadowColor NOTIFY shadowColorChanged)
    Q_PROPERTY(qreal shadowSize READ shadowSize WRITE setShadowSize NOTIFY shadowSizeChanged)
    Q_PROPERTY(qreal shadowStrength READ shadowStrength WRITE setShadowStrength NOTIFY shadowStrengthChanged)
    Q_PROPERTY(int pieceCount READ pieceCount NOTIFY piecesChanged)

public:
    explicit BlobField(QQuickItem *parent = nullptr);

    QVariantList blobs() const { return m_blobs; }
    void setBlobs(const QVariantList &blobs);
    QVariantMap frame() const { return m_frame; }
    void setFrame(const QVariantMap &frame);
    qreal smoothing() const { return m_smoothing; }
    void setSmoothing(qreal k);
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

    Q_INVOKABLE qreal gapBetween(const QVariantMap &a, const QVariantMap &b) const;

signals:
    void blobsChanged();
    void frameChanged();
    void smoothingChanged();
    void fillColorChanged();
    void edgeColorChanged();
    void edgeWidthChanged();
    void shadowColorChanged();
    void shadowSizeChanged();
    void shadowStrengthChanged();
    void piecesChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *) override;
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;

private:
    void pack();

    QVariantList m_blobs;
    QVariantMap m_frame;
    qreal m_smoothing = 14;
    QColor m_fill = Qt::black;
    QColor m_edge = Qt::transparent;
    qreal m_edgeWidth = 0;
    QColor m_shadow = Qt::black;
    qreal m_shadowSize = 0;
    qreal m_shadowStrength = 0;
    QSharedPointer<BlobPack> m_pack;
    std::vector<BlobPiece> m_pieces;
    int m_dropped = 0;
};

}
