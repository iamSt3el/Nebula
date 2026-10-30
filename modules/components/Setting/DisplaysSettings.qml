import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    readonly property var mons: ServiceHyprConfig.monitors
    property string selected: ""
    readonly property var sel: root.mons.find(m => m.name === root.selected) ?? root.mons[0] ?? null
    readonly property var others: root.mons.filter(m => m.name !== (root.sel?.name ?? ""))
    readonly property int enabledCount: root.mons.filter(m => !m.disabled).length
    readonly property var selModes: root.modesOf(root.sel)
    readonly property string selRes: root.sel ? root.sel.width + "x" + root.sel.height : ""
    readonly property string selHz: root.sel ? Number(root.sel.refreshRate).toFixed(2) : ""
    readonly property string useMode: root.sel?.disabled ? "off"
        : (root.sel?.mirrorOf && root.sel.mirrorOf !== "none") ? "mirror" : "extend"

    function logical(m) {
        const rot = (m.transform % 2) === 1
        const w = (rot ? m.height : m.width) / m.scale
        const h = (rot ? m.width : m.height) / m.scale
        return { x: m.x, y: m.y, w: w, h: h }
    }

    function modesOf(m) {
        const out = {}
        for (const s of (m?.availableModes ?? [])) {
            const r = s.match(/^(\d+)x(\d+)@([\d.]+)/)
            if (!r)
                continue
            const res = r[1] + "x" + r[2]
            if (!out[res])
                out[res] = []
            const hz = Number(r[3]).toFixed(2)
            if (out[res].indexOf(hz) < 0)
                out[res].push(hz)
        }
        return out
    }

    function niceRes(res) {
        return res.replace("x", " × ")
    }

    function nameOf(m) {
        if (!m)
            return ""
        if (/^eDP|^LVDS|^DSI/.test(m.name))
            return "Built-in display"
        return (m.description ?? "").replace(/\s+\S+$/, "") || m.model || m.name
    }

    function summaryOf(m) {
        if (m.disabled)
            return m.name + " · off"
        return m.name + " · " + m.width + " × " + m.height + " at " + Number(m.refreshRate).toFixed(2) + " Hz"
            + (Math.abs(m.scale - 1) > 0.01 ? " · " + Math.round(m.scale * 100) + "%" : "")
    }

    function open(m) {
        root.selected = m.name
        stages.push("display")
    }

    function snapPosition(m, gx, gy) {
        const me = root.logical(m)
        let best = null, bestD = 1e12
        for (const o of root.mons) {
            if (o.name === m.name || o.disabled)
                continue
            const r = root.logical(o)
            const cands = [
                { x: r.x + r.w, y: r.y }, { x: r.x - me.w, y: r.y },
                { x: r.x, y: r.y + r.h }, { x: r.x, y: r.y - me.h },
                { x: r.x + r.w, y: r.y + r.h - me.h }, { x: r.x - me.w, y: r.y + r.h - me.h }
            ]
            for (const c of cands) {
                const d = (c.x - gx) * (c.x - gx) + (c.y - gy) * (c.y - gy)
                if (d < bestD) {
                    bestD = d
                    best = c
                }
            }
        }
        return best ?? { x: Math.round(gx), y: Math.round(gy) }
    }

    Component.onCompleted: ServiceHyprConfig.refreshMonitors()

    StageView {
        id: stages

        StagePage {
            stageId: "front"

            HyprTargetRow { area: "displays" }

            Rectangle {
                id: arena
                Layout.fillWidth: true
                Layout.preferredHeight: 230
                radius: 28
                color: Colors.surfaceContainerLow
                clip: true

                readonly property var box: {
                    let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9
                    for (const m of root.mons) {
                        const r = root.logical(m)
                        x0 = Math.min(x0, r.x); y0 = Math.min(y0, r.y)
                        x1 = Math.max(x1, r.x + r.w); y1 = Math.max(y1, r.y + r.h)
                    }
                    return root.mons.length ? { x: x0, y: y0, w: x1 - x0, h: y1 - y0 } : { x: 0, y: 0, w: 1, h: 1 }
                }
                readonly property real s: Math.min((width - 80) / Math.max(1, box.w), (height - 60) / Math.max(1, box.h))
                readonly property real ox: (width - box.w * s) / 2
                readonly property real oy: (height - box.h * s) / 2

                Repeater {
                    model: root.mons

                    Rectangle {
                        id: mon
                        required property var modelData
                        required property int index
                        readonly property var r: root.logical(mon.modelData)
                        readonly property bool isSel: mon.modelData.name === (root.sel?.name ?? "")

                        x: arena.ox + (mon.r.x - arena.box.x) * arena.s + 2
                        y: arena.oy + (mon.r.y - arena.box.y) * arena.s + 2
                        width: mon.r.w * arena.s - 4
                        height: mon.r.h * arena.s - 4
                        radius: 14
                        opacity: mon.modelData.disabled ? 0.45 : 1
                        color: mon.isSel ? Colors.primaryContainer : Colors.surfaceContainerHighest
                        border.width: mon.isSel ? 3 : 0
                        border.color: Colors.primary
                        z: dragArea.drag.active ? 2 : 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 2

                            RowLayout {
                                spacing: 8
                                Rectangle {
                                    implicitWidth: 22; implicitHeight: 22; radius: 11
                                    color: mon.isSel ? Colors.primary : Colors.inverseSurface
                                    CustomText {
                                        anchors.centerIn: parent
                                        content: String(mon.index + 1)
                                        size: 11; weight: 700
                                        customColor: mon.isSel ? Colors.primaryText : Colors.inverseSurfaceText
                                    }
                                }
                                CustomText {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    content: root.nameOf(mon.modelData)
                                    size: 12; weight: 600
                                    customColor: mon.isSel ? Colors.primaryContainerText : Colors.surfaceText
                                }
                            }
                            Item { Layout.fillHeight: true }
                            CustomText {
                                content: mon.modelData.disabled ? "Off" : mon.modelData.width + " × " + mon.modelData.height
                                size: 11
                                customColor: mon.isSel ? Colors.primaryContainerText : Colors.outline
                            }
                        }

                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            drag.target: root.mons.length > 1 ? mon : null
                            drag.threshold: 6
                            onPressed: root.selected = mon.modelData.name
                            onClicked: root.open(mon.modelData)
                            onReleased: {
                                if (!drag.active)
                                    return
                                const gx = (mon.x - 2 - arena.ox) / arena.s + arena.box.x
                                const gy = (mon.y - 2 - arena.oy) / arena.s + arena.box.y
                                const p = root.snapPosition(mon.modelData, gx, gy)
                                ServiceHyprConfig.setMonitor(mon.modelData.name, { position: Math.round(p.x) + "x" + Math.round(p.y) })
                            }
                        }
                    }
                }
            }

            StageNote { content: "Drag a display to move it; edges snap together. Click one for its settings." }

            Repeater {
                model: root.mons

                StageNavRow {
                    required property var modelData
                    icon: /^eDP|^LVDS|^DSI/.test(modelData.name) ? "laptop_chromebook" : "desktop_windows"
                    tonal: modelData.name === (SettingsConfig.general.primaryMonitor ?? "")
                    title: root.nameOf(modelData)
                    subtitle: root.summaryOf(modelData)
                    value: tonal ? "Main" : ""
                    onClicked: root.open(modelData)
                }
            }

            StageGap {}

            StageNavRow {
                icon: "tune"
                title: "All displays"
                subtitle: "Variable refresh rate mode"
                target: "all"
            }

            StageNavRow {
                icon: "screen_search_desktop"
                title: "Detect displays"
                subtitle: "Look again for screens that were plugged in"
                onClicked: ServiceHyprConfig.refresh()
            }
        }

        StageLazy {
            stageId: "display"

            StagePage {
                stageId: "display"
                title: root.nameOf(root.sel)
                aside: root.sel?.name ?? ""

                StageChoiceRow {
                    title: "Use this display"
                    options: {
                        const m = [{ value: "extend", label: "Extend" }]
                        if (root.others.length)
                            m.push({ value: "mirror", label: "Mirror " + root.others[0].name })
                        if (root.enabledCount > 1 || root.sel?.disabled)
                            m.push({ value: "off", label: "Off" })
                        return m
                    }
                    current: root.useMode
                    onPicked: v => {
                        if (v === "extend")
                            ServiceHyprConfig.setMonitor(root.sel.name, { disabled: false, mirror: "" })
                        else if (v === "mirror")
                            ServiceHyprConfig.setMonitor(root.sel.name, { disabled: false, mirror: root.others[0].name })
                        else
                            ServiceHyprConfig.setMonitor(root.sel.name, { disabled: true })
                    }
                }

                StageGap {}

                StageDropdownRow {
                    enabled: !root.sel?.disabled
                    title: "Resolution"
                    options: Object.keys(root.selModes).map(r => root.niceRes(r))
                    current: root.niceRes(root.selRes)
                    onPicked: name => {
                        const res = name.replace(" × ", "x")
                        const hz = root.selModes[res]?.[0] ?? root.selHz
                        ServiceHyprConfig.setMonitor(root.sel.name, { mode: res + "@" + hz })
                    }
                }

                StageChoiceRow {
                    enabled: !root.sel?.disabled
                    title: "Refresh rate"
                    options: (root.selModes[root.selRes] ?? [root.selHz]).map(hz => ({ value: hz, label: Number(hz) + " Hz" }))
                    current: root.selHz
                    onPicked: v => ServiceHyprConfig.setMonitor(root.sel.name, { mode: root.selRes + "@" + v })
                }

                StageChoiceRow {
                    enabled: !root.sel?.disabled
                    title: "Scale"
                    subtitle: root.sel ? "Apps get " + Math.round(root.sel.width / root.sel.scale) + " × " + Math.round(root.sel.height / root.sel.scale) + " of room" : ""
                    options: [1, 1.25, 1.5, 1.75, 2].map(v => ({ value: v, label: Math.round(v * 100) + "%" }))
                    current: [1, 1.25, 1.5, 1.75, 2].find(v => Math.abs((root.sel?.scale ?? 1) - v) < 0.01)
                    onPicked: v => ServiceHyprConfig.setMonitor(root.sel.name, { scale: v })
                }

                StageChoiceRow {
                    enabled: !root.sel?.disabled
                    title: "Orientation"
                    options: [
                        { value: 0, label: "Landscape", icon: "crop_landscape" },
                        { value: 1, label: "Portrait", icon: "crop_portrait" },
                        { value: 2, label: "Flipped", icon: "rotate_right" },
                        { value: 3, label: "Portrait flipped", icon: "rotate_left" }
                    ]
                    current: root.sel?.transform ?? 0
                    onPicked: v => ServiceHyprConfig.setMonitor(root.sel.name, { transform: v })
                }

                StageSwitchRow {
                    enabled: !root.sel?.disabled
                    title: "Variable refresh rate"
                    subtitle: "Lets games and video set the refresh rate; some panels flicker with it"
                    checked: !!root.sel?.vrr
                    onToggled: on => ServiceHyprConfig.setMonitor(root.sel.name, { vrr: on ? 1 : 0 })
                }

                StageHeading { text: "Workspaces that open here" }

                StageRow {
                    subtitle: "Click a number to pin it to this display; click again to let it open anywhere"

                    below: RowLayout {
                        spacing: 6

                        Repeater {
                            model: 10

                            Rectangle {
                                id: wsChip
                                required property int index
                                readonly property int ws: wsChip.index + 1
                                readonly property string owner: ServiceHyprConfig.workspaceMonitor(wsChip.ws)
                                readonly property bool mine: wsChip.owner === (root.sel?.name ?? "")
                                implicitWidth: 38
                                implicitHeight: 38
                                radius: wsChip.mine ? 19 : 12
                                color: wsChip.mine ? Colors.secondaryContainer : "transparent"
                                border.width: wsChip.mine ? 0 : 1
                                border.color: Colors.outlineVariant

                                Behavior on radius { SpatialAnim {} }

                                CustomText {
                                    anchors.centerIn: parent
                                    content: String(wsChip.ws)
                                    size: 13
                                    weight: 600
                                    customColor: wsChip.mine ? Colors.secondaryContainerText : (wsChip.owner === "" ? Colors.surfaceText : Colors.outline)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ServiceHyprConfig.setWorkspaceMonitor(wsChip.ws, wsChip.mine ? "" : root.sel.name)
                                }
                            }
                        }
                    }
                }
            }
        }

        StageLazy {
            stageId: "all"

            StagePage {
                stageId: "all"
                title: "All displays"

                HyprChoiceRow {
                    autoRadius: false; topRadius: 20; bottomRadius: 20
                    title: "Variable refresh rate mode"
                    subtitle: "Applies to displays that support it"
                    path: "misc.vrr"
                    model: [
                        { value: 0, label: "Off" },
                        { value: 1, label: "Always" },
                        { value: 2, label: "Fullscreen" },
                        { value: 3, label: "Games" }
                    ]
                }
            }
        }
    }

    Rectangle {
        visible: !!ServiceHyprConfig.pendingMonitor
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: Math.min(parent.width - 20, 520)
        height: 52
        radius: 16
        color: Colors.inverseSurface

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 8
            spacing: 8

            MaterialIconSymbol { content: "timer"; iconSize: 20; customColor: Colors.inverseSurfaceText }
            CustomText {
                Layout.fillWidth: true
                content: "Keep these display settings? Reverting in " + ServiceHyprConfig.revertIn + " s"
                size: 13
                customColor: Colors.inverseSurfaceText
            }
            M3Button { variant: "tonal"; label: "Revert"; onClicked: ServiceHyprConfig.revertMonitor() }
            M3Button { variant: "filled"; label: "Keep"; onClicked: ServiceHyprConfig.keepMonitor() }
        }
    }
}
