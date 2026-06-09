import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import "../../MatrialShapes" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MatrialShapeFn

Item {
    id: root
    implicitWidth: 300
    implicitHeight: 300

    signal cameraClicked()
    signal recordingClicked()

    property real iconOpacity: 0

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

    MaterialShapes.ShapeCanvas {
        id: shapeCanvas
        anchors.fill: parent
        roundedPolygon: MatrialShapeFn.getCircle()
        color: Colors.primary
        scale: 0
        transformOrigin: Item.Center
    }

    // Camera / Screenshot
    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 30
        anchors.leftMargin: 30
        width: 80; height: 80
        opacity: root.iconOpacity
        MaterialIconSymbol {
            anchors.centerIn: parent
            content: "photo_camera"
            iconSize: camArea.containsMouse ? 56 : 50
            color: Colors.primaryText
            Behavior on iconSize { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            id: camArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.cameraClicked()
        }
    }

    // Recording
    Item {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 30
        anchors.rightMargin: 30
        width: 80; height: 80
        opacity: root.iconOpacity
        MaterialIconSymbol {
            anchors.centerIn: parent
            content: "videocam"
            iconSize: recArea.containsMouse ? 56 : 50
            color: Colors.primaryText
            Behavior on iconSize { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            id: recArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.recordingClicked()
        }
    }

    // Power
    Item {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: 30
        anchors.leftMargin: 30
        width: 80; height: 80
        opacity: root.iconOpacity
        MaterialIconSymbol {
            anchors.centerIn: parent
            content: "power_settings_new"
            iconSize: powerArea.containsMouse ? 56 : 50
            color: Colors.primaryText
            Behavior on iconSize { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            id: powerArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }
    }

    // Settings
    Item {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: 30
        anchors.rightMargin: 30
        width: 80; height: 80
        opacity: root.iconOpacity
        MaterialIconSymbol {
            anchors.centerIn: parent
            content: "settings"
            iconSize: settingsArea.containsMouse ? 56 : 50
            color: Colors.primaryText
            Behavior on iconSize { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            id: settingsArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: GlobalStates.settingsOpen = true
        }
    }

    Rectangle {
        anchors.centerIn: parent
        implicitWidth: 50
        implicitHeight: 50
        radius: width / 2
        color: Colors.primaryText
        opacity: root.iconOpacity

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: "close"
            iconSize: 40
            color: Colors.primary
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: GlobalStates.toolsWidgetOpen = false
        }
    }
}
