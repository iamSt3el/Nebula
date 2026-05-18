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
import "../../MatrialShapes/material-shapes.js" as MaterialShapesFn


Item{
    id: root
    implicitHeight: 400
    implicitWidth: 400

    property bool editMode: false

    Component.onCompleted: {
        root.x = SettingsConfig.widgets.temperatureX
        root.y = SettingsConfig.widgets.temperatureY
    }

    onXChanged: if (editMode) tempSaveTimer.restart()
    onYChanged: if (editMode) tempSaveTimer.restart()

    Timer {
        id: tempSaveTimer
        interval: 500
        repeat: false
        onTriggered: {
            SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { temperatureX: root.x, temperatureY: root.y })
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
    MaterialShapes.ShapeCanvas{
        anchors.centerIn: parent
        implicitWidth: 300
        implicitHeight: 300
        color: Colors.surface
        roundedPolygon: MaterialShapesFn.getCookie6Sided()



        MaterialShapes.ShapeCanvas{
            anchors.centerIn: parent
            implicitWidth: 260
            implicitHeight: 260
            color: Colors.surfaceContainer
            roundedPolygon: MaterialShapesFn.getCookie6Sided()


        }

        MaterialShapes.ShapeCanvas{
            anchors.centerIn: parent
            implicitWidth: 220
            implicitHeight: 220
            color: Colors.surfaceContainerHigh
            roundedPolygon: MaterialShapesFn.getCookie6Sided()


        }

        MaterialShapes.ShapeCanvas{
            anchors.centerIn: parent
            implicitWidth: 180
            implicitHeight: 180
            color: Colors.surfaceContainerHighest
            roundedPolygon: MaterialShapesFn.getCookie6Sided()


        }

        MaterialShapes.ShapeCanvas{
            x: -50
            y: -50
            implicitWidth: 200
            implicitHeight: 200
            color: Colors.primary
            roundedPolygon: MaterialShapesFn.getGem()


            MaterialIconSymbol{
                anchors.centerIn: parent
                color: Colors.primaryText
                content: ServiceWeather.weatherIconPath
                iconSize: 80
            }

        }


        // MaterialShapes.ShapeCanvas{
        //     x: 180
        //     y: -40
        //     implicitWidth: 150
        //     implicitHeight: 150
        //     color: Colors.tertiary
        //     roundedPolygon: MaterialShapesFn.getCookie12Sided()
        //
        //     CustomText{
        //         anchors.centerIn: parent
        //         content: ServiceWeather.description
        //         size: 24
        //         color: Colors.tertiaryText
        //         font.family: "Titan One"
        //         weight: 600
        //
        //     }
        //
        // }


        MaterialShapes.ShapeCanvas{
            x: 150
            y: 150
            implicitWidth: 160
            implicitHeight: 160
            color: Colors.error
            roundedPolygon: MaterialShapesFn.getVerySunny()
            CustomText{
                anchors.centerIn: parent
                content: ServiceWeather.temperature
                size: 40
                color: Colors.errorText
                font.family: "Titan One"
                weight: 600

            }
        }
    }
}
