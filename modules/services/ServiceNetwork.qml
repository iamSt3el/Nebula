pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

Singleton {
    id: root

    property var availableNetworks: Networking.devices ?? null
    property bool isConnected: Networking.wifiEnabled
    property var currentNetwork: (availableNetworks?.values?.length ?? 0) > 0 ? availableNetworks.values[1] : null

    property var networks: !currentNetwork?.networks?.values ? [] :
    currentNetwork.networks.values.slice()

    property var connectedNetwork: networks.find(n => n.connected) ?? null
    property var savedNetworks: networks.filter(n => n.known && !n.connected)
    property var available: networks.filter(n => !n.known && !n.connected)
    property var connectedAndSavedNetworks: networks.filter(n => n.connected || n.known)
    .sort((a, b) => b.connected - a.connected)



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
