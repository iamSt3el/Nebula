import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item{
    id: utility
    implicitWidth: row.width + 20 
    implicitHeight: Appearance.size.barHeight
    anchors.right: parent.right
    property alias container: container
    property bool isClicked: false 

    property bool isWifiClicked: false
    property bool isBluetoothClicked: false
    property bool isNotificationClicked: false
    property bool isSoundPanelClicked: false
    property bool isBatteryInfoClicked: false
    property bool isWeatherPanelClicked: false
    property bool isDashboard: height > 900

    onIsClickedChanged:{
        if(utility.isClicked){
            utility.implicitWidth = Appearance.size.dashboardPanelWidth
            utility.implicitHeight = Appearance.size.dashboardPanelHeight
        }else{
            utility.implicitWidth = row.width + 20
            utility.implicitHeight = Appearance.size.barHeight
        }
    }

    onIsNotificationClickedChanged:{
        if(utility.isNotificationClicked){
            utility.implicitWidth = Appearance.size.notificationPanelWidth
            utility.implicitHeight = Appearance.size.notificationPanelHeight
        }else{
            utility.implicitWidth = row.width + 20
            utility.implicitHeight = Appearance.size.barHeight
        }
    }

    onIsWeatherPanelClickedChanged:{
        if(utility.isWeatherPanelClicked){
            utility.implicitWidth = Appearance.size.weatherPanelWidth
            utility.implicitHeight = Appearance.size.weatherPanelHeight
        }else{
            utility.implicitWidth = row.width + 20
            utility.implicitHeight = Appearance.size.barHeight
        }

    }

    // onIsBatteryInfoClickedChanged:{
    //     if(utility.isBatteryInfoClicked){
    //         utility.implicitWidth = Appearance.size.batteryPanelWidth
    //         utility.implicitHeight = Appearance.size.batteryPanelHeight
    //     }else{
    //         utility.implicitWidth = row.width + 20
    //         utility.implicitHeight = Appearance.size.barHeight
    //     }
    // }

    Behavior on implicitWidth{
        NumberAnimation{
            duration: Appearance.duration.normal
            easing.type: Easing.OutQuad
        }
    }
    Behavior on implicitHeight{
        NumberAnimation{
            duration: Appearance.duration.normal
            easing.type: Easing.OutQuad
        }
    }

    Loader{
        active: utility.isSoundPanelClicked
        visible: active
        sourceComponent: SoundPanel{
            onClose: utility.isSoundPanelClicked = false
        }
    }


    Item{
        id: container 
        anchors.fill: parent
        //color: Settings.layoutColor

        Loader{
            id: notificationLoader
            active: utility.isNotificationClicked
            anchors.fill: parent
            //anchors.margins: Appearance.margin.medium
            visible: false
            Timer{
                interval: Appearance.duration.normal 
                running: utility.isNotificationClicked
                onTriggered:{
                    notificationLoader.visible = true
                }
            }
            sourceComponent: NotificationCenter{
                id: notificationCenter
                onNotificationCenterClosed: {
                    utility.isNotificationClicked = false
                    notificationLoader.visible = false
                }
            }
        }

        Loader{
            id: weatherLoader
            active: utility.isWeatherPanelClicked
            anchors.fill: parent
            visible: false
            Timer{
                interval: Appearance.duration.normal 
                running: utility.isWeatherPanelClicked
                onTriggered:{
                    weatherLoader.visible = true
                }
            }
            sourceComponent: WeatherPanel{
                id: weatherCenter
                onClosed: {
                    utility.isWeatherPanelClicked = false
                    weatherLoader.visible = false
                }
            }
        }

        Loader{
            id: dashboardLoader
            active: utility.isClicked
            anchors.centerIn: parent
            anchors.fill: parent
            visible: false
            Timer{
                interval: Appearance.duration.normal
                running: utility.isClicked
                onTriggered:{
                    dashboardLoader.visible = true
                }
            }
            sourceComponent: Dashboard{
                id: dashboard
                onToggleDashboard: {
                    utility.isClicked = false
                    dashboardLoader.visible = false
                }
                onIsWifiClickedChanged: utility.isWifiClicked = dashboard.isWifiClicked
                onIsBluetoothClickedChanged: utility.isBluetoothClicked = dashboard.isBluetoothClicked
            }
        }



        RowLayout{
            id: row
            visible: !utility.isClicked && !utility.isTodoClicked && utility.height === 40
            spacing: Appearance.spacing.medium
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Appearance.margin.medium

            Loader{
                active: ServiceSystemTray.active
                visible: active
                Layout.fillWidth: true
                sourceComponent:SystemTray{
                }
            }

            Weather{
                Layout.preferredHeight: Appearance.size.widgetHeight
                onClicked: utility.isWeatherPanelClicked = true
            }

            Rectangle{
                Layout.preferredWidth: speaker.implicitWidth + 10
                Layout.preferredHeight: Appearance.size.widgetHeight
                radius: Appearance.radius.medium
                color: Colors.surfaceContainerHigh


                MaterialIconSymbol{
                    id: speaker
                    anchors.centerIn: parent
                    content: "volume_up"
                    iconSize: Appearance.size.iconSizeNormal - 2
                }

                CustomMouseArea{
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked:{
                        utility.isSoundPanelClicked = true
                    }
                }
                
            }



            Rectangle{
                radius: Appearance.radius.medium
                Layout.preferredWidth: child.width + child.spacing * 2
                Layout.preferredHeight: Appearance.size.widgetHeight
                color: Colors.surfaceContainerHigh
                RowLayout{
                    id: child
                    spacing: Appearance.spacing.medium
                    anchors.centerIn: parent
                    MaterialIconSymbol{
                        iconSize: Appearance.size.iconSizeNormal
                        content: ServiceWifi.wifiEnabled ? ServiceWifi.icon : "signal_wifi_off"                    
                        MouseArea{
                            id: wifiArea
                            anchors.fill: parent
                            hoverEnabled: true

                        }

                        CustomToolTip{
                            content: ServiceWifi.currentSSID
                            visible: wifiArea.containsMouse
                        }
                    }

                    MaterialIconSymbol{
                        iconSize: Appearance.size.iconSizeNormal - 1
                        content: ServiceBluetooth.state ? "bluetooth" : "bluetooth_disabled"

                        MouseArea{
                            id: bluetoothArea
                            anchors.fill: parent
                            hoverEnabled: true

                        }

                        CustomToolTip{
                            content: ServiceBluetooth.connectedDevices + " connected"
                            visible: bluetoothArea.containsMouse
                        }
                    }


                    MaterialIconSymbol{
                        iconSize: Appearance.size.iconSizeNormal - 1
                        content: ServiceNotification.notificationsNumber > 0 ? "notifications_active" : "notifications"


                        CustomMouseArea{
                            id: notificaitonArea
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked:{
                                utility.isNotificationClicked = true
                            }
                        }
                        CustomToolTip{
                            content: ServiceNotification.notificationsNumber + " notifications"
                            visible: notificaitonArea.containsMouse
                        }
                    }
                }
            }

            Battery{
                Layout.preferredHeight: 25
                Layout.preferredWidth: 34

            }


            Rectangle{
                Layout.preferredHeight: dashboardIcon.height + 4
                Layout.preferredWidth: dashboardIcon.width + 10
                color: Colors.surfaceContainerHighest
                radius: Appearance.radius.medium

                Behavior on scale{
                    NumberAnimation{
                        duration: Appearance.duration.small
                    }
                }
                MaterialIconSymbol{
                    id: dashboardIcon
                    iconSize: 18
                    content: "dashboard"
                    anchors.centerIn: parent
                }

                CustomMouseArea{
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked:{
                        utility.isClicked = true
                    }
                }
            }

        }
    }
}
