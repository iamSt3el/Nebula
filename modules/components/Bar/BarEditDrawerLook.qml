import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.Edit
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

ColumnLayout {
    id: drawerGroup3
    required property Item host
    Layout.fillWidth: true
    visible: host.sidePage === "look"
    spacing: 8
    EditRow {
        visible: host.iconSizable
        RowLayout {
            Layout.fillWidth: true
            visible: host.iconSizable
            spacing: 12

            CustomText {
                Layout.preferredWidth: 60
                content: "Size"
                size: 12
            }
            EditStepper {
                Layout.fillWidth: true
                value: host.itemIconSize > 0 ? Math.round(host.itemIconSize) : 18
                from: 10
                to: 24
                stepSize: 1
                offValue: 18
                canAuto: true
                isAuto: !(host.itemIconSize > 0)
                onPicked: v => BarLayout.setItemStyle(host.selected, "iconSize", v)
                onAutoPicked: BarLayout.setItemStyle(host.selected, "iconSize", 0)
            }
        }
    }
    EditRow {
        visible: !host.chromeless
        ColumnLayout {
            Layout.fillWidth: true
            visible: !host.chromeless
            spacing: 8

            CustomText { Layout.fillWidth: true; content: "Tint"; size: 13; weight: 600; customColor: Colors.surfaceVariantText }

            EditChoice {
                Layout.fillWidth: true
                maxPerRow: 5
                minCell: 76
                choices: host.tintChoices
                value: host.itemTint
                onPicked: v => BarLayout.setItemStyle(host.selected, "tint", v)
            }
        }
    }
    EditRow {
        visible: !host.chromeless && host.chipStyled && !host.ownShape
        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 100000
            visible: !host.chromeless && host.chipStyled && !host.ownShape
            spacing: 8

            CustomText {
                Layout.fillWidth: true
                content: "Shape"
                size: 12
            }

            CustomText {
                Layout.fillWidth: true
                visible: !host.iconItem
                wrapMode: Text.WordWrap
                content: "Single-icon items only."
                size: 12
                customColor: Colors.outline
            }

            RowLayout {
                Layout.fillWidth: true
                visible: host.iconItem
                spacing: 10

                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 12
                    color: Colors.surfaceContainerHigh

                    MaterialShapes.ShapeCanvas {
                        anchors.centerIn: parent
                        visible: host.itemShape !== "none" && host.itemShape !== ""
                        width: 26
                        height: 26
                        roundedPolygon: visible ? ShapeLibrary.get(host.itemShape) : ShapeLibrary.get("circle")
                        color: Colors.primary
                    }
                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        visible: host.itemShape === "none" || host.itemShape === ""
                        content: "crop_square"
                        iconSize: 22
                        customColor: Colors.surfaceVariantText
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 100000
                    spacing: 0
                    CustomText {
                        content: host.shapeName(host.itemShape)
                        size: 13
                        weight: 600
                    }
                    CustomText {
                        content: host.itemShape === "none" || host.itemShape === "" ? "Rounded rectangle" : "Material shape"
                        size: 11
                        customColor: Colors.outline
                    }
                }

                EditPill {
                    icon: "interests"
                    label: "Choose"
                    tonal: true
                    lit: false
                    box: 36
                    onClicked: host.sidePage = "itemshape"
                }
            }
        }
    }
    EditRow {
        visible: host.rotatable
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            CustomText {
                Layout.preferredWidth: 60
                content: "Rotate"
                size: 12
            }
            EditStepper {
                readonly property real angle: BarLayout.itemStyle(host.selected, "rotate", 0)
                Layout.fillWidth: true
                value: angle
                from: 0
                to: 345
                stepSize: 15
                unit: "°"
                onPicked: v => {
                    if (v !== angle)
                        BarLayout.setItemStyle(host.selected, "rotate", v)
                }
            }
        }
    }
    EditRow {
        visible: !host.chromeless && (host.chipStyled || host.groupPage)
        Repeater {
            model: [
                { key: "radius", label: "Radius",    min: 0, max: 24,  step: 1, def: -1, auto: "Pill", shapeLabel: "",        tintOnly: true,  groupOnly: false },
                { key: "pad",    label: "Padding",   min: 0, max: 24,  step: 2, def: 10, auto: "",     shapeLabel: "Padding", tintOnly: true,  groupOnly: false },
                { key: "gap",    label: "Spacing",   min: 0, max: 20,  step: 2, def: -1, auto: "Auto", shapeLabel: "Spacing", tintOnly: false, groupOnly: true },
                { key: "minW",   label: "Min width", min: 0, max: 160, step: 8, def: 0,  auto: "",     shapeLabel: "",        tintOnly: true,  groupOnly: false },
                { key: "minH",   label: "Height",    min: 0, max: 56,  step: 2, def: 0,  auto: "",     shapeLabel: "Size",    tintOnly: false, groupOnly: false }
            ]

            delegate: RowLayout {
                id: chipRow
                required property var modelData
                readonly property bool hasAuto: chipRow.modelData.auto !== ""
                readonly property real value: BarLayout.itemStyle(host.selected,
                                                                  chipRow.modelData.key,
                                                                  chipRow.modelData.def)
                readonly property int off: chipRow.hasAuto ? 1 : 0
                readonly property bool isAuto: chipRow.hasAuto && chipRow.value < 0

                Layout.fillWidth: true
                visible: !host.chromeless
                    && (host.chipStyled
                        || (!chipRow.modelData.tintOnly && host.groupPage))
                    && (!chipRow.modelData.groupOnly || host.groupPage)
                    && (!host.shapedChip || chipRow.modelData.shapeLabel !== "")
                spacing: 12

                CustomText {
                    Layout.preferredWidth: 60
                    content: host.shapedChip && chipRow.modelData.shapeLabel !== ""
                             ? chipRow.modelData.shapeLabel : chipRow.modelData.label
                    size: 12
                }
                EditStepper {
                    Layout.fillWidth: true
                    value: chipRow.isAuto ? Math.max(chipRow.modelData.min, chipRow.modelData.def) : chipRow.value
                    from: chipRow.modelData.min
                    to: chipRow.modelData.max
                    stepSize: chipRow.modelData.step
                    presets: chipRow.modelData.key === "minW" ? [{ label: "Hug", value: 0 }] : []
                    canAuto: chipRow.hasAuto
                    isAuto: chipRow.isAuto
                    autoLabel: chipRow.hasAuto ? chipRow.modelData.auto : "Auto"
                    autoText: chipRow.hasAuto ? chipRow.modelData.auto : "Auto"
                    offValue: chipRow.modelData.key === "radius" ? 12 : chipRow.modelData.key === "gap" ? 6 : chipRow.modelData.min
                    onPicked: v => {
                        if (v !== chipRow.value)
                            BarLayout.setItemStyle(host.selected, chipRow.modelData.key, v)
                    }
                    onAutoPicked: BarLayout.setItemStyle(host.selected, chipRow.modelData.key, -1)
                }
            }
        }
    }
}
