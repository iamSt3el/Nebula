import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: root
    property string icon
    property int    iconSize:       20
    property color  iconColor:      Colors.surfaceText
    property color  iconHoverColor: Colors.primaryText

    radius: 20
    color: ripple.containsMouse ? Colors.primary : Colors.surfaceContainerHighest
    Behavior on color { ColorAnimation { duration: 150 } }

    signal clicked

    MaterialIconSymbol {
        anchors.centerIn: parent
        content: root.icon
        iconSize: root.iconSize
        color: ripple.containsMouse ? root.iconHoverColor : root.iconColor
        Behavior on color { ColorAnimation { duration: 150 } }

        layer.enabled: true
        layer.smooth:  true

        scale: ripple.pressed ? 0.82 : ripple.containsMouse ? 1.15 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
        }

        rotation: ripple.pressed ? 20 : ripple.containsMouse ? 10 : 0
        Behavior on rotation {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }

    RippleEffect {
        id: ripple
        anchors.fill: parent
        radius: parent.radius
        onClicked: root.clicked()
    }
}
