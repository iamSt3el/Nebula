import Quickshell
import Quickshell.Widgets
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
    property bool isWifiSettingClicked: false
    property var wifiDetailsData

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
            content: "Wi-Fi"
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
            onClicked: ServiceNetwork.currentNetwork.scannerEnabled = true

        }
    }


    CustomText{
        content: "Saved Networks"
        size: 14
        color: Colors.outline
    }


    Item{
        Layout.fillWidth: true
        Layout.preferredHeight: 200
        clip: true
        ListView{ 
            id: list
            anchors.fill: parent
            implicitHeight: contentHeight
            orientation: Qt.Vertical
            model: ServiceNetwork.connectedAndSavedNetworks
            spacing: 5

            delegate: Rectangle{
                implicitHeight: 40
                implicitWidth: parent ? parent.width : 0
                color: modelData?.connected ? Colors.primary : wifiArea.containsMouse ? Qt.alpha(Colors.primary, 0.7) : "transparent"
                radius: 10

                Behavior on color{
                    ColorAnimation{
                        duration: 200
                    }
                }

                MouseArea{
                    id: wifiArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked:{
                        if(!modelData?.connected)modelData.connect()
                        else modelData?.disconnect()
                    }
                }

                RowLayout{
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 10


                    MaterialIconSymbol {
                        property string batteryIcon: {
                            let signal = modelData?.signalStrength * 100
                            if(signal >= 90){
                                return "signal_wifi_4_bar"
                            }
                            else if(signal < 90 && signal >=60){
                                return "network_wifi_3_bar"
                            }else if(signal < 60 && signal >= 30){
                                return "network_wifi_2_bar"
                            }
                            return "network_wifi_1_bar"
                        }

                        iconSize: 20
                        content: batteryIcon
                        color: modelData?.connected ? Colors.primaryText : Colors.surfaceText

                    }



                    ColumnLayout{
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10
                        CustomText{
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            size: 12
                            content: modelData?.name ?? ""
                            color: modelData.connected ? Colors.primaryText : Colors.surfaceText
                        }

                        CustomText{
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: modelData?.connected
                            content: modelData?.connected ? "Connected" : ""
                            color: Colors.outline
                        }
                    }


                    Item{
                        Layout.preferredWidth: row.implicitWidth 
                        Layout.fillHeight: true

                        Behavior on Layout.preferredWidth{
                            NumberAnimation{
                                duration: 200
                                easing.type:Easing.OutQuad
                            }
                        }
                        RowLayout{
                            id: row
                            anchors.fill: parent
                            spacing: 10
                            Loader{
                                id: lockLoader
                                active: modelData?.security ? true : false

                                sourceComponent: MaterialIconSymbol {
                                    iconSize: Appearance.size.iconSizeNormal - 5
                                    content: "lock"
                                    color: modelData?.connected ? Colors.primaryText : Colors.surfaceText
                                }
                            }

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
        content: "Available Networks"
        size: 14
        color: Colors.outline

    }
    Item{
        Layout.fillHeight: true
        Layout.fillWidth: true
        clip: true

        Loader{
            anchors.centerIn: parent
            active: ServiceNetwork.available.length === 0
            visible: active
            sourceComponent: ColumnLayout{
                anchors.centerIn: parent
                MaterialShapes.ShapeCanvas{
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredHeight: 60
                    Layout.preferredWidth: 60
                    roundedPolygon: MatrialShapeFn.getSunny()
                    color: Colors.primaryText

                    MaterialIconSymbol{
                        anchors.centerIn: parent
                        content: "wifi_find"
                        iconSize: 26
                        color: Colors.primary
                    }
                }
                CustomText{
                    Layout.alignment: Qt.AlignCenter
                    content: "Scan for networks"
                    size: 14
                    color: Colors.outline
                }
            }
        }

        Loader{
            anchors.fill: parent
            visible: active
            active:  ServiceNetwork.available.length > 0
            sourceComponent:ListView{   
                anchors.fill: parent
                orientation: Qt.Vertical
                model: ServiceNetwork.available
                spacing: 5

                delegate: Rectangle{
                    implicitHeight: 40
                    implicitWidth: parent ? parent.width : 0
                    radius: 10
                    color: newWifiArea.containsMouse ? Qt.alpha(Colors.primary, 0.7) : "transparent"

                    Behavior on color{
                        ColorAnimation{
                            duration: 200
                        }
                    }

                    MouseArea{
                        id: newWifiArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked:{
                            if(!modelData?.connected)modelData.connect()
                            else modelData?.disconnect()
                        }
                    }

                    RowLayout{
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 10


                        MaterialIconSymbol {
                            property string batteryIcon: {
                                let signal = modelData.signalStrength * 100
                                if(signal >= 90){
                                    return "signal_wifi_4_bar"
                                }
                                else if(signal < 90 && signal >=60){
                                    return "network_wifi_3_bar"
                                }else if(signal < 60 && signal >= 30){
                                    return "network_wifi_2_bar"
                                }
                                return "network_wifi_1_bar"
                            }

                            iconSize: 20
                            content: batteryIcon

                        }



                        ColumnLayout{
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 10
                            CustomText{
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                size: 12
                                content: modelData?.name ?? ""
                            }

                            CustomText{
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: modelData?.known
                                content: modelData?.known ? "Known" : "Unknown"
                                color: Colors.outline
                            }
                        }


                        Item{
                            Layout.preferredWidth: row.implicitWidth 
                            Layout.fillHeight: true

                            Behavior on Layout.preferredWidth{
                                NumberAnimation{
                                    duration: 200
                                    easing.type:Easing.OutQuad
                                }
                            }
                            RowLayout{
                                id: row
                                anchors.fill: parent
                                spacing: 10
                                Loader{
                                    id: lockLoader
                                    active: modelData?.security ? true : false

                                    sourceComponent: MaterialIconSymbol {
                                        iconSize: Appearance.size.iconSizeNormal - 5
                                        content: "lock"
                                        color: modelData?.connected ? Colors.primaryText : Colors.surfaceText
                                    }
                                }

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
                content: "Wifi Settings"
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
                GlobalStates.settingsPage = 4
                GlobalStates.settingsOpen = true
            }
        }
    }
}

