import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

WidgetHost {
    id: root
    configKey: "weatherWind"
    tile: WidgetSizes.small
    defaultPos: Qt.point(1025, 165)

    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"
    readonly property bool ready: root.preview || !!ServiceWeather.currentCondition
    readonly property string speed: root.preview ? "5" : String(ServiceWeather.currentCondition?.windspeedKmph ?? "")
    readonly property string fromDir: root.preview ? "S" : ServiceWeather.windDirection
    readonly property real degree: root.preview ? 187 : Number(ServiceWeather.windDegree)

    WidgetCard {
        id: card
        anchors.fill: parent

        Item {
            id: dial
            anchors.centerIn: parent
            width: Math.min(card.width, card.height) - 28
            height: width
            visible: root.ready

            readonly property real c: dial.width / 2

            MaterialShapes.ShapeCanvas {
                anchors.fill: parent
                roundedPolygon: ShapeLibrary.get("cookie12")
                color: Colors.surfaceContainerHigh
            }

            Rectangle {
                x: dial.c - 3
                y: dial.width * 0.11 - 3
                width: 6
                height: 6
                radius: 3
                color: Colors.tertiary
            }

            Item {
                anchors.fill: parent
                rotation: root.degree + 180
                Behavior on rotation {
                    RotationAnimation {
                        direction: RotationAnimation.Shortest
                        duration: M3Motion.spatialDuration("slow")
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: M3Motion.spatialCurve("slow")
                    }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: Colors.primary
                        strokeColor: "transparent"
                        startX: dial.c
                        startY: dial.c - dial.c * 0.78
                        PathLine { x: dial.c + dial.c * 0.32; y: dial.c + dial.c * 0.1 }
                        PathLine { x: dial.c - dial.c * 0.32; y: dial.c + dial.c * 0.1 }
                        PathLine { x: dial.c; y: dial.c - dial.c * 0.78 }
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: dial.width * 0.42
                height: width
                radius: width / 2
                color: card.color
            }

            Column {
                anchors.centerIn: parent
                CustomText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    content: root.speed
                    family: root.display
                    size: 28
                    weight: 400
                }
                CustomText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    content: "km/h " + root.fromDir
                    size: 11
                    weight: 700
                    customColor: Colors.surfaceVariantText
                }
            }
        }

        CustomText {
            anchors.centerIn: parent
            visible: !root.ready
            content: ServiceWeather.hasError ? "No weather" : "Loading…"
            size: 13
            weight: 600
            customColor: Colors.outline
        }
    }
}
