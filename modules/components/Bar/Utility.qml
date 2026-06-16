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

Item {
    id: utility
    implicitWidth: {
        if (isClicked)             return Appearance.size.dashboardPanelWidth
        if (isNotificationClicked) return Appearance.size.notificationPanelWidth
        if (isWeatherPanelClicked) return Appearance.size.weatherPanelWidth
        return row.implicitWidth + 20
    }
    implicitHeight: {
        if (isClicked)             return Appearance.size.dashboardPanelHeight
        if (isNotificationClicked) return Appearance.size.notificationPanelHeight
        if (isWeatherPanelClicked) return Appearance.size.weatherPanelHeight
        return Appearance.size.barHeight
    }
    anchors.right: parent.right
    property alias container: container

    property bool isClicked:             false
    property bool isWifiClicked:         false
    property bool isBluetoothClicked:    false
    property bool isNotificationClicked: false
    property bool isSoundPanelClicked:   false
    property bool isBatteryInfoClicked:  false
    property bool isWeatherPanelClicked: false
    property bool isDashboard:           height > 900

    Behavior on implicitWidth  { NumberAnimation { duration: Appearance.duration.normal; easing.type: Easing.OutQuad } }
    Behavior on implicitHeight { NumberAnimation { duration: Appearance.duration.normal; easing.type: Easing.OutQuad } }

    // ── Sound panel ────────────────────────────────────────────────────────
    Loader {
        active:  utility.isSoundPanelClicked
        visible: active
        sourceComponent: SoundPanel { onClose: utility.isSoundPanelClicked = false }
    }

    Item {
        id: container
        anchors.fill: parent

        // ── Notification panel ─────────────────────────────────────────────
        Loader {
            id: notificationLoader
            active:      utility.isNotificationClicked
            anchors.fill: parent
            visible:     false
            Timer {
                interval: Appearance.duration.normal
                running:  utility.isNotificationClicked
                onTriggered: notificationLoader.visible = true
            }
            sourceComponent: NotificationCenter {
                onNotificationCenterClosed: {
                    utility.isNotificationClicked    = false
                    notificationLoader.visible       = false
                }
            }
        }

        // ── Weather panel ──────────────────────────────────────────────────
        Loader {
            id: weatherLoader
            active:       utility.isWeatherPanelClicked
            anchors.fill: parent
            visible:      false
            Timer {
                interval: Appearance.duration.normal
                running:  utility.isWeatherPanelClicked
                onTriggered: weatherLoader.visible = true
            }
            sourceComponent: WeatherPanel {
                onClosed: {
                    utility.isWeatherPanelClicked = false
                    weatherLoader.visible         = false
                }
            }
        }

        // ── Dashboard panel ────────────────────────────────────────────────
        Loader {
            id: dashboardLoader
            active:       utility.isClicked
            anchors.fill: parent
            visible:      false
            Timer {
                interval: Appearance.duration.normal
                running:  utility.isClicked
                onTriggered: dashboardLoader.visible = true
            }
            sourceComponent: Dashboard {
                onToggleDashboard: {
                    utility.isClicked          = false
                    dashboardLoader.visible    = false
                }
                onIsWifiClickedChanged:      utility.isWifiClicked      = dashboard.isWifiClicked
                onIsBluetoothClickedChanged: utility.isBluetoothClicked = dashboard.isBluetoothClicked
            }
        }

        // ── Utility row ────────────────────────────────────────────────────
        RowLayout {
            id: row
            visible:             !utility.isClicked && utility.height === Appearance.size.barHeight
            spacing:             6
            anchors.verticalCenter: parent.verticalCenter
            anchors.right:          parent.right
            anchors.rightMargin:    10

            // ── REC pill ───────────────────────────────────────────────────
            Loader {
                active:  ServiceTools.isRecording
                visible: active
                Layout.preferredHeight: 30
                Layout.preferredWidth:  active ? implicitWidth : 0

                sourceComponent: Rectangle {
                    implicitWidth:  recRow.implicitWidth + 20
                    implicitHeight: 30
                    radius:         15
                    color:          Colors.errorContainer
                    clip:           true

                    RowLayout {
                        id: recRow
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: Colors.error
                            SequentialAnimation on opacity {
                                running: true; loops: Animation.Infinite
                                NumberAnimation { to: 0.2; duration: 700; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                            }
                        }

                        CustomText { content: "REC"; size: 11; weight: 700; customColor: Colors.errorContainerText }

                        Rectangle { width: 1; height: 10; color: Qt.alpha(Colors.errorContainerText, 0.30) }

                        CustomText {
                            content: {
                                const s = ServiceTools.recordingSeconds
                                return String(Math.floor(s / 60)).padStart(2, "0") + ":" +
                                       String(s % 60).padStart(2, "0")
                            }
                            size: 11; weight: 500; customColor: Colors.errorContainerText
                        }
                    }

                    MouseArea {
                        id: recPillMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    ServiceTools.stopRecording()
                    }

                    CustomToolTip { content: "Stop recording"; visible: recPillMa.containsMouse }
                }
            }

            // ── System tray ────────────────────────────────────────────────
            Loader {
                active:  ServiceSystemTray.active
                visible: active
                sourceComponent: SystemTray {}
            }

            // ── Weather pill ───────────────────────────────────────────────
            Rectangle {
                Layout.preferredHeight: 30
                implicitWidth:          weatherRow.implicitWidth + 22
                radius:                 15
                color:                  weatherHov.containsMouse ? Colors.primaryContainer : Colors.surfaceContainerHigh
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    id: weatherRow
                    anchors.centerIn: parent
                    spacing: 7

                    Image {
                        width: 16; height: 16
                        sourceSize: Qt.size(width, height)
                        source: IconUtil.getSystemIcon(ServiceWeather.weatherIconPath.svg)
                    }

                    CustomText {
                        content: ServiceWeather.temperature
                        size: 13; weight: 500
                        customColor: weatherHov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                        Behavior on customColor { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    id: weatherHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    utility.isWeatherPanelClicked = true
                }
            }

            // ── Volume pill ────────────────────────────────────────────────
            Rectangle {
                Layout.preferredHeight: 30
                implicitWidth:          volRow.implicitWidth + 22
                radius:                 15
                color:                  volHov.containsMouse ? Colors.primaryContainer : Colors.surfaceContainerHigh
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    id: volRow
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIconSymbol {
                        content: ServicePipewire.muted ? "volume_off"
                               : ServicePipewire.volume > 0.6 ? "volume_up"
                               : ServicePipewire.volume > 0.2 ? "volume_down"
                               : "volume_mute"
                        iconSize: 18
                        customColor: volHov.containsMouse ? Colors.primaryContainerText : Colors.outline
                        Behavior on customColor { ColorAnimation { duration: 150 } }
                    }

                    CustomText {
                        content: ServicePipewire.muted ? "Muted"
                               : Math.round(ServicePipewire.volume * 100) + "%"
                        size: 13; weight: 500
                        customColor: volHov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                        Behavior on customColor { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    id: volHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    utility.isSoundPanelClicked = true
                }
            }

            // ── Network / BT / Notification group ─────────────────────────
            Rectangle {
                Layout.preferredHeight: 30
                implicitWidth:          groupRow.implicitWidth + 8
                radius:                 15
                color:                  Colors.surfaceContainerHigh

                RowLayout {
                    id: groupRow
                    anchors.centerIn: parent
                    spacing: 2

                    // WiFi
                    Rectangle {
                        implicitWidth:  28; implicitHeight: 28; radius: 14
                        color:          wifiHov.containsMouse ? Colors.primaryContainer : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content:     ServiceWifi.wifiEnabled ? ServiceWifi.icon : "signal_wifi_off"
                            iconSize:    18
                            customColor: wifiHov.containsMouse ? Colors.primaryContainerText : Colors.outline
                            Behavior on customColor { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: wifiHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                        }

                        CustomToolTip {
                            content: ServiceWifi.currentSSID.length > 0 ? ServiceWifi.currentSSID : "No network"
                            visible: wifiHov.containsMouse
                        }
                    }

                    // Bluetooth
                    Rectangle {
                        implicitWidth:  28; implicitHeight: 28; radius: 14
                        color:          btHov.containsMouse ? Colors.primaryContainer : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content:     ServiceBluetooth.state ? "bluetooth" : "bluetooth_disabled"
                            iconSize:    18
                            customColor: btHov.containsMouse ? Colors.primaryContainerText : Colors.outline
                            Behavior on customColor { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: btHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                        }

                        CustomToolTip {
                            content: ServiceBluetooth.connectedDevices + " connected"
                            visible: btHov.containsMouse
                        }
                    }

                    // Notifications
                    Rectangle {
                        implicitWidth:  28; implicitHeight: 28; radius: 14
                        color:          notifHov.containsMouse ? Colors.primaryContainer : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content:     ServiceNotification.notificationsNumber > 0
                                         ? "notifications_active" : "notifications"
                            iconSize:    18
                            customColor: notifHov.containsMouse
                                         ? Colors.primaryContainerText
                                         : ServiceNotification.notificationsNumber > 0
                                           ? Colors.primary : Colors.outline
                            Behavior on customColor { ColorAnimation { duration: 150 } }
                        }

                        // Count badge
                        Rectangle {
                            visible:        ServiceNotification.notificationsNumber > 0
                            anchors.right:  parent.right
                            anchors.top:    parent.top
                            anchors.topMargin:   -1
                            anchors.rightMargin: -1
                            width:  badgeText.implicitWidth + 4
                            height: 12
                            radius: 6
                            color:  Colors.primary

                            CustomText {
                                id: badgeText
                                anchors.centerIn: parent
                                content:     ServiceNotification.notificationsNumber > 9
                                             ? "9+" : String(ServiceNotification.notificationsNumber)
                                size:        8; weight: 700
                                customColor: Colors.primaryText
                            }
                        }

                        MouseArea {
                            id: notifHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    utility.isNotificationClicked = true
                        }

                        CustomToolTip {
                            content: ServiceNotification.notificationsNumber + " notifications"
                            visible: notifHov.containsMouse
                        }
                    }
                }
            }

            // ── Battery pill ───────────────────────────────────────────────
            Rectangle {
                Layout.preferredHeight: 30
                implicitWidth:          battRow.implicitWidth + 22
                radius:                 15
                color:                  battHov.containsMouse
                                        ? Colors.primaryContainer
                                        : ServiceUPower.powerLevel < 0.2 && !ServiceUPower.isCharging
                                          ? Qt.alpha(Colors.error, 0.15)
                                          : Colors.surfaceContainerHigh
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    id: battRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIconSymbol {
                        content: {
                            if (ServiceUPower.isCharging)                  return "battery_android_bolt"
                            const l = ServiceUPower.powerLevel
                            if (l === 1)                                   return "battery_android_full"
                            if (l > 0.9)                                   return "battery_android_6"
                            if (l > 0.7)                                   return "battery_android_5"
                            if (l > 0.5)                                   return "battery_android_4"
                            if (l > 0.3)                                   return "battery_android_3"
                            if (l > 0.2)                                   return "battery_android_2"
                            if (l > 0.0)                                   return "battery_android_1"
                            return "battery_android_0"
                        }
                        iconSize: 18
                        customColor: battHov.containsMouse
                                     ? Colors.primaryContainerText
                                     : ServiceUPower.powerLevel < 0.2 && !ServiceUPower.isCharging
                                       ? Colors.error : Colors.outline
                        Behavior on customColor { ColorAnimation { duration: 150 } }
                    }

                    CustomText {
                        content: Math.round(ServiceUPower.powerLevel * 100) + "%"
                        size: 13; weight: 500
                        customColor: battHov.containsMouse
                                     ? Colors.primaryContainerText
                                     : ServiceUPower.powerLevel < 0.2 && !ServiceUPower.isCharging
                                       ? Colors.error : Colors.surfaceText
                        Behavior on customColor { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    id: battHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                }

                CustomToolTip {
                    content: ServiceUPower.isCharging ? "Charging" : "Battery"
                    visible: battHov.containsMouse
                }
            }

            // ── Dashboard button ───────────────────────────────────────────
            Rectangle {
                Layout.preferredHeight: 30
                Layout.preferredWidth:  30
                radius:                 15
                color:                  dashHov.containsMouse ? Colors.primary : Colors.primaryContainer
                Behavior on color { ColorAnimation { duration: 150 } }

                scale: dashHov.containsMouse ? 1.1 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.5 }
                }

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content:     "dashboard"
                    iconSize:    18
                    customColor: dashHov.containsMouse ? Colors.primaryText : Colors.primaryContainerText
                    Behavior on customColor { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: dashHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    utility.isClicked = true
                }

                CustomToolTip { content: "Dashboard"; visible: dashHov.containsMouse }
            }
        }
    }
}
