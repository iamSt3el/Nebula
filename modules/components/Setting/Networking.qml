pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import Qt.labs.platform
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    property bool scanning: false
    property bool qrCode: false
    property var joinTarget: null
    property bool joinHidden: false
    property bool joining: false
    property string joinError: ""
    property string savedQuery: ""
    property string forgetArmed: ""

    property var savedAll: []
    property var vpns: []
    property bool hotspotOn: false
    property string hotspotName: ""
    property string hotspotPsk: ""

    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property bool hardwareOn: Networking.wifiHardwareEnabled
    readonly property var wired: ServiceNetwork.wiredDevice
    readonly property bool wiredUp: root.wired?.connected ?? false
    readonly property var current: root.wifiOn ? ServiceNetwork.connectedNetwork : null
    readonly property var nearby: root.wifiOn
        ? ServiceNetwork.ordered(ServiceNetwork.savedNetworks).concat(ServiceNetwork.ordered(ServiceNetwork.available.filter(n => (n.name ?? "") !== "")))
        : []
    readonly property bool wifiFirst: root.current !== null && (!root.wiredUp || (wifiLink.metric > 0 && wifiLink.metric < ethLink.metric))
    readonly property var savedUsed: root.savedAll.filter(s => s.ts > 0 && root.matches(s))
    readonly property var savedNever: root.savedAll.filter(s => s.ts === 0 && root.matches(s))

    function matches(s) {
        return root.savedQuery === "" || s.name.toLowerCase().indexOf(root.savedQuery.toLowerCase()) >= 0
    }

    function ago(ts) {
        if (ts <= 0)
            return "Never joined"
        const days = Math.floor((Date.now() / 1000 - ts) / 86400)
        if (days < 1) return "Today"
        if (days < 2) return "Yesterday"
        if (days < 31) return days + " days ago"
        return Qt.formatDate(new Date(ts * 1000), "d MMM yyyy")
    }

    function networkLine(n) {
        const parts = []
        if (n.known)
            parts.push("Saved")
        parts.push(ServiceNetwork.strengthLabel(n.signalStrength))
        const sec = ServiceNetwork.securityLabel(n.security)
        if (sec !== "")
            parts.push(sec)
        return parts.join(" · ")
    }

    function startScan() {
        if (!ServiceNetwork.scan())
            return
        root.scanning = true
        scanTimer.restart()
    }

    function activate(n) {
        if (!n)
            return
        if (n.connected) {
            stages.push("wifi")
            return
        }
        if (!n.known && ServiceNetwork.isSecured(n.security)) {
            root.openJoin(n)
            return
        }
        n.connect()
    }

    function openJoin(n) {
        root.joinTarget = n
        root.joinHidden = n === null
        root.joinError = ""
        root.joining = false
        joinName.clear()
        joinPsk.clear()
        stages.push("join")
        Qt.callLater(() => root.joinHidden ? joinName.focusField() : joinPsk.focusField())
    }

    function submitJoin() {
        const psk = joinPsk.typed
        root.joinError = ""
        if (root.joinHidden) {
            const ssid = joinName.typed.trim()
            if (ssid === "")
                return
            root.joining = true
            joiner.command = ["nmcli", "dev", "wifi", "connect", ssid, "hidden", "yes"].concat(psk !== "" ? ["password", psk] : [])
            joiner.running = true
            return
        }
        if (!root.joinTarget || psk === "")
            return
        root.joining = true
        root.joinTarget.connectWithPsk(psk)
    }

    function failReason(reason) {
        switch (reason) {
        case ConnectionFailReason.WifiAuthTimeout: return "Wrong password"
        case ConnectionFailReason.WifiNetworkLost: return "Network out of range"
        case ConnectionFailReason.WifiClientDisconnected: return "Disconnected by the network"
        case ConnectionFailReason.NoSecrets: return "A password is needed"
        }
        return "Couldn't connect"
    }

    function nm(args) {
        Quickshell.execDetached(["nmcli"].concat(args))
        connsTimer.restart()
    }

    function setWifiFirst(on) {
        if (!root.current)
            return
        const metric = on ? "50" : "-1"
        Quickshell.execDetached(["sh", "-c", "nmcli connection modify id \"$1\" ipv4.route-metric \"$2\" ipv6.route-metric \"$2\" && nmcli device reapply \"$3\"",
            "sh", root.current.name, metric, wifiLink.iface])
        wifiTimer.restart()
    }

    function setAutoconnect(name, on) {
        root.nm(["connection", "modify", "id", name, "connection.autoconnect", on ? "yes" : "no"])
        wifiTimer.restart()
    }

    function setMetered(name, on) {
        root.nm(["connection", "modify", "id", name, "connection.metered", on ? "yes" : "no"])
        wifiTimer.restart()
    }

    function forget(name) {
        if (root.forgetArmed !== name) {
            root.forgetArmed = name
            disarm.restart()
            return
        }
        root.forgetArmed = ""
        root.nm(["connection", "delete", "id", name])
    }

    function copy(link) {
        Quickshell.clipboardText = link.report()
    }

    function toggleHotspot(on) {
        if (!on) {
            root.nm(["connection", "down", "id", "Hotspot"])
            return
        }
        const name = hotName.typed.trim() || "Nebula"
        const psk = hotPsk.typed
        if (psk.length > 0 && psk.length < 8)
            return
        root.nm(["device", "wifi", "hotspot", "ifname", wifiLink.iface, "con-name", "Hotspot", "ssid", name].concat(psk !== "" ? ["password", psk] : []))
    }

    function importVpn(file) {
        const path = file.toString().replace(/^file:\/\//, "")
        root.nm(["connection", "import", "type", path.endsWith(".ovpn") ? "openvpn" : "wireguard", "file", decodeURIComponent(path)])
    }

    function sinceLabel(bytes) {
        return ServiceSystemInfo.formatBytes(bytes)
    }

    Component.onCompleted: {
        ServiceSystemInfo.retain()
        warmup.start()
    }

    Timer {
        id: warmup
        interval: 600
        onTriggered: {
            conns.running = true
            if (root.wifiOn)
                root.startScan()
        }
    }
    Component.onDestruction: ServiceSystemInfo.release()

    NetLinkDetails {
        id: ethLink
        iface: root.wired?.name ?? ""
        active: root.wiredUp
        interval: stages.current === "eth" ? 2000 : 10000
    }

    NetLinkDetails {
        id: wifiLink
        iface: ServiceNetwork.wifiDevice?.name ?? ""
        connection: root.current?.name ?? ""
        wifi: true
        active: root.current !== null
        interval: stages.current === "wifi" ? 2000 : 10000
    }

    Timer {
        id: wifiTimer
        interval: 900
        onTriggered: {
            wifiLink.refresh()
            ethLink.refresh()
        }
    }

    Timer {
        id: scanTimer
        interval: 8000
        onTriggered: root.scanning = false
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.forgetArmed = ""
    }

    Timer {
        id: connsTimer
        interval: 1500
        onTriggered: conns.running = true
    }

    Process {
        id: conns
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE,TIMESTAMP,ACTIVE connection show 2>/dev/null; echo '#'; nmcli -s -t -g 802-11-wireless.ssid,802-11-wireless-security.psk connection show id Hotspot 2>/dev/null"]
        stdout: StdioCollector {
            id: connsOut
            onStreamFinished: {
                const [list, hot] = connsOut.text.split("\n#\n")
                const saved = []
                const vpns = []
                let hotspotOn = false
                for (const line of (list ?? "").split("\n")) {
                    const f = line.replace(/\\:/g, "\u0001").split(":").map(s => s.replace(/\u0001/g, ":"))
                    if (f.length < 4)
                        continue
                    const [name, type, ts, act] = f
                    if (name === "Hotspot") {
                        hotspotOn = act === "yes"
                        continue
                    }
                    if (type === "802-11-wireless")
                        saved.push({ name, ts: parseInt(ts) || 0, active: act === "yes" })
                    else if (type === "vpn" || type === "wireguard")
                        vpns.push({ name, type: type === "vpn" ? "OpenVPN" : "WireGuard", active: act === "yes" })
                }
                root.savedAll = saved.sort((a, b) => b.ts - a.ts || a.name.localeCompare(b.name))
                root.vpns = vpns
                root.hotspotOn = hotspotOn
                const h = (hot ?? "").split("\n")
                root.hotspotName = h[0] ?? ""
                root.hotspotPsk = h[1] ?? ""
            }
        }
    }

    Process {
        id: joiner
        stderr: StdioCollector { id: joinErr }
        onExited: code => {
            root.joining = false
            if (code === 0) {
                stages.back()
                connsTimer.restart()
                return
            }
            const msg = (joinErr.text || "").trim().split("\n").pop()
            root.joinError = msg !== "" ? msg.replace(/^Error:\s*/, "") : "Couldn't join that network"
        }
    }

    Connections {
        target: root.joinTarget
        ignoreUnknownSignals: true
        enabled: root.joining && !root.joinHidden

        function onConnectionFailed(reason) {
            root.joining = false
            root.joinError = root.failReason(reason)
        }

        function onConnectedChanged() {
            if (!root.joinTarget?.connected)
                return
            root.joining = false
            if (stages.current === "join")
                stages.back()
        }
    }

    FileDialog {
        id: vpnPicker
        title: "Import a VPN file"
        nameFilters: ["VPN files (*.conf *.ovpn)"]
        onAccepted: {
            root.importVpn(vpnPicker.file)
            GlobalStates.fileDialogOpen = false
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }

    Loader {
        anchors.fill: parent
        active: root.qrCode
        visible: active
        z: 10
        sourceComponent: QrCode {
            network: root.current
            onClose: root.qrCode = false
        }
    }

    StageView {
        id: stages

        StagePage {
            stageId: "front"

            StageNavRow {
                visible: root.wiredUp
                tonal: !root.wifiFirst
                icon: "lan"
                title: "Ethernet"
                subtitle: ["Connected", ethLink.speed, root.wifiFirst ? "backup" : "in use"].filter(s => s !== "").join(" · ")
                target: "eth"
            }

            StageNavRow {
                visible: root.current !== null
                tonal: root.wifiFirst
                icon: ServiceNetwork.signalIcon(root.current)
                title: root.current?.name ?? ""
                subtitle: ["Connected", root.wiredUp && !root.wifiFirst ? "backup" : "in use", ServiceNetwork.band(parseInt(wifiLink.freq) || 0)].filter(s => s !== "").join(" · ")
                target: "wifi"
            }

            StageRow {
                visible: !root.wiredUp && root.current === null
                icon: "signal_disconnected"
                title: "Not connected"
                subtitle: root.wifiOn ? "Pick a network below" : "Turn on Wi-Fi or plug in a cable"
            }

            StageGap {}

            StageSwitchRow {
                icon: root.wifiOn ? "wifi" : "wifi_off"
                title: "Wi-Fi"
                subtitle: !root.hardwareOn ? "Blocked by the hardware switch"
                    : root.wifiOn ? (root.current ? "On · " + root.current.name : "On · not joined") : "Off"
                checked: root.wifiOn
                onToggled: on => {
                    if (root.hardwareOn)
                        Networking.wifiEnabled = on
                }
            }

            StageHeading {
                visible: root.wifiOn
                text: "Networks nearby"
                aside: root.scanning ? "Looking…" : root.nearby.length + " found"

                M3IconButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    icon: "refresh"
                    iconSize: 18
                    iconColor: Colors.outline
                    enabledButton: !root.scanning
                    onClicked: root.startScan()
                }
            }

            Repeater {
                model: root.nearby

                StageRow {
                    id: net

                    required property var modelData
                    readonly property bool busy: net.modelData?.state === ConnectionState.Connecting

                    clickable: true
                    icon: ServiceNetwork.signalIcon(net.modelData)
                    title: net.modelData?.name ?? ""
                    subtitle: root.networkLine(net.modelData)
                    value: net.busy ? "Connecting…" : net.modelData?.known ? "Connect" : "Join"
                    onClicked: root.activate(net.modelData)
                }
            }

            StageRow {
                visible: root.wifiOn
                clickable: true
                icon: "add"
                title: "Add a hidden network"
                onClicked: root.openJoin(null)
            }

            StageHeading { text: "More" }

            StageNavRow {
                icon: "bookmark"
                title: "Saved networks"
                subtitle: "Forget old ones, see when each was used"
                value: String(root.savedAll.length)
                target: "saved"
            }

            StageNavRow {
                icon: "vpn_key"
                title: "VPN"
                subtitle: root.vpns.length === 0 ? "None set up" : root.vpns.filter(v => v.active).map(v => v.name).join(", ") || root.vpns.length + " set up, off"
                target: "vpn"
            }

            StageNavRow {
                icon: "wifi_tethering"
                title: "Hotspot"
                subtitle: root.hotspotOn ? "Sharing as " + root.hotspotName : "Share this connection with nearby devices"
                target: "hotspot"
            }
        }

        StageLazy {
            stageId: "eth"

            StagePage {
                stageId: "eth"
                title: "Ethernet"

                StageHero {
                    tone: root.wifiFirst ? "plain" : "primary"
                    icon: "lan"
                    title: "Connected"
                    subtitle: ethLink.first("GENERAL.CONNECTION") + (root.wifiFirst ? " · backup" : " · in use")
                    value: ServiceSystemInfo.formatNetSpeed(ServiceSystemInfo.netDownloadBps)
                    valueCaption: "↑ " + ServiceSystemInfo.formatNetSpeed(ServiceSystemInfo.netUploadBps)

                    M3Button {
                        variant: "tonal"
                        icon: "link_off"
                        label: "Disconnect"
                        onClicked: {
                            root.nm(["device", "disconnect", ethLink.iface])
                            stages.back()
                        }
                    }

                    M3Button {
                        variant: "tonal"
                        icon: "content_copy"
                        label: "Copy all"
                        onClicked: root.copy(ethLink)
                    }
                }

                StageHeading { text: "Link" }
                StageInfoRow { title: "Speed"; value: ethLink.speed || "Unknown" }
                StageInfoRow { title: "Interface"; value: ethLink.iface }
                StageInfoRow { title: "MTU"; value: ethLink.mtu }
                StageInfoRow { title: "Priority"; value: (root.wifiFirst ? "Backup" : "Used first") + (ethLink.metric > 0 ? " (metric " + ethLink.metric + ")" : "") }

                StageHeading { text: "Addresses" }
                StageInfoRow { title: "IPv4"; value: ethLink.ipv4 || "None" }
                StageInfoRow { visible: ethLink.ipv6 !== ""; title: "IPv6"; value: ethLink.ipv6 }
                StageInfoRow { title: "Gateway"; value: ethLink.gateway || "None" }
                StageInfoRow { title: "DNS"; value: ethLink.dns || "None" }
                StageInfoRow { title: "MAC"; value: ethLink.mac }

                StageHeading { text: "This session" }
                StageInfoRow { title: "Downloaded"; value: root.sinceLabel(ethLink.rx) }
                StageInfoRow { title: "Uploaded"; value: root.sinceLabel(ethLink.tx) }
            }
        }

        StageLazy {
            stageId: "wifi"

            StagePage {
                stageId: "wifi"
                title: root.current?.name ?? "Wi-Fi"

                StageHero {
                    tone: root.wifiFirst ? "primary" : "plain"
                    icon: ServiceNetwork.signalIcon(root.current)
                    title: root.wiredUp && !root.wifiFirst ? "Connected, backup" : "Connected"
                    subtitle: root.wiredUp && !root.wifiFirst ? "Takes over if the Ethernet cable drops" : "All traffic goes through this network"

                    M3Button {
                        variant: "tonal"
                        icon: "qr_code_2"
                        label: "Share"
                        onClicked: root.qrCode = true
                    }

                    M3Button {
                        variant: "tonal"
                        icon: "link_off"
                        label: "Disconnect"
                        onClicked: {
                            root.current?.disconnect()
                            stages.back()
                        }
                    }

                    M3Button {
                        variant: "tonal"
                        icon: "delete"
                        label: root.forgetArmed === (root.current?.name ?? "") ? "Sure?" : "Forget"
                        onClicked: {
                            const n = root.current
                            if (!n)
                                return
                            if (root.forgetArmed !== n.name) {
                                root.forgetArmed = n.name
                                disarm.restart()
                                return
                            }
                            root.forgetArmed = ""
                            n.forget()
                            stages.back()
                            connsTimer.restart()
                        }
                    }
                }

                StageSwitchRow {
                    visible: root.wiredUp
                    icon: "swap_vert"
                    title: "Use this first"
                    subtitle: "Send traffic over Wi-Fi even with a cable plugged in"
                    checked: root.wifiFirst
                    onToggled: on => root.setWifiFirst(on)
                }

                StageHeading { text: "Radio" }
                StageInfoRow { title: "Signal"; value: Math.round((root.current?.signalStrength ?? 0) * 100) + "%, " + ServiceNetwork.strengthLabel(root.current?.signalStrength).toLowerCase() }
                StageInfoRow { title: "Band and channel"; value: [ServiceNetwork.band(parseInt(wifiLink.freq) || 0), wifiLink.channel, wifiLink.freq].filter(s => s !== "").join(" · ") }
                StageInfoRow { title: "Link rate"; value: wifiLink.rate || "Unknown" }
                StageInfoRow { title: "Security"; value: ServiceNetwork.securityLabel(root.current?.security) || wifiLink.security }
                StageInfoRow { visible: wifiLink.bssid !== ""; title: "Router"; value: wifiLink.bssid }

                StageHeading { text: "Addresses" }
                StageInfoRow { title: "IPv4"; value: wifiLink.ipv4 || "None" }
                StageInfoRow { visible: wifiLink.ipv6 !== ""; title: "IPv6"; value: wifiLink.ipv6 }
                StageInfoRow { title: "Gateway and DNS"; value: [wifiLink.gateway, wifiLink.dns].filter(s => s !== "").join(" · ") }
                StageInfoRow { title: "MAC"; value: wifiLink.mac }

                StageHeading { text: "Options" }

                StageSwitchRow {
                    title: "Connect automatically"
                    subtitle: "Join whenever it is in range"
                    checked: wifiLink.autoconnect
                    onToggled: on => root.setAutoconnect(root.current?.name ?? "", on)
                }

                StageSwitchRow {
                    title: "Metered connection"
                    subtitle: "Apps hold back big downloads"
                    checked: wifiLink.metered === "yes"
                    onToggled: on => root.setMetered(root.current?.name ?? "", on)
                }

                StageRow {
                    clickable: true
                    icon: "content_copy"
                    title: "Copy all details"
                    onClicked: root.copy(wifiLink)
                }
            }
        }

        StagePage {
            stageId: "join"
            title: root.joinHidden ? "Hidden network" : "Join network"

            StageHero {
                tone: "plain"
                icon: root.joinHidden ? "wifi_find" : ServiceNetwork.signalIcon(root.joinTarget)
                title: root.joinHidden ? "Hidden network" : (root.joinTarget?.name ?? "")
                subtitle: root.joinHidden ? "Type the exact name; it isn't broadcast"
                    : [ServiceNetwork.securityLabel(root.joinTarget?.security), ServiceNetwork.strengthLabel(root.joinTarget?.signalStrength).toLowerCase() + " signal, " + Math.round((root.joinTarget?.signalStrength ?? 0) * 100) + "%"].filter(s => s !== "").join(" · ")
            }

            StageFieldRow {
                id: joinName
                visible: root.joinHidden
                title: "Name"
                fieldWidth: 280
                placeholder: "Network name"
                onAccepted: joinPsk.focusField()
            }

            StageFieldRow {
                id: joinPsk
                title: "Password"
                subtitle: root.joinHidden ? "Leave empty for an open network" : ""
                fieldWidth: 280
                secret: true
                allowEmpty: true
                placeholder: "Password"
                onAccepted: root.submitJoin()
            }

            StageNote {
                visible: root.joinError !== ""
                content: root.joinError
                customColor: Colors.error
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: 8
                spacing: 8

                M3Button {
                    variant: "tonal"
                    label: "Cancel"
                    onClicked: stages.back()
                }

                M3Button {
                    icon: root.joining ? "hourglass_top" : "wifi"
                    label: root.joining ? "Connecting…" : "Connect"
                    enabledButton: !root.joining
                    onClicked: root.submitJoin()
                }
            }
        }

        StagePage {
            stageId: "saved"
            title: "Saved networks"
            aside: String(root.savedAll.length)

            StageFieldRow {
                title: "Find"
                fieldIcon: "search"
                fieldWidth: 280
                allowEmpty: true
                placeholder: "Network name"
                onTypedChanged: root.savedQuery = typed.trim()
            }

            StageHeading {
                visible: root.savedUsed.length > 0
                text: "Used before"
                aside: String(root.savedUsed.length)
            }

            Repeater {
                model: root.savedUsed

                StageRow {
                    id: saved
                    required property var modelData
                    icon: saved.modelData.active ? "wifi" : "bookmark"
                    tonal: saved.modelData.active
                    title: saved.modelData.name
                    subtitle: saved.modelData.active ? "Connected now" : root.ago(saved.modelData.ts)

                    M3Button {
                        visible: !saved.modelData.active
                        variant: root.forgetArmed === saved.modelData.name ? "filled" : "text"
                        label: root.forgetArmed === saved.modelData.name ? "Sure?" : "Forget"
                        onClicked: root.forget(saved.modelData.name)
                    }
                }
            }

            StageHeading {
                visible: root.savedNever.length > 0
                text: "Never joined"
                aside: String(root.savedNever.length)
            }

            StageNote {
                visible: root.savedNever.length > 0
                content: "These were saved but never used. They are safe to forget."
            }

            Repeater {
                model: root.savedNever

                StageRow {
                    id: never
                    required property var modelData
                    title: never.modelData.name

                    M3Button {
                        variant: root.forgetArmed === never.modelData.name ? "filled" : "text"
                        label: root.forgetArmed === never.modelData.name ? "Sure?" : "Forget"
                        onClicked: root.forget(never.modelData.name)
                    }
                }
            }
        }

        StagePage {
            stageId: "vpn"
            title: "VPN"

            StageHero {
                visible: root.vpns.length === 0
                tone: "plain"
                icon: "vpn_key"
                title: "No VPN yet"
                subtitle: "A VPN sends your traffic through another server. Import the file your provider gives you."
            }

            Repeater {
                model: root.vpns

                StageSwitchRow {
                    id: vpn
                    required property var modelData
                    icon: "vpn_key"
                    tonal: vpn.modelData.active
                    title: vpn.modelData.name
                    subtitle: vpn.modelData.type + (vpn.modelData.active ? " · connected" : "")
                    checked: vpn.modelData.active
                    onToggled: on => root.nm(["connection", on ? "up" : "down", "id", vpn.modelData.name])
                }
            }

            StageGap {}

            StageNavRow {
                icon: "upload_file"
                title: "Import a WireGuard file"
                subtitle: ".conf from your provider"
                onClicked: {
                    GlobalStates.fileDialogOpen = true
                    vpnPicker.open()
                }
            }

            StageNavRow {
                icon: "description"
                title: "Import an OpenVPN file"
                subtitle: ".ovpn, needs the networkmanager-openvpn plugin"
                onClicked: {
                    GlobalStates.fileDialogOpen = true
                    vpnPicker.open()
                }
            }
        }

        StagePage {
            stageId: "hotspot"
            title: "Hotspot"

            StageHero {
                tone: root.hotspotOn ? "primary" : "plain"
                icon: "wifi_tethering"
                title: root.hotspotOn ? "Sharing" : "Hotspot is off"
                subtitle: root.hotspotOn ? "Devices can join " + root.hotspotName : "Nearby devices join your connection over Wi-Fi"

                M3Button {
                    icon: root.hotspotOn ? "stop" : "play_arrow"
                    label: root.hotspotOn ? "Turn off" : "Turn on"
                    enabledButton: root.hardwareOn && wifiLink.iface !== ""
                    onClicked: root.toggleHotspot(!root.hotspotOn)
                }
            }

            StageHeading { text: "Network" }

            StageFieldRow {
                id: hotName
                title: "Name"
                text: root.hotspotName || "Nebula"
                allowEmpty: true
            }

            StageFieldRow {
                id: hotPsk
                title: "Password"
                subtitle: hotPsk.typed.length > 0 && hotPsk.typed.length < 8 ? "At least 8 characters" : "Leave empty to make one up"
                text: root.hotspotPsk
                secret: true
                allowEmpty: true
            }

            StageNote {
                content: root.wiredUp ? "The hotspot shares your Ethernet connection. While it is on, Wi-Fi can't also join a network."
                    : "Without a cable the hotspot takes over the Wi-Fi radio, so this computer goes offline while it runs."
            }
        }
    }
}
