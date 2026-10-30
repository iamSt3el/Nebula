pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    property bool scanning: false
    property var device: null
    property var pendingPair: null
    property bool forgetArmed: false
    property string address: ""
    property string systemAlias: ""

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: root.adapter?.enabled ?? false
    readonly property string computerName: root.systemAlias || root.adapter?.name || "This computer"
    readonly property var connected: root.powered ? ServiceBluetooth.connectedDevicesList : []
    readonly property var paired: root.powered ? ServiceBluetooth.pairedDevices : []
    readonly property var knownNames: ServiceBluetooth.connectedAndPairedDevices.map(d => d.name).filter(n => !!n)
    readonly property var fresh: root.powered
        ? ServiceBluetooth.unpairedDevices.filter(d => d.state !== BluetoothDeviceState.Connected && root.knownNames.indexOf(d.name) < 0)
        : []

    function batteryText(d) {
        return d?.batteryAvailable ? Math.round(Math.max(0, Math.min(1, d.battery)) * 100) + "%" : ""
    }

    function kindOf(d) {
        const icon = ServiceBluetooth.deviceIcon(d?.icon)
        switch (icon) {
        case "headphones": return "Headphones"
        case "speaker": return "Speaker"
        case "keyboard": return "Keyboard"
        case "mouse": return "Mouse"
        case "stadia_controller": return "Controller"
        case "stylus": return "Tablet"
        case "smartphone": return "Phone"
        case "computer": return "Computer"
        case "tv": return "Display"
        case "print": return "Printer"
        }
        return "Device"
    }

    function open(d) {
        root.device = d
        root.forgetArmed = false
        stages.push("dev")
    }

    function startScan() {
        if (!root.adapter || !root.powered)
            return
        root.adapter.discovering = true
        root.scanning = true
        scanTimer.restart()
    }

    function stopScan() {
        scanTimer.stop()
        root.scanning = false
        if (root.adapter)
            root.adapter.discovering = false
    }

    function pair(d) {
        if (!d)
            return
        root.pendingPair = d
        d.pair()
    }

    function toggle(d) {
        if (!d || ServiceBluetooth.busy(d))
            return
        if (d.state === BluetoothDeviceState.Connected)
            d.disconnect()
        else
            d.connect()
    }

    function forget() {
        if (!root.forgetArmed) {
            root.forgetArmed = true
            disarm.restart()
            return
        }
        const d = root.device
        root.forgetArmed = false
        stages.back()
        d?.forget()
    }

    function rename(name) {
        Quickshell.execDetached(["bluetoothctl", "system-alias", name])
        root.systemAlias = name
        infoTimer.restart()
    }

    Component.onCompleted: info.running = true
    Component.onDestruction: root.stopScan()

    Connections {
        target: stages

        function onCurrentChanged() {
            if (stages.current === "pair") {
                root.startScan()
                if (root.adapter)
                    root.adapter.discoverable = true
            } else if (root.scanning) {
                root.stopScan()
            }
        }
    }

    Connections {
        target: root.pendingPair
        ignoreUnknownSignals: true

        function onPairedChanged() {
            const d = root.pendingPair
            if (!d?.paired)
                return
            d.trusted = true
            d.connect()
            root.pendingPair = null
        }
    }

    Timer {
        id: scanTimer
        interval: 30000
        onTriggered: root.stopScan()
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.forgetArmed = false
    }

    Timer {
        id: infoTimer
        interval: 800
        onTriggered: info.running = true
    }

    Process {
        id: info
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            id: infoOut
            onStreamFinished: {
                const text = infoOut.text
                root.address = (text.match(/Controller ([0-9A-F:]{17})/) ?? [])[1] ?? ""
                root.systemAlias = ((text.match(/\n\s*Alias: (.*)/) ?? [])[1] ?? "").trim()
            }
        }
    }

    component DeviceRow: StageRow {
        id: devRow

        required property var modelData

        clickable: true
        value: root.batteryText(devRow.modelData)
        icon: ServiceBluetooth.deviceIcon(devRow.modelData?.icon)
        tonal: devRow.modelData?.state === BluetoothDeviceState.Connected
        title: ServiceBluetooth.nameOf(devRow.modelData)
        subtitle: ServiceBluetooth.stateText(devRow.modelData)
        onClicked: root.open(devRow.modelData)
    }

    StageView {
        id: stages

        StagePage {
            stageId: "front"

            StageSwitchRow {
                icon: root.powered ? "bluetooth" : "bluetooth_disabled"
                title: "Bluetooth"
                subtitle: !root.adapter ? "No adapter found"
                    : root.powered ? "On · seen as " + root.computerName : "Off"
                checked: root.powered
                onToggled: on => {
                    if (root.adapter)
                        root.adapter.enabled = on
                }
            }

            StageNavRow {
                visible: root.powered
                tonal: true
                icon: "add"
                title: "Pair new device"
                subtitle: root.fresh.length > 0 ? root.fresh.length + " nearby right now" : "Headphones, keyboards, phones and more"
                target: "pair"
            }

            StageHeading {
                visible: root.connected.length > 0
                text: "Connected"
                aside: String(root.connected.length)
            }

            Repeater {
                model: root.connected
                DeviceRow {}
            }

            StageHeading {
                visible: root.paired.length > 0
                text: "Paired"
                aside: String(root.paired.length)
            }

            Repeater {
                model: root.paired

                DeviceRow {
                    id: pairedRow

                    M3Button {
                        variant: "text"
                        label: ServiceBluetooth.busy(pairedRow.modelData) ? "…" : "Connect"
                        onClicked: root.toggle(pairedRow.modelData)
                    }
                }
            }

            StageRow {
                visible: root.powered && root.connected.length === 0 && root.paired.length === 0
                icon: "bluetooth_searching"
                title: "No devices yet"
                subtitle: "Pair one to see it here"
            }

            StageHeading { text: "This computer" }

            StageNavRow {
                icon: "computer"
                title: "Name"
                subtitle: "What other devices see"
                value: root.computerName
                target: "name"
            }

            StageSwitchRow {
                visible: root.powered
                title: "Visible to nearby devices"
                subtitle: "Turns itself off after a few minutes"
                checked: root.adapter?.discoverable ?? false
                onToggled: on => {
                    if (root.adapter)
                        root.adapter.discoverable = on
                }
            }
        }

        StageLazy {
            stageId: "dev"

            StagePage {
                stageId: "dev"
                title: ServiceBluetooth.nameOf(root.device)

                StageHero {
                    tone: root.device?.state === BluetoothDeviceState.Connected ? "primary" : "plain"
                    icon: ServiceBluetooth.deviceIcon(root.device?.icon)
                    title: ServiceBluetooth.nameOf(root.device)
                    subtitle: ServiceBluetooth.stateText(root.device)
                    value: root.batteryText(root.device)
                    valueCaption: root.device?.batteryAvailable ? "battery" : ""

                    M3Button {
                        readonly property bool linked: root.device?.state === BluetoothDeviceState.Connected
                        icon: linked ? "link_off" : "link"
                        label: ServiceBluetooth.busy(root.device) ? "Working…" : linked ? "Disconnect" : "Connect"
                        enabledButton: !ServiceBluetooth.busy(root.device)
                        onClicked: root.toggle(root.device)
                    }
                }

                StageFieldRow {
                    icon: "edit"
                    title: "Name"
                    subtitle: "Only on this computer"
                    text: root.device?.name ?? ""
                    onSubmitted: t => {
                        if (root.device)
                            root.device.name = t
                    }
                }

                StageHeading { text: "About" }
                StageInfoRow { title: "Type"; value: root.kindOf(root.device) }
                StageInfoRow { title: "Address"; value: root.device?.address ?? "" }
                StageInfoRow { visible: root.device?.batteryAvailable ?? false; title: "Battery"; value: root.batteryText(root.device) }
                StageInfoRow { visible: ServiceBluetooth.isOutput(root.device); title: "Audio"; value: "Current output" }

                StageHeading { text: "Behaviour" }

                StageSwitchRow {
                    title: "Trust this device"
                    subtitle: "It can reconnect on its own without asking"
                    checked: root.device?.trusted ?? false
                    onToggled: on => {
                        if (root.device)
                            root.device.trusted = on
                    }
                }

                StageSwitchRow {
                    title: "Block this device"
                    subtitle: "Refuse every connection from it"
                    checked: root.device?.blocked ?? false
                    onToggled: on => {
                        if (root.device)
                            root.device.blocked = on
                    }
                }

                StageGap {}

                StageRow {
                    clickable: true
                    danger: true
                    icon: "delete"
                    title: root.forgetArmed ? "Press again to forget" : "Forget this device"
                    subtitle: "You will need to pair it again"
                    onClicked: root.forget()
                }
            }
        }

        StageLazy {
            stageId: "pair"

            StagePage {
                stageId: "pair"
                title: "Pair new device"

                StageHero {
                    tone: "primary"
                    icon: "bluetooth_searching"
                    title: root.scanning ? "Looking for devices" : "Search paused"
                    subtitle: "Put your device in pairing mode. " + root.computerName + " is visible to others while this is open."

                    M3Button {
                        visible: !root.scanning
                        variant: "tonal"
                        icon: "refresh"
                        label: "Search again"
                        onClicked: root.startScan()
                    }
                }

                StageHeading {
                    text: "Found"
                    aside: String(root.fresh.length)
                }

                Repeater {
                    model: root.fresh

                    StageRow {
                        id: freshRow

                        required property var modelData

                        icon: ServiceBluetooth.deviceIcon(freshRow.modelData?.icon)
                        title: ServiceBluetooth.nameOf(freshRow.modelData)
                        subtitle: root.kindOf(freshRow.modelData) + " · " + (freshRow.modelData?.address ?? "")

                        M3Button {
                            variant: "tonal"
                            label: freshRow.modelData?.pairing ? "Pairing…" : "Pair"
                            enabledButton: !(freshRow.modelData?.pairing ?? false)
                            onClicked: root.pair(freshRow.modelData)
                        }
                    }
                }

                StageNote {
                    visible: root.fresh.length === 0
                    content: root.scanning ? "Nothing yet. Devices show up here as they are found." : "Nothing found. Check the device is in pairing mode and search again."
                }

                StageNote {
                    content: "Keyboards may ask you to type a code on them, then press Enter."
                }
            }
        }

        StageLazy {
            stageId: "name"

            StagePage {
                stageId: "name"
                title: "Name"

                StageNote {
                    content: "This is the name your phone, headphones and other devices see when they look for this computer."
                }

                StageFieldRow {
                    title: "Device name"
                    text: root.computerName
                    fieldWidth: 260
                    onSubmitted: t => root.rename(t)
                }

                StageInfoRow { visible: root.address !== ""; title: "Address"; value: root.address }
                StageInfoRow { title: "Adapter"; value: root.adapter?.adapterId ?? "" }
            }
        }
    }
}
