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
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Colors.surfaceContainerHighest
                        strokeWidth: 5
                        PathAngleArc { centerX: 62; centerY: 62; radiusX: 59; radiusY: 59; startAngle: 0; sweepAngle: 360 }
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Colors.primary
                        strokeWidth: 5
                        capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 62; centerY: 62; radiusX: 59; radiusY: 59; startAngle: -90; sweepAngle: 360 * ServiceProfile.dayFrac }
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
                content: Math.round(ServiceProfile.dayFrac * 100) + "% of " + Qt.formatDate(new Date(ServiceProfile.now), "dddd") + " done"
                size: 11
                weight: 400
                customColor: Colors.outline
            }

            Item { Layout.fillHeight: true }
        }
    }
}
