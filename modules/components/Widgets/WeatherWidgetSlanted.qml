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

    Component.onCompleted: {
        root.x = SettingsConfig.widgets.weatherSlantedX ?? 100
        root.y = SettingsConfig.widgets.weatherSlantedY ?? 200
    }

    Connections {
        target: SettingsConfig
        function onWidgetsChanged() {
            if (!root.editMode) {
                root.x = SettingsConfig.widgets.weatherSlantedX ?? 100
                root.y = SettingsConfig.widgets.weatherSlantedY ?? 200
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
                weatherSlantedX: root.x, weatherSlantedY: root.y
            })
        }
    }

    MouseArea {
        anchors.fill: parent
        drag.target: root.editMode ? root : undefined
        cursorShape: root.editMode ? Qt.SizeAllCursor : Qt.ArrowCursor
        onDoubleClicked: root.editMode = !root.editMode
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: root.editMode ? "#aaffffff" : "transparent"
        border.width: 2
        radius: 12
        visible: root.editMode
    }

    // getPill() is a horizontal pill — render it on a swapped canvas rotated 90°
    // so it becomes a vertical pill that fills the portrait Item exactly.
    MaterialShapes.ShapeCanvas {
        anchors.centerIn: parent
        width: parent.height
        height: parent.width
        roundedPolygon: MaterialShapeFn.getPill()
        color: Colors.surface
    }



    CustomText {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 30
        anchors.rightMargin: 30
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 2
        content: ServiceWeather.temperature
        size: 60
        color: Colors.surfaceText
    }

    Image {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: 40
        anchors.leftMargin: 40
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 8
        width: 60
        height: 60
        sourceSize: Qt.size(width, height)
        source: IconUtil.getSystemIcon(ServiceWeather.weatherIconPath.svg)
    }

}
