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
    // Bar-mode defaults — states override these for panels; content changes
    // (systray icons, recording timer) update immediately without animation.
    implicitWidth:  row.implicitWidth + 20
    implicitHeight: Appearance.size.barHeight
    anchors.right: parent.right
    property alias container: container

    property bool isClicked:             false
    property bool isNotificationClicked: false
    property bool isSoundPanelClicked:   false
    property bool isWeatherPanelClicked: false
    property bool isDashboard:           height > 900
    property real soundPanelCenterX: 0
    readonly property real dashBtnCenterX: dashBtnRect.mapToItem(null, dashBtnRect.width / 2, 0).x
    readonly property bool isPill: SettingsConfig.general.barMode === "pill"

    states: [
        State {
            name: "dashboard"
            // In pill mode the bar stays compact — dashboard renders in Layout.qml
            when: utility.isClicked && !utility.isPill
            PropertyChanges {
                target: utility
                implicitWidth:  Appearance.size.dashboardPanelWidth
                implicitHeight: Appearance.size.dashboardPanelHeight
            }
        },
        State {
            name: "notification"
            when: utility.isNotificationClicked && !utility.isPill
            PropertyChanges {
                target: utility
                implicitWidth:  Appearance.size.notificationPanelWidth
                implicitHeight: Appearance.size.notificationPanelHeight
            }
        },
        State {
            name: "weather"
            when: utility.isWeatherPanelClicked && !utility.isPill
            PropertyChanges {
                target: utility
                implicitWidth:  Appearance.size.weatherPanelWidth
                implicitHeight: Appearance.size.weatherPanelHeight
            }
        }
    ]

    transitions: Transition {
        NumberAnimation {
            properties: "implicitWidth,implicitHeight"
            duration:   Appearance.duration.normal
            easing.type: Easing.OutQuad
        }
    }

    // ── Sound panel ────────────────────────────────────────────────────────
    Loader {
        active:  utility.isSoundPanelClicked
        visible: active
        sourceComponent: SoundPanel { onClose: utility.isSoundPanelClicked = false }
    }

    Item {
        id: container
        anchors.fill: parent

        // ── Notification panel (non-pill — expands bar) ───────────────────
        Loader {
            id: notificationLoader
            active:       utility.isNotificationClicked && !utility.isPill
            anchors.fill: parent
            visible:      false
            Timer {
                interval: Appearance.duration.normal
                running:  utility.isNotificationClicked && !utility.isPill
                onTriggered: notificationLoader.visible = true
            }
            sourceComponent: NotificationCenter {
                onNotificationCenterClosed: {
                    utility.isNotificationClicked = false
                    notificationLoader.visible    = false
                }
            }
        }

        // ── Weather panel (non-pill — expands bar) ────────────────────────
        Loader {
            id: weatherLoader
            active:       utility.isWeatherPanelClicked && !utility.isPill
            anchors.fill: parent
            visible:      false
            Timer {
                interval: Appearance.duration.normal
                running:  utility.isWeatherPanelClicked && !utility.isPill
                onTriggered: weatherLoader.visible = true
            }
            sourceComponent: WeatherPanel {
                onClosed: {
                    utility.isWeatherPanelClicked = false
                    weatherLoader.visible         = false
                }
            }
        }

        // ── Dashboard panel (non-pill modes — expands bar) ────────────────
        Loader {
            id: dashboardLoader
            active:       utility.isClicked && !utility.isPill
            anchors.fill: parent
            visible:      false
            Timer {
                interval: Appearance.duration.normal
                running:  utility.isClicked && !utility.isPill
                onTriggered: dashboardLoader.visible = true
            }
            sourceComponent: Dashboard {
                onToggleDashboard: {
                    utility.isClicked       = false
                    dashboardLoader.visible = false
                }
            }
        }

        // ── Utility row ────────────────────────────────────────────────────
        RowLayout {
            id: row
            visible:             (!utility.isClicked || utility.isPill) && (!utility.isNotificationClicked || utility.isPill) && (!utility.isWeatherPanelClicked || utility.isPill) && utility.height === Appearance.size.barHeight
            spacing:             10
            anchors.verticalCenter: parent.verticalCenter
            anchors.right:          parent.right
            anchors.rightMargin:    10

            // ── REC pill ───────────────────────────────────────────────────
            Loader {
                active:  ServiceTools.isRecording
                visible: active
                Layout.preferredHeight: 28
                Layout.preferredWidth:  active ? implicitWidth : 0

                sourceComponent: Rectangle {
                    id: recPill
                    implicitWidth:  recRow.implicitWidth + 16
                    implicitHeight: 28
                    radius:         14
                    clip:           true
                    color:          recHov.hovered
                                    ? Qt.alpha(Colors.error, 0.22)
                                    : Qt.alpha(Colors.error, 0.10)
                    Behavior on color         { ColorAnimation  { duration: 180 } }
                    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    border.color: Qt.alpha(Colors.error, recHov.hovered ? 0.65 : 0.35)
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 180 } }

                    NumberAnimation on opacity { from: 0; to: 1; duration: 220; running: true }

                    RowLayout {
                        id: recRow
                        anchors.centerIn: parent
                        spacing: 6

                        // Icon with layered red glow rings
                        Item {
                            width: 20; height: 20

                            // Outer glow ring — pulses in opacity
                            Rectangle {
                                anchors.centerIn: parent
                                width: 20; height: 20; radius: 10
                                color: Colors.error
                                SequentialAnimation on opacity {
                                    running: true; loops: Animation.Infinite
                                    NumberAnimation { to: 0.20; duration: 850; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 0.04; duration: 850; easing.type: Easing.InOutSine }
                                }
                            }

                            // Inner ambient glow
                            Rectangle {
                                anchors.centerIn: parent
                                width: 13; height: 13; radius: 6.5
                                color: Colors.error; opacity: 0.18
                            }

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content:     "screen_record"
                                iconSize:    16
                                customColor: Colors.error
                            }
                        }

                        // Timer — revealed on hover
                        CustomText {
                            visible: recHov.hovered
                            content: {
                                const s = ServiceTools.recordingSeconds
                                return String(Math.floor(s / 60)).padStart(2, "0") + ":" +
                                       String(s % 60).padStart(2, "0")
                            }
                            size: 11; weight: 500
                            customColor: Colors.errorContainerText
                        }
                    }

                    HoverHandler { id: recHov }

                    CustomMouseArea {
                        anchors.fill: parent
                        radius:       parent.radius
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    ServiceTools.stopRecording()
                    }

                    CustomToolTip { content: "Click to stop recording"; visible: recHov.hovered }
                }
            }

            // ── System tray ────────────────────────────────────────────────
            Loader {
                active:  ServiceSystemTray.active
                visible: active
                sourceComponent: SystemTray {}
            }

            // ── Info pill: Weather + Volume ────────────────────────────────
            Rectangle {
                Layout.preferredHeight: 30
                implicitWidth:          infoRow.implicitWidth + 8
                radius:                 15
                color:                  "transparent"//Colors.surfaceContainerHigh

                RowLayout {
                    id: infoRow
                    anchors.centerIn: parent
                    spacing: 0

                    // Weather zone
                    Rectangle {
                        implicitWidth:  weatherRow.implicitWidth + 18
                        implicitHeight: 26
                        radius:         13
                        color:          weatherHov.containsMouse ? Colors.primaryContainer : "transparent"
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


                    // Volume zone
                    Rectangle {
                        id: volPill
                        implicitWidth:  volRow.implicitWidth + 18
                        implicitHeight: 26
                        radius:         13
                        color:          volHov.containsMouse ? Colors.primaryContainer : "transparent"
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
                                customColor: volHov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                                Behavior on customColor { ColorAnimation { duration: 150 } }
                            }

                            CustomText {
                                content: ServicePipewire.muted ? "Muted"
                                : Math.round(ServicePipewire.volume * 100) + "%"
                                size: 13; weight: 700
                                customColor: volHov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                                Behavior on customColor { ColorAnimation { duration: 150 } }
                            }
                        }

                        MouseArea {
                            id: volHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                utility.soundPanelCenterX = volPill.mapToItem(null, volPill.width / 2, 0).x
                                utility.isSoundPanelClicked = true
                            }
                        }
                    }
                }
            }

            // ── Status pill: Network / BT / Notification / Battery ─────────
            Rectangle {
                Layout.preferredHeight: 30
                implicitWidth:          groupRow.implicitWidth + 8
                radius:                 15
                color:                  "transparent"//Colors.surfaceContainerHigh

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
                            content:     ServiceNetwork.wifiEnabled ? ServiceNetwork.icon : "signal_wifi_off"
                            iconSize:    18
                            customColor: wifiHov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                            Behavior on customColor { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: wifiHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                        }

                        CustomToolTip {
                            content: ServiceNetwork.currentSSID.length > 0 ? ServiceNetwork.currentSSID : "No network"
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
                            customColor: btHov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
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
                            ? Colors.primary : Colors.surfaceText
                            Behavior on customColor { ColorAnimation { duration: 150 } }
                        }

                        // Count badge
                        Rectangle {
                            visible:             ServiceNotification.notificationsNumber > 0
                            anchors.right:       parent.right
                            anchors.top:         parent.top
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

                    // Battery (icon only)
                    Rectangle {
                        implicitWidth:  28; implicitHeight: 28; radius: 14
                        color:          battHov.containsMouse ? Colors.primaryContainer
                        : ServiceUPower.powerLevel < 0.2 && !ServiceUPower.isCharging
                        ? Qt.alpha(Colors.error, 0.15) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: {
                                if (ServiceUPower.isCharging)  return "battery_android_bolt"
                                const l = ServiceUPower.powerLevel
                                if (l === 1)                   return "battery_android_full"
                                if (l > 0.9)                   return "battery_android_6"
                                if (l > 0.7)                   return "battery_android_5"
                                if (l > 0.5)                   return "battery_android_4"
                                if (l > 0.3)                   return "battery_android_3"
                                if (l > 0.2)                   return "battery_android_2"
                                if (l > 0.0)                   return "battery_android_1"
                                return "battery_android_0"
                            }
                            iconSize: 18
                            customColor: battHov.containsMouse ? Colors.primaryContainerText
                            : ServiceUPower.powerLevel < 0.2 && !ServiceUPower.isCharging
                            ? Colors.error : Colors.surfaceText
                            Behavior on customColor { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: battHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                        }

                        CustomToolTip {
                            content: (ServiceUPower.isCharging ? "Charging · " : "")
                            + Math.round(ServiceUPower.powerLevel * 100) + "%"
                            visible: battHov.containsMouse
                        }
                    }
                }
            }

            // ── Dashboard button ───────────────────────────────────────────
            Rectangle {
                id: dashBtnRect
                Layout.preferredHeight: 30
                Layout.preferredWidth:  30
                radius:                 15
                color:                  dashHov.containsMouse ? Colors.primary : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content:     "dashboard"
                    iconSize:    18
                    customColor: dashHov.containsMouse ? Colors.primaryContainer : Colors.surfaceText
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
