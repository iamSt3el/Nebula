pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Current network info
    property string currentSSID: ""
    property int signalStrength: 0
    property bool isConnected: false
    property bool wifiEnabled: false
    property string connectionType: "disconnected" // "wifi", "ethernet", "disconnected"
    property bool wifiScanning: false
    // Available WiFi networks
    property var availableNetworks: []

    property string icon: {
        if(signalStrength >= 90){
            return "signal_wifi_4_bar"
        }
        else if(signalStrength < 90 && signalStrength >=60){
            return "network_wifi_3_bar"
        }else if(signalStrength < 60 && signalStrength >= 30){
            return "network_wifi_2_bar"
        }
        return "network_wifi_1_bar"
    }

    // Connect to a network
    function connect(ssid) {
        connectProc.exec(["nmcli", "dev", "wifi", "connect", ssid])
    }

    // Disconnect from current network
    function disconnect() {
        if (currentSSID) {
            disconnectProc.exec(["nmcli", "connection", "down", currentSSID])
        }
    }

    // Turn WiFi on or off
    function setWifi(enabled) {
        const cmd = enabled ? "on" : "off"
        wifiToggleProc.exec(["nmcli", "radio", "wifi", cmd])
    }

    // Toggle WiFi on/off
    function toggleWifi() {
        setWifi(!wifiEnabled)
    }

    // Scan for WiFi networks
    function scanNetworks() {
        wifiScanning = true
        scanProc.running = true
    }

    // Refresh network status
    function refresh() {
        updateStatus.running = true
        checkWifiStatus.running = true
    }

    // Process to connect to network
    Process {
        id: connectProc
        stdout: SplitParser {
            onRead: line => {
                root.refresh()
            }
        }
    }

    // Process to disconnect
    Process {
        id: disconnectProc
        stdout: SplitParser {
            onRead: line => {
                root.refresh()
            }
        }
    }

    // Process to toggle WiFi on/off
    Process {
        id: wifiToggleProc
        stdout: SplitParser {
            onRead: line => {
                root.refresh()
            }
        }
    }

    // Check WiFi enabled status
    Process {
        id: checkWifiStatus
        running: true
        command: ["nmcli", "radio", "wifi"]
        stdout: SplitParser {
            onRead: data => {
                root.wifiEnabled = data.trim() === "enabled"
            }
        }
    }

    // Scan and get available WiFi networks
    Process {
        id: scanProc
        command: ["nmcli", "-g", "ACTIVE,SIGNAL,SSID,SECURITY,BSSID,CHAN,FREQ,RATE,MODE", "d", "w", "list"]

        property string buffer: ""

        stdout: SplitParser {
            onRead: data => {
                scanProc.buffer += data + "\n"
            }
        }

        onExited: {
            const lines = buffer.trim().split('\n').filter(line => line.length > 0)
            buffer = ""

            const networks = []
            const seenSSIDs = new Set()

            for (const line of lines) {
                // nmcli escapes colons as \: - replace with placeholder before splitting
                const safeLine = line.replace(/\\:/g, '##COLON##')
                const parts = safeLine.split(':').map(p => p.replace(/##COLON##/g, ':'))

                if (parts.length >= 3) {
                    const ssid = parts[2].trim()

                    // Skip empty SSIDs and duplicates
                    if (!ssid || seenSSIDs.has(ssid)) continue

                    seenSSIDs.add(ssid)

                    // Parse frequency to get band (2.4GHz or 5GHz)
                    const freqStr = parts[6] || ""
                    const freqMhz = parseInt(freqStr) || 0
                    const band = freqMhz >= 5000 ? "5 GHz" : "2.4 GHz"

                    networks.push({
                        active: parts[0] === "yes",
                        signal: parseInt(parts[1]) || 0,
                        ssid: ssid,
                        security: parts[3] || "Open",
                        isSecure: (parts[3] || "").length > 0,
                        bssid: parts[4] || "",
                        channel: parts[5] || "",
                        frequency: freqStr,
                        band: band,
                        rate: parts[7] || "",
                        mode: parts[8] || "Infra"
                    })
                }
            }

            // Sort by signal strength (strongest first), but keep active network at top
            networks.sort((a, b) => {
                if (a.active && !b.active) return -1
                if (!a.active && b.active) return 1
                return b.signal - a.signal
            })

            root.availableNetworks = networks
            root.wifiScanning = false
        }
    }

    // Monitor network changes
    Timer {
        id: monitorDebounceTimer
        interval: 2000
        repeat: false
        onTriggered: {
            root.refresh()
            root.scanNetworks()
        }
    }
    Process {
        id: subscriber
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: {
                monitorDebounceTimer.restart()
            }
        }
    }

    // Get current network status
    Process {
        id: updateStatus
        running: true
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE d status && nmcli -t -f NAME c show --active | head -1 && nmcli -f IN-USE,SIGNAL,SSID device wifi | awk '/^\\*/{if (NR!=1) {print $2}}'"]
        
        property string buffer: ""
        
        stdout: SplitParser {
            onRead: data => {
                updateStatus.buffer += data + "\n"
            }
        }
        
        onExited: {
            const lines = buffer.trim().split('\n')
            buffer = ""
            
            let hasWifi = false
            let hasEthernet = false
            
            // Check connection types
            lines.forEach(line => {
                if (line.includes("ethernet") && line.includes("connected")) {
                    hasEthernet = true
                } else if (line.includes("wifi:connected")) {
                    hasWifi = true
                }
            })
            
            // Get SSID (usually second-to-last line)
            if (lines.length >= 2) {
                root.currentSSID = lines[lines.length - 2] || ""
            }
            
            // Get signal strength (last line)
            if (lines.length >= 1) {
                const strength = parseInt(lines[lines.length - 1])
                if (!isNaN(strength)) {
                    root.signalStrength = strength
                }
            }
            
            // Set connection status
            if (hasEthernet) {
                root.connectionType = "ethernet"
                root.isConnected = true
            } else if (hasWifi) {
                root.connectionType = "wifi"
                root.isConnected = true
            } else {
                root.connectionType = "disconnected"
                root.isConnected = false
                root.currentSSID = ""
                root.signalStrength = 0
            }
        }
    }
    
    Component.onCompleted: {
        refresh()
        scanNetworks()
    }
}
