import Quickshell
import Quickshell.Widgets
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
                MaterialIconSymbol { content: "widgets"; iconSize: 20 }
                CustomText { content: "Widgets"; size: 20; customColor: Colors.primary }
            }

            // ── Widget Screen ────────────────────────────────────────────
            CustomText { Layout.topMargin: 24; content: "Widget Screen"; size: 13; customColor: Colors.primary }

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
                            CustomText { content: "Circular Music Player"; size: 14 }
                            CustomText { content: "Floating circular player on the desktop"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.widgets.showCircularMusicPlayer ?? true
                            onToggled: function(state) {
                                SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { showCircularMusicPlayer: state })
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
                            CustomText { content: "Clock"; size: 14 }
                            CustomText { content: "Large digital clock widget on the desktop"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.widgets.showClock ?? false
                            onToggled: function(state) {
                                SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { showClock: state })
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
                            CustomText { content: "Date Widget"; size: 14 }
                            CustomText { content: "Compact date card with week indicator"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.widgets.showDateWidget ?? false
                            onToggled: function(state) {
                                SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { showDateWidget: state })
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
                            CustomText { content: "Style"; size: 14 }
                            CustomText { content: "Default · Calendar · Pill · Split · Bold · Ghost · Accent · Inline"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 140
                            color: Colors.surfaceContainerHighest
                            currentVal: SettingsConfig.widgets.dateWidgetStyle ?? "default"
                            list: [{ name: "default" }, { name: "calendar" }, { name: "pill" }, { name: "split" }, { name: "bold" }, { name: "ghost" }, { name: "accent" }, { name: "inline" }]
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== (SettingsConfig.widgets.dateWidgetStyle ?? "default"))
                                    SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { dateWidgetStyle: currentVal })
                            }
                        }
                    }
                }
            }

            // ── Analog Clock ─────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Analog Clock"; size: 13; customColor: Colors.primary }

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
                            CustomText { content: "Show Analog Clock"; size: 14 }
                            CustomText { content: "Analog clock widget on the desktop"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.widgets.showAnalogClock ?? false
                            onToggled: function(state) {
                                SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { showAnalogClock: state })
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
                            CustomText { content: "Style"; size: 14 }
                            CustomText { content: "Classic · Minimal · Shape"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 120
                            color: Colors.surfaceContainerHighest
                            currentVal: SettingsConfig.widgets.analogClockStyle ?? "classic"
                            list: [{ name: "classic" }, { name: "minimal" }, { name: "shape" }]
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== (SettingsConfig.widgets.analogClockStyle ?? "classic"))
                                    SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { analogClockStyle: currentVal })
                            }
                        }
                    }
                }
            }

            // ── Music Visualizer ─────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Music Visualizer"; size: 13; customColor: Colors.primary }

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
                            CustomText { content: "Visualizer"; size: 14 }
                            CustomText { content: "Display audio bars alongside the music player"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.general.musicVisOn
                            onToggled: function(state) {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { musicVisOn: state })
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
                            CustomText { content: "Bar Count"; size: 14 }
                            CustomText { content: "Number of frequency bands to render"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            value: SettingsConfig.general.musicVisBars ?? 60
                            onValChanged: {
                                if (val !== value)
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { musicVisBars: val })
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
