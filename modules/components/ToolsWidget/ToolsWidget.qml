import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Scope {
    LazyLoader {
        id: loader
        activeAsync: true

        component: PanelWindow {
            id: panelWindow

            readonly property bool shouldOpen: GlobalStates.toolsWidgetOpen
            property real openProgress: panelWindow.shouldOpen ? 1 : 0
            Behavior on openProgress { SpatialAnim { speed: "fast" } }

            visible: panelWindow.shouldOpen || panelWindow.openProgress > 0.01
            implicitWidth: 600
            implicitHeight: 600
            WlrLayershell.namespace: "quickshell:toolsWidget"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            mask: Region {
                item: maskRect
                intersection: Intersection.Xor

                Region {
                    item: container
                    intersection: Intersection.Subtract
                }
            }

            Rectangle {
                id: maskRect
                anchors.fill: parent
                color: "transparent"
            }

            HyprlandFocusGrab {
                windows: [panelWindow]
                active: panelWindow.shouldOpen
                onCleared: GlobalStates.toolsWidgetOpen = false
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: GlobalStates.toolsWidgetOpen = false

                ToolsWidgetOverall {
                    id: container
                    anchors.centerIn: parent
                    opacity: panelWindow.openProgress
                    scale: 0.92 + 0.08 * panelWindow.openProgress
                    layer.enabled: panelWindow.openProgress > 0
                                   && panelWindow.openProgress < 1
                }
            }
        }
    }

    GlobalShortcut {
        name: "toolsWidget"
        onPressed: GlobalStates.toolsWidgetOpen = !GlobalStates.toolsWidgetOpen
    }
}
