pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"
    readonly property real totalGb: ServiceSystemInfo.memTotalGb
    readonly property real usedGb: ServiceSystemInfo.memUsedGb
    readonly property real readyGb: Math.max(0, root.totalGb - root.usedGb)
    property var apps: []
    property var history: []

    readonly property var tones: [Colors.primary, Colors.tertiaryContainer, Colors.secondary,
        Colors.primaryContainer, Colors.secondaryContainer, Colors.outline]
    readonly property var inks: [Colors.primaryText, Colors.tertiaryContainerText, Colors.secondaryText,
        Colors.primaryContainerText, Colors.secondaryContainerText, Colors.surface]

    readonly property var friendly: ({
        "zen-bin": "Zen Browser", "firefox": "Firefox", "qs": "Nebula shell", "quickshell": "Nebula shell",
        "claude": "Claude Code", "vesktop": "Vesktop", "Hyprland": "Hyprland", "kitty": "kitty"
    })
    readonly property var lookupId: ({ "zen-bin": "zen", "vesktop": "vesktop", "kitty": "kitty", "firefox": "firefox" })

    readonly property real appsMb: root.apps.reduce((a, b) => a + b.mb, 0)
    readonly property real otherMb: Math.max(0, root.usedGb * 1024 - root.appsMb)
    readonly property var rows: {
        const out = root.apps.map((a, i) => Object.assign({}, a, { color: root.tones[i % root.tones.length], ink: root.inks[i % root.inks.length] }))
        if (root.otherMb > 1)
            out.push({ name: "System and others", mb: root.otherMb, comm: "", color: Colors.surfaceContainerHighest, ink: Colors.surfaceVariantText, system: true })
        return out
    }
    readonly property real maxMb: root.rows.reduce((a, b) => Math.max(a, b.mb), 1)
    readonly property var segments: root.rows.concat([{ name: "free", mb: root.readyGb * 1024, color: Colors.surfaceContainerHigh }])
    readonly property int rowCount: root.rows.length
    readonly property int segmentCount: root.segments.length

    readonly property string trend: {
        const h = root.history
        if (h.length < 4) return "Watching"
        const lo = Math.min.apply(null, h)
        const hi = Math.max.apply(null, h)
        if (hi - lo < 0.15) return "Steady"
        return h[h.length - 1] > h[0] ? "Rising" : "Falling"
    }

    function fmt(mb) {
        return mb >= 1000 ? (mb / 1024).toFixed(1) + " GB" : Math.round(mb) + " MB"
    }

    function iconFor(comm) {
        if (!comm) return ""
        const e = DesktopEntries.heuristicLookup(root.lookupId[comm] ?? comm)
        return e ? IconUtil.getDesktopIconPath(e.icon) : ""
    }

    implicitWidth: 380
    implicitHeight: col.implicitHeight + 36

    Component.onCompleted: {
        ServiceSystemInfo.retain()
        pssProc.running = true
        root.sample()
    }
    Component.onDestruction: ServiceSystemInfo.release()

    function sample() {
        if (root.usedGb <= 0) return
        const h = root.history.slice()
        h.push(root.usedGb)
        while (h.length > 16) h.shift()
        root.history = h
        spark.requestPaint()
    }

    Timer {
        interval: 4000
        repeat: true
        running: root.visible
        onTriggered: {
            root.sample()
            if (!pssProc.running) pssProc.running = true
        }
    }

    Process {
        id: pssProc
        command: ["sh", "-c", "awk 'FNR==1{print \"c\", FILENAME, $0}' /proc/[0-9]*/comm 2>/dev/null; awk 'BEGINFILE{if (ERRNO != \"\") nextfile} /^Pss:/{print \"p\", FILENAME, $2; nextfile}' /proc/[0-9]*/smaps_rollup 2>/dev/null"]
        property var comm: ({})
        property var pss: ({})
        stdout: SplitParser {
            onRead: line => {
                const kind = line.slice(0, 1)
                const rest = line.slice(2)
                const sp = rest.indexOf(" ")
                if (sp < 0) return
                const pid = rest.slice(0, sp).split("/")[2]
                const val = rest.slice(sp + 1)
                if (kind === "c") pssProc.comm[pid] = val
                else if (kind === "p") pssProc.pss[pid] = parseInt(val)
            }
        }
        onExited: {
            const comms = Object.values(pssProc.comm)
            const browserComm = comms.indexOf("zen-bin") >= 0 ? "zen-bin" : comms.indexOf("firefox") >= 0 ? "firefox" : ""
            const groups = {}
            for (const pid in pssProc.pss) {
                let c = pssProc.comm[pid] ?? ""
                if (/^(Isolated |Web Content|WebExtensions|Privileged Cont|RDD Process|Utility Process|Socket Process|Isolated Servic)/.test(c) && browserComm !== "")
                    c = browserComm
                const name = root.friendly[c] ?? c
                if (!groups[name]) groups[name] = { name: name, kb: 0, comm: c, best: 0 }
                groups[name].kb += pssProc.pss[pid]
            }
            root.apps = Object.values(groups).sort((a, b) => b.kb - a.kb).slice(0, 6)
                .map(g => ({ name: g.name, mb: g.kb / 1024, comm: g.comm }))
            pssProc.comm = {}
            pssProc.pss = {}
        }
    }

    ColumnLayout {
        id: col
        x: 18
        y: 18
        width: root.width - 36
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                CustomText { Layout.fillWidth: true; content: "Memory"; size: 20; weight: 600 }
                CustomText {
                    Layout.fillWidth: true
                    content: root.usedGb.toFixed(1) + " of " + root.totalGb.toFixed(1) + " GB in use, " + root.readyGb.toFixed(1) + " GB ready"
                    size: 13
                    weight: 400
                    elide: Text.ElideRight
                    customColor: Colors.surfaceVariantText
                }
            }

            RowLayout {
                spacing: 2
                CustomText {
                    Layout.alignment: Qt.AlignBaseline
                    content: Math.round(ServiceSystemInfo.memUsage * 100)
                    family: root.displayFamily
                    size: 36
                    weight: 400
                    customColor: Colors.primary
                }
                CustomText {
                    Layout.alignment: Qt.AlignBaseline
                    content: "%"
                    size: 14
                    weight: 600
                    customColor: Colors.primary
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            spacing: 3

            Repeater {
                model: root.segmentCount
                delegate: Rectangle {
                    id: seg
                    required property int index
                    readonly property var modelData: root.segments[seg.index] ?? ({ mb: 0, color: "transparent" })
                    readonly property int count: root.segmentCount
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: Math.max(3, seg.modelData.mb)
                    Behavior on Layout.preferredWidth { SpatialAnim {} }
                    topLeftRadius: seg.index === 0 ? 7 : 2
                    bottomLeftRadius: seg.index === 0 ? 7 : 2
                    topRightRadius: seg.index === seg.count - 1 ? 7 : 2
                    bottomRightRadius: seg.index === seg.count - 1 ? 7 : 2
                    color: seg.modelData.color
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: root.rowCount

                delegate: Rectangle {
                    id: app
                    required property int index
                    readonly property var modelData: root.rows[app.index] ?? ({ name: "", mb: 0, comm: "", color: "transparent", ink: "transparent" })
                    readonly property string iconPath: root.iconFor(app.modelData.comm)
                    Layout.fillWidth: true
                    implicitHeight: 54
                    topLeftRadius: app.index === 0 ? 18 : 5
                    topRightRadius: app.index === 0 ? 18 : 5
                    bottomLeftRadius: app.index === root.rowCount - 1 ? 18 : 5
                    bottomRightRadius: app.index === root.rowCount - 1 ? 18 : 5
                    color: Colors.surfaceContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Item {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34

                            Image {
                                anchors.fill: parent
                                visible: app.iconPath !== ""
                                source: app.iconPath
                                sourceSize.width: 34
                                sourceSize.height: 34
                                fillMode: Image.PreserveAspectFit
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: app.iconPath === ""
                                radius: 11
                                color: app.modelData.color

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: app.modelData.system ? "memory" : app.modelData.name === "Nebula shell" ? "dashboard" : "apps"
                                    iconSize: 19
                                    fill: 1
                                    customColor: app.modelData.ink
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                CustomText {
                                    Layout.fillWidth: true
                                    content: app.modelData.name
                                    size: 14
                                    weight: 400
                                    elide: Text.ElideRight
                                }
                                CustomText {
                                    content: root.fmt(app.modelData.mb)
                                    size: 13
                                    weight: 600
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 5
                                radius: 3
                                color: Colors.surfaceContainerHighest

                                Rectangle {
                                    width: Math.max(4, parent.width * app.modelData.mb / root.maxMb)
                                    height: parent.height
                                    radius: 3
                                    color: app.modelData.system ? Colors.outline : app.modelData.color
                                    Behavior on width { SpatialAnim {} }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 58
            radius: 20
            color: Colors.surfaceContainerHigh

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Canvas {
                    id: spark
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 32
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const h = root.history
                        if (h.length < 2) return
                        const lo = Math.min.apply(null, h) - 0.2
                        const hi = Math.max.apply(null, h) + 0.2
                        ctx.beginPath()
                        for (let i = 0; i < h.length; i++) {
                            const x = i / 15 * width
                            const y = height - 3 - (h[i] - lo) / (hi - lo) * (height - 6)
                            if (i === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                        }
                        ctx.strokeStyle = Colors.primary
                        ctx.lineWidth = 2
                        ctx.lineJoin = "round"
                        ctx.stroke()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    CustomText { content: root.trend; size: 14; weight: 400 }
                    CustomText {
                        Layout.fillWidth: true
                        content: root.history.length < 2 ? "Collecting the last minute"
                            : Math.min.apply(null, root.history).toFixed(1) + " to " + Math.max.apply(null, root.history).toFixed(1) + " GB over the last minute"
                        size: 12
                        weight: 400
                        elide: Text.ElideRight
                        customColor: Colors.surfaceVariantText
                    }
                }
            }
        }
    }
}
