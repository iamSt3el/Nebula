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
    implicitWidth: {
        if (isClicked)              return Appearance.size.dashboardPanelWidth
        if (isNotificationClicked)  return Appearance.size.notificationPanelWidth
        if (isWeatherPanelClicked)  return Appearance.size.weatherPanelWidth
        return row.implicitWidth + 20
    }
    implicitHeight: {
        if (isClicked)              return Appearance.size.dashboardPanelHeight
        if (isNotificationClicked)  return Appearance.size.notificationPanelHeight
        if (isWeatherPanelClicked)  return Appearance.size.weatherPanelHeight
        return Appearance.size.barHeight
    }
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
            visible: !utility.isClicked && utility.height === Appearance.size.barHeight
            spacing: Appearance.spacing.medium
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Appearance.margin.medium

            // ── Recording pill (M3 error container chip) ──────────────────
            Loader {
                active: ServiceTools.isRecording
                visible: active
                Layout.preferredHeight: Appearance.size.widgetHeight
                Layout.preferredWidth:  active ? implicitWidth : 0

                sourceComponent: Rectangle {
                    implicitWidth:  recPillContent.implicitWidth + 16
                    implicitHeight: Appearance.size.widgetHeight
                    radius: height / 2
                    color:  Colors.errorContainer
                    clip:   true

                    RowLayout {
                        id: recPillContent
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: Colors.error
                            SequentialAnimation on opacity {
                                running: true
                                loops:   Animation.Infinite
                                NumberAnimation { to: 0.2; duration: 700; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                            }
                        }

                        CustomText { content: "REC"; size: 10; weight: 700; color: Colors.errorContainerText }

                        Rectangle { width: 1; height: 10; color: Qt.alpha(Colors.errorContainerText, 0.30) }

                        CustomText {
                            content: {
                                const s = ServiceTools.recordingSeconds
                                return String(Math.floor(s / 60)).padStart(2, "0") + ":" +
                                       String(s % 60).padStart(2, "0")
                            }
                            size: 10; weight: 500; color: Colors.errorContainerText
                        }
                    }

                    MouseArea {
                        id: recPillMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    ServiceTools.stopRecording()
                    }

                    CustomToolTip {
                        content: "Stop recording"
                        visible: recPillMa.containsMouse
                    }
                }
            }

            Loader{
                active: ServiceSystemTray.active
                visible: active
                sourceComponent: SystemTray {}
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
                    radius: parent.radius
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked:{
                        utility.isSoundPanelClicked = true
                    }
                }
                
            }



            Rectangle{
                radius: Appearance.radius.medium
                Layout.preferredWidth: child.implicitWidth + Appearance.spacing.medium * 2
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
                            radius: 0
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
                    radius: parent.radius
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
