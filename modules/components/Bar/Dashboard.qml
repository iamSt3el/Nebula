import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MatrialShapeFn

Item{
    id: root
    anchors.fill: parent

    Component.onCompleted: ServiceSystemInfo.retain()
    Component.onDestruction: ServiceSystemInfo.release()
    implicitHeight: col.implicitHeight
    property string panelMode: ""   // "" | "wifi" | "bluetooth"
    property bool   compact:   false

    property var parentPos
    property var wifiPos
    property var bluetoothPos
    property var pos


    Timer{
        id: rowTimer
        interval: 300
        onTriggered: colu.visible = true
    }

    readonly property bool isPill: SettingsConfig.general.barMode === "pill"

    opacity: 0
    scale: root.isPill ? 1 : 0.8

    NumberAnimation on opacity {
        from: 0; to: 1; duration: 400; running: true
    }

    NumberAnimation on scale {
        from: root.isPill ? 1 : 0.8
        to: 1
        duration: 400
        running: true
    }

    property var downloadHistory: []

    // Feed it on each poll (e.g. via a Connections on ServiceSystemInfo)
    Connections {
        target: ServiceSystemInfo
        function onNetDownloadBpsChanged() {
            sparkline.addValue(ServiceSystemInfo.netDownloadBps)
        }
    }

    Connections {
        target: ServiceNetwork
        function onWifiEnabledChanged() {
            SettingsConfig.toggles = Object.assign({}, SettingsConfig.toggles, { airplaneMode: !ServiceNetwork.wifiEnabled })
        }
    }

    Connections {
        target: ServicePipewire
        function onMutedChanged() {
            SettingsConfig.toggles = Object.assign({}, SettingsConfig.toggles, { speakerMuted: ServicePipewire.muted })
        }
        function onMicMutedChanged() {
            SettingsConfig.toggles = Object.assign({}, SettingsConfig.toggles, { micMuted: ServicePipewire.micMuted })
        }
    }




    // Overlay backdrop — fades in/out independently
    Rectangle {
        id: overlayBackdrop
        anchors.fill: parent
        z: 1
        radius: 20
        color: Qt.alpha(Colors.surface, 0.7)
        opacity: root.panelMode !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    // Panel container — persistent so states/transitions actually animate
    Rectangle {
        id: container
        z: 2
        enabled: root.panelMode !== ""

        // Default (closed) position — tracks the tile that was last clicked
        x: root.pos ? root.pos.x : 0
        y: root.pos ? root.pos.y : 0
        width: wifi.width
        height: 60
        opacity: 0

        color: Colors.surfaceContainerHigh
        radius: 20
        clip: true

        states: [
            State {
                name: "wifi"
                when: root.panelMode === "wifi"
                PropertyChanges {
                    target: container
                    x: root.parentPos ? root.parentPos.x : 0
                    y: root.parentPos ? root.parentPos.y : 0
                    width: controleRectangle.width
                    height: controleRectangle.height + 400
                    opacity: 1
                }
            },
            State {
                name: "bluetooth"
                when: root.panelMode === "bluetooth"
                PropertyChanges {
                    target: container
                    x: root.parentPos ? root.parentPos.x : 0
                    y: root.parentPos ? root.parentPos.y : 0
                    width: controleRectangle.width
                    height: controleRectangle.height + 400
                    opacity: 1
                }
            }
        ]

        transitions: Transition {
            NumberAnimation {
                properties: "x,y,width,height,opacity"
                duration: 300
                easing.type: Easing.InOutCirc
            }
        }

        // Show content after open animation completes
        Timer {
            id: contentTimer
            interval: 300
            onTriggered: panelLoader.active = true
        }

        Connections {
            target: root
            function onPanelModeChanged() {
                panelLoader.active = false
                if (root.panelMode !== "") contentTimer.start()
            }
        }

        Loader {
            id: panelLoader
            active: false
            anchors.fill: parent
            visible: active
            sourceComponent: root.panelMode === "wifi" ? wifiComponent : bluetoothComponent
        }

        Component {
            id: wifiComponent
            Wifi {
                onBackClicked: {
                    root.panelMode = ""
                    panelLoader.active = false
                    rowTimer.start()
                }
            }
        }

        Component {
            id: bluetoothComponent
            Bluetooth {
                onBackClicked: {
                    root.panelMode = ""
                    panelLoader.active = false
                    rowTimer.start()
                }
            }
        }
    }

    NumberAnimation on opacity{
        from: 0
        to: 1
        duration: 200
        running: true
    }


    signal toggleDashboard
    property bool active: false//hoverHandler.hovered

    onActiveChanged:{
        if(!active) root.toggleDashboard()
    }


    // HoverHandler{
    //     id: hoverHandler
    // }

    ColumnLayout{
        id: col
        anchors.fill: parent
        spacing:         root.compact ? 7 : 10
        anchors.margins: root.compact ? 7 : 10

        Rectangle{
            Layout.preferredHeight: root.compact ? 42 : 50
            Layout.fillWidth: true
            color: Colors.surfaceContainer
            radius: 20
            RowLayout{
                anchors.fill: parent
                anchors.margins: 10
                anchors.rightMargin: 10
                spacing: 5

                ClippingWrapperRectangle{
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: height
                    color: "transparent"

                    border{
                        width: 1
                        color: Colors.outline
                    }

                    Image{
                        anchors.fill: parent
                        sourceSize: Qt.size(width, height)
                        source: SettingsConfig.general.profile
                    }
                }

                ColumnLayout{
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    spacing: 0
                    CustomText{
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        content: "St3el"
                        size: 14
                    }
                    CustomText{
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        content: "uptime " + ServiceSystemInfo.getUptime()

                        size: 13
                        color: Colors.outline
                    }
                }

                // MaterialIconSymbol{
                //     content: "settings"
                //     iconSize: 20 
                //     MouseArea{
                //         cursorShape: Qt.PointingHandCursor
                //         anchors.fill: parent
                //         onClicked: {
                //             GlobalStates.settingsOpen = true
                //             root.toggleDashboard()
                //         }
                //     }
                // }
                CustomButton{
                    icon: "settings"
                    iconSize: 18
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 30
                    radius: 10
                    onClicked: {
                        root.toggleDashboard()
                        GlobalStates.settingsPage = 9
                        GlobalStates.settingsOpen = true
                    }
                }

                CustomButton{
                    icon: "power_settings_new"
                    iconSize: 18
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 40
                    radius: 10
                    onClicked: {
                        root.toggleDashboard()
                        GlobalStates.shutdownWindow = true
                    }
                }
                CustomButton{
                    icon: "close"
                    iconSize: 18
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 30
                    radius: 10

                    onClicked: {
                        root.toggleDashboard()
                    }
                }
               
                // MaterialIconSymbol{
                //     content: "close"
                //     iconSize: 20
                //     MouseArea{
                //         cursorShape: Qt.PointingHandCursor
                //         anchors.fill: parent
                //         onClicked: root.toggleDashboard()
                //     }
                // }


            }
        }

        Rectangle{
            id: controleRectangle
            Layout.preferredHeight: colu.implicitHeight
            Layout.fillWidth: true
            color: "transparent"//Colors.surfaceContainer
            radius: 20

            Behavior on Layout.preferredHeight{
                NumberAnimation{
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }

            ColumnLayout{
                id: colu
                anchors.fill: parent
                anchors.margins: 0
                spacing: root.compact ? 7 : 10

                RowLayout{
                    Layout.fillWidth: true
                    spacing: root.compact ? 7 : 10

                    ColumnLayout{
                        Layout.fillHeight: true
                        spacing: root.compact ? 7 : 10
                        Rectangle{
                            id: wifi
                            Layout.preferredHeight: root.compact ? 50 : 60
                            Layout.fillWidth: true
                            radius: 20
                            color: Colors.surfaceContainerHigh
                            opacity: root.panelMode === "wifi" ? 0 : 1

                            Behavior on opacity {
                                NumberAnimation { duration: 300 }
                            }

                            RowLayout{
                                anchors.fill: parent
                                anchors.margins: 5

                                MaterialShapes.ShapeCanvas{
                                    Layout.preferredHeight: root.compact ? 42 : 50
                                    Layout.preferredWidth:  root.compact ? 42 : 50
                                    roundedPolygon: MatrialShapeFn.getCookie6Sided()
                                    color: Colors.primary


                                    MaterialIconSymbol{
                                        anchors.centerIn: parent
                                        iconSize: root.compact ? 22 : 28
                                        content: ServiceNetwork.icon
                                        color: ServiceNetwork.wifiEnabled ? Colors.primaryText : Colors.surfaceText
                                    }
                                }

                                ColumnLayout{
                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                    spacing: 5
                                    CustomText{
                                        Layout.fillWidth: true
                                        content: ServiceNetwork.connectionType
                                        size: 14
                                        weight: 700
                                    }

                                    CustomText{
                                        Layout.fillWidth: true
                                        content: ServiceNetwork.currentSSID || "no device"
                                        size: 12
                                        color: Colors.outline
                                    }
                                }

                                MaterialIconSymbol{
                                    content: "chevron_right"
                                    size: 14
                                    color: Colors.outline
                                }
                            }

                            MouseArea{
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked:{
                                    root.parentPos = controleRectangle.mapToItem(root, 0, 0)
                                    root.pos = wifi.mapToItem(root, 0, 0)
                                    root.panelMode = "wifi"
                                }
                            }
                        }
                        Rectangle{
                            id: bluetooth
                            Layout.preferredHeight: root.compact ? 50 : 60
                            Layout.fillWidth: true
                            radius: 20
                            color: Colors.surfaceContainerHigh

                            RowLayout{
                                anchors.fill: parent
                                anchors.margins: 5



                                MaterialShapes.ShapeCanvas{
                                    Layout.preferredHeight: root.compact ? 42 : 50
                                    Layout.preferredWidth:  root.compact ? 42 : 50
                                    roundedPolygon: MatrialShapeFn.getCookie6Sided()
                                    color: Colors.primary


                                    MaterialIconSymbol{
                                        anchors.centerIn: parent
                                        iconSize: root.compact ? 22 : 28
                                        content: ServiceBluetooth.connectedDevices > 0 ? "bluetooth" : "bluetooth_disabled"
                                        color: Colors.primaryText
                                    }
                                }

                                ColumnLayout{
                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                    spacing: 5
                                    CustomText{
                                        Layout.fillWidth: true
                                        content: "Bluetooth"
                                        size: 14
                                    }

                                    CustomText{
                                        Layout.fillWidth: true
                                        content: ServiceBluetooth.connectedDevices + " connected"
                                        size: 12
                                        color: Colors.outline
                                    }
                                }
                                MaterialIconSymbol{
                                    content: "chevron_right"
                                    size: 14
                                    color: Colors.outline
                                }
                            }
                            MouseArea{
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked:{
                                    root.parentPos = controleRectangle.mapToItem(root, 0, 0)
                                    root.pos = bluetooth.mapToItem(root, 0, 0)
                                    root.panelMode = "bluetooth"
                                }
                            }
                        }

                        Rectangle{
                            Layout.preferredHeight: root.compact ? 32 : 40
                            Layout.fillWidth: true
                            radius: 20
                            color: Colors.surfaceContainerHigh

                            RowLayout{
                                anchors.fill: parent
                                anchors.margins: 5

                                Repeater{
                                    model: ServiceUPower.powerProfiles

                                    Rectangle{
                                        property bool active: ServiceUPower.powerProfile === index
                                        Layout.fillHeight: true
                                        Layout.fillWidth: true
                                        radius: 20
                                        color: active ? Colors.primary : profileArea.containsMouse ? Qt.alpha(Colors.primary, 0.5) :"transparent"

                                        MaterialIconSymbol{
                                            anchors.centerIn: parent
                                            iconSize: 20
                                            content: modelData.icon
                                            color: parent.active ? Colors.primaryText : Colors.surfaceText
                                            fill: 1
                                        }

                                        Behavior on color{
                                            ColorAnimation {
                                                duration: 200
                                            }
                                        }

                                        MouseArea{
                                            id: profileArea
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onClicked:{
                                                ServiceUPower.setPowerProfile(index)
                                            }
                                        }
                                    }
                                }

                            }
                        }
                    }

                    // CustomSlider{
                    //     Layout.fillHeight: true
                    //     icon: "volume_up"
                    //     progress: ServicePipewire.volume
                    //     onProgressChanged:{
                    //         ServicePipewire.setVolume(progress)
                    //     }
                    //
                    // }
                    CustomSliderOld{
                        Layout.fillHeight: true
                        Layout.preferredWidth: 50
                        icon: "volume_up"
                        progress: ServicePipewire.volume
                        onProgressChanged:{
                            ServicePipewire.setVolume(progress)
                        }
                    }

                    CustomSliderOld{
                        property var brightnessMonitor: ServiceBrightness.getMonitorForScreen(screen)
                        Layout.fillHeight: true
                        Layout.preferredWidth: 50
                        icon: "brightness_7"

                        progress: ServiceBrightness.getMonitorForScreen(screen).brightness
                        onChange:{
                            brightnessMonitor.setBrightness(progress)
                        }

                    }
                    // CustomSlider{
                    //     property var brightnessMonitor: ServiceBrightness.getMonitorForScreen(screen)
                    //     Layout.fillHeight: true
                    //     icon: "brightness_7"
                    //     progress: brightnessMonitor.brightness
                    //     onChange:{
                    //         brightnessMonitor.setBrightness(progress)
                    //     }
                    //
                    // }
                }
            }
        }

        Rectangle{
            Layout.fillWidth: true
            Layout.preferredHeight: root.compact ? 42 : 50
            color: Colors.surfaceContainer
            radius: 20

            ColumnLayout{
                anchors.fill: parent
                anchors.margins: root.compact ? 7 : 10
                spacing: root.compact ? 7 : 10


                RowLayout{
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.compact ? 32 : 40
                    spacing: 4
                    Repeater{
                        model: Settings.quickIcons
                        delegate: Rectangle{
                            id: qBtn
                            required property int index
                            required property var modelData

                            Layout.fillHeight: true
                            Layout.fillWidth: true

                            property bool active: {
                                if (index === 0) return !ServiceNetwork.wifiEnabled
                                if (index === 1) return ServiceNotification.muted
                                if (index === 2) return ServicePipewire.muted
                                if (index === 3) return ServicePipewire.micMuted
                                return false
                            }
                            property bool isFirst: index === 0
                            property bool isLast:  index === Settings.quickIcons.length - 1

                            color: active ? Colors.primary : Colors.surfaceContainerHigh
                            Behavior on color { ColorAnimation { duration: 150 } }

                            topLeftRadius:     (active || isFirst) ? height / 2 : 5
                            topRightRadius:    (active || isLast)  ? height / 2 : 5
                            bottomLeftRadius:  (active || isFirst) ? height / 2 : 5
                            bottomRightRadius: (active || isLast)  ? height / 2 : 5
                            Behavior on topLeftRadius     { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            Behavior on topRightRadius    { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            Behavior on bottomLeftRadius  { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            Behavior on bottomRightRadius { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: qBtn.active ? qBtn.modelData.iconActive : qBtn.modelData.icon
                                iconSize: 20
                                color: qBtn.active ? Colors.primaryText : Colors.surfaceText
                                Behavior on color { ColorAnimation { duration: 150 } }
                                layer.enabled: true
                                layer.smooth: true
                                scale: qRipple.pressed ? 0.82 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                            }

                            RippleEffect {
                                id: qRipple
                                anchors.fill: parent
                                topLeftRadius:     qBtn.topLeftRadius
                                topRightRadius:    qBtn.topRightRadius
                                bottomLeftRadius:  qBtn.bottomLeftRadius
                                bottomRightRadius: qBtn.bottomRightRadius
                                hoverColor: Qt.alpha(qBtn.active ? Colors.primaryText : Colors.primary, 0.10)
                                pressColor: Qt.alpha(qBtn.active ? Colors.primaryText : Colors.primary, 0.20)
                                onClicked: {
                                    if      (qBtn.index === 0) ServiceNetwork.toggleWifi()
                                    else if (qBtn.index === 1) ServiceNotification.toggleMute()
                                    else if (qBtn.index === 2) ServicePipewire.toggleMute()
                                    else if (qBtn.index === 3) ServicePipewire.toggleMicMute()
                                }
                            }
                        }
                    }
                }
            }
        }

        MusicPlayer{
            Layout.fillWidth: true
            Layout.preferredHeight: root.compact ? 120 : 150
        }

        // Item{
        //     Layout.fillWidth: true
        //     Layout.fillHeight: true
        // }


        Rectangle{
            Layout.fillWidth: true
            Layout.preferredHeight: cpu.implicitHeight + 20
            radius: 20
            color: Colors.surfaceContainer

            ColumnLayout{
                id: cpu
                anchors.fill: parent
                anchors.margins: 10
                spacing: 2
                RowLayout{ 
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    CustomMatrialCircularProgress{
                        Layout.preferredWidth:  root.compact ? 50 : 60
                        Layout.preferredHeight: root.compact ? 50 : 60
                        progress: ServiceSystemInfo.cpuUsage
                        thickness: 4
                        gap: 0.6
                        icon: "memory"
                        iconSize: root.compact ? 22 : 30
                        sperm: false
                    }

                    ColumnLayout{
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        CustomText{
                            content: "CPU"
                            size: 16
                            color: Colors.primary
                        }
                        CustomText{
                            Layout.fillWidth: true
                            content: ServiceSystemInfo.cpuName
                            size: 14

                        }
                    }

                    MaterialShapes.ShapeCanvas{
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 50

                        roundedPolygon: MatrialShapeFn.getCookie4Sided()
                        color: Colors.primaryText

                        CustomText{
                            anchors.centerIn: parent
                            content: Math.round(ServiceSystemInfo.cpuUsage * 100) + "%"
                            size: 14
                            color: Colors.primary
                        }
                    }
                }

                // RowLayout{
                //     Layout.leftMargin: 5
                //     spacing: 0
                //     MaterialIconSymbol{
                //         content: "device_thermostat"
                //         iconSize: 20
                //         color: Colors.primary
                //     }
                //
                //     CustomText{
                //         content: ServiceSystemInfo.cpuTemp.toFixed(1) + "°C"
                //         size: 14
                //     }
                // }
                //
                //
                // CustomProgressBar{
                //     value: ServiceSystemInfo.cpuTemp / 100
                //     Layout.leftMargin: 10
                //     Layout.rightMargin: 10
                //     Layout.preferredHeight: 3
                //     Layout.fillWidth: true
                //     valueBarGap: 6
                // }
            }
        }

        Rectangle{
            Layout.fillWidth: true
            Layout.preferredHeight: gpu.implicitHeight + 20
            radius: 20
            color: Colors.surfaceContainer

            ColumnLayout{
                id: gpu
                anchors.fill: parent
                anchors.margins: 10


                RowLayout{ 
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    CustomMatrialCircularProgress{
                        Layout.preferredWidth:  root.compact ? 50 : 60
                        Layout.preferredHeight: root.compact ? 50 : 60
                        progress: ServiceSystemInfo.gpuUsage
                        thickness: 4
                        gap: 0.6
                        icon: "desktop_windows"
                        iconSize: root.compact ? 20 : 24
                        sperm: false
                    }

                    ColumnLayout{
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        CustomText{
                            content: "GPU"
                            size: 16
                            color: Colors.primary
                        }
                        CustomText{
                            Layout.fillWidth: true
                            content: ServiceSystemInfo.gpuName
                            size: 14

                        }
                    }

                    MaterialShapes.ShapeCanvas{
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 50

                        roundedPolygon: MatrialShapeFn.getPill()
                        color: Colors.primaryText

                        CustomText{
                            anchors.centerIn: parent
                            content: Math.round(ServiceSystemInfo.gpuUsage * 100) + "%"
                            size: 14
                            color: Colors.primary
                        }
                    }
                }

                // RowLayout{
                //     Layout.leftMargin: 5
                //     MaterialIconSymbol{
                //         content: "device_thermostat"
                //         iconSize: 24
                //         color: Colors.primary
                //     }
                //
                //     CustomText{
                //         content: ServiceSystemInfo.gpuTemp.toFixed(1) + "°C"
                //         size: 16
                //     }
                // }
                //
                // Item{
                //     Layout.fillHeight: true
                //     Layout.fillWidth: true
                //     Layout.leftMargin: 10
                //     Layout.rightMargin: 10
                //     CustomProgressBar{
                //         value: ServiceSystemInfo.gpuTemp / 100
                //         implicitHeight: 4
                //         implicitWidth: parent.width
                //         valueBarGap: 6
                //     }
                // }
            }
        }

        RowLayout{
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: 10

            Rectangle{
                Layout.fillWidth: true
                Layout.preferredHeight: mem.implicitHeight + 20
                radius: 20
                color: Colors.surfaceContainer

                ColumnLayout{
                    id: mem
                    anchors.centerIn: parent
                    spacing: 0
                    CustomGaugeProgress{
                        Layout.preferredWidth:  root.compact ? 100 : 120
                        Layout.preferredHeight: root.compact ? 100 : 120
                        progress: ServiceSystemInfo.memUsage
                        thickness: 8
                        gap: 0.2
                        icon: "memory_alt"
                        iconSize: 18
                        sperm: false
                    }

                    CustomText{
                        Layout.alignment: Qt.AlignCenter
                        content: ServiceSystemInfo.memUsedGb.toFixed(1) + " / " + ServiceSystemInfo.memTotalGb.toFixed(1) + " GB"
                        size: 14
                    }
                }
            }

            Rectangle{
                Layout.fillWidth: true
                Layout.preferredHeight: disk.implicitHeight + 20
                radius: 20
                color: Colors.surfaceContainer

                ColumnLayout{
                    id: disk
                    anchors.centerIn: parent
                    spacing: 0
                    CustomGaugeProgress{
                        Layout.preferredWidth:  root.compact ? 100 : 120
                        Layout.preferredHeight: root.compact ? 100 : 120
                        progress: ServiceSystemInfo.diskUsage
                        thickness: 8
                        gap: 0.2
                        icon: "hard_disk"
                        iconSize: 18
                        sperm: false
                    }

                    CustomText{
                        Layout.alignment: Qt.AlignCenter
                        content: ServiceSystemInfo.diskUsedGb.toFixed(1) + " / " + ServiceSystemInfo.diskTotalGb.toFixed(1) + " GB"
                        size: 14
                    }
                }
            }
        }

        Rectangle{
            visible: !root.compact
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 20
            color: Colors.surfaceContainer

            ColumnLayout{
                anchors.fill: parent
                anchors.margins: 15
                RowLayout{
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    MaterialIconSymbol{
                        content: "network_check"
                        iconSize: 20
                        color: Colors.primary
                    }

                    CustomText{
                        content: "Network"
                        size: 16
                    }
                }

                // Item{
                //     Layout.fillWidth: true
                //     Layout.fillHeight: true
                // }
                CustomSparkline {
                    id: sparkline
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    lineColor: Colors.primary
                }


                RowLayout{
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    MaterialIconSymbol{
                        content: "download"
                        iconSize: 20
                        color: Colors.primary
                    }

                    CustomText{
                        content: "Download"
                        size: 16
                    }

                    Item{
                        Layout.fillWidth: true
                    }

                    CustomText{
                        content: ServiceSystemInfo.formatBytes(ServiceSystemInfo.netDownloadBps)
                        size: 16
                        color: Colors.primary
                    }
                }


                RowLayout{
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    MaterialIconSymbol{
                        content: "upload"
                        iconSize: 20
                        color: Colors.primary
                    }

                    CustomText{
                        content: "Upload"
                        size: 16
                    }

                    Item{
                        Layout.fillWidth: true
                    }

                    CustomText{
                        content: ServiceSystemInfo.formatBytes(ServiceSystemInfo.netUploadBps)
                        size: 16
                        color: Colors.primary
                    }
                }


                RowLayout{
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    MaterialIconSymbol{
                        content: "history"
                        iconSize: 20
                        color: Colors.outline
                    }

                    CustomText{
                        content: "Total"
                        size: 16
                        color: Colors.outline
                    }

                    Item{
                        Layout.fillWidth: true
                    }

                    CustomText{
                        content: "↓" +ServiceSystemInfo.formatBytes(ServiceSystemInfo.netTotalRxBytes) + " ↑" + ServiceSystemInfo.formatBytes(ServiceSystemInfo.netTotalTxBytes) 
                        size: 16
                        color: Colors.outline
                    }
                }

            }
        }
    }
}
