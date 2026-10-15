pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MatrialShapeFn

Item {
    id: root
    anchors.fill: parent

    signal backClicked
    property bool showBack: true

    property bool scanning: false
    property var pendingPair: null

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothOn: root.adapter?.enabled ?? false
    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"

    readonly property var connected: root.bluetoothOn ? ServiceBluetooth.connectedDevicesList : []
    readonly property var paired: root.bluetoothOn ? ServiceBluetooth.pairedDevices : []
    readonly property var knownNames: ServiceBluetooth.connectedAndPairedDevices.map(d => d.name).filter(n => !!n)
    readonly property var fresh: root.bluetoothOn
        ? ServiceBluetooth.unpairedDevices.filter(d => d.state !== BluetoothDeviceState.Connected
            && root.knownNames.indexOf(d.name) < 0) : []

    function deviceIcon(icon) {
        switch (icon) {
        case "audio-headset":
        case "audio-headphones":
            return "headphones"
        case "audio-card":
        case "audio-speakers":
            return "speaker"
        case "input-keyboard":
            return "keyboard"
        case "input-mouse":
            return "mouse"
        case "input-gaming":
            return "stadia_controller"
        case "input-tablet":
            return "stylus"
        case "phone":
            return "smartphone"
        case "computer":
            return "computer"
        case "video-display":
            return "tv"
        case "printer":
            return "print"
        default:
            return "bluetooth"
        }
    }

    function nameOf(device) {
        return device?.name || device?.address || "Unknown device"
    }

    function isOutput(device) {
        const addr = (device?.address ?? "").replace(/:/g, "_")
        return addr !== "" && (ServicePipewire.sink?.name ?? "").indexOf(addr) >= 0
    }

    function busy(device) {
        return device?.state === BluetoothDeviceState.Connecting
            || device?.state === BluetoothDeviceState.Disconnecting
            || (device?.pairing ?? false)
    }

    function startScan() {
        if (!root.adapter || !root.bluetoothOn) return
        root.adapter.discovering = true
        root.scanning = true
        scanTimer.restart()
    }

    function pair(device) {
        if (!device) return
        root.pendingPair = device
        device.pair()
    }

    function openSettings() {
        root.backClicked()
        GlobalStates.settingsPage = 5
        GlobalStates.settingsOpen = true
    }

    Connections {
        target: root.pendingPair
        ignoreUnknownSignals: true
        function onPairedChanged() {
            const d = root.pendingPair
            if (!d?.paired) return
            d.trusted = true
            d.connect()
            root.pendingPair = null
        }
    }

    Timer {
        id: scanTimer
        interval: 10000
        onTriggered: {
            root.scanning = false
            if (root.adapter) root.adapter.discovering = false
        }
    }

    Component.onDestruction: {
        if (scanTimer.running && Bluetooth.defaultAdapter)
            Bluetooth.defaultAdapter.discovering = false
    }

    opacity: 0
    EffectsAnim {
        target: root
        property: "opacity"
        from: 0; to: 1
        speed: "slow"
        running: true
    }

    component SectionLabel: RowLayout {
        id: sl
        property string text: ""
        property bool busy: false
        property string busyText: ""

        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.topMargin: 6
        Layout.bottomMargin: 3
        spacing: 8

        CustomText {
            Layout.fillWidth: true
            content: sl.text
            size: 13
            weight: 600
            customColor: Colors.primary
        }

        CustomText {
            visible: sl.busy
            content: sl.busyText
            size: 12
            weight: 400
            customColor: Colors.surfaceVariantText
        }

        CustomCircularLoader {
            visible: sl.busy
            size: 14
            trackWidth: 2
            waveAmplitude: 0
            highlightColor: Colors.primary
            trackColor: Colors.surfaceContainerHighest
        }
    }

    component DeviceTile: Rectangle {
        id: tile
        property var device: null
        readonly property bool hasBattery: tile.device?.batteryAvailable ?? false
        readonly property real level: Math.max(0, Math.min(1, tile.device?.battery ?? 0))
        readonly property bool low: tile.hasBattery && tile.level < 0.2
        readonly property bool output: root.isOutput(tile.device)
        readonly property bool busy: root.busy(tile.device)
        readonly property color ringColor: tile.low ? Colors.error : Colors.primary

        implicitHeight: 152
        radius: 24
        color: tileHover.hovered ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
        Behavior on color { EffectsColorAnim {} }

        HoverHandler { id: tileHover }

        Item {
            x: 14
            y: 14
            width: 68
            height: 68

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colors.outlineVariant
                    strokeWidth: 5
                    PathAngleArc {
                        centerX: 34; centerY: 34
                        radiusX: 30; radiusY: 30
                        startAngle: 0
                        sweepAngle: 360
                    }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: tile.hasBattery ? tile.ringColor : "transparent"
                    strokeWidth: 5
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 34; centerY: 34
                        radiusX: 30; radiusY: 30
                        startAngle: -90
                        sweepAngle: Math.max(0.5, 360 * tile.level)
                        Behavior on sweepAngle { SpatialAnim {} }
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 44
                height: 44
                radius: 22
                color: Colors.secondaryContainer

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: root.deviceIcon(tile.device?.icon)
                    iconSize: 24
                    fill: 1
                    customColor: Colors.secondaryContainerText
                }
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            visible: tile.output
            opacity: tileHover.hovered ? 0 : 1
            Behavior on opacity { EffectsAnim { speed: "fast" } }
            implicitWidth: outRow.implicitWidth + 16
            implicitHeight: 24
            radius: 12
            color: Colors.tertiaryContainer

            RowLayout {
                id: outRow
                anchors.centerIn: parent
                spacing: 4

                MaterialIconSymbol {
                    content: "volume_up"
                    iconSize: 14
                    fill: 1
                    customColor: Colors.tertiaryContainerText
                }

                CustomText {
                    content: "Output"
                    size: 11
                    weight: 600
                    customColor: Colors.tertiaryContainerText
                }
            }
        }

        M3IconButton {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            width: 36
            height: 36
            icon: "link_off"
            iconSize: 18
            opacity: tileHover.hovered && !tile.busy ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { EffectsAnim { speed: "fast" } }
            onClicked: tile.device?.disconnect()
        }

        CustomCircularLoader {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            visible: tile.busy
            size: 20
            trackWidth: 2
            waveAmplitude: 0
            highlightColor: Colors.primary
            trackColor: Colors.surfaceContainerHighest
        }

        ColumnLayout {
            x: 14
            width: parent.width - 28
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            spacing: 0

            CustomText {
                Layout.fillWidth: true
                content: root.nameOf(tile.device)
                size: 14
                weight: 600
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                CustomText {
                    visible: tile.hasBattery
                    content: Math.round(tile.level * 100) + "%"
                    family: root.displayFamily
                    renderType: Text.QtRendering
                    size: 22
                    weight: 400
                    customColor: tile.ringColor
                }

                CustomText {
                    Layout.fillWidth: true
                    content: tile.device?.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                        : !tile.hasBattery ? "Connected"
                        : tile.low ? "charge soon" : "battery"
                    size: 12
                    weight: 400
                    customColor: Colors.surfaceVariantText
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: dr
        property var device: null
        property bool fresh: false
        property bool first: false
        property bool last: false
        readonly property bool busy: root.busy(dr.device)

        Layout.fillWidth: true
        implicitHeight: 52
        topLeftRadius: dr.first ? 18 : 4
        topRightRadius: dr.first ? 18 : 4
        bottomLeftRadius: dr.last ? 18 : 4
        bottomRightRadius: dr.last ? 18 : 4
        color: drRipple.containsMouse ? Colors.surfaceContainerHighest
            : dr.fresh ? Colors.surfaceContainer : Colors.surfaceContainerHigh
        Behavior on color { EffectsColorAnim {} }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: dr.fresh ? Colors.surfaceContainerHigh : Colors.surfaceContainerHighest

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: root.deviceIcon(dr.device?.icon)
                    iconSize: 20
                    fill: 1
                    customColor: Colors.surfaceVariantText
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                CustomText {
                    Layout.fillWidth: true
                    content: root.nameOf(dr.device)
                    size: 14
                    weight: 600
                }

                CustomText {
                    Layout.fillWidth: true
                    visible: dr.busy
                    content: dr.device?.pairing ? "Pairing…"
                        : dr.device?.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                        : "Connecting…"
                    size: 12
                    weight: 400
                    customColor: Colors.surfaceVariantText
                }
            }

            Rectangle {
                visible: !dr.busy
                implicitWidth: actText.implicitWidth + 28
                implicitHeight: 32
                radius: 16
                color: dr.fresh ? "transparent" : Colors.secondaryContainer
                border.width: dr.fresh ? 1 : 0
                border.color: Colors.outlineVariant

                CustomText {
                    id: actText
                    anchors.centerIn: parent
                    content: dr.fresh ? "Pair" : "Connect"
                    size: 13
                    weight: 600
                    customColor: dr.fresh ? Colors.primary : Colors.secondaryContainerText
                }
            }

            Item {
                visible: dr.busy
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32

                CustomCircularLoader {
                    anchors.centerIn: parent
                    size: 18
                    trackWidth: 2
                    waveAmplitude: 0
                    highlightColor: Colors.primary
                    trackColor: Colors.surfaceContainerHighest
                }
            }
        }

        RippleEffect {
            id: drRipple
            anchors.fill: parent
            topLeftRadius: dr.topLeftRadius
            topRightRadius: dr.topRightRadius
            bottomLeftRadius: dr.bottomLeftRadius
            bottomRightRadius: dr.bottomRightRadius
            onClicked: {
                if (dr.busy || !dr.device) return
                if (dr.fresh) root.pair(dr.device)
                else dr.device.connect()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            spacing: 8

            M3IconButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                icon: "chevron_backward"
                iconSize: 20
                visible: root.showBack
                onClicked: root.backClicked()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                CustomText {
                    Layout.fillWidth: true
                    content: "Bluetooth"
                    family: root.displayFamily
                    renderType: Text.QtRendering
                    size: 22
                    weight: 400
                }

                CustomText {
                    Layout.fillWidth: true
                    content: !root.adapter ? "No adapter found"
                        : !root.bluetoothOn ? "Off"
                        : root.adapter.discoverable ? "Visible as " + (root.adapter.name || "this laptop")
                        : root.connected.length === 1 ? "1 device connected"
                        : root.connected.length > 1 ? root.connected.length + " devices connected"
                        : "No devices connected"
                    size: 12
                    weight: 400
                    customColor: Colors.surfaceVariantText
                }
            }

            M3IconButton {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                icon: "settings"
                iconSize: 20
                onClicked: root.openSettings()
            }

            Item {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40

                M3IconButton {
                    anchors.fill: parent
                    icon: "bluetooth_searching"
                    iconSize: 20
                    enabledButton: root.bluetoothOn && !root.scanning
                    opacity: root.scanning ? 0 : root.bluetoothOn ? 1 : 0.4
                    onClicked: if (root.bluetoothOn && !root.scanning) root.startScan()
                    Behavior on opacity { EffectsAnim {} }
                }

                CustomCircularLoader {
                    anchors.centerIn: parent
                    size: 22
                    trackWidth: 2
                    waveAmplitude: 0
                    highlightColor: Colors.primary
                    trackColor: Colors.surfaceContainerHighest
                    visible: root.scanning
                }
            }

            CustomToogle {
                Layout.alignment: Qt.AlignVCenter
                isToggleOn: root.bluetoothOn
                opacity: root.adapter ? 1 : 0.4
                onToggled: function (state) {
                    if (root.adapter) root.adapter.enabled = state
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                anchors.centerIn: parent
                visible: !root.bluetoothOn
                spacing: 10

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 56
                    implicitHeight: 56

                    MaterialShapes.ShapeCanvas {
                        anchors.fill: parent
                        roundedPolygon: MatrialShapeFn.getCookie9Sided()
                        color: Colors.surfaceContainerHigh
                    }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "bluetooth_disabled"
                        iconSize: 24
                        customColor: Colors.outline
                    }
                }

                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: root.adapter ? "Turn Bluetooth on to see your devices" : "No Bluetooth adapter found"
                    size: 12
                    weight: 400
                    customColor: Colors.outline
                }
            }

            Flickable {
                id: flick
                anchors.fill: parent
                visible: root.bluetoothOn
                contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: CustomScrollBar {}

                ColumnLayout {
                    id: body
                    width: flick.width
                    spacing: 3

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 8
                        visible: root.connected.length > 0
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            model: ScriptModel { values: root.connected }

                            DeviceTile {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.columnSpan: index === root.connected.length - 1 && root.connected.length % 2 === 1 ? 2 : 1
                                device: modelData
                            }
                        }
                    }

                    SectionLabel {
                        visible: root.paired.length > 0
                        text: "Paired"
                    }

                    Repeater {
                        model: ScriptModel { values: root.paired }

                        DeviceRow {
                            required property var modelData
                            required property int index
                            device: modelData
                            first: index === 0
                            last: index === root.paired.length - 1
                        }
                    }

                    SectionLabel {
                        Layout.topMargin: root.paired.length > 0 || root.connected.length > 0 ? 14 : 6
                        text: "New devices"
                        busy: root.scanning
                        busyText: "Searching"
                    }

                    Repeater {
                        model: ScriptModel { values: root.fresh }

                        DeviceRow {
                            required property var modelData
                            required property int index
                            device: modelData
                            fresh: true
                            first: index === 0
                            last: index === root.fresh.length - 1
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 52
                        visible: root.fresh.length === 0
                        radius: 18
                        color: Colors.surfaceContainer

                        CustomText {
                            anchors.centerIn: parent
                            content: root.scanning ? "Looking for devices…" : "Search to find devices nearby"
                            size: 12
                            weight: 400
                            customColor: Colors.surfaceVariantText
                        }

                        RippleEffect {
                            anchors.fill: parent
                            radius: parent.radius
                            enabled: !root.scanning
                            onClicked: root.startScan()
                        }
                    }
                }
            }

            ScrollFade {
                anchors.fill: parent
                visible: flick.visible
                flickable: flick
                color: Colors.surface
            }
        }
    }
}
