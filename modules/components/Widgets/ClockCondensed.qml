import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "clock"
    tile: Qt.size(WidgetSizes.span(4), WidgetSizes.span(2))
    defaultPos: Qt.point(100, 100)
    backdrop: false
    outlined: false

    readonly property bool showLabel: SettingsConfig.widgets.clockLabel ?? true
    readonly property string _display: "Fira Sans Condensed"

    ClockParts { id: t }

    optionsComponent: Component {
        ClockOptions { rows: [{ key: "clockLabel", label: "Label", sub: "\"Local time\" above the numerals", def: true }] }
    }

    ClockLift {
        anchors.fill: parent

        MotionEnter {
            visible: root.showLabel
            x: 4
            y: 10
            delay: 300
            dy: -10
            animated: !root.preview

            CustomText {
                content: ("Local time" + (t.ampm !== "" ? " · " + t.ampm : "")).toUpperCase()
                size: 13
                weight: 600
                font.letterSpacing: 2.4
                customColor: t.inkVariant
            }
        }

        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            spacing: 18

            Item {
                Layout.preferredWidth: timeText.implicitWidth
                Layout.preferredHeight: timeText.implicitHeight
                clip: true

                RollText {
                    id: timeText
                    text: t.time
                    family: root._display
                    pixelSize: 150
                    weight: 800
                    letterSpacing: -3
                    lineHeight: 0.8
                    color: t.accent
                    travel: 90
                    animated: !root.preview

                    property real rise: root.preview ? 0 : 1
                    transform: Translate { y: timeText.rise * timeText.implicitHeight }
                    SequentialAnimation {
                        running: !root.preview
                        PauseAnimation { duration: 80 }
                        NumberAnimation { target: timeText; property: "rise"; to: 0; duration: 700; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1, 1] }
                    }
                }
            }

            MotionEnter {
                visible: t.showDate
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 8
                delay: 420
                dx: -16
                dy: 0
                animated: !root.preview

                Column {
                    Text {
                        text: t.day
                        color: t.ink
                        font.family: root._display
                        font.pixelSize: 54
                        font.weight: 800
                        lineHeight: 0.9
                        renderType: Text.QtRendering
                    }
                    CustomText { content: t.weekday; size: 14; weight: 600; customColor: t.inkVariant }
                    CustomText { content: t.month; size: 14; weight: 600; customColor: t.inkVariant }
                }
            }
        }
    }
}
