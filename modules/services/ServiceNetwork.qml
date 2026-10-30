pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

Singleton {
    id: root

    property var availableNetworks: Networking.devices ?? null
    readonly property var devices: availableNetworks?.values ?? []

    readonly property var wifiDevice:  devices.find(d => d.type === DeviceType.Wifi)  ?? null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null

    readonly property var activeDevice: wiredDevice?.connected ? wiredDevice
                                      : wifiDevice?.connected  ? wifiDevice
                                      : null

    readonly property string activeInterface: activeDevice?.name ?? ""

    property bool isConnected: activeDevice !== null
    property var currentNetwork: wifiDevice

    property var networks: !currentNetwork?.networks?.values ? [] :
    currentNetwork.networks.values.slice()

    property var connectedNetwork: networks.find(n => n.connected) ?? null
    property var savedNetworks: networks.filter(n => n.known && !n.connected)
    property var available: networks.filter(n => !n.known && !n.connected)
    property var connectedAndSavedNetworks: networks.filter(n => n.connected || n.known)
    .sort((a, b) => b.connected - a.connected)



    property bool wifiEnabled: Networking.wifiEnabled

    property string currentSSID: connectedNetwork?.name ?? ""

    property string connectionType: {
        if (wiredDevice?.connected) return "ethernet"
        if (Networking.wifiEnabled && connectedNetwork) return "wifi"
        return "disconnected"
    }

    readonly property string connectionLabel: connectionType === "ethernet" ? "Ethernet" : currentSSID

    property string icon: {
        if (connectionType === "ethernet") return "lan"
        const sig = (connectedNetwork?.signalStrength ?? 0) * 100
        if (!Networking.wifiEnabled || !connectedNetwork) return "signal_wifi_off"
        if (sig >= 90) return "signal_wifi_4_bar"
        if (sig >= 60) return "network_wifi_3_bar"
        if (sig >= 30) return "network_wifi_2_bar"
        return "network_wifi_1_bar"
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled
    }

    function scan() {
        const dev = root.wifiDevice
        if (!Networking.wifiEnabled || !dev) return false
        if (dev.scannerEnabled) rescanProcess.running = true
        else dev.scannerEnabled = true
        return true
    }

    function bucket(n) {
        return Math.min(3, Math.floor((n?.signalStrength ?? 0) * 4))
    }

    function ordered(list) {
        return list.slice().sort((a, b) => root.bucket(b) - root.bucket(a)
            || (a.name || "").localeCompare(b.name || ""))
    }

    function strengthLabel(strength) {
        const v = (strength ?? 0) * 100
        if (v >= 75) return "Excellent"
        if (v >= 50) return "Good"
        if (v >= 25) return "Fair"
        return "Weak"
    }

    function securityLabel(security) {
        switch (security) {
        case WifiSecurityType.Wpa3SuiteB192:
        case WifiSecurityType.Sae: return "WPA3"
        case WifiSecurityType.Wpa2Psk:
        case WifiSecurityType.Wpa2Eap: return "WPA2"
        case WifiSecurityType.WpaPsk:
        case WifiSecurityType.WpaEap: return "WPA"
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep: return "WEP"
        case WifiSecurityType.Leap: return "LEAP"
        case WifiSecurityType.Owe: return "Enhanced open"
        case WifiSecurityType.Open: return "Open"
        }
        return ""
    }

    function isSecured(security) {
        if (security === undefined || security === null) return false
        return security !== WifiSecurityType.Open
            && security !== WifiSecurityType.Owe
            && security !== WifiSecurityType.Unknown
    }

    function band(mhz) {
        if (mhz <= 0) return ""
        if (mhz < 3000) return "2.4 GHz"
        if (mhz < 5925) return "5 GHz"
        return "6 GHz"
    }

    function signalIcon(n) {
        const bars = Math.round((n?.signalStrength ?? 0) * 4)
        const locked = root.isSecured(n?.security)
        if (bars >= 4) return locked ? "wifi_lock" : "wifi"
        if (bars >= 1) return "network_wifi_" + bars + "_bar" + (locked ? "_locked" : "")
        return locked ? "wifi_lock" : "signal_wifi_off"
    }

    Process {
        id: rescanProcess
        command: ["nmcli", "device", "wifi", "rescan"]
    }

    property string qrImagePath: "/tmp/wifi_qr.png"
    signal qrGenerated(string path)
    signal qrFailed()

    property string _pendingSsid: ""
    property string _pendingAuth: ""
    property string _fetchedPassword: ""

    // security: WifiSecurityType value from WifiNetwork.security
    function generateQr(ssid, security) {
        root._pendingSsid = ssid
        root._pendingAuth = _securityToQrAuth(security)
        root._fetchedPassword = ""

        if (root._pendingAuth === "nopass") {
            // open network — no password needed
            var wifiString = "WIFI:T:nopass;S:" + _escapeWifi(ssid) + ";;"
            qrProcess.command = ["qrencode", "-o", root.qrImagePath, "-s", "10", wifiString]
            qrProcess.running = true
        } else {
            passwordFetcher.command = ["nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", ssid]
            passwordFetcher.running = true
        }
    }

    function _securityToQrAuth(security) {
        switch (security) {
            case WifiSecurityType.StaticWep:
            case WifiSecurityType.DynamicWep:
                return "WEP"
            case WifiSecurityType.Open:
            case WifiSecurityType.Owe:
                return "nopass"
            default:
                return "WPA"
        }
    }

    function _escapeWifi(str) {
        return str.replace(/\\/g, "\\\\")
                  .replace(/;/g, "\\;")
                  .replace(/,/g, "\\,")
                  .replace(/"/g, "\\\"")
                  .replace(/:/g, "\\:")
    }

    Process {
        id: passwordFetcher
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                root._fetchedPassword = line.trim()
            }
        }
        onExited: function(code) {
            if (code === 0 && root._fetchedPassword !== "") {
                var wifiString = "WIFI:T:" + root._pendingAuth
                    + ";S:" + root._escapeWifi(root._pendingSsid)
                    + ";P:" + root._escapeWifi(root._fetchedPassword) + ";;"
                qrProcess.command = ["qrencode", "-o", root.qrImagePath, "-s", "10", wifiString]
                qrProcess.running = true
            } else {
                root.qrFailed()
            }
        }
    }

    Process {
        id: qrProcess
        running: false
        onExited: function(code) {
            if (code === 0)
                root.qrGenerated(root.qrImagePath)
            else
                root.qrFailed()
        }
    }
}
