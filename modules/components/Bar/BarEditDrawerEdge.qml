import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.Edit

ColumnLayout {
    id: edgesPage
    required property Item host
    Layout.fillWidth: true
    spacing: 12
    visible: !host.itemPage && host.tab !== "general"

    EditHeading {
        Layout.fillWidth: true
        Layout.topMargin: 10
        visible: true
        content: "Edge"
        size: 13
        customColor: Colors.primary
    }
    ColumnLayout {
        id: drawerGroupEdge
        Layout.fillWidth: true
        visible: true
        spacing: 8
        EditRow {
            visible: host.edgeBlocks.length > 0
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 100000
                    spacing: 1

                    CustomText { content: "Show this edge"; size: 13 }
                    CustomText {
                        content: host.edgeCfg.hidden ? "Hidden. Its blocks stay saved." : "Turn off to hide every block on this edge"
                        size: 11
                        customColor: Colors.outline
                    }
                }

                CustomToogle {
                    isToggleOn: !host.edgeCfg.hidden
                    onToggled: state => BarLayout.setEdge(host.edgeSide, "hidden", !state)
                }
            }
        }
        EditRow {
            visible: host.edgeBlocks.length > 0 && !host.edgeCfg.hidden
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 100000
                    spacing: 1

                    CustomText { content: "Auto-hide"; size: 13 }
                    CustomText {
                        content: "Slide away until the pointer reaches the edge"
                        size: 11
                        customColor: Colors.outline
                    }
                }

                CustomToogle {
                    isToggleOn: host.edgeCfg.autoHide
                    onToggled: state => BarLayout.setEdge(host.edgeSide, "autoHide", state)
                }
            }
        }
        EditRow {
            visible: host.edgeBlocks.length > 0 && !host.edgeCfg.hidden
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 100000
                    spacing: 1

                    CustomText { content: "Hide in game mode"; size: 13 }
                    CustomText {
                        content: "Tuck this edge away while game mode hides widgets"
                        size: 11
                        customColor: Colors.outline
                    }
                }

                CustomToogle {
                    isToggleOn: host.edgeCfg.gameHide === true
                    onToggled: state => BarLayout.setEdge(host.edgeSide, "gameHide", state)
                }
            }
        }
    }

    EditHeading {
        Layout.fillWidth: true
        Layout.topMargin: 10
        visible: true
        content: "Shape"
        size: 13
        customColor: Colors.primary
    }
    ColumnLayout {
        id: drawerGroupEdgeShape
        Layout.fillWidth: true
        visible: true
        spacing: 8
        EditRow {
            visible: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                EditTextChoice {
                    Layout.fillWidth: true
                    model: BarLayout.gapPresetInfo
                    current: BarLayout.gapPresetOf(host.edgeSide)
                    onPicked: v => BarLayout.applyGapPreset(host.edgeSide, v)
                }

                EditSideRow {
                    id: fineHead
                    readonly property bool custom: BarLayout.gapPresetOf(host.edgeSide) === ""
                    readonly property bool open: host.fineOpen || fineHead.custom
                    icon: "tune"
                    label: "Fine-tune"
                    value: fineHead.custom ? "Your own mix" : ""
                    trailing: fineHead.open ? "expand_less" : "expand_more"
                    onClicked: if (!fineHead.custom) host.fineOpen = !host.fineOpen
                }

                Repeater {
                    model: fineHead.open ? [
                        { key: "edge",   label: "Distance from the screen edge", sub: "Gap between the screen and every block", min: -60, max: 40, step: 1 },
                        { key: "block",  label: "Space between blocks",          sub: "Gap between neighbours in a group", min: 0, max: 60,  step: 1 },
                        { key: "end",    label: "Space at the ends",             sub: "Inset of the first and last block", min: 0, max: 120, step: 2 },
                        { key: "fill",   label: "Fill between groups",           sub: "How much the gaps between groups fill in", min: 0, max: 100, step: 5, scale: 100 },
                        { key: "radius", label: "Corner roundness",              sub: "Shared by blocks that follow the edge", min: 0, max: 28,  step: 1, auto: -1 }
                    ] : []
                    delegate: RowLayout {
                        id: gapRow
                        required property var modelData
                        readonly property real scale: gapRow.modelData.scale ?? 1
                        readonly property real value: Number(BarLayout.edgeGaps(host.edgeSide)[gapRow.modelData.key] ?? 0) * gapRow.scale
                        readonly property bool isAuto: gapRow.modelData.auto !== undefined && gapRow.value < 0

                        Layout.fillWidth: true
                        Layout.minimumHeight: 46
                        spacing: 12

                        HoverHandler {
                            onHoveredChanged: BarLayout.hoverGap(hovered, "edges", host.edgeSide, "")
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            CustomText {
                                Layout.fillWidth: true
                                content: gapRow.modelData.label
                                elide: Text.ElideRight
                                size: 13
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: gapRow.modelData.sub
                                elide: Text.ElideRight
                                size: 11
                                customColor: Colors.surfaceVariantText
                            }
                        }
                        EditStepper {
                            Layout.fillWidth: false
                            value: gapRow.isAuto ? gapRow.modelData.min : Math.max(gapRow.modelData.min, gapRow.value)
                            from: gapRow.modelData.min
                            to: gapRow.modelData.max
                            stepSize: gapRow.modelData.step
                            canAuto: gapRow.modelData.auto !== undefined
                            isAuto: gapRow.isAuto
                            autoLabel: "Auto"
                            autoText: "Auto"
                            offValue: gapRow.modelData.key === "radius"
                                ? Math.min(gapRow.modelData.max, Math.round(Number(host.edgeCfg.radius ?? 18))) : gapRow.modelData.min
                            unit: gapRow.modelData.key === "fill" ? "%" : "px"
                            onPicked: v => BarLayout.setEdgeGaps(host.edgeSide, { [gapRow.modelData.key]: v / gapRow.scale })
                            onAutoPicked: BarLayout.setEdgeGaps(host.edgeSide, { [gapRow.modelData.key]: gapRow.modelData.auto })
                        }
                    }
                }

                RowLayout {
                    id: ownCorners
                    readonly property int count: {
                        const ids = BarLayout.edgeOverrides(host.edgeSide, "corners").map(b => b.id)
                        for (const b of BarLayout.edgeOverrides(host.edgeSide, "radius"))
                            if (ids.indexOf(b.id) < 0)
                                ids.push(b.id)
                        return ids.length
                    }
                    visible: fineHead.open && ownCorners.count > 0
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialIconSymbol {
                        content: "info"
                        iconSize: 15
                        customColor: Colors.surfaceVariantText
                    }
                    CustomText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        content: ownCorners.count + (ownCorners.count === 1 ? " block keeps its own corners" : " blocks keep their own corners")
                            + " and won't follow this"
                        size: 11
                        customColor: Colors.surfaceVariantText
                    }
                    M3Button {
                        size: "xsmall"
                        variant: "text"
                        icon: "sync"
                        label: "Make all follow"
                        onClicked: {
                            BarLayout.clearEdgeOverrides(host.edgeSide, "corners")
                            BarLayout.clearEdgeOverrides(host.edgeSide, "radius")
                        }
                    }
                }
            }
        }
    }

    EditHeading {
        Layout.fillWidth: true
        Layout.topMargin: 10
        visible: true
        content: "Size"
        size: 13
        customColor: Colors.primary
    }
    ColumnLayout {
        id: drawerGroupEdgeSize
        Layout.fillWidth: true
        visible: true
        spacing: 8
        EditRow {
            visible: true
            Repeater {
                model: [
                    { key: "height",   label: "Thickness",  min: 28, max: 80,  step: 2, auto: -9,
                      presets: [{ label: "Slim", value: 32 }, { label: "Default", value: 40 }, { label: "Roomy", value: 48 }] },
                    { key: "iconSize", label: "Icon size",  min: 16, max: 48,  step: 2, auto: 0, autoText: "Auto" },
                    { key: "radius",   label: "Corners",    min: 8,  max: 28,  step: 1, auto: -9,
                      presets: [{ label: "Soft", value: 12 }, { label: "Round", value: 20 }, { label: "Full", value: 28 }] },
                    { key: "itemGap",  label: "Item gap",   min: 0,  max: 16,  step: 1, auto: -9 },
                    { key: "blockGap", label: "Block gap",  min: 0,  max: 120, step: 8, auto: -1, autoText: "Auto" }
                ].filter(r => r.key !== "radius" && r.key !== "blockGap")

                delegate: RowLayout {
                    id: edgeRow
                    required property var modelData
                    readonly property bool canAuto: edgeRow.modelData.auto !== -9
                    readonly property real value: Number(host.edgeCfg[edgeRow.modelData.key])
                    readonly property bool isAuto: edgeRow.canAuto && edgeRow.value === edgeRow.modelData.auto

                    Layout.fillWidth: true
                    spacing: 12

                    HoverHandler {
                        onHoveredChanged: BarLayout.hoverGap(hovered, edgeRow.modelData.key, host.edgeSide, "")
                    }

                    CustomText {
                        Layout.preferredWidth: 84
                        content: edgeRow.modelData.label
                        size: 12
                    }
                    EditStepper {
                        Layout.fillWidth: true
                        value: edgeRow.isAuto ? edgeRow.modelData.min : edgeRow.value
                        from: edgeRow.modelData.min
                        to: edgeRow.modelData.max
                        stepSize: edgeRow.modelData.step
                        presets: edgeRow.modelData.presets ?? []
                        canAuto: edgeRow.canAuto
                        isAuto: edgeRow.isAuto
                        autoText: edgeRow.modelData.autoText ?? "Auto"
                        onPicked: v => {
                            if (v !== edgeRow.value)
                                BarLayout.setEdge(host.edgeSide, edgeRow.modelData.key, v)
                            BarLayout.flashGap(edgeRow.modelData.key, host.edgeSide, "")
                        }
                        onAutoPicked: {
                            BarLayout.setEdge(host.edgeSide, edgeRow.modelData.key, edgeRow.modelData.auto)
                            BarLayout.flashGap(edgeRow.modelData.key, host.edgeSide, "")
                        }
                    }
                }
            }

        }
    }

    EditHeading {
        Layout.fillWidth: true
        Layout.topMargin: 10
        visible: true
        content: "Panels"
        size: 13
        customColor: Colors.primary
    }
    ColumnLayout {
        id: drawerGroupEdgePanels
        Layout.fillWidth: true
        visible: true
        spacing: 8
        EditRow {
            visible: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                CustomText {
                    Layout.fillWidth: true
                    content: "How panels open on this edge"
                    size: 13
                    weight: 600
                    customColor: Colors.surfaceVariantText
                }
                CustomText {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    content: host.panelOverrides === 0
                        ? "Every block on this edge follows this. Select a block to give it its own style."
                        : host.panelOverrides + (host.panelOverrides === 1 ? " block uses its own style." : " blocks use their own style.")
                    size: 11
                    customColor: Colors.outline
                }
                EditTextChoice {
                    Layout.fillWidth: true
                    cols: 3
                    model: BarLayout.panelStyleInfo
                    current: host.edgePanels
                    onPicked: v => BarLayout.setEdgePanels(host.edgeSide, v)
                }
                M3Button {
                    Layout.alignment: Qt.AlignRight
                    visible: host.panelOverrides > 0
                    size: "xsmall"
                    variant: "text"
                    icon: "sync"
                    label: "Use edge style for all blocks"
                    onClicked: BarLayout.clearEdgeOverrides(host.edgeSide, "panels")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    HoverHandler {
                        onHoveredChanged: BarLayout.hoverGap(hovered, "panelGap", "", "")
                    }

                    CustomText {
                        Layout.preferredWidth: 84
                        content: "Panel gap"
                        size: 12
                    }
                    EditStepper {
                        readonly property bool own: typeof host.edgeCfg.panelGap === "number" && host.edgeCfg.panelGap >= 0
                        Layout.fillWidth: true
                        value: BarLayout.edgePanelGap(host.edgeSide)
                        from: 0
                        to: 40
                        stepSize: 2
                        canAuto: true
                        isAuto: !own
                        autoLabel: "Bar"
                        autoText: "Bar · " + Math.round(BarLayout.panelGap) + " px"
                        offValue: Math.round(BarLayout.panelGap / 2) * 2
                        onPicked: v => {
                            if (!own || v !== BarLayout.edgePanelGap(host.edgeSide))
                                BarLayout.setEdgePanelGap(host.edgeSide, v)
                            BarLayout.flashGap("panelGap", "", "")
                        }
                        onAutoPicked: {
                            BarLayout.setEdgePanelGap(host.edgeSide, null)
                            BarLayout.flashGap("panelGap", "", "")
                        }
                    }
                }
                M3Button {
                    Layout.alignment: Qt.AlignRight
                    visible: host.gapOverrides > 0
                    size: "xsmall"
                    variant: "text"
                    icon: "sync"
                    label: "Use edge gap for all blocks"
                    onClicked: BarLayout.clearEdgeOverrides(host.edgeSide, "panelGap")
                }
            }
        }
    }

    EditHeading {
        Layout.fillWidth: true
        Layout.topMargin: 10
        visible: true
        content: "Blocks"
        size: 13
        customColor: Colors.primary
    }
    ColumnLayout {
        id: drawerGroupEdgeBlocks
        Layout.fillWidth: true
        visible: true
        spacing: 8
        EditRow {
            visible: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                CustomText { Layout.fillWidth: true; content: "Add a block on this edge"; size: 13; weight: 600; customColor: Colors.surfaceVariantText }
                M3ButtonGroup {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    fillWidth: true
                    iconSize: 16
                    textSize: 12
                    model: host.edgeSide === "left" || host.edgeSide === "right"
                        ? [{ value: "left", label: "Top", icon: "add" }, { value: "center", label: "Middle", icon: "add" }, { value: "right", label: "Bottom", icon: "add" }]
                        : [{ value: "left", label: "Left", icon: "add" }, { value: "center", label: "Centre", icon: "add" }, { value: "right", label: "Right", icon: "add" }]
                    activeCheck: function(v) { return false }
                    onSegmentClicked: function(v) { BarLayout.addBlock(v, host.edgeSide) }
                }
            }
        }
    }
}
