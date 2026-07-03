import Quickshell
import Quickshell.Widgets
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings
import QtQuick.Effects
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MatrialShapeFn

ColumnLayout{
    id: root
    anchors.fill: parent
    anchors.margins: 10
    spacing: 10
    signal backClicked
    property var bluetoothData

    opacity: 0

    NumberAnimation on opacity{
        from: 0
        to: 1
        duration: 200
        running: true
    }

    RowLayout{
        Layout.fillWidth: true
        Layout.fillHeight: true
        CustomButton{
            icon: "chevron_backward"
            iconSize: 24
            radius: 10
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            onClicked: {
                if(root.isWifiSettingClicked){
                    root.isWifiSettingClicked = false
                }else{
                    root.backClicked()
                }
            }
        }
        Item{
            Layout.fillWidth: true
        }

        CustomText{
            content: "Bluetooth"
            size: 18
            color: Colors.primary
        }
        Item{
            Layout.fillWidth: true
        }
        CustomButton{
            icon: "search"
            iconSize: 18
            radius: 10
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            onClicked:  Bluetooth.defaultAdapter.discovering = true

        }
    }

    CustomText{
        content: "Saved Devices"
        size: 14
        color: Colors.outline
    }

    Item{
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        ListView{
            id: list
            anchors.fill: parent
            orientation: Qt.Vertical
            model: ServiceBluetooth.connectedAndPairedDevices
            spacing: 5

            delegate: Rectangle{
                implicitHeight: 40
                implicitWidth:  parent ? parent.width : 0
                color: modelData.state === 1 ? Colors.primary : bluetoothArea.containsMouse ? Qt.alpha(Colors.primary, 0.5) : "transparent"
                radius: 10

                Behavior on color{
                    ColorAnimation{
                        duration: 200
                    }
                }

                MouseArea{
                    id: bluetoothArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked:{
                        if(modelData.connected){
                            modelData.disconnect()
                        }else{
                            modelData.connect()
                        }
                    }
                }

                RowLayout{
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 10

                    MaterialIconSymbol{
                        content:{
                            if(modelData.icon === "audio-headset"){
                                return "headphones"
                            }else if(modelData.icon === "input-keyboard"){
                                return "keyboard"
                            }else if(modelData.icon === "input-mouse"){
                                return "mouse"
                            }else return "bluetooth"
                        }
                        iconSize: 22
                        color: modelData.state === 1 ? Colors.primaryText : Colors.surfaceText
                    }



                    ColumnLayout{
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        CustomText{
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            size: 12
                            content: modelData.name
                            color: modelData.state === 1 ? Colors.primaryText : Colors.surfaceText
                        }

                        CustomText{
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            size: 11
                            content: modelData.bonded ? "Saved" : "Not Trusted"
                            color: Colors.outline
                        }
                    }

   

                    Loader{
                        id: batteryLoader
                        active: modelData.batteryAvailable
                        Layout.alignment: Qt.AlignCenter
                        property string icon:{
                            let level = modelData.battery
                            if(level === 1){
                                return "battery_android_full"
                            }else if(level < 1 && level >= 0.9){
                                return "battery_android_6"
                            }else if(level < 0.9 && level >= 0.7){
                                return "battery_android_5"
                            }else if(level < 0.7 && level >= 0.5){
                                return "battery_android_4"
                            }else if(level < 0.5 && level >= 0.3){
                                return "battery_android_3"
                            }else if(level < 0.3 && level >= 0.2){
                                return "battery_android_2"
                            }else if(level < 0.2 && level >= 0){
                                return "battery_android_1"
                            }
                            return "battery_android_0"
                        }
                        sourceComponent: MaterialIconSymbol{
                            anchors.centerIn: parent
                            content: icon
                            iconSize: 22
                            color: Colors.primaryText
                        }
                    }
                }
            }
        }
    }

    // Rectangle{
    //     Layout.fillWidth: true
    //     Layout.preferredHeight: 1
    //     color: Colors.outline
    // }
    CustomSpermSeparator{
        Layout.fillWidth: true
        Layout.preferredHeight: 6
        color: Colors.outline
        frequency: 14
    }

    CustomText{
        content: "Available Devices"
        size: 14
        color: Colors.outline
    }

    Item{
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        Loader{
            anchors.centerIn: parent
            visible: active
            active: ServiceBluetooth.unpairedDevices.length === 0
            sourceComponent:ColumnLayout{
                anchors.centerIn: parent
                MaterialShapes.ShapeCanvas{
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredHeight: 60
                    Layout.preferredWidth: 60
                    roundedPolygon: MatrialShapeFn.getSunny()
                    color: Colors.primaryText

                    MaterialIconSymbol{
                        anchors.centerIn: parent
                        content: "bluetooth_searching"
                        iconSize: 26
                        color: Colors.primary
                    }
                }
                CustomText{
                    Layout.alignment: Qt.AlignCenter
                    content: "Scan for Bluetooth Devices"
                    size: 14
                    color: Colors.outline
                }

            }
        }

        Loader{
            anchors.fill: parent
            visible: active
            active: ServiceBluetooth.unpairedDevices.length > 0
            sourceComponent: ListView{
                anchors.fill: parent
                orientation: Qt.Vertical
                model: ServiceBluetooth.unpairedDevices
                spacing: 5

                delegate: Rectangle{
                    implicitHeight: 40
                    implicitWidth:  parent ? parent.width : 0
                    color: area.containsMouse ? Qt.alpha(Colors.primary, 0.5) : "transparent"
                    radius: 10

                    Behavior on color{
                        ColorAnimation{
                            duration: 200
                        }
                    }

                    MouseArea{
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked:{
                            if(modelData.connected){
                                modelData.disconnect()
                            }else{
                                modelData.connect()
                            }
                        }
                    }

                    RowLayout{
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 10

                        MaterialIconSymbol{
                            content:{
                                if(modelData.icon === "audio-headset"){
                                    return "headphones"
                                }else if(modelData.icon === "input-keyboard"){
                                    return "keyboard"
                                }else if(modelData.icon === "input-mouse"){
                                    return "mouse"
                                }else return "bluetooth"
                            }
                            iconSize: 20
                        }



                        ColumnLayout{
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            CustomText{
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                size: 12
                                content: modelData.name
                                color: modelData.state === 1 ? Colors.primaryText : Colors.surfaceText
                            }

                            CustomText{
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                size: 11
                                content: modelData.bonded ? "Saved" : "Not Trusted"
                                color: Colors.outline
                            }
                        }
                    }
                }
            }
        }
    }

        Rectangle{
            Layout.alignment: Qt.AlignCenter
            Layout.preferredHeight: 40
            Layout.fillWidth: true
            radius: 15
            color: area.containsMouse ? Colors.primary : Colors.surfaceContainerHighest
            RowLayout{
                anchors.centerIn: parent
                spacing: 10
                MaterialIconSymbol{
                    content: "settings"
                    iconSize: 18
                    color: area.containsMouse ? Colors.primaryText : Colors.surfaceText

                }
                CustomText{
                    content: "Bluetooth Settings"
                    size: 14
                    color: area.containsMouse ? Colors.primaryText : Colors.surfaceText
                } 
            }
            MouseArea{
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.backClicked()
                    GlobalStates.settingsPage = 5
                    GlobalStates.settingsOpen = true
                }
            }
        }
    }
