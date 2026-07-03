import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MaterialShapeFn

Item {
    id: root
    implicitWidth: 200
    implicitHeight: 200

    property bool editMode: false

    scale: root.editMode ? 1.05 : 1.0
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    layer.enabled: root.editMode
    layer.smooth: true
    layer.textureSize: root.editMode ? Qt.size(width * 1.05, height * 1.05) : Qt.size(width, height)
    property real clockSize: 200

    Component.onCompleted: {
        root.x = SettingsConfig.widgets.analogClockX ?? 400
        root.y = SettingsConfig.widgets.analogClockY ?? 200
    }

    Connections {
        target: SettingsConfig
        function onWidgetsChanged() {
            if (!root.editMode) {
                root.x = SettingsConfig.widgets.analogClockX ?? 400
                root.y = SettingsConfig.widgets.analogClockY ?? 200
            }
        }
    }

    onXChanged: if (editMode) saveTimer.restart()
    onYChanged: if (editMode) saveTimer.restart()

    Timer {
        id: saveTimer
        interval: 500
        repeat: false
        onTriggered: {
            SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, {
                analogClockX: root.x, analogClockY: root.y
            })
        }
    }

    MouseArea {
        anchors.fill: parent
        drag.target: root.editMode ? root : undefined
        cursorShape: root.editMode ? Qt.SizeAllCursor : Qt.ArrowCursor
        onDoubleClicked: root.editMode = true
        onReleased: if (root.editMode) root.editMode = false
    }

    // Cookie9 shape face
    MaterialShapes.ShapeCanvas {
        anchors.centerIn: parent
        width: root.clockSize
        height: root.clockSize
        roundedPolygon: MaterialShapeFn.getCookie12Sided()
        color: Colors.surface
    }

    // Hour hand
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        width: 10
        height: root.clockSize * 0.24
        radius: 5
        color: "transparent"//Colors.surfaceText
        border.width: 2
        border.color: Colors.primary
        transformOrigin: Item.Bottom
        rotation: (parseInt(ServiceClock.hour) % 12 + parseInt(ServiceClock.minute) / 60) / 12 * 360
        Behavior on rotation {
            RotationAnimation { direction: RotationAnimation.Clockwise; duration: 400; easing.type: Easing.OutCubic }
        }
    }

    // Minute hand
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        width: 6
        height: root.clockSize * 0.32
        radius: 3
        color: Colors.surfaceText
        transformOrigin: Item.Bottom
        rotation: (parseInt(ServiceClock.minute) + parseInt(ServiceClock.seconds) / 60) / 60 * 360
        Behavior on rotation {
            RotationAnimation { direction: RotationAnimation.Clockwise; duration: 400; easing.type: Easing.OutCubic }
        }
    }

    // Second hand
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        width: 2
        height: root.clockSize * 0.35
        radius: 1
        color: Colors.primary
        transformOrigin: Item.Bottom
        rotation: parseInt(ServiceClock.seconds) / 60 * 360
        Behavior on rotation {
            RotationAnimation { direction: RotationAnimation.Clockwise; duration: 200; easing.type: Easing.Linear }
        }
    }

    // Center cap
    Rectangle {
        anchors.centerIn: parent
        width: 14; height: 14; radius: 7
        color: Colors.primary
        z: 10
    }
    Rectangle {
        anchors.centerIn: parent
        width: 6; height: 6; radius: 3
        color: Colors.primaryText
        z: 11
    }
}
