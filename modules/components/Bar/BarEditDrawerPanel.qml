import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.Edit

ColumnLayout {
    id: panelSection
    required property Item host
    readonly property bool isSection: true
    Layout.fillWidth: true
    visible: (panelSizeSection.spec !== null && !!host.editor && host.editor.panelStage)
        || (host.itemPage && !host.dashPage && BarLayout.hasOpenChoice(host.selected))
    spacing: 8

    EditHeading {
        Layout.fillWidth: true
        Layout.topMargin: 10
        visible: panelSizeSection.spec !== null && !!host.editor && host.editor.panelStage
        content: "Panel size"
        size: 13
        customColor: Colors.primary
    }
    ColumnLayout {
        id: drawerGroup2
        Layout.fillWidth: true
        visible: panelSizeSection.spec !== null && !!host.editor && host.editor.panelStage
        spacing: 8
        EditRow {
            visible: true
            ColumnLayout {
                id: panelSizeSection
                readonly property string kind: host.dashPage ? "" : BarLayout.panelFor(host.selected)
                readonly property var spec: BarLayout.panelSpecs[panelSizeSection.kind] ?? null
                readonly property bool custom: panelSizeSection.kind !== ""
                    && BarLayout.panelCustom(panelSizeSection.kind)
                readonly property real roomH: Math.max(0, Window.height - Appearance.size.barHeight - 16)

                Layout.fillWidth: true
                visible: panelSizeSection.spec !== null && !!host.editor && host.editor.panelStage
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4

                    CustomText {
                        Layout.fillWidth: true
                        content: "Panel size"
                        size: 13
                        customColor: Colors.primary
                    }
                    M3Button {
                        variant: "text"
                        icon: "restart_alt"
                        label: "Default size"
                        enabledButton: panelSizeSection.custom
                        onClicked: BarLayout.clearPanelSize(panelSizeSection.kind)
                    }
                }

                CustomText {
                    Layout.fillWidth: true
                    visible: host.selected !== "dashboard"
                    wrapMode: Text.WordWrap
                    content: "The " + (panelSizeSection.spec ? panelSizeSection.spec.label.toLowerCase() : "")
                        + " panel is open as a live preview. Drag its edges or use the sliders to resize it."
                    size: 12
                    customColor: Colors.outline
                }

                Repeater {
                    model: panelSizeSection.spec && !panelSizeSection.spec.fitOnly ? [
                        { key: "w", label: "Width",  min: panelSizeSection.spec.minW, auto: false,
                          max: panelSizeSection.spec.maxW },
                        { key: "h", label: "Height", min: panelSizeSection.spec.minH, auto: panelSizeSection.spec.defH < 0,
                          max: Math.max(panelSizeSection.spec.minH,
                                        Math.min(panelSizeSection.spec.maxH, panelSizeSection.roomH)) }
                    ] : []

                    delegate: RowLayout {
                        id: panelRow
                        required property var modelData
                        readonly property string kind: panelSizeSection.kind
                        readonly property real value: panelRow.modelData.key === "w" ? BarLayout.panelW(panelRow.kind)
                                                                                     : BarLayout.panelH(panelRow.kind)
                        readonly property int offset: panelRow.modelData.auto ? 1 : 0
                        readonly property bool isAuto: panelRow.modelData.auto && panelRow.value < 0
                        readonly property int step: 10

                        Layout.fillWidth: true
                        spacing: 12

                        CustomText {
                            Layout.preferredWidth: 110
                            content: panelRow.modelData.label
                            size: 12
                        }
                        EditStepper {
                            Layout.fillWidth: true
                            value: panelRow.isAuto ? panelRow.modelData.min : Math.round(panelRow.value)
                            from: panelRow.modelData.min
                            to: panelRow.modelData.max
                            stepSize: panelRow.step
                            canAuto: !!panelRow.modelData.auto
                            isAuto: panelRow.isAuto
                            onPicked: v => {
                                const k = panelRow.kind
                                if (panelRow.modelData.key === "w")
                                    BarLayout.setPanelSize(k, v, BarLayout.panelH(k))
                                else
                                    BarLayout.setPanelSize(k, BarLayout.panelW(k), v)
                            }
                            onAutoPicked: {
                                const k = panelRow.kind
                                BarLayout.setPanelSize(k, BarLayout.panelW(k), -1)
                            }
                        }
                    }
                }
            }
        }
    }

    EditHeading {
        Layout.fillWidth: true
        Layout.topMargin: 10
        visible: drawerGroupOpen.visible
        content: "Its panel"
        size: 13
        customColor: Colors.primary
    }
    ColumnLayout {
        id: drawerGroupOpen
        Layout.fillWidth: true
        visible: host.itemPage && !host.dashPage && BarLayout.hasOpenChoice(host.selected)
        spacing: 8
        EditRow {
            visible: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                CustomText {
                    Layout.fillWidth: true
                    content: "Open the panel with"
                    size: 13
                }
                M3ButtonGroup {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    fillWidth: true
                    iconSize: 16
                    textSize: 12
                    activeColor: Colors.secondaryContainer
                    activeTextColor: Colors.secondaryContainerText
                    model: [
                        { value: "click", label: "Click", icon: "ads_click" },
                        { value: "hover", label: "Hover", icon: "arrow_selector_tool" }
                    ]
                    activeCheck: function(v) { return BarLayout.openOn(host.selected) === v }
                    onSegmentClicked: function(v) { BarLayout.setOpenOn(host.selected, v) }
                }
                CustomText {
                    Layout.fillWidth: true
                    visible: BarLayout.openOn(host.selected) === "hover"
                    wrapMode: Text.WordWrap
                    content: "Pointing at the item opens its panel and leaving closes it. A click still keeps it open."
                    size: 11
                    customColor: Colors.outline
                }
            }
        }
    }
}
