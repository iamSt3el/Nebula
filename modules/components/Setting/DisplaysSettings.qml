import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    readonly property var mons: ServiceHyprConfig.monitors
    property string selected: ""
    readonly property var sel: root.mons.find(m => m.name === root.selected) ?? root.mons[0] ?? null
    readonly property var others: root.mons.filter(m => m.name !== (root.sel?.name ?? ""))
    readonly property int enabledCount: root.mons.filter(m => !m.disabled).length

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
            if (!r) continue
            const res = r[1] + "x" + r[2]
            if (!out[res]) out[res] = []
            const hz = Number(r[3]).toFixed(2)
            if (out[res].indexOf(hz) < 0) out[res].push(hz)
        }
        return out
    }

    readonly property var selModes: root.modesOf(root.sel)
    readonly property string selRes: root.sel ? root.sel.width + "x" + root.sel.height : ""
    readonly property string selHz: root.sel ? Number(root.sel.refreshRate).toFixed(2) : ""

    function niceRes(res) {
        return res.replace("x", " × ")
    }

    function snapPosition(m, gx, gy) {
        const me = root.logical(m)
        var best = null, bestD = 1e12
        for (const o of root.mons) {
            if (o.name === m.name || o.disabled) continue
            const r = root.logical(o)
            const cands = [
                { x: r.x + r.w, y: r.y }, { x: r.x - me.w, y: r.y },
                { x: r.x, y: r.y + r.h }, { x: r.x, y: r.y - me.h },
                { x: r.x + r.w, y: r.y + r.h - me.h }, { x: r.x - me.w, y: r.y + r.h - me.h }
            ]
            for (const c of cands) {
                const d = (c.x - gx) * (c.x - gx) + (c.y - gy) * (c.y - gy)
                if (d < bestD) { bestD = d; best = c }
            }
        }
        return best ?? { x: Math.round(gx), y: Math.round(gy) }
    }

    Flickable {
        id: pageFlick
        ScrollBar.vertical: CustomScrollBar {}
        anchors.fill: parent
        contentHeight: column.implicitHeight + 70
        contentWidth: width
        clip: true

        ColumnLayout {
            id: column
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            anchors.topMargin: 5
            spacing: 0

            CustomText { Layout.topMargin: 24; content: "Arrangement"; size: 13; customColor: Colors.primary }

            Rectangle {
                id: arena
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.preferredHeight: 230
                topLeftRadius: 20; topRightRadius: 20; bottomLeftRadius: 5; bottomRightRadius: 5
                color: Colors.surfaceContainerLow
                clip: true

                readonly property var box: {
                    var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9
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
                        radius: 12
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
                                    content: /^eDP|^LVDS|^DSI/.test(mon.modelData.name) ? "Built-in display" : (mon.modelData.model || mon.modelData.name)
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
                            onReleased: {
                                if (!drag.active) return
                                const gx = (mon.x - 2 - arena.ox) / arena.s + arena.box.x
                                const gy = (mon.y - 2 - arena.oy) / arena.s + arena.box.y
                                const p = root.snapPosition(mon.modelData, gx, gy)
                                ServiceHyprConfig.setMonitor(mon.modelData.name, { position: Math.round(p.x) + "x" + Math.round(p.y) })
                            }
                        }
                    }
                }
            }

            CustomCard {
                Layout.topMargin: 3
                autoRadius: false; topRadius: 5; bottomRadius: 20

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    M3Button {
                        variant: "tonal"
                        icon: "refresh"
                        label: "Detect"
                        onClicked: ServiceHyprConfig.refresh()
                    }
                    Item { Layout.fillWidth: true }
                    CustomText { content: "Drag a display to move it; edges snap together"; size: 12; customColor: Colors.outline }
                }
            }

            CustomText {
                visible: !!root.sel
                Layout.topMargin: 16
                content: /^eDP|^LVDS|^DSI/.test(root.sel?.name ?? "") ? "Built-in display" : ((root.sel?.description ?? "").replace(/\s+\S+$/, "") || (root.sel?.name ?? ""))
                size: 13
                customColor: Colors.primary
            }

            ColumnLayout {
                visible: !!root.sel
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            CustomText { Layout.fillWidth: true; content: "Resolution"; size: 14 }
                            CustomText { content: root.sel?.name ?? ""; size: 12; customColor: Colors.outline }
                        }
                        CustomListNew {
                            Layout.preferredWidth: 180
                            Layout.preferredHeight: 32
                            color: Colors.surfaceContainerHighest
                            currentVal: root.niceRes(root.selRes)
                            list: Object.keys(root.selModes).map(r => ({ name: root.niceRes(r), res: r }))
                            onListChildClicked: child => {
                                const hz = root.selModes[child.res]?.[0] ?? root.selHz
                                ServiceHyprConfig.setMonitor(root.sel.name, { mode: child.res + "@" + hz })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        CustomText { Layout.fillWidth: true; content: "Refresh rate"; size: 14 }
                        M3ButtonGroup {
                            height: 32
                            textSize: 12
                            model: (root.selModes[root.selRes] ?? [root.selHz]).map(hz => ({ value: hz, label: Number(hz) + " Hz" }))
                            activeCheck: function(value) { return value === root.selHz }
                            onSegmentClicked: value => ServiceHyprConfig.setMonitor(root.sel.name, { mode: root.selRes + "@" + value })
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            CustomText { Layout.fillWidth: true; content: "Scale"; size: 14 }
                            CustomText {
                                content: root.sel ? "Apps get " + Math.round(root.sel.width / root.sel.scale) + " × " + Math.round(root.sel.height / root.sel.scale) + " of room" : ""
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                        M3ButtonGroup {
                            height: 32
                            textSize: 12
                            model: [1, 1.25, 1.5, 1.75, 2].map(v => ({ value: v, label: Math.round(v * 100) + "%" }))
                            activeCheck: function(value) { return Math.abs((root.sel?.scale ?? 1) - value) < 0.01 }
                            onSegmentClicked: value => ServiceHyprConfig.setMonitor(root.sel.name, { scale: value })
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        CustomText { Layout.fillWidth: true; content: "Orientation"; size: 14 }
                        M3ButtonGroup {
                            height: 32
                            textSize: 12
                            model: [
                                { value: 0, label: "Landscape", icon: "crop_landscape" },
                                { value: 1, label: "Portrait", icon: "crop_portrait" },
                                { value: 2, label: "Flipped", icon: "rotate_right" },
                                { value: 3, label: "Portrait flipped", icon: "rotate_left" }
                            ]
                            activeCheck: function(value) { return (root.sel?.transform ?? 0) === value }
                            onSegmentClicked: value => ServiceHyprConfig.setMonitor(root.sel.name, { transform: value })
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            CustomText { Layout.fillWidth: true; content: "Variable refresh rate"; size: 14 }
                            CustomText {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                content: "Lets games and video set the refresh rate; some panels flicker with it"
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                        CustomToogle {
                            isToggleOn: !!root.sel?.vrr
                            onToggled: function(state) { ServiceHyprConfig.setMonitor(root.sel.name, { vrr: state ? 1 : 0 }) }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        CustomText { Layout.fillWidth: true; content: "Use this display"; size: 14 }
                        M3ButtonGroup {
                            height: 32
                            textSize: 12
                            readonly property string mode: root.sel?.disabled ? "off"
                                : (root.sel?.mirrorOf && root.sel.mirrorOf !== "none") ? "mirror" : "extend"
                            model: {
                                const m = [{ value: "extend", label: "Extend" }]
                                if (root.others.length) m.push({ value: "mirror", label: "Mirror " + root.others[0].name })
                                if (root.enabledCount > 1 || root.sel?.disabled) m.push({ value: "off", label: "Off" })
                                return m
                            }
                            activeCheck: function(value) { return value === mode }
                            onSegmentClicked: value => {
                                if (value === "extend") ServiceHyprConfig.setMonitor(root.sel.name, { disabled: false, mirror: "" })
                                else if (value === "mirror") ServiceHyprConfig.setMonitor(root.sel.name, { disabled: false, mirror: root.others[0].name })
                                else ServiceHyprConfig.setMonitor(root.sel.name, { disabled: true })
                            }
                        }
                    }
                }
            }

            CustomText { visible: !!root.sel; Layout.topMargin: 16; content: "Workspaces"; size: 13; customColor: Colors.primary }

            CustomCard {
                visible: !!root.sel
                Layout.topMargin: 6
                autoRadius: false; topRadius: 20; bottomRadius: 20

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        spacing: 2
                        CustomText { content: "Workspaces that open on this display"; size: 14 }
                        CustomText { content: "Click a number to move it here; click again to let it go anywhere"; size: 12; customColor: Colors.outline }
                    }

                    RowLayout {
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

            CustomText { Layout.topMargin: 16; content: "All displays"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

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

            Item { Layout.preferredHeight: 20 }
        }
    }

    ScrollFade {
        anchors.fill: parent
        flickable: pageFlick
    }

    Rectangle {
        id: revertBar
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

    Component.onCompleted: ServiceHyprConfig.refreshMonitors()
}
