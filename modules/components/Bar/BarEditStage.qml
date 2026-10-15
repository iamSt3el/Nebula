pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Edit

EditKit.Card {
    id: stageCard

    required property Item host

    readonly property var panel: stageCard.host.panelOf(stageCard.host.sel)
    readonly property string kind: stageCard.panel ? stageCard.panel.kind : ""
    readonly property var spec: stageCard.kind !== "" ? BarLayout.panelSpecs[stageCard.kind] ?? null : null
    readonly property var styleOpt: {
        const map = { launcher: ["launcher", "style"], wallpaper: ["wallpaper", "style"], clipboard: ["clipboard", "style"],
                      calendar: ["clock", "panel"], osd: ["osd", "style"] }
        const m = map[stageCard.kind]
        if (!m) return null
        const s = BarLayout.specFor(m[0], m[1])
        return s && s.choices ? { item: m[0], key: m[1], spec: s } : null
    }
    readonly property string opener: stageCard.panel ? stageCard.host.hostText(stageCard.panel) : ""
    readonly property bool hostMissing: stageCard.panel !== null && stageCard.host.hostOf(stageCard.panel).type === "none"
    readonly property bool momentary: stageCard.kind === "notifPopup" || stageCard.kind === "osd"

    readonly property var placeChoices: {
        switch (stageCard.kind) {
        case "launcher":
            return [{ value: "item", label: "Apps item", icon: "apps" }, { value: "center", label: "Centre", icon: "center_focus_strong" }]
        case "wallpaper":
        case "clipboard":
            return [{ value: "dock", label: "Item or edge", icon: "dock_to_bottom" }, { value: "center", label: "Centre panel", icon: "center_focus_strong" }]
        case "notifPopup":
            return [{ value: "item", label: "Popups item", icon: "notifications_active" }, { value: "bell", label: "The bell", icon: "notifications" },
                    { value: "icons", label: "Dock icons", icon: "apps" }]
        case "osd":
            return [{ value: "item", label: "OSD item", icon: "volume_up" }, { value: "sys", label: "Edge centre", icon: "dock_to_bottom" }]
        }
        return []
    }

    readonly property string placeValue: {
        const gen = SettingsConfig.general ?? {}
        switch (stageCard.kind) {
        case "launcher": return ServiceLauncher.position === "center" ? "center" : "item"
        case "wallpaper": return (gen.wallpaperPanelMode ?? "dock") === "center" ? "center" : "dock"
        case "clipboard": return (gen.clipboardPanelMode ?? "dock") === "center" ? "center" : "dock"
        case "notifPopup":
            return BarLayout.isPlaced("popups") ? "item" : (gen.notifPopupStyle ?? "item") === "icon" ? "icons" : "bell"
        case "osd": return BarLayout.osdHostItem !== "" ? "item" : "sys"
        }
        return ""
    }

    function placeNear(id, near) {
        const real = BarLayout.allBlocks.filter(b => b.id !== "__sys")
        const hit = real.find(b => b.items.some(i => BarLayout.baseId(i) === near))
        const blk = hit ?? real.find(b => b.edge === BarLayout.sysEdge) ?? real[0]
        if (!blk)
            return
        const at = hit ? hit.items.findIndex(i => BarLayout.baseId(i) === near) + 1 : blk.items.length
        Qt.callLater(() => BarLayout.moveItem(id, blk.id, at))
    }

    function place(v) {
        switch (stageCard.kind) {
        case "launcher":
            BarLayout.setOption("launcher", "position", v)
            if (v === "item" && !BarLayout.isPlaced("launcher"))
                stageCard.placeNear("launcher", "dockApps")
            return
        case "wallpaper":
        case "clipboard":
            BarLayout.setOption(stageCard.kind, "place", v)
            return
        case "notifPopup":
            if (v === "item") {
                if (!BarLayout.isPlaced("popups"))
                    stageCard.placeNear("popups", "notifications")
                return
            }
            BarLayout.setOption("notifications", "popupStyle", v === "icons" ? "icon" : "item")
            if (BarLayout.isPlaced("popups"))
                Qt.callLater(() => BarLayout.hideItem("popups"))
            return
        case "osd":
            if (v === "item") {
                if (BarLayout.osdHostItem === "")
                    stageCard.placeNear("osd", "volume")
            } else if (BarLayout.osdHostItem !== "") {
                const id = BarLayout.osdHostItem
                Qt.callLater(() => BarLayout.hideItem(id))
            }
            return
        }
    }

    readonly property bool wanted: stageCard.host.editing && stageCard.host.stage && !stageCard.host.drawerShown
    readonly property var panelOpts: {
        const map = { launcher: ["launcher", ["sort", "calc", "run", "emoji", "windows", "radius", "iconSize"]],
                      notifPopup: ["popups", ["timeout", "cards", "group", "sticky"]] }
        const m = map[stageCard.kind]
        if (!m) return null
        const specs = m[1].map(k => BarLayout.specFor(m[0], k)).filter(s => !!s)
        return specs.length ? { item: m[0], specs: specs } : null
    }
    readonly property string cornerEdge: {
        if (!stageCard.panel || stageCard.momentary)
            return ""
        const h = stageCard.host.hostOf(stageCard.panel)
        if (h.type === "sys")
            return BarLayout.sysEdge
        if (h.type !== "item")
            return ""
        const b = stageCard.host.blockOfItem(h.item)
        return b ? b.edge : ""
    }
    readonly property real cornerOwn: BarLayout.panelRadius(stageCard.kind)
    readonly property real cornerEdgeR: stageCard.cornerEdge !== "" ? (BarLayout.edge(stageCard.cornerEdge).radius ?? 18) : 18
    readonly property var sectionOpts: stageCard.kind === "dashboard" ? stageCard.host.toggleOptsOf("dashboard") : []
    readonly property bool defaultLeft: stageCard.host.insetLeft !== stageCard.host.insetRight
        ? stageCard.host.insetLeft < stageCard.host.insetRight : stageCard.host.previewRight
    readonly property bool goalLeft: stageCard.host.stageSide !== "" ? stageCard.host.stageSide === "left" : stageCard.defaultLeft
    readonly property real goalW: Math.min(400, Math.max(320, stageCard.host.stageRoom))
    property bool onLeft: true
    property real cardW: 400
    readonly property bool moving: stageCard.wanted && stageCard.onLeft !== stageCard.goalLeft
    property real fade: stageCard.wanted && !stageCard.moving && !stageCard.host.stageHold ? 1 : 0
    Behavior on fade { EffectsAnim { speed: "fast" } }

    function settle() {
        stageCard.onLeft = stageCard.goalLeft
        stageCard.cardW = stageCard.goalW
    }

    onFadeChanged: if (stageCard.fade === 0) stageCard.settle()
    onGoalLeftChanged: if (stageCard.fade === 0) stageCard.settle()
    onGoalWChanged: if (stageCard.fade === 0 || !stageCard.moving) stageCard.cardW = stageCard.goalW
    Component.onCompleted: stageCard.settle()

    visible: stageCard.wanted && stageCard.fade > 0.01
    opacity: stageCard.fade
    x: stageCard.onLeft ? stageCard.host.insetLeft + 16 : stageCard.host.width - width - stageCard.host.insetRight - 16
    y: (stageCard.host.surfTop && stageCard.host.surfTop.present ? stageCard.host.surfTop.thickness : 0) + 40
    width: stageCard.cardW
    Behavior on width {
        enabled: stageCard.fade > 0.99
        SpatialAnim { speed: "fast" }
    }
    readonly property real floorY: stageCard.host.height
        - (stageCard.host.surfBottom && stageCard.host.surfBottom.visible && stageCard.host.surfBottom.present
           ? stageCard.host.surfBottom.thickness : 0) - 56
    height: Math.max(160, Math.min(stageBody.implicitHeight + 36, stageCard.floorY - stageCard.y))
    radius: 28
    clip: true

    Flickable {
        id: stageFlick
        anchors.fill: parent
        anchors.topMargin: 18
        anchors.bottomMargin: 18
        contentWidth: width
        contentHeight: stageBody.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        clip: true

    ColumnLayout {
        id: stageBody
        x: 18
        width: stageFlick.width - 36
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                CustomText {
                    content: stageCard.panel ? stageCard.panel.label + " panel" : "Panels"
                    size: 18
                    weight: 600
                }
                CustomText {
                    Layout.fillWidth: true
                    content: stageCard.hostMissing ? "Its bar item isn't placed, so there's nothing to preview"
                        : stageCard.momentary ? "Send a test to see where it appears"
                        : stageCard.spec ? "Open live · drag its edges to resize" : "Open live"
                    size: 12
                    weight: 400
                    customColor: Colors.surfaceVariantText
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
            }

            EditKit.Pill {
                icon: "close"
                box: 38
                onClicked: stageCard.host.editor.panelStage = false
            }
        }

        EditChoice {
            Layout.fillWidth: true
            maxPerRow: 3
            choices: stageCard.host.panelList.map(p => ({ value: p.item, label: p.label, icon: p.icon }))
            isActive: function(v) { return stageCard.panel !== null && stageCard.panel.item === v }
            onPicked: v => stageCard.host.openStage(v)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.outlineVariant
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: stageCard.styleOpt !== null

            EditKit.SectionLabel { content: "Style" }

            EditChoice {
                Layout.fillWidth: true
                choices: stageCard.styleOpt ? stageCard.styleOpt.spec.choices : []
                value: stageCard.styleOpt ? BarLayout.opt(stageCard.styleOpt.item, stageCard.styleOpt.key) : undefined
                onPicked: v => BarLayout.setOption(stageCard.styleOpt.item, stageCard.styleOpt.key, v)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: stageCard.cornerEdge !== ""

            EditKit.SectionLabel { content: "Corners" }

            EditStepper {
                Layout.fillWidth: true
                value: stageCard.cornerOwn >= 0 ? stageCard.cornerOwn : stageCard.cornerEdgeR
                from: 0
                to: 40
                stepSize: 1
                canAuto: true
                isAuto: stageCard.cornerOwn < 0
                autoLabel: "Match bar"
                autoText: "Bar"
                onPicked: v => BarLayout.setPanelRadius(stageCard.kind, v)
                onAutoPicked: BarLayout.setPanelRadius(stageCard.kind, -1)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: stageCard.panelOpts !== null

            EditKit.SectionLabel { content: "Options" }

            Repeater {
                model: stageCard.panelOpts ? stageCard.panelOpts.specs : []

                EditOptionRow {
                    required property var modelData
                    Layout.fillWidth: true
                    instanceId: stageCard.panelOpts ? stageCard.panelOpts.item : ""
                    spec: modelData
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: stageCard.sectionOpts.length > 0

            EditKit.SectionLabel { content: "Sections" }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: stageCard.sectionOpts

                    EditKit.ChoiceChip {
                        required property var modelData
                        readonly property bool isOn: BarLayout.opt("dashboard", modelData.key) === true
                        label: modelData.label
                        lit: isOn
                        onClicked: BarLayout.setOption("dashboard", modelData.key, !isOn)
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: stageCard.spec !== null

            RowLayout {
                Layout.fillWidth: true
                EditKit.SectionLabel { content: "Size"; Layout.fillWidth: true }
                CustomText {
                    content: stageCard.spec
                        ? BarLayout.panelW(stageCard.kind) + " × " + (BarLayout.panelH(stageCard.kind) < 0 ? "auto" : BarLayout.panelH(stageCard.kind))
                        : ""
                    size: 12
                    weight: 700
                    customColor: Colors.primary
                }
            }

            EditChoice {
                Layout.fillWidth: true
                choices: BarLayout.panelPresets(stageCard.kind)
                isActive: function(v) { return BarLayout.presetActive(stageCard.kind, v) }
                onPicked: v => BarLayout.applyPreset(stageCard.kind, v)
            }

            PanelSizeSliders {
                Layout.fillWidth: true
                kind: stageCard.kind
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: stageCard.placeChoices.length > 0

            EditKit.SectionLabel { content: "Opens from" }

            EditChoice {
                Layout.fillWidth: true
                maxPerRow: 3
                choices: stageCard.placeChoices
                value: stageCard.placeValue
                onPicked: v => stageCard.place(v)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: stageCard.momentary

            M3Button {
                Layout.fillWidth: true
                icon: stageCard.kind === "osd" ? "volume_up" : "send"
                label: stageCard.kind === "osd" ? "Show volume" : "Test popup"
                onClicked: stageCard.kind === "osd" ? BarLayout.testOsd("volume") : BarLayout.testPopup(false)
            }
            M3Button {
                Layout.fillWidth: true
                variant: "tonal"
                icon: stageCard.kind === "osd" ? "brightness_6" : "priority_high"
                label: stageCard.kind === "osd" ? "Show brightness" : "Urgent one"
                onClicked: stageCard.kind === "osd" ? BarLayout.testOsd("brightness") : BarLayout.testPopup(true)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: openCol.implicitHeight + 28
                radius: 20
                color: Colors.surfaceContainerHigh

                ColumnLayout {
                    id: openCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 1
                    CustomText { content: stageCard.opener; size: 13; weight: 500; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    CustomText {
                        Layout.fillWidth: true
                        content: stageCard.hostMissing ? "Drag the handle onto a block to place it"
                            : "Drag the handle onto any block to open it from there"
                        size: 11
                        weight: 400
                        customColor: Colors.surfaceVariantText
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                    }
                }
            }

            Rectangle {
                id: grabPin
                visible: stageCard.panel !== null
                implicitWidth: grabRow.implicitWidth + 22
                implicitHeight: 40
                radius: grabArea.pressed ? 12 : 20
                color: grabArea.containsMouse ? Colors.primary : Colors.primaryContainer
                Behavior on color { EffectsColorAnim { speed: "fast" } }
                Behavior on radius { SpatialAnim { speed: "fast" } }

                RowLayout {
                    id: grabRow
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialIconSymbol {
                        content: "drag_indicator"
                        iconSize: 18
                        customColor: grabArea.containsMouse ? Colors.primaryText : Colors.primaryContainerText
                    }
                    MaterialIconSymbol {
                        content: stageCard.panel ? stageCard.panel.icon : ""
                        iconSize: 16
                        customColor: grabArea.containsMouse ? Colors.primaryText : Colors.primaryContainerText
                    }
                }

                MouseArea {
                    id: grabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    property real sx: 0
                    property real sy: 0
                    property bool live: false

                    onPressed: mouse => {
                        grabArea.sx = mouse.x
                        grabArea.sy = mouse.y
                    }
                    onPositionChanged: mouse => {
                        if (!grabArea.pressed)
                            return
                        const sp = grabArea.mapToItem(null, mouse.x, mouse.y)
                        if (!grabArea.live && Math.hypot(mouse.x - grabArea.sx, mouse.y - grabArea.sy) > 6) {
                            grabArea.live = true
                            stageCard.host.startPinDrag(stageCard.panel, sp.x, sp.y, 28)
                        } else if (grabArea.live) {
                            stageCard.host.editor.update(sp.x, sp.y)
                        }
                    }
                    onReleased: {
                        if (!grabArea.live)
                            return
                        grabArea.live = false
                        stageCard.host.finishPinDrag(stageCard.panel)
                    }
                    onCanceled: {
                        if (!grabArea.live)
                            return
                        grabArea.live = false
                        stageCard.host.editor.cancel()
                    }
                }

                CustomToolTip { content: "Drag onto any block to open this panel from there"; visible: grabArea.containsMouse && !grabArea.pressed }
            }

            EditKit.Pill {
                id: stageMore
                icon: "tune"
                label: "More"
                onClicked: {
                    stageCard.host.editor.drawerFrom = stageMore.mapToItem(stageCard.host, 0, 0, stageMore.width, stageMore.height)
                    stageCard.host.editor.drawerMode = "options"
                }
            }
        }
    }
    }
}
