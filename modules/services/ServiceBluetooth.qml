pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import Quickshell.Bluetooth
import QtQml.Models

Singleton {
    id: root

    property var list: !Bluetooth.devices?.values ? [] :
        Bluetooth.devices.values.slice().sort((a, b) =>
            a.connected !== b.connected ? b.connected - a.connected :
            (a.name || "").localeCompare(b.name || "")
    )
    property var pairedDevices: list.filter(device => device.paired && device.state !== 1)
    property var unpairedDevices: list.filter(device => !device.paired)
    property var connectedDevicesList: list.filter(device => device.state === 1)
    property var connectedAndPairedDevices: list.filter(device => device.state === 1 || device.paired)
    property int connectedDevices: list.filter(device => device.state === 1).length
    property bool state: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.state === 1 ? true : false

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

    function stateText(device) {
        if (device?.pairing) return "Pairing…"
        if (device?.state === BluetoothDeviceState.Connecting) return "Connecting…"
        if (device?.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…"
        if (device?.state !== BluetoothDeviceState.Connected) return "Paired, not connected"
        const parts = ["Connected"]
        if (device?.batteryAvailable) parts.push("battery " + Math.round(Math.max(0, Math.min(1, device.battery)) * 100) + "%")
        if (root.isOutput(device)) parts.push("audio output")
        return parts.join(", ")
    }

    // Watch each device for state changes
     property Instantiator _watchers: Instantiator {
    model: Bluetooth.devices?.values ?? []
    delegate: QtObject {
        id: watcher
        required property BluetoothDevice modelData
        property int prevState: modelData.state

        property Connections _conn: Connections {
            target: watcher.modelData
            function onStateChanged() {
                const dev = watcher.modelData
                const prev = watcher.prevState
                if (prev !== 1 && dev.state === 1) {
                    ServiceNotification.sendNotification(
                        dev.name,
                        "Connected",
                        "Bluetooth",
                        "bluetooth-active"
                    )
                } else if (prev === 1 && dev.state !== 1) {
                    ServiceNotification.sendNotification(
                        dev.name,
                        "Disconnected",
                        "Bluetooth",
                        "bluetooth-disconnected"
                    )
                }
                watcher.prevState = dev.state
            }
        }
    }
}
}
