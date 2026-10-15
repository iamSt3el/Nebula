import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import QtQuick
import qs.modules.settings
import qs.modules.services

QtObject {
    id: root

    property var closer: null

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property int btCount: ServiceBluetooth.connectedDevices

    readonly property var all: [
        { key: "wifi", icon: Networking.wifiEnabled ? "wifi" : "wifi_off", label: "Wi-Fi",
          sub: !Networking.wifiEnabled ? "Off" : ServiceNetwork.connectionLabel || "Not connected",
          on: Networking.wifiEnabled },
        { key: "bluetooth", icon: root.adapter?.enabled ? "bluetooth" : "bluetooth_disabled", label: "Bluetooth",
          sub: !(root.adapter?.enabled ?? false) ? "Off" : root.btCount === 1 ? "1 device" : root.btCount + " devices",
          on: root.adapter?.enabled ?? false },
        { key: "dnd", icon: "do_not_disturb_on", label: "Silence",
          sub: ServiceNotification.dnd ? "On" : "Off", on: ServiceNotification.dnd },
        { key: "mic", icon: ServicePipewire.micMuted ? "mic_off" : "mic", label: "Microphone",
          sub: ServicePipewire.micMuted ? "Muted" : "On", on: !ServicePipewire.micMuted },
        { key: "caffeine", icon: "coffee", label: "Stay awake",
          sub: ServiceIdleInhibit.active ? "On" : "Off", on: ServiceIdleInhibit.active },
        { key: "game", icon: "sports_esports", label: "Game mode",
          sub: ServiceGameMode.active ? "On" : "Off", on: ServiceGameMode.active },
        { key: "capture", icon: "screenshot_region", label: "Capture", sub: "Region", on: false }
    ]

    function pick(keys) {
        return keys.map(k => root.all.find(t => t.key === k)).filter(t => !!t)
    }

    function fire(key) {
        switch (key) {
        case "wifi": Networking.wifiEnabled = !Networking.wifiEnabled; break
        case "bluetooth": if (root.adapter) root.adapter.enabled = !root.adapter.enabled; break
        case "dnd": ServiceNotification.setDnd(!ServiceNotification.dnd, 0); break
        case "mic": ServicePipewire.toggleMicMute(); break
        case "caffeine": ServiceIdleInhibit.toggle(); break
        case "game": ServiceGameMode.toggle(); break
        case "capture":
            if (root.closer) root.closer()
            GlobalStates.areaSelectMode = "screenshot"
            GlobalStates.areaSelectOpen = true
            break
        }
    }

    function lock() {
        if (root.closer) root.closer()
        Quickshell.execDetached(["loginctl", "lock-session"])
    }

    function settings() {
        if (root.closer) root.closer()
        GlobalStates.settingsOpen = true
    }

    function power() {
        if (root.closer) root.closer()
        GlobalStates.openPanel("power")
    }
}
