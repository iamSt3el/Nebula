import Quickshell
import QtQuick
import qs.modules.settings
import qs.modules.utils
import qs.modules.customComponents

Item {
    id: root

    property bool isToggleOn: false
    property bool showIcons: true
    signal toggled(bool state)

    property int _pending: -1
    readonly property bool _on: root._pending >= 0 ? root._pending === 1 : root.isToggleOn
    onIsToggleOnChanged: root._pending = -1

    Timer {
        id: pendingTimer
        interval: 1000
        onTriggered: root._pending = -1
    }

    implicitHeight: 32
    implicitWidth: root.height * 52 / 32

    readonly property real _s: root.height / 32

    readonly property real _handleSize: toggleArea.pressed ? 28 * root._s
                                      : root._on ? 24 * root._s
                                      : 16 * root._s

    readonly property var _standard: [0.2, 0.0, 0.0, 1.0, 1, 1]

    property real _handleCenter: root._on
        ? root.width - 16 * root._s
        : 16 * root._s

    Behavior on _handleCenter {
        NumberAnimation {
            duration: M3Motion.effects.defaultDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root._standard
        }
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root._on ? Colors.primary : Colors.surfaceContainerHighest

        border.width: root._on ? 0 : 2 * root._s
        border.color: Colors.outline

        Behavior on color {
            ColorAnimation {
                duration: M3Motion.effects.defaultDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: M3Motion.effects.curve
            }
        }
        Behavior on border.width {
            NumberAnimation {
                duration: M3Motion.effects.fastDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: M3Motion.effects.curve
            }
        }

        MouseArea {
            id: toggleArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const next = !root._on
                root._pending = next ? 1 : 0
                pendingTimer.restart()
                root.toggled(next)
            }
        }

        Rectangle {
            id: handle
            anchors.verticalCenter: parent.verticalCenter
            width: root._handleSize
            height: root._handleSize
            radius: width / 2
            x: root._handleCenter - width / 2
            color: root._on ? Colors.primaryText : Colors.outline

            Behavior on width {
                NumberAnimation {
                    duration: M3Motion.effects.defaultDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root._standard
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: M3Motion.effects.defaultDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: M3Motion.effects.curve
                }
            }

            MaterialIconSymbol {
                anchors.centerIn: parent
                visible: root.showIcons
                content: root._on ? "check" : "close"
                iconSize: 16 * root._s
                fill: 1
                customColor: root._on ? Colors.primary
                                             : Colors.surfaceContainerHighest
            }
        }
    }
}
