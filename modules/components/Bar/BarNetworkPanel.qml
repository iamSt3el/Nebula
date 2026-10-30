pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    signal backClicked
    property string page: "main"
    readonly property bool passwordPrompt: sub.item ? (sub.item.passwordPrompt ?? false) : false

    readonly property var wired: ServiceNetwork.wiredDevice
    readonly property var wifi: ServiceNetwork.wifiDevice
    readonly property var active: ServiceNetwork.activeDevice
    readonly property bool wiredActive: root.wired !== null && root.active === root.wired
    readonly property bool wifiUp: root.wifi !== null && (root.wifi.connected ?? false)
    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"

    readonly property string status: {
        if (root.wiredActive)
            return root.wifiUp ? "On Ethernet, Wi-Fi standing by" : "On Ethernet"
        if (root.wifiUp)
            return "On Wi-Fi, " + ServiceNetwork.currentSSID
        return "Not connected"
    }

    readonly property int capacity: Math.max(2, Math.round(60000 / ServiceSystemInfo.netSampleIntervalMs) + 1)
    property var downs: []
    property var ups: []
    property var counters: ({})
    property var ips: ({})
    property var speeds: ({})

    function parts(bps) {
        if (bps >= 1024 * 1024) return { v: (bps / (1024 * 1024)).toFixed(1), u: "MB/s" }
        if (bps >= 1024) return { v: (bps / 1024).toFixed(1), u: "KB/s" }
        return { v: Math.round(bps).toString(), u: "B/s" }
    }

    function linkSpeed(mbit) {
        if (!mbit || mbit <= 0) return ""
        return mbit >= 1000 ? (mbit / 1000) + " Gbit/s" : mbit + " Mbit/s"
    }

    function push() {
        const d = root.downs.slice()
        const u = root.ups.slice()
        d.push(ServiceSystemInfo.netDownloadBps)
        u.push(ServiceSystemInfo.netUploadBps)
        while (d.length > root.capacity) d.shift()
        while (u.length > root.capacity) u.shift()
        root.downs = d
        root.ups = u
        chart.requestPaint()
    }

    readonly property real peakDown: root.downs.length ? Math.max.apply(null, root.downs) : 0
    readonly property real peakUp: root.ups.length ? Math.max.apply(null, root.ups) : 0

    readonly property var split: {
        const out = []
        if (root.wired && root.counters[root.wired.name])
            out.push({ name: "Ethernet", bytes: root.counters[root.wired.name].rx, color: Colors.primary })
        if (root.wifi && root.counters[root.wifi.name])
            out.push({ name: "Wi-Fi", bytes: root.counters[root.wifi.name].rx, color: Colors.tertiaryContainer })
        return out
    }
    readonly property int splitCount: root.split.length
    readonly property real splitTotal: root.split.reduce((a, s) => a + s.bytes, 0)
    readonly property real upTotal: {
        let t = 0
        if (root.wired && root.counters[root.wired.name]) t += root.counters[root.wired.name].tx
        if (root.wifi && root.counters[root.wifi.name]) t += root.counters[root.wifi.name].tx
        return t
    }

    Component.onCompleted: {
        ServiceSystemInfo.retain()
        infoProc.running = true
    }
    Component.onDestruction: ServiceSystemInfo.release()

    Connections {
        target: ServiceSystemInfo
        function onNetSampled() {
            root.push()
            if (!infoProc.running)
                infoProc.running = true
        }
    }

    Process {
        id: infoProc
        command: ["sh", "-c", "cat /proc/net/dev; echo @ip; ip -4 -br addr; echo @speed; for d in /sys/class/net/*; do echo \"${d##*/} $(cat $d/speed 2>/dev/null)\"; done"]
        property string mode: "dev"
        property var c: ({})
        property var i: ({})
        property var s: ({})
        stdout: SplitParser {
            onRead: line => {
                const t = line.trim()
                if (t === "@ip") { infoProc.mode = "ip"; return }
                if (t === "@speed") { infoProc.mode = "speed"; return }
                if (infoProc.mode === "dev") {
                    const k = t.indexOf(":")
                    if (k < 0) return
                    const f = t.slice(k + 1).trim().split(/\s+/)
                    infoProc.c[t.slice(0, k)] = { rx: Number(f[0]), tx: Number(f[8]) }
                } else if (infoProc.mode === "ip") {
                    const f = t.split(/\s+/)
                    if (f.length >= 3) infoProc.i[f[0]] = f[2].split("/")[0]
                } else {
                    const f = t.split(/\s+/)
                    if (f.length >= 2) infoProc.s[f[0]] = parseInt(f[1])
                }
            }
        }
        onExited: {
            root.counters = infoProc.c
            root.ips = infoProc.i
            root.speeds = infoProc.s
            infoProc.c = {}
            infoProc.i = {}
            infoProc.s = {}
            infoProc.mode = "dev"
        }
    }

    Item {
        id: main
        anchors.fill: parent
        opacity: root.page === "main" ? 1 : 0
        visible: opacity > 0.01
        transform: Translate { x: root.page === "main" ? 0 : -40; Behavior on x { SpatialAnim {} } }
        Behavior on opacity { EffectsAnim {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    CustomText { Layout.fillWidth: true; content: "Network"; size: 20; weight: 600 }
                    CustomText {
                        Layout.fillWidth: true
                        content: root.status
                        size: 13
                        weight: 400
                        elide: Text.ElideRight
                        customColor: Colors.surfaceVariantText
                    }
                }

                M3IconButton {
                    id: netGear
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    icon: "settings"
                    iconSize: 20
                    tip: "Network settings"
                    onClicked: GlobalStates.openQuickSettings(4, netGear)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        spacing: 4
                        MaterialIconSymbol { content: "arrow_downward"; iconSize: 16; customColor: Colors.primary }
                        CustomText { content: "Download"; size: 12; weight: 400; customColor: Colors.surfaceVariantText }
                    }
                    RowLayout {
                        spacing: 6
                        readonly property var p: root.parts(ServiceSystemInfo.netDownloadBps)
                        CustomText {
                            Layout.alignment: Qt.AlignBaseline
                            content: parent.p.v
                            family: root.displayFamily
                            size: 56
                            weight: 400
                            customColor: Colors.primary
                        }
                        CustomText {
                            Layout.alignment: Qt.AlignBaseline
                            content: parent.p.u
                            size: 16
                            weight: 600
                            customColor: Colors.primary
                        }
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 6
                    spacing: 2
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 4
                        MaterialIconSymbol { content: "arrow_upward"; iconSize: 16; customColor: Colors.tertiary }
                        CustomText { content: "Upload"; size: 12; weight: 400; customColor: Colors.surfaceVariantText }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 4
                        readonly property var p: root.parts(ServiceSystemInfo.netUploadBps)
                        CustomText {
                            Layout.alignment: Qt.AlignBaseline
                            content: parent.p.v
                            family: root.displayFamily
                            size: 28
                            weight: 400
                            customColor: Colors.tertiary
                        }
                        CustomText {
                            Layout.alignment: Qt.AlignBaseline
                            content: parent.p.u
                            size: 13
                            weight: 600
                            customColor: Colors.tertiary
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 150
                radius: 24
                color: Colors.surfaceContainer

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 14
                    anchors.bottomMargin: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        CustomText { Layout.fillWidth: true; content: "Last minute"; size: 13; weight: 600 }
                        CustomText {
                            content: "Peak ↓ " + ServiceSystemInfo.formatNetSpeed(root.peakDown) + "  ↑ " + ServiceSystemInfo.formatNetSpeed(root.peakUp)
                            size: 12
                            weight: 400
                            customColor: Colors.surfaceVariantText
                        }
                    }

                    Canvas {
                        id: chart
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()

                        Connections {
                            target: Colors
                            function onPrimaryChanged() { chart.requestPaint() }
                        }

                        function trace(ctx, vals, mx, mid, half, sign, n) {
                            const step = width / (root.capacity - 1)
                            const x0 = width - (n - 1) * step
                            ctx.beginPath()
                            for (let i = 0; i < n; i++) {
                                const y = mid - sign * Math.sqrt(vals[i] / mx) * half
                                if (i === 0) ctx.moveTo(x0, y)
                                else ctx.lineTo(x0 + i * step, y)
                            }
                            return x0
                        }

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const mid = Math.round(height / 2) + 0.5
                            const half = height / 2 - 4
                            ctx.strokeStyle = Colors.outlineVariant
                            ctx.lineWidth = 1
                            ctx.beginPath()
                            ctx.moveTo(0, mid)
                            ctx.lineTo(width, mid)
                            ctx.stroke()
                            const n = root.downs.length
                            if (n < 2)
                                return
                            const mx = Math.max(1, root.peakDown, root.peakUp)
                            const sets = [[root.downs, 1, Colors.primary], [root.ups, -1, Colors.tertiary]]
                            for (const s of sets) {
                                const x0 = chart.trace(ctx, s[0], mx, mid, half, s[1], n)
                                ctx.lineTo(width, mid)
                                ctx.lineTo(x0, mid)
                                ctx.closePath()
                                ctx.fillStyle = Qt.alpha(s[2], 0.2)
                                ctx.fill()
                                chart.trace(ctx, s[0], mx, mid, half, s[1], n)
                                ctx.strokeStyle = s[2]
                                ctx.lineWidth = 2
                                ctx.lineJoin = "round"
                                ctx.stroke()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        CustomText { Layout.fillWidth: true; content: "60 s ago"; size: 11; weight: 400; customColor: Colors.surfaceVariantText }
                        CustomText { content: "Now"; size: 11; weight: 400; customColor: Colors.surfaceVariantText }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: root.split.length > 0
                implicitHeight: splitCol.implicitHeight + 28
                radius: 24
                color: Colors.surfaceContainer

                ColumnLayout {
                    id: splitCol
                    x: 16
                    y: 14
                    width: parent.width - 32
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        CustomText { Layout.fillWidth: true; content: "Since startup"; size: 13; weight: 600 }
                        CustomText {
                            content: "↓ " + ServiceSystemInfo.formatBytes(root.splitTotal) + "  ↑ " + ServiceSystemInfo.formatBytes(root.upTotal)
                            size: 12
                            weight: 400
                            customColor: Colors.surfaceVariantText
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12
                        spacing: 3

                        Repeater {
                            model: root.splitCount
                            delegate: Rectangle {
                                id: seg
                                required property int index
                                readonly property var modelData: root.split[seg.index] ?? ({ bytes: 0, color: "transparent" })
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: Math.max(4, root.splitTotal > 0 ? seg.modelData.bytes / root.splitTotal * 1000 : 1)
                                Behavior on Layout.preferredWidth { SpatialAnim {} }
                                topLeftRadius: seg.index === 0 ? 6 : 3
                                bottomLeftRadius: seg.index === 0 ? 6 : 3
                                topRightRadius: seg.index === root.splitCount - 1 ? 6 : 3
                                bottomRightRadius: seg.index === root.splitCount - 1 ? 6 : 3
                                color: seg.modelData.color
                            }
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 18
                        Repeater {
                            model: root.splitCount
                            delegate: Row {
                                id: key
                                required property int index
                                readonly property var modelData: root.split[key.index] ?? ({ name: "", bytes: 0, color: "transparent" })
                                spacing: 6
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: key.modelData.color
                                }
                                CustomText {
                                    content: key.modelData.name + " " + ServiceSystemInfo.formatBytes(key.modelData.bytes)
                                    size: 12
                                    weight: 400
                                    customColor: Colors.surfaceVariantText
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: {
                        const out = []
                        if (root.wired)
                            out.push({ kind: "wired", dev: root.wired })
                        if (root.wifi)
                            out.push({ kind: "wifi", dev: root.wifi })
                        return out
                    }

                    delegate: Rectangle {
                        id: link
                        required property var modelData
                        required property int index
                        readonly property var dev: link.modelData.dev
                        readonly property bool isWifi: link.modelData.kind === "wifi"
                        readonly property bool up: link.dev && (link.dev.connected ?? false)
                        readonly property bool inUse: link.dev === root.active
                        readonly property bool first: link.index === 0
                        readonly property bool last: link.index === (root.wired && root.wifi ? 1 : 0)
                        Layout.fillWidth: true
                        implicitHeight: 58
                        topLeftRadius: link.first ? 18 : 6
                        topRightRadius: link.first ? 18 : 6
                        bottomLeftRadius: link.last ? 18 : 6
                        bottomRightRadius: link.last ? 18 : 6
                        color: Colors.surfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12

                            MaterialIconSymbol {
                                content: link.isWifi ? "wifi" : "lan"
                                iconSize: 20
                                fill: 1
                                customColor: link.inUse ? Colors.primary : Colors.surfaceVariantText
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                CustomText {
                                    Layout.fillWidth: true
                                    content: link.isWifi ? (ServiceNetwork.currentSSID || "Wi-Fi") : "Ethernet"
                                    size: 14
                                    weight: 500
                                    elide: Text.ElideRight
                                }
                                CustomText {
                                    Layout.fillWidth: true
                                    content: {
                                        if (link.isWifi && !ServiceNetwork.wifiEnabled) return "Turned off"
                                        if (!link.up) return link.isWifi ? "Not connected, tap to pick a network" : "Cable unplugged"
                                        const bits = []
                                        if (!link.isWifi) {
                                            const s = root.linkSpeed(root.speeds[link.dev.name])
                                            if (s !== "") bits.push(s)
                                        }
                                        const ip = root.ips[link.dev.name] ?? ""
                                        if (ip !== "") bits.push(ip)
                                        return bits.join(", ")
                                    }
                                    size: 12
                                    weight: 400
                                    elide: Text.ElideRight
                                    customColor: Colors.surfaceVariantText
                                }
                            }

                            CustomText {
                                content: link.inUse ? "In use" : link.up ? "Standby" : ""
                                size: 12
                                weight: link.inUse ? 600 : 400
                                customColor: link.inUse ? Colors.primary : Colors.surfaceVariantText
                            }

                            MaterialIconSymbol {
                                visible: link.isWifi
                                content: "chevron_right"
                                iconSize: 20
                                customColor: Colors.surfaceVariantText
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            visible: link.isWifi
                            topLeftRadius: link.topLeftRadius
                            topRightRadius: link.topRightRadius
                            bottomLeftRadius: link.bottomLeftRadius
                            bottomRightRadius: link.bottomRightRadius
                            onClicked: root.page = "wifi"
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: sub
        anchors.fill: parent
        active: root.page === "wifi"
        opacity: active ? 1 : 0
        Behavior on opacity { EffectsAnim {} }
        transform: Translate { x: sub.active ? 0 : 40; Behavior on x { SpatialAnim {} } }
        sourceComponent: Component {
            Wifi {
                showBack: true
                onBackClicked: root.page = "main"
            }
        }
    }
}
