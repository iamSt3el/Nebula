import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        contentWidth: width
        clip: true

        ColumnLayout {
            id: column
            width: parent.width
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            anchors.topMargin: 5
            spacing: 0

            // ── Page header ──────────────────────────────────────────────
            RowLayout {
                spacing: 10
                MaterialIconSymbol { content: "brush"; iconSize: 20 }
                CustomText { content: "Appearance"; size: 20; customColor: Colors.primary }
            }

            // ── Fonts ────────────────────────────────────────────────────
            CustomText { Layout.topMargin: 24; content: "Fonts"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Body Font"; size: 14 }
                            CustomText { content: "Applied globally to all UI text"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 180
                            color: Colors.surfaceContainerHighest
                            currentVal: SettingsConfig.general.defaultFont
                            list: Settings.fonts
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.general.defaultFont)
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { defaultFont: currentVal })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Display Font"; size: 14 }
                            CustomText { content: "Used in clocks, date widgets, and headings"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 180
                            color: Colors.surfaceContainerHighest
                            currentVal: SettingsConfig.general.displayFont ?? "Titan One"
                            list: Settings.displayFonts
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== (SettingsConfig.general.displayFont ?? "Titan One"))
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { displayFont: currentVal })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Font Size"; size: 14 }
                            CustomText { content: "Scale applied to all text"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        M3Slider {
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 30
                            stepCount: 4
                            stepLabels: ["compact", "normal", "large", "xlarge"]
                            currentStep: ({ "compact": 0, "normal": 1, "large": 2, "xlarge": 3 })[SettingsConfig.general.fontScale ?? "normal"] ?? 1
                            onStepChanged: step => {
                                var val = ["compact", "normal", "large", "xlarge"][step]
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { fontScale: val })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Font Weight"; size: 14 }
                            CustomText { content: "Default weight for body text"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        M3Slider {
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 30
                            stepCount: 6
                            stepLabels: ["thin", "regular", "medium", "semibold", "bold", "extrabold"]
                            currentStep: ({ "thin": 0, "regular": 1, "medium": 2, "semibold": 3, "bold": 4, "extrabold": 5 })[SettingsConfig.general.fontWeight ?? "extrabold"] ?? 5
                            onStepChanged: step => {
                                var val = ["thin", "regular", "medium", "semibold", "bold", "extrabold"][step]
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { fontWeight: val })
                            }
                        }
                    }
                }
            }

            // ── Bar ──────────────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Bar"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    id: barModeCard
                    autoRadius: false; topRadius: 20
                    bottomRadius: pillMarginCard.visible ? 5 : 20

                    readonly property string currentBarMode: SettingsConfig.general.barMode
                        ?? (SettingsConfig.general.flatBarMode === false ? "stepped" : "flat")

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Bar Mode"; size: 14 }
                            CustomText { content: "Shape of the top bar"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        ButtonGroup {
                            model: [
                                { value: "stepped", label: "Stepped", icon: "view_agenda" },
                                { value: "flat",    label: "Flat",    icon: "remove" },
                                { value: "pill",    label: "Pill",    icon: "circle" }
                            ]
                            activeCheck: function(value) { return barModeCard.currentBarMode === value }
                            onSegmentClicked: function(value) {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { barMode: value })
                            }
                        }
                    }
                }

                CustomCard {
                    id: pillMarginCard
                    visible: barModeCard.currentBarMode === "pill"
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Top Margin"; size: 14 }
                            CustomText { content: "Gap between pill and top screen edge"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            inc: 1; limit: 30
                            value: SettingsConfig.general.pillMargin ?? 6
                            onValChanged: {
                                if (val !== (SettingsConfig.general.pillMargin ?? 6))
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { pillMargin: val })
                            }
                        }
                    }
                }

                CustomCard {
                    visible: barModeCard.currentBarMode === "pill"
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Left Margin"; size: 14 }
                            CustomText { content: "Gap between pill and left screen edge"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            inc: 1; limit: 60
                            value: SettingsConfig.general.pillLeftMargin ?? 6
                            onValChanged: {
                                if (val !== (SettingsConfig.general.pillLeftMargin ?? 6))
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { pillLeftMargin: val })
                            }
                        }
                    }
                }

                CustomCard {
                    visible: barModeCard.currentBarMode === "pill"
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Right Margin"; size: 14 }
                            CustomText { content: "Gap between pill and right screen edge"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            inc: 1; limit: 60
                            value: SettingsConfig.general.pillRightMargin ?? 6
                            onValChanged: {
                                if (val !== (SettingsConfig.general.pillRightMargin ?? 6))
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { pillRightMargin: val })
                            }
                        }
                    }
                }
            }

            // ── Window Gaps ──────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Window Gaps"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Top Extra"; size: 14 }

                            CustomText { content: "Added on top of bar height (auto-calculated)"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            inc: 1; limit: 100
                            value: SettingsConfig.general.gapTop ?? 0
                            onValChanged: {
                                if (val !== (SettingsConfig.general.gapTop ?? 0))
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { gapTop: val })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Bottom"; size: 14 }
                            CustomText { content: "Gap from bottom screen edge"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            inc: 1; limit: 100
                            value: SettingsConfig.general.gapBottom ?? 5
                            onValChanged: {
                                if (val !== (SettingsConfig.general.gapBottom ?? 5))
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { gapBottom: val })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Left"; size: 14 }
                            CustomText { content: "Gap from left screen edge"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            inc: 1; limit: 100
                            value: SettingsConfig.general.gapLeft ?? 5
                            onValChanged: {
                                if (val !== (SettingsConfig.general.gapLeft ?? 5))
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { gapLeft: val })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Right"; size: 14 }
                            CustomText { content: "Gap from right screen edge"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            inc: 1; limit: 100
                            value: SettingsConfig.general.gapRight ?? 5
                            onValChanged: {
                                if (val !== (SettingsConfig.general.gapRight ?? 5))
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { gapRight: val })
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
