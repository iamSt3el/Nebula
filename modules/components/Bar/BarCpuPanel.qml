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

    readonly property var shapes: ["cookie4", "cookie6", "cookie9", "cookie12", "clover4", "sunny", "flower", "gem"]
    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"
    readonly property var loads: ServiceSystemInfo.cpuCores ?? []
    property var freqs: []
    property var coreOf: []
    property var loadAvg: [0, 0, 0]
    property var procs: []

    readonly property real avgGhz: {
        const f = root.freqs.filter(v => v > 0)
        return f.length ? f.reduce((a, b) => a + b, 0) / f.length / 1000000 : 0
    }

    readonly property int threadCount: root.loads.length
    readonly property int procCount: root.procs.length
    readonly property var cores: {
        const n = root.threadCount
        const groups = []
        const index = {}
        for (let t = 0; t < n; t++) {
            const id = root.coreOf[t] ?? t
            if (index[id] === undefined) {
                index[id] = groups.length
                groups.push({ id: id, threads: [] })
            }
            groups[index[id]].threads.push(t)
        }
        return groups
    }
    readonly property int columns: Math.max(1, Math.min(4, root.cores.length))

    readonly property var friendly: ({
        "zen-bin": "Zen Browser", "firefox": "Firefox", "qs": "Nebula shell", "quickshell": "Nebula shell",
        "claude": "Claude Code", "vesktop": "Vesktop", "Hyprland": "Hyprland", "kitty": "kitty"
    })

    function nameOf(comm) {
        if (root.friendly[comm])
            return root.friendly[comm]
        if (/^(Isolate|Web Con|WebExte|Privile|RDD Pro|Utility|Socket)/.test(comm))
            return "Browser tabs"
        const e = DesktopEntries.heuristicLookup(comm.replace(/\+$/, ""))
        return e ? e.name : comm.replace(/\+$/, "")
    }

    implicitWidth: 380
    implicitHeight: col.implicitHeight + 36

    Component.onCompleted: {
        ServiceSystemInfo.retain()
        topoProc.running = true
        freqProc.running = true
        topProc.running = true
    }
    Component.onDestruction: ServiceSystemInfo.release()

    Process {
        id: topoProc
        command: ["sh", "-c", "for c in /sys/devices/system/cpu/cpu[0-9]*; do echo \"${c##*cpu} $(cat $c/topology/core_id 2>/dev/null)\"; done"]
        property var acc: []
        stdout: SplitParser {
            onRead: line => {
                const f = line.trim().split(/\s+/)
                if (f.length >= 2) topoProc.acc[parseInt(f[0])] = parseInt(f[1])
            }
        }
        onExited: {
            root.coreOf = topoProc.acc
            topoProc.acc = []
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.visible
        onTriggered: if (!freqProc.running) freqProc.running = true
    }

    Process {
        id: freqProc
        command: ["sh", "-c", "for c in /sys/devices/system/cpu/cpu[0-9]*; do echo \"f ${c##*cpu} $(cat $c/cpufreq/scaling_cur_freq 2>/dev/null)\"; done; echo \"l $(cat /proc/loadavg)\""]
        property var f: []
        property var l: [0, 0, 0]
        stdout: SplitParser {
            onRead: line => {
                const p = line.trim().split(/\s+/)
                if (p[0] === "f" && p.length >= 3) freqProc.f[parseInt(p[1])] = parseInt(p[2])
                else if (p[0] === "l") freqProc.l = [parseFloat(p[1]), parseFloat(p[2]), parseFloat(p[3])]
            }
        }
        onExited: {
            root.freqs = freqProc.f
            root.loadAvg = freqProc.l
            freqProc.f = []
        }
    }

    Process {
        id: topProc
        command: ["sh", "-c", "top -b -n 2 -d 1.5 -o %CPU -w 512 | awk '/^top -/{n++} n==2 && $1 ~ /^[0-9]+$/ {print $9, $12}' | head -40"]
        property var acc: ({})
        stdout: SplitParser {
            onRead: line => {
                const i = line.indexOf(" ")
                if (i < 0) return
                const pct = parseFloat(line.slice(0, i).replace(",", "."))
                const name = root.nameOf(line.slice(i + 1).trim())
                if (line.slice(i + 1).trim() === "top") return
                if (!isNaN(pct) && pct > 0) topProc.acc[name] = (topProc.acc[name] ?? 0) + pct
            }
        }
        onExited: {
            const n = Math.max(1, root.loads.length)
            root.procs = Object.keys(topProc.acc).map(k => ({ name: k, share: topProc.acc[k] / n }))
                .sort((a, b) => b.share - a.share).slice(0, 4)
            topProc.acc = {}
            if (root.visible) topRestart.restart()
        }
    }

    Timer {
        id: topRestart
        interval: 1500
        onTriggered: if (root.visible && !topProc.running) topProc.running = true
    }
    onVisibleChanged: if (root.visible && !topProc.running) topProc.running = true

    ColumnLayout {
        id: col
        x: 18
        y: 18
        width: root.width - 36
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                CustomText {
                    Layout.fillWidth: true
                    content: ServiceSystemInfo.cpuName.replace(/ with .*$/, "").replace(/\s+\d+-Core Processor$/, "")
                    size: 13
                    weight: 400
                    elide: Text.ElideRight
                    customColor: Colors.surfaceVariantText
                }
                RowLayout {
                    spacing: 4
                    CustomText {
                        Layout.alignment: Qt.AlignBaseline
                        content: Math.round(ServiceSystemInfo.cpuUsage * 100)
                        family: root.displayFamily
                        size: 64
                        weight: 400
                        customColor: Colors.primary
                    }
                    CustomText {
                        Layout.alignment: Qt.AlignBaseline
                        content: "%"
                        size: 20
                        weight: 600
                        customColor: Colors.primary
                    }
                }
                CustomText {
                    Layout.fillWidth: true
                    content: root.loads.length + " threads" + (root.avgGhz > 0 ? " averaging " + root.avgGhz.toFixed(1) + " GHz" : "")
                    size: 13
                    weight: 400
                    customColor: Colors.surfaceVariantText
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 4
                spacing: 6

                Repeater {
                    model: [
                        { icon: "thermostat", text: Math.round(ServiceSystemInfo.cpuTemp) + " °C", tonal: true, show: ServiceSystemInfo.cpuTemp > 0 },
                        { icon: "stacks", text: "Load " + root.loadAvg[0].toFixed(2), tonal: false, show: root.loadAvg[0] > 0 }
                    ]
                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        Layout.alignment: Qt.AlignRight
                        visible: chip.modelData.show
                        implicitWidth: chipRow.implicitWidth + 20
                        implicitHeight: 30
                        radius: 15
                        color: chip.modelData.tonal ? Colors.primaryContainer : Colors.surfaceContainerHigh

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialIconSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                content: chip.modelData.icon
                                iconSize: 18
                                fill: 1
                                customColor: chip.modelData.tonal ? Colors.primaryContainerText : Colors.primary
                            }
                            CustomText {
                                anchors.verticalCenter: parent.verticalCenter
                                content: chip.modelData.text
                                size: 13
                                weight: 500
                                customColor: chip.modelData.tonal ? Colors.primaryContainerText : Colors.surfaceText
                            }
                        }
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.columns
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: root.cores

                delegate: Rectangle {
                    id: core
                    required property var modelData
                    required property int index
                    readonly property string shape: root.shapes[core.index % root.shapes.length]
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: coreCol.implicitHeight + 20
                    radius: 22
                    color: Colors.surfaceContainer

                    ColumnLayout {
                        id: coreCol
                        x: 6
                        y: 10
                        width: core.width - 12
                        spacing: 8

                        Repeater {
                            model: core.modelData.threads

                            delegate: ColumnLayout {
                                id: thread
                                required property int modelData
                                readonly property real load: Math.max(0, Math.min(1, root.loads[thread.modelData] ?? 0))
                                readonly property real ghz: (root.freqs[thread.modelData] ?? 0) / 1000000
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 4

                                LiquidShape {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 54
                                    Layout.preferredHeight: 54
                                    shape: core.shape
                                    level: thread.load
                                    fill: thread.load > 0.85 ? Colors.error : Colors.primary
                                    onInk: thread.load > 0.85 ? Colors.errorText : Colors.primaryText
                                    track: Colors.surfaceContainerHighest
                                    label: Math.round(thread.load * 100)
                                    labelSize: 16
                                }
                                CustomText {
                                    Layout.alignment: Qt.AlignHCenter
                                    content: thread.ghz > 0 ? thread.ghz.toFixed(1) + " GHz" : ""
                                    size: 11
                                    weight: 400
                                    customColor: Colors.surfaceVariantText
                                }
                            }
                        }

                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            content: "Core " + (core.index + 1)
                            size: 11
                            weight: 600
                            customColor: Colors.surfaceText
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: root.procs.length > 0

            CustomText {
                Layout.leftMargin: 4
                Layout.bottomMargin: 6
                content: "Busiest right now"
                size: 13
                weight: 600
                customColor: Colors.primary
            }

            Repeater {
                model: root.procCount

                delegate: Rectangle {
                    id: proc
                    required property int index
                    readonly property var modelData: root.procs[proc.index] ?? ({ name: "", share: 0 })
                    readonly property real peak: Math.max(0.1, root.procs[0].share)
                    Layout.fillWidth: true
                    implicitHeight: 44
                    topLeftRadius: proc.index === 0 ? 18 : 6
                    topRightRadius: proc.index === 0 ? 18 : 6
                    bottomLeftRadius: proc.index === root.procCount - 1 ? 18 : 6
                    bottomRightRadius: proc.index === root.procCount - 1 ? 18 : 6
                    color: Colors.surfaceContainerHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        CustomText {
                            Layout.fillWidth: true
                            content: proc.modelData.name
                            size: 14
                            weight: 400
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            Layout.preferredWidth: 90
                            Layout.preferredHeight: 6
                            radius: 3
                            color: Colors.surfaceContainerHighest
                            Rectangle {
                                width: Math.max(4, parent.width * Math.min(1, proc.modelData.share / proc.peak))
                                height: parent.height
                                radius: 3
                                color: Colors.tertiary
                                Behavior on width { SpatialAnim {} }
                            }
                        }
                        CustomText {
                            Layout.preferredWidth: 44
                            horizontalAlignment: Text.AlignRight
                            content: proc.modelData.share.toFixed(1) + "%"
                            size: 13
                            weight: 600
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            visible: ServiceUPower.availableProfiles.length > 1

            M3ButtonGroup {
                anchors.left: parent.left
                anchors.right: parent.right
                height: 44
                fillWidth: true
                iconSize: 18
                textSize: 13
                inactiveColor: Colors.surfaceContainerHigh
                model: ServiceUPower.availableProfiles.map(p => ({ value: p.id, label: p.name, icon: p.icon }))
                activeCheck: value => ServiceUPower.powerProfile === value
                onSegmentClicked: value => ServiceUPower.setPowerProfile(value)
            }
        }
    }
}
