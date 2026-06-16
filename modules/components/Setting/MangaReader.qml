import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
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

            // ── Page header ──────────────────────────────────────
            RowLayout {
                spacing: 10
                MaterialIconSymbol { content: "menu_book"; iconSize: 20 }
                CustomText { content: "Manga Reader"; size: 20; customColor: Colors.primary }
            }

            // ── Content ──────────────────────────────────────────
            CustomText { Layout.topMargin: 24; content: "Content"; size: 13; customColor: Colors.primary }

            CustomCard {
                Layout.topMargin: 6
                autoRadius: false; topRadius: 20; bottomRadius: 20

                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        spacing: 2
                        CustomText { content: "Filter Adult Content"; size: 14 }
                        CustomText { content: "Filters out 18+ titles from search results"; size: 12; customColor: Colors.outline }
                    }
                    Item { Layout.fillWidth: true }
                    CustomToogle {
                        isToggleOn: SettingsConfig.manga.filterAdult
                        onToggled: (state) => SettingsConfig.manga = Object.assign({}, SettingsConfig.manga, { filterAdult: state })
                    }
                }
            }

            // ── Reader ───────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Reader"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.topMargin: 6
                Layout.fillWidth: true
                spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Scroll Speed"; size: 14 }
                            CustomText { content: "Higher values scroll faster per swipe"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            val: SettingsConfig.manga.scrollSpeed
                            inc: 1; limit: 30
                            onValChanged: SettingsConfig.manga = Object.assign({}, SettingsConfig.manga, { scrollSpeed: val })
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Page Spacing"; size: 14 }
                            CustomText { content: "Vertical gap between consecutive pages"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            val: SettingsConfig.manga.pageSpacing
                            inc: 2; limit: 60
                            onValChanged: SettingsConfig.manga = Object.assign({}, SettingsConfig.manga, { pageSpacing: val })
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Preload Buffer"; size: 14 }
                            CustomText { content: "More pixels reduces load-in but uses more memory"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            val: SettingsConfig.manga.preloadPages
                            inc: 500; limit: 8000
                            onValChanged: SettingsConfig.manga = Object.assign({}, SettingsConfig.manga, { preloadPages: val })
                        }
                    }
                }
            }

            // ── Source ───────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Source"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.topMargin: 6
                Layout.fillWidth: true
                spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Default Site"; size: 14 }
                            CustomText { content: "Library searched when opening the reader"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        ButtonGroup {
                            model: [
                                { value: "comix",       label: "Comix.to",    icon: "public"   },
                                { value: "weebcentral", label: "WEEBCentral", icon: "language" }
                            ]
                            activeCheck: function(v) { return SettingsConfig.manga.defaultSite === v }
                            onSegmentClicked: function(v) {
                                SettingsConfig.manga = Object.assign({}, SettingsConfig.manga, { defaultSite: v })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        spacing: 8
                        MaterialIconSymbol { content: "info"; iconSize: 16; customColor: Colors.outline }
                        CustomText {
                            Layout.fillWidth: true
                            content: "Switch sources anytime from the manga panel. This sets the default for the next launch."
                            size: 12; customColor: Colors.outline
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
