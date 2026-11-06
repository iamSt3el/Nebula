import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.Edit

ColumnLayout {
    id: generalPage
    required property Item host
    Layout.fillWidth: true
    spacing: 12
    visible: !host.itemPage && host.tab === "general"

    EditHeading {
        Layout.fillWidth: true
        Layout.topMargin: 10
        visible: true
        content: "Screen border"
        size: 13
        customColor: Colors.primary
    }
    ColumnLayout {
        id: drawerGroupBorder
        Layout.fillWidth: true
        visible: true
        spacing: 8
        EditRow {
            visible: true
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 100000
                    spacing: 1

                    CustomText { content: "Border around the screen"; size: 13 }
                    CustomText {
                        content: "A frame in the bar colour; the bar and panels curve into it"
                        size: 11
                        customColor: Colors.outline
                    }
                }

                CustomToogle {
                    isToggleOn: BarLayout.screenBorder.on === true
                    onToggled: state => BarLayout.setBorder({ on: state })
                }
            }
        }
        EditRow {
            visible: BarLayout.screenBorder.on === true
            Repeater {
                model: [
                    { key: "size",   label: "Thickness",     min: 2, max: 32, step: 2 },
                    { key: "radius", label: "Corner radius", min: 0, max: 40, step: 2 }
                ]

                delegate: RowLayout {
                    id: borderRow
                    required property var modelData
                    readonly property real value: Number(BarLayout.screenBorder[borderRow.modelData.key])

                    Layout.fillWidth: true
                    spacing: 12

                    CustomText {
                        Layout.preferredWidth: 110
                        content: borderRow.modelData.label
                        size: 12
                    }
                    EditStepper {
                        Layout.fillWidth: true
                        value: borderRow.value
                        from: borderRow.modelData.min
                        to: borderRow.modelData.max
                        stepSize: borderRow.modelData.step
                        onPicked: v => {
                            const o = {}
                            o[borderRow.modelData.key] = v
                            BarLayout.setBorder(o)
                        }
                    }
                }
            }
        }
        EditRow {
            visible: BarLayout.screenBorder.on === true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                CustomText { Layout.fillWidth: true; content: "Sides"; size: 13; weight: 600; customColor: Colors.surfaceVariantText }
                M3ButtonGroup {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    fillWidth: true
                    iconSize: 16
                    textSize: 12
                    activeColor: Colors.secondaryContainer
                    activeTextColor: Colors.secondaryContainerText
                    model: [
                        { value: "top",    label: "Top",    icon: "border_top" },
                        { value: "bottom", label: "Bottom", icon: "border_bottom" },
                        { value: "left",   label: "Left",   icon: "border_left" },
                        { value: "right",  label: "Right",  icon: "border_right" }
                    ]
                    activeCheck: function(value) { return BarLayout.screenBorder[value] !== false }
                    onSegmentClicked: function(value) {
                        const o = {}
                        o[value] = BarLayout.screenBorder[value] === false
                        BarLayout.setBorder(o)
                    }
                }
            }
        }
    }

    EditHeading {
        Layout.fillWidth: true
        Layout.topMargin: 10
        visible: true
        content: "Shadow"
        size: 13
        customColor: Colors.primary
    }
    ColumnLayout {
        id: drawerGroupShadow
        Layout.fillWidth: true
        visible: true
        spacing: 8
        EditRow {
            visible: true
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 100000
                    spacing: 1

                    CustomText { content: "Shadow under the bar"; size: 13 }
                    CustomText {
                        content: "A soft shadow around every edge, its panels and the border"
                        size: 11
                        customColor: Colors.outline
                    }
                }

                CustomToogle {
                    isToggleOn: BarLayout.barShadow.on === true
                    onToggled: state => BarLayout.setShadow({ on: state })
                }
            }
        }
        EditRow {
            visible: BarLayout.barShadow.on === true
            ColumnLayout {
                Layout.fillWidth: true
                visible: BarLayout.barShadow.on === true
                spacing: 8

                CustomText { Layout.fillWidth: true; content: "Style"; size: 12 }

                EditChoice {
                    Layout.fillWidth: true
                    maxPerRow: 5
                    minCell: 64
                    choices: BarLayout.shadowPresets
                    value: BarLayout.shadowPreset
                    onPicked: v => BarLayout.applyShadowPreset(v)
                }

                CustomText { Layout.fillWidth: true; content: "Colour"; size: 12 }

                EditChoice {
                    Layout.fillWidth: true
                    maxPerRow: 2
                    minCell: 64
                    choices: [
                        { value: false, label: "Black" },
                        { value: true,  label: "Theme tint" }
                    ]
                    value: BarLayout.barShadow.tint === true
                    onPicked: v => BarLayout.setShadow({ tint: v })
                }
            }
        }
        EditRow {
            visible: BarLayout.barShadow.on === true
            Repeater {
                model: [
                    { key: "size",     label: "Size",     min: 4, max: 48,  step: 2 },
                    { key: "strength", label: "Strength", min: 0, max: 100, step: 5 },
                    { key: "offset",   label: "Offset",   min: 0, max: 16,  step: 1 },
                    { key: "contact",  label: "Contact",  min: 0, max: 100, step: 5 }
                ]

                delegate: RowLayout {
                    id: shadowRow
                    required property var modelData
                    readonly property real value: Number(BarLayout.barShadow[shadowRow.modelData.key])

                    Layout.fillWidth: true
                    spacing: 12

                    CustomText {
                        Layout.preferredWidth: 110
                        content: shadowRow.modelData.label
                        size: 12
                    }
                    EditStepper {
                        Layout.fillWidth: true
                        value: shadowRow.value
                        from: shadowRow.modelData.min
                        to: shadowRow.modelData.max
                        stepSize: shadowRow.modelData.step
                        onPicked: v => {
                            const o = {}
                            o[shadowRow.modelData.key] = v
                            BarLayout.setShadow(o)
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
        id: drawerGroupPanels
        Layout.fillWidth: true
        visible: true
        spacing: 8
        EditRow {
            visible: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    HoverHandler {
                        onHoveredChanged: BarLayout.hoverGap(hovered, "panelGap", "", "")
                    }

                    CustomText {
                        Layout.preferredWidth: 110
                        content: "Panel gap"
                        size: 12
                    }
                    EditStepper {
                        Layout.fillWidth: true
                        value: BarLayout.panelGap
                        from: 0
                        to: 40
                        stepSize: 2
                        onPicked: v => {
                            if (v !== BarLayout.panelGap)
                                BarLayout.setPanelGap(v)
                            BarLayout.flashGap("panelGap", "", "")
                        }
                    }
                }
                CustomText {
                    Layout.fillWidth: true
                    content: "Space between floating or merged panels and their bar, and beside blocks on the side edges. Changing it resets every edge and block to this gap."
                    size: 11
                    wrapMode: Text.WordWrap
                    customColor: Colors.outline
                }
            }
        }
    }

    EditHeading {
        Layout.fillWidth: true
        Layout.topMargin: 10
        visible: true
        content: "Editor mode"
        size: 13
        customColor: Colors.primary
    }
    ColumnLayout {
        id: drawerGroupEditMode
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
                    content: "Choose how the bar and widget editor opens"
                    size: 11
                    customColor: Colors.outline
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
                        { value: "panel",   label: "In-bar panel",        icon: "dock_to_bottom" },
                        { value: "overlay", label: "Fullscreen overlay",  icon: "fullscreen" }
                    ]
                    activeCheck: function(value) { return (SettingsConfig.general.editMode ?? "panel") === value }
                    onSegmentClicked: function(value) {
                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, { editMode: value })
                    }
                }
            }
        }
    }

    BarEditDrawerPins {
        host: generalPage.host
    }
}
