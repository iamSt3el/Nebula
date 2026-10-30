import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "clock"
    tile: Qt.size(WidgetSizes.span(4), WidgetSizes.span(1.5))
    defaultPos: Qt.point(100, 100)
    backdrop: false
    outlined: false

    readonly property bool tilt: SettingsConfig.widgets.clockTilt ?? true
    readonly property string _hand: "Just Another Hand"

    ClockParts { id: t }

    optionsComponent: Component {
        ClockOptions { rows: [{ key: "clockTilt", label: "Tilt", sub: "Lean the writing a few degrees", def: true }] }
    }

    property real ink: root.preview ? 1 : 0
    SequentialAnimation {
        running: !root.preview
        PauseAnimation { duration: 380 }
        NumberAnimation { target: root; property: "ink"; to: 1; duration: 1300; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1] }
    }

    ClockLift {
        anchors.fill: parent
        rotation: root.tilt ? -3 : 0
        Behavior on rotation { SpatialAnim {} }

        MotionEnter {
            x: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            dx: -24
            dy: 0
            animated: !root.preview

            Row {
                spacing: 18

                RollText {
                    text: t.time + (t.ampm !== "" ? " " + t.ampm.toLowerCase() : "")
                    color: t.ink
                    family: root._hand
                    pixelSize: 118
                    weight: 400
                    lineHeight: 0.8
                    travel: 0
                    animated: !root.preview
                }

                Text {
                    visible: t.showDate
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    text: (t.weekday.slice(0, 3) + " " + t.day + " " + t.month.slice(0, 3)).toLowerCase()
                    color: t.accentTertiary
                    font.family: root._hand
                    font.pixelSize: 44
                    renderType: Text.QtRendering
                }
            }
        }

        Shape {
            x: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            width: 300
            height: 24
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: t.accentTertiary
                strokeWidth: 5
                capStyle: ShapePath.RoundCap
                strokeStyle: ShapePath.DashLine
                dashPattern: [70, 70]
                dashOffset: 70 * (1 - root.ink)
                PathSvg { path: "M4 14 C 60 4, 120 22, 180 10 S 270 8, 296 12" }
            }
        }
    }
}
