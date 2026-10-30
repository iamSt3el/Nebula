pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings
import "../../MatrialShapes/" as MaterialShapes

Item {
    id: root
    anchors.fill: parent

    signal backClicked
    property bool showBack: true

    property bool scanning: false
    property var pendingPair: null
    property string openAddress: ""

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothOn: root.adapter?.enabled ?? false
    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"
    readonly property string adapterName: root.adapter?.name || "this laptop"

    readonly property var connected: root.bluetoothOn ? ServiceBluetooth.connectedDevicesList : []
    readonly property var paired: root.bluetoothOn ? ServiceBluetooth.pairedDevices : []
    readonly property var mine: root.connected.concat(root.paired)
    readonly property var knownNames: ServiceBluetooth.connectedAndPairedDevices.map(d => d.name).filter(n => !!n)
    readonly property var fresh: root.bluetoothOn
        ? ServiceBluetooth.unpairedDevices.filter(d => d.state !== BluetoothDeviceState.Connected
            && root.knownNames.indexOf(d.name) < 0) : []

    function deviceIcon(icon) { return ServiceBluetooth.deviceIcon(icon) }

    function deviceShape(icon) {
        switch (root.deviceIcon(icon)) {
        case "keyboard":   return "squircle"
        case "mouse":      return "pill"
        case "headphones": return "cookie6"
        case "speaker":    return "cookie9"
        case "smartphone": return "gem"
        case "stadia_controller": return "clover4"
        case "computer":
        case "tv":         return "arch"
        }
        return "cookie4"
    }

    function nameOf(device) { return ServiceBluetooth.nameOf(device) }
    function isOutput(device) { return ServiceBluetooth.isOutput(device) }
    function busy(device) { return ServiceBluetooth.busy(device) }
    function stateText(device) { return ServiceBluetooth.stateText(device) }

    function startScan() {
        if (!root.adapter || !root.bluetoothOn) return
        root.adapter.discovering = true
        root.scanning = true
        scanTimer.restart()
    }

    function stopScan() {
        scanTimer.stop()
        root.scanning = false
        if (root.adapter) root.adapter.discovering = false
    }

    function pair(device) {
        if (!device) return
        root.pendingPair = device
        device.pair()
    }

    function openSettings(from) {
        GlobalStates.openQuickSettings(5, from)
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
        onTriggered: root.stopScan()
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
        property string note: ""
        property bool busy: false

        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.topMargin: 12
        Layout.bottomMargin: 4
        spacing: 8

        CustomText {
            Layout.fillWidth: true
            content: sl.text
            size: 14
            weight: 800
        }

        MaterialShapes.ShapeCanvas {
            visible: sl.busy
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            roundedPolygon: "softBurst"
            color: Colors.primary
            angle: spin.angle

            QtObject {
                id: spin
                property real angle: 0
                NumberAnimation on angle {
                    from: 0; to: 360
                    duration: 2400
                    loops: Animation.Infinite
                    running: sl.busy && sl.visible
                }
            }
        }

        CustomText {
            visible: sl.note !== ""
            content: sl.note
            size: 12
            weight: 500
            customColor: Colors.surfaceVariantText
        }
    }

    component GroupRow: Rectangle {
        id: gr
        property bool first: false
        property bool last: false

        Layout.fillWidth: true
        implicitHeight: 60
        topLeftRadius: gr.first ? 24 : 6
        topRightRadius: gr.first ? 24 : 6
        bottomLeftRadius: gr.last ? 24 : 6
        bottomRightRadius: gr.last ? 24 : 6
        color: Colors.surfaceContainer
        Behavior on color { EffectsColorAnim {} }
    }

    component SplitButton: RowLayout {
        id: sb
        property string label: ""
        property bool strong: false
        property bool open: false
        signal pressed()
        signal toggled()

        readonly property color fill: sb.strong ? Colors.primary : Colors.secondaryContainer
        readonly property color ink: sb.strong ? Colors.primaryText : Colors.secondaryContainerText

        spacing: 2

        Rectangle {
            Layout.preferredHeight: 40
            Layout.preferredWidth: sbText.implicitWidth + 28
            topLeftRadius: 20
            bottomLeftRadius: 20
            topRightRadius: 4
            bottomRightRadius: 4
            color: sb.fill

            CustomText {
                id: sbText
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 1
                content: sb.label
                size: 13
                weight: 700
                customColor: sb.ink
            }

            RippleEffect {
                anchors.fill: parent
                topLeftRadius: 20
                bottomLeftRadius: 20
                topRightRadius: 4
                bottomRightRadius: 4
                hoverColor: Qt.alpha(sb.ink, 0.08)
                rippleColor: Qt.alpha(sb.ink, 0.18)
                onClicked: sb.pressed()
            }
        }

        Rectangle {
            Layout.preferredHeight: 40
            Layout.preferredWidth: 36
            topLeftRadius: sb.open ? 20 : 4
            bottomLeftRadius: sb.open ? 20 : 4
            topRightRadius: 20
            bottomRightRadius: 20
            color: sb.fill
            Behavior on topLeftRadius { SpatialAnim { speed: "fast" } }
            Behavior on bottomLeftRadius { SpatialAnim { speed: "fast" } }

            MaterialIconSymbol {
                anchors.centerIn: parent
                content: "keyboard_arrow_down"
                iconSize: 20
                customColor: sb.ink
                rotation: sb.open ? 180 : 0
                Behavior on rotation { SpatialAnim { speed: "fast" } }
            }

            RippleEffect {
                anchors.fill: parent
                topLeftRadius: parent.topLeftRadius
                bottomLeftRadius: parent.bottomLeftRadius
                topRightRadius: 20
                bottomRightRadius: 20
                hoverColor: Qt.alpha(sb.ink, 0.08)
                rippleColor: Qt.alpha(sb.ink, 0.18)
                onClicked: sb.toggled()
            }
        }
    }

    component DeviceRow: Rectangle {
        id: dr
        property var device: null
        property bool first: false
        property bool last: false
        readonly property bool isConnected: dr.device?.state === BluetoothDeviceState.Connected
        readonly property bool busy: root.busy(dr.device)
        readonly property bool open: root.openAddress !== "" && root.openAddress === (dr.device?.address ?? "")

        Layout.fillWidth: true
        implicitHeight: dr.open ? 64 + extra.implicitHeight : 64
        Behavior on implicitHeight { SpatialAnim {} }
        clip: true
        topLeftRadius: dr.first ? 24 : 6
        topRightRadius: dr.first ? 24 : 6
        bottomLeftRadius: dr.last ? 24 : 6
        bottomRightRadius: dr.last ? 24 : 6
        color: Colors.surfaceContainer

        RowLayout {
            x: 10
            y: 10
            width: parent.width - 20
            height: 44
            spacing: 12

            Item {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44

                MaterialShapes.ShapeCanvas {
                    anchors.fill: parent
                    roundedPolygon: root.deviceShape(dr.device?.icon)
                    color: dr.isConnected ? Colors.tertiaryContainer : Colors.surfaceContainerHighest
                    Behavior on color { EffectsColorAnim {} }
                }

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: root.deviceIcon(dr.device?.icon)
                    iconSize: 22
                    fill: 1
                    customColor: dr.isConnected ? Colors.tertiaryContainerText : Colors.surfaceVariantText
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2

                CustomText {
                    Layout.fillWidth: true
                    content: root.nameOf(dr.device)
                    size: 14
                    weight: 800
                }

                CustomText {
                    Layout.fillWidth: true
                    content: root.stateText(dr.device)
                    size: 12
                    weight: 500
                    customColor: Colors.surfaceVariantText
                }
            }

            SplitButton {
                visible: !dr.busy
                label: dr.isConnected ? "Disconnect" : "Connect"
                strong: dr.isConnected
                open: dr.open
                onPressed: {
                    if (!dr.device) return
                    if (dr.isConnected) dr.device.disconnect()
                    else dr.device.connect()
                }
                onToggled: root.openAddress = dr.open ? "" : (dr.device?.address ?? "")
            }

            Item {
                visible: dr.busy
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40

                CustomCircularLoader {
                    anchors.centerIn: parent
                    size: 22
                    trackWidth: 2
                    waveAmplitude: 0
                    highlightColor: Colors.primary
                    trackColor: Colors.surfaceContainerHighest
                }
            }
        }

        ColumnLayout {
            id: extra
            x: 10
            y: 64
            width: parent.width - 20
            spacing: 0
            opacity: dr.open ? 1 : 0
            Behavior on opacity { EffectsAnim {} }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.outlineVariant
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                Layout.leftMargin: 6
                spacing: 12

                CustomText {
                    Layout.fillWidth: true
                    content: "Connect automatically"
                    size: 13
                    weight: 600
                }

                CustomToogle {
                    isToggleOn: dr.device?.trusted ?? false
                    onToggled: s => { if (dr.device) dr.device.trusted = s }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.leftMargin: 6
                Layout.bottomMargin: 6
                spacing: 12

                CustomText {
                    Layout.fillWidth: true
                    content: dr.device?.address ?? ""
                    size: 11
                    weight: 500
                    customColor: Colors.outline
                }

                Rectangle {
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: forgetText.implicitWidth + 28
                    radius: 18
                    color: "transparent"
                    border.width: 1
                    border.color: Colors.outlineVariant

                    CustomText {
                        id: forgetText
                        anchors.centerIn: parent
                        content: "Forget device"
                        size: 13
                        weight: 700
                        customColor: Colors.error
                    }

                    RippleEffect {
                        anchors.fill: parent
                        radius: 18
                        hoverColor: Qt.alpha(Colors.error, 0.08)
                        rippleColor: Qt.alpha(Colors.error, 0.18)
                        onClicked: {
                            root.openAddress = ""
                            dr.device?.forget()
                        }
                    }
                }
            }
        }
    }

    component NearbyRow: Rectangle {
        id: nr
        property var device: null
        property bool first: false
        property bool last: false
        readonly property bool busy: root.busy(nr.device)

        Layout.fillWidth: true
        implicitHeight: 56
        topLeftRadius: nr.first ? 24 : 6
        topRightRadius: nr.first ? 24 : 6
        bottomLeftRadius: nr.last ? 24 : 6
        bottomRightRadius: nr.last ? 24 : 6
        color: nrRipple.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainer
        Behavior on color { EffectsColorAnim {} }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 8
            spacing: 14

            MaterialIconSymbol {
                content: root.deviceIcon(nr.device?.icon)
                iconSize: 22
                fill: 1
                customColor: Colors.surfaceVariantText
            }

            CustomText {
                Layout.fillWidth: true
                content: root.nameOf(nr.device)
                size: 14
                weight: 700
            }

            CustomText {
                visible: !nr.busy
                Layout.rightMargin: 10
                content: "Pair"
                size: 13
                weight: 800
                customColor: Colors.primary
            }

            Item {
                visible: nr.busy
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36

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
            id: nrRipple
            anchors.fill: parent
            topLeftRadius: nr.topLeftRadius
            topRightRadius: nr.topRightRadius
            bottomLeftRadius: nr.bottomLeftRadius
            bottomRightRadius: nr.bottomRightRadius
            onClicked: if (!nr.busy && nr.device) root.pair(nr.device)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            spacing: 8

            M3IconButton {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                icon: "chevron_backward"
                iconSize: 20
                visible: root.showBack
                onClicked: root.backClicked()
            }

            CustomText {
                Layout.fillWidth: true
                content: "Bluetooth"
                family: root.displayFamily
                size: 30
                weight: 400
            }

            Rectangle {
                id: pairBtn
                visible: root.bluetoothOn
                Layout.preferredHeight: 40
                Layout.preferredWidth: pairRow.implicitWidth + 28
                radius: 20
                color: Colors.tertiaryContainer

                RowLayout {
                    id: pairRow
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIconSymbol {
                        visible: !root.scanning
                        content: "add"
                        iconSize: 20
                        customColor: Colors.tertiaryContainerText
                    }

                    CustomCircularLoader {
                        visible: root.scanning
                        size: 18
                        trackWidth: 2
                        waveAmplitude: 0
                        highlightColor: Colors.tertiaryContainerText
                        trackColor: Qt.alpha(Colors.tertiaryContainerText, 0.2)
                    }

                    CustomText {
                        content: root.scanning ? "Stop" : "Pair"
                        size: 13
                        weight: 800
                        customColor: Colors.tertiaryContainerText
                    }
                }

                RippleEffect {
                    anchors.fill: parent
                    radius: 20
                    hoverColor: Qt.alpha(Colors.tertiaryContainerText, 0.08)
                    rippleColor: Qt.alpha(Colors.tertiaryContainerText, 0.18)
                    onClicked: root.scanning ? root.stopScan() : root.startScan()
                }

                CustomToolTip {
                    content: root.scanning ? "Stop searching" : "Pair new device"
                    visible: pairTip.hovered
                }

                HoverHandler { id: pairTip }
            }

            M3IconButton {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                id: btGear
                icon: "settings"
                iconSize: 20
                tip: "Bluetooth settings"
                onClicked: root.openSettings(btGear)
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: flick
                anchors.fill: parent
                contentHeight: body.implicitHeight + 16
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                ScrollBar.vertical: CustomScrollBar {}

                ColumnLayout {
                    id: body
                    width: flick.width
                    spacing: 2

                    GroupRow {
                        first: true
                        last: !root.bluetoothOn
                        color: root.bluetoothOn ? Colors.primaryContainer : Colors.surfaceContainer

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 14
                            spacing: 12

                            CustomText {
                                Layout.fillWidth: true
                                content: root.adapter ? "Use Bluetooth" : "No Bluetooth adapter"
                                size: 15
                                weight: 800
                                customColor: root.bluetoothOn ? Colors.primaryContainerText : Colors.surfaceText
                            }

                            CustomToogle {
                                visible: !!root.adapter
                                isToggleOn: root.bluetoothOn
                                onToggled: s => { if (root.adapter) root.adapter.enabled = s }
                            }
                        }
                    }

                    GroupRow {
                        visible: root.bluetoothOn

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                CustomText { Layout.fillWidth: true; content: "Device name"; size: 14; weight: 700 }
                                CustomText { Layout.fillWidth: true; content: root.adapterName; size: 12; weight: 500; customColor: Colors.surfaceVariantText }
                            }

                            MaterialIconSymbol {
                                content: "chevron_right"
                                iconSize: 22
                                customColor: Colors.surfaceVariantText
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            radius: 6
                            onClicked: root.openSettings(parent)
                        }
                    }

                    GroupRow {
                        visible: root.bluetoothOn
                        last: true

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 14
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                CustomText { Layout.fillWidth: true; content: "Visible to nearby devices"; size: 14; weight: 700 }
                                CustomText {
                                    Layout.fillWidth: true
                                    content: root.adapter?.discoverable ? "On, others can find " + root.adapterName
                                                                        : "Off, others can't find " + root.adapterName
                                    size: 12
                                    weight: 500
                                    customColor: Colors.surfaceVariantText
                                }
                            }

                            CustomToogle {
                                isToggleOn: root.adapter?.discoverable ?? false
                                onToggled: s => { if (root.adapter) root.adapter.discoverable = s }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 40
                        visible: !root.bluetoothOn
                        spacing: 10

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 64
                            implicitHeight: 64

                            MaterialShapes.ShapeCanvas {
                                anchors.fill: parent
                                roundedPolygon: "cookie9"
                                color: Colors.surfaceContainerHigh
                            }

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: "bluetooth_disabled"
                                iconSize: 26
                                customColor: Colors.outline
                            }
                        }

                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            content: root.adapter ? "Turn Bluetooth on to see your devices" : "No Bluetooth adapter found"
                            size: 12
                            weight: 500
                            customColor: Colors.surfaceVariantText
                        }
                    }

                    SectionLabel {
                        visible: root.bluetoothOn && root.mine.length > 0
                        text: "Your devices"
                        note: root.mine.length === 1 ? "1 paired" : root.mine.length + " paired"
                    }

                    Repeater {
                        model: ScriptModel { values: root.mine }

                        DeviceRow {
                            required property var modelData
                            required property int index
                            device: modelData
                            first: index === 0
                            last: index === root.mine.length - 1
                        }
                    }

                    SectionLabel {
                        visible: root.bluetoothOn
                        text: "Nearby"
                        busy: root.scanning
                        note: root.scanning ? "Searching" : ""
                    }

                    Repeater {
                        model: ScriptModel { values: root.fresh }

                        NearbyRow {
                            required property var modelData
                            required property int index
                            device: modelData
                            first: index === 0
                            last: index === root.fresh.length - 1
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 56
                        visible: root.bluetoothOn && root.fresh.length === 0
                        radius: 24
                        color: Colors.surfaceContainer

                        CustomText {
                            anchors.centerIn: parent
                            content: root.scanning ? "Looking for devices…" : "Nothing found yet"
                            size: 12
                            weight: 500
                            customColor: Colors.surfaceVariantText
                        }
                    }
                }
            }

            ScrollFade {
                anchors.fill: parent
                flickable: flick
                color: Colors.surface
            }
        }
    }
}
