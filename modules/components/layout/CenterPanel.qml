import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import qs.modules.settings
import qs.modules.utils

Scope {
    id: root

    property bool open: false
    property string name: "center"
    property int panelWidth: 1000
    property int panelHeight: 520
    property Component content: null
    signal dismissed()

    property real t: 0
    property var targetScreen: null

    onOpenChanged: {
        if (root.open) {
            const mon = Hyprland.focusedMonitor
            root.targetScreen = Quickshell.screens.find(s => mon && s.name === mon.name) ?? Quickshell.screens[0]
            closeAnim.stop()
            openAnim.restart()
        } else {
            GlobalStates.panelHold = false
            openAnim.stop()
            closeAnim.restart()
        }
    }

    NumberAnimation {
        id: openAnim
        target: root
        property: "t"
        to: 1
        duration: M3Motion.panel.openDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: M3Motion.panel.openCurve
    }

    NumberAnimation {
        id: closeAnim
        target: root
        property: "t"
        to: 0
        duration: M3Motion.panel.closeDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: M3Motion.panel.closeCurve
    }

    Loader {
        active: root.open || root.t > 0

        sourceComponent: PanelWindow {
            id: win

            readonly property int margin: 40

            screen: root.targetScreen
            implicitWidth: Math.min(root.panelWidth, (win.screen ? win.screen.width : 1920) - 2 * win.margin) + 2 * win.margin
            implicitHeight: Math.min(root.panelHeight, (win.screen ? win.screen.height : 1080) - 2 * win.margin) + 2 * win.margin
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell:" + root.name
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            HyprlandFocusGrab {
                windows: [win]
                active: root.open && !GlobalStates.panelHold && !GlobalStates.fileDialogOpen
                onCleared: if (root.open) root.dismissed()
            }

            Item {
                id: card
                anchors.centerIn: parent
                width: win.width - 2 * win.margin
                height: win.height - 2 * win.margin
                opacity: Math.min(1, root.t * 1.6)
                scale: 0.94 + 0.06 * root.t
                focus: true
                Keys.onEscapePressed: root.dismissed()

                RectangularShadow {
                    anchors.fill: parent
                    radius: 28
                    blur: 36
                    spread: 0
                    offset.y: 10
                    color: Qt.rgba(0, 0, 0, 0.35)
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 28
                    color: Colors.surface

                    Loader {
                        anchors.fill: parent
                        sourceComponent: root.content
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: GlobalStates.panelHold
                    onPressed: mouse => {
                        GlobalStates.panelHold = false
                        mouse.accepted = false
                    }
                }
            }
        }
    }
}
