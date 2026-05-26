import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services

Scope {
    id: root

    property real dotX: 0
    property real dotY: 0

    PanelWindow {
        id: panelWindow
        implicitWidth: 200
        implicitHeight: 200
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Normal
        color: "transparent"
        mask: Region {
            item: maskRect
            intersection: Intersection.Xor
        }

        Rectangle {
            id: maskRect
            implicitHeight: parent.height
            implicitWidth: parent.width
            anchors.bottom: parent.bottom
            color: "transparent"
        }

        Rectangle{
            implicitHeight: 40
            implicitWidth: 80
            color: Colors.surface
            radius: 10
            anchors.centerIn: parent

            MaterialIconSymbol{
                id: icon
                anchors.centerIn: parent
                content: "battery_android_3"
                iconSize: 50

                CustomText{
                    anchors.centerIn: parent
                    content: "100"
                    color: Colors.surfaceContainerHighest
                    size: 16
                }
            }
        }
    }
}
