import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

WidgetHost {
    id: root
    configKey: "profileShape"
    tile: WidgetSizes.small
    defaultPos: Qt.point(1135, 620)

    WidgetCard {
        id: card
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 0

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 124
                implicitHeight: 124

                Shape {
                    id: ring
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    readonly property real frac: Math.max(0, Math.min(1, ServiceProfile.dayFrac))
                    readonly property real gapDeg: ring.frac > 0.01 && ring.frac < 0.99 ? 16 : 0

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Colors.surfaceContainerHighest
                        strokeWidth: 6
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 62; centerY: 62; radiusX: 57; radiusY: 57
                            startAngle: -90 + 360 * ring.frac + ring.gapDeg
                            sweepAngle: Math.max(0, 360 * (1 - ring.frac) - ring.gapDeg * 2)
                        }
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Colors.primary
                        strokeWidth: 6
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathPolyline {
                            path: {
                                const pts = []
                                const n = Math.max(2, Math.round(180 * ring.frac))
                                const span = Math.PI * 2 * ring.frac
                                for (let i = 0; i <= n; i++) {
                                    const t = span * i / n
                                    const r = 57 + 2.4 * Math.sin(t * 14)
                                    pts.push(Qt.point(62 + r * Math.cos(t - Math.PI / 2), 62 + r * Math.sin(t - Math.PI / 2)))
                                }
                                return pts
                            }
                        }
                    }
                }

                Item {
                    id: shapeMask
                    anchors.centerIn: parent
                    width: 100
                    height: 100
                    layer.enabled: true
                    visible: false

                    MaterialShapes.ShapeCanvas {
                        anchors.fill: parent
                        roundedPolygon: ShapeLibrary.get("cookie12")
                        color: "white"
                    }
                }

                Item {
                    id: face
                    anchors.centerIn: parent
                    width: 100
                    height: 100
                    visible: false

                    Rectangle {
                        anchors.fill: parent
                        color: Colors.primaryContainer
                    }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        visible: pic.status !== Image.Ready
                        content: "person"
                        iconSize: 48
                        fill: 1
                        customColor: Colors.primaryContainerText
                    }

                    Image {
                        id: pic
                        anchors.fill: parent
                        source: ServiceProfile.avatar
                        sourceSize.width: 256
                        sourceSize.height: 256
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                MultiEffect {
                    anchors.fill: face
                    source: face
                    maskEnabled: true
                    maskSource: shapeMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
            }

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width
                Layout.topMargin: 6
                content: ServiceProfile.name
                size: 20
                weight: 400
                family: SettingsConfig.general.displayFont ?? "Titan One"
                renderType: Text.QtRendering
                elide: Text.ElideRight
            }

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                content: Math.round(ServiceProfile.dayFrac * 100) + "% of " + Qt.formatDate(new Date(ServiceProfile.now), "dddd")
                size: 11
                weight: 600
                customColor: Colors.surfaceVariantText
            }

            Item { Layout.fillHeight: true }
        }
    }
}
