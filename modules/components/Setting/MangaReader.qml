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

            // ── Header ───────────────────────────────────────────────────────
            RowLayout {
                spacing: 10
                MaterialIconSymbol {
                    content: "menu_book"
                    iconSize: 20
                }
                CustomText {
                    content: "Manga Reader"
                    size: 20
                    color: Colors.primary
                }
            }

            // ── Content ──────────────────────────────────────────────────────
            CustomText {
                Layout.topMargin: 30
                content: "Content"
                size: 18
                color: Colors.primary
            }
            CustomText {
                content: "Control what types of content appear in search results"
                size: 14
                color: Colors.outline
            }

            // Filter Adult Content
            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 0
                    CustomText {
                        content: "Filter Adult Content"
                        size: 16
                    }
                    CustomText {
                        content: "Filters out 18+ titles from search results"
                        size: 13
                        color: Colors.outline
                    }
                }
                Item { Layout.fillWidth: true }
                CustomToogle {
                    isToggleOn: SettingsConfig.manga.filterAdult
                    onToggled: (state) => SettingsConfig.manga = Object.assign({}, SettingsConfig.manga, {filterAdult: state})
                }
            }

            Rectangle {
                Layout.topMargin: 16
                Layout.bottomMargin: 16
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.outline
            }

            // ── Reader ───────────────────────────────────────────────────────
            CustomText {
                content: "Reader"
                size: 18
                color: Colors.primary
            }
            CustomText {
                content: "Tune scroll behavior, spacing, and image preloading"
                size: 14
                color: Colors.outline
            }

            // Scroll Speed
            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 0
                    CustomText {
                        content: "Scroll Speed"
                        size: 16
                    }
                    CustomText {
                        content: "Higher values scroll faster per swipe"
                        size: 13
                        color: Colors.outline
                    }
                }
                Item { Layout.fillWidth: true }
                CustomSpinBox {
                    val: SettingsConfig.manga.scrollSpeed
                    inc: 1
                    limit: 30
                    onValChanged: SettingsConfig.manga = Object.assign({}, SettingsConfig.manga, {scrollSpeed: val})
                }
            }

            // Page Spacing
            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 0
                    CustomText {
                        content: "Page Spacing"
                        size: 16
                    }
                    CustomText {
                        content: "Vertical gap between consecutive pages"
                        size: 13
                        color: Colors.outline
                    }
                }
                Item { Layout.fillWidth: true }
                CustomSpinBox {
                    val: SettingsConfig.manga.pageSpacing
                    inc: 2
                    limit: 60
                    onValChanged: SettingsConfig.manga = Object.assign({}, SettingsConfig.manga, {pageSpacing: val})
                }
            }

            // Preload Buffer
            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 0
                    CustomText {
                        content: "Preload Buffer"
                        size: 16
                    }
                    CustomText {
                        content: "More pixels reduces load-in but uses more memory"
                        size: 13
                        color: Colors.outline
                    }
                }
                Item { Layout.fillWidth: true }
                CustomSpinBox {
                    val: SettingsConfig.manga.preloadPages
                    inc: 500
                    limit: 8000
                    onValChanged: SettingsConfig.manga = Object.assign({}, SettingsConfig.manga, {preloadPages: val})
                }
            }

            Rectangle {
                Layout.topMargin: 16
                Layout.bottomMargin: 16
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.outline
            }

            // ── Source ───────────────────────────────────────────────────────
            CustomText {
                content: "Source"
                size: 18
                color: Colors.primary
            }
            CustomText {
                content: "Sets the library searched when opening the reader"
                size: 14
                color: Colors.outline
            }

            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true
                spacing: 10

                // Comix button
                Rectangle {
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: siteComixRow.implicitWidth + 24
                    radius: 10
                    color: SettingsConfig.manga.defaultSite === "comix"
                           ? Colors.primary
                           : Colors.surfaceContainerHigh

                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        id: siteComixRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIconSymbol {
                            content: "public"
                            iconSize: 16
                            color: SettingsConfig.manga.defaultSite === "comix"
                                   ? Colors.primaryText : Colors.surfaceVariantText
                        }
                        CustomText {
                            content: "Comix.to"
                            size: 13
                            color: SettingsConfig.manga.defaultSite === "comix"
                                   ? Colors.primaryText : Colors.surfaceVariantText
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsConfig.manga = Object.assign({}, SettingsConfig.manga, {defaultSite: "comix"})
                    }
                }

                // WEEBCentral button
                Rectangle {
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: siteWeebRow.implicitWidth + 24
                    radius: 10
                    color: SettingsConfig.manga.defaultSite === "weebcentral"
                           ? Colors.primary
                           : Colors.surfaceContainerHigh

                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        id: siteWeebRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIconSymbol {
                            content: "language"
                            iconSize: 16
                            color: SettingsConfig.manga.defaultSite === "weebcentral"
                                   ? Colors.primaryText : Colors.surfaceVariantText
                        }
                        CustomText {
                            content: "WEEBCentral"
                            size: 13
                            color: SettingsConfig.manga.defaultSite === "weebcentral"
                                   ? Colors.primaryText : Colors.surfaceVariantText
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsConfig.manga = Object.assign({}, SettingsConfig.manga, {defaultSite: "weebcentral"})
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // Info note about default site
            Rectangle {
                Layout.topMargin: 12
                Layout.fillWidth: true
                Layout.preferredHeight: noteCol.implicitHeight + 16
                radius: 10
                color: Colors.surfaceContainer

                ColumnLayout {
                    id: noteCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        spacing: 6
                        MaterialIconSymbol {
                            content: "info"
                            iconSize: 15
                            color: Colors.outline
                        }
                        CustomText {
                            content: "Default site"
                            size: 12
                            color: Colors.outline
                        }
                    }
                    CustomText {
                        Layout.fillWidth: true
                        content: "This sets the active source the next time the app launches. Switch sources anytime from the manga panel."
                        size: 12
                        color: Colors.outline
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Rectangle {
                Layout.topMargin: 16
                Layout.bottomMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.outline
            }
        }
    }
}
