import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MatrialSHapeFn

Item {
    id: root
    anchors.fill: parent

    readonly property var permanentShapeGetters: [
        MatrialSHapeFn.getSquare,
        MatrialSHapeFn.getSquare,
        MatrialSHapeFn.getSquare,
        MatrialSHapeFn.getSquare
    ]

    readonly property var hoverShapeGetters: [
        MatrialSHapeFn.getArch,
        MatrialSHapeFn.getCookie7Sided,
        MatrialSHapeFn.getPill,
        MatrialSHapeFn.getCookie12Sided
    ]

    readonly property var actionIcons: [
        "power_settings_new",
        "refresh",
        "logout",
        "lock"
    ]

    readonly property var actionCommands: [
        ["systemctl", "poweroff"],
        ["systemctl", "reboot"],
        ["hyprctl", "dispatch", "exit"],
        ["loginctl", "lock-session"]
    ]


    // Image {
    //     id: background
    //     source: WallpaperTheme.wallpaper
    //     anchors.fill: parent
    //     fillMode: Image.PreserveAspectCrop
    //     sourceSize: Qt.size(width, height)
    //
    //     NumberAnimation on opacity {
    //         from: 0
    //         to: 1
    //         duration: 200
    //     }
    //
    //     layer.enabled: true
    //     layer.effect: MultiEffect {
    //         blurEnabled: true
    //         blur: 0.8
    //         blurMax: 40
    //         autoPaddingEnabled: false
    //     }
    // }
    Rectangle{
        anchors.fill: parent
        color: Qt.alpha(Colors.surface, 0.5)
        layer.enabled: true


    }



    GridLayout {
        anchors.centerIn: parent
        columns: 2
        rows: 2
        columnSpacing: 20
        rowSpacing: 20

        Repeater {
            model: root.actionIcons.length

            delegate: Item {
                id: delegateItem
                z: 2
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 200
                Layout.preferredHeight: 200

                property bool isHovered: false

                MaterialShapes.ShapeCanvas {
                    anchors.fill: parent
                    color: delegateItem.isHovered ? Colors.primary : Colors.surface
                    roundedPolygon: delegateItem.isHovered
                    ? root.hoverShapeGetters[index]()
                    : root.permanentShapeGetters[index]()

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: root.actionIcons[index]
                        color: delegateItem.isHovered ? Colors.primaryText : Colors.surfaceText
                        iconSize: 100
                    }

                    Behavior on color{
                        ColorAnimation{
                            duration: 100
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            delegateItem.isHovered = true
                        }
                        onExited: {
                            delegateItem.isHovered = false
                        }
                        onClicked: {
                            GlobalStates.shutdownWindow = false
                            Quickshell.execDetached(root.actionCommands[index])
                        }
                    }

                    NumberAnimation on scale {
                        from: 0.6
                        to: 1
                        duration: 200
                    }
                }
            }
        }
    }
}
