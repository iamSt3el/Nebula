import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import "modules/MatrialShapes/" as MaterialShapes
import "modules/MatrialShapes/material-shapes.js" as MatrialShapeFn


PanelWindow {
    id: root
    implicitWidth: 400
    implicitHeight: 400
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    property real posX: 0
    property real posY: 0
    property real iconOpacity: 0

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

    SequentialAnimation {
        id: introAnim
        NumberAnimation {
            target: shapeCanvas
            property: "scale"
            from: 0
            to: 1
            duration: 600
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
        PauseAnimation { duration: 80 }
        ScriptAction {
            script: shapeCanvas.roundedPolygon = MatrialShapeFn.getCookie4Sided()
        }
        PauseAnimation { duration: 400 }
        NumberAnimation {
            target: root
            property: "iconOpacity"
            from: 0
            to: 1
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    Component.onCompleted: introAnim.start()

    Item{
        anchors.centerIn: parent
        implicitWidth: 300
        implicitHeight: 300

        MaterialShapes.ShapeCanvas{
            id: shapeCanvas
            anchors.fill: parent
            roundedPolygon: MatrialShapeFn.getCircle()
            color: Colors.primary
            scale: 0
            transformOrigin: Item.Center
        }

        MaterialIconSymbol{
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 50
            anchors.leftMargin: 50
            content: "camera"
            iconSize: 50
            color: Colors.primaryText
            opacity: root.iconOpacity
        }

        MaterialIconSymbol{
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 50
            anchors.rightMargin: 50
            content: "videocam"
            iconSize: 50
            color: Colors.primaryText
            opacity: root.iconOpacity
        }

        MaterialIconSymbol{
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 50
            anchors.leftMargin: 50
            content: "power_settings_new"
            iconSize: 50
            color: Colors.primaryText
            opacity: root.iconOpacity
        }

        MaterialIconSymbol{
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.bottomMargin: 50
            anchors.rightMargin: 50
            content: "settings"
            iconSize: 50
            color: Colors.primaryText
            opacity: root.iconOpacity
        }


        Rectangle{
            anchors.centerIn: parent
            implicitHeight: 50
            implicitWidth: 50
            radius: width / 2
            color: Colors.primaryText
            opacity: root.iconOpacity
            MaterialIconSymbol{
                anchors.centerIn: parent
                content: "close"
                iconSize: 40
                color: Colors.primary
            }
        }
    }
}
