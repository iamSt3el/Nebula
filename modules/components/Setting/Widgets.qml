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

    // ── Reusable section header ───────────────────────────────────────────
    component SectionLabel: CustomText {
        Layout.topMargin: 20
        size: 13
        customColor: Colors.primary
    }

    // ── Toggle row inside a card (no style picker) ───────────────────────
    component ToggleCard: CustomCard {
        property string label: ""
        property string description: ""
        property bool checked: false
        signal toggled(bool state)

        autoRadius: false; topRadius: 20; bottomRadius: 20

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 2
                CustomText { content: parent.parent.parent.label; size: 14 }
                CustomText {
                    content: parent.parent.parent.description
                    size: 12; customColor: Colors.outline
                    visible: content !== ""
                }
            }
            Item { Layout.fillWidth: true }
            CustomToogle {
                isToggleOn: parent.parent.parent.checked
                onToggled: function(state) { parent.parent.parent.toggled(state) }
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        contentWidth: width
        clip: true

        ColumnLayout {
            id: column
            width: parent.width
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors { leftMargin: 5; rightMargin: 5; topMargin: 5 }
            spacing: 0

            // ── Page header ──────────────────────────────────────────────
            RowLayout {
                spacing: 10
                MaterialIconSymbol { content: "widgets"; iconSize: 20 }
                CustomText { content: "Widgets"; size: 20; customColor: Colors.primary }
            }

            // ════════════════════════════════════════════════════════════
            // MUSIC
            // ════════════════════════════════════════════════════════════
            SectionLabel { content: "Music" }

            ColumnLayout {
                Layout.fillWidth: true; Layout.topMargin: 6; spacing: 3

                // Circular player
                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Circular Player"; size: 14 }
                            CustomText { content: "Rotating cookie-shape with cava visualizer"; size: 12; customColor: Colors.outline }
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


                // Visualizer
                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Cava Visualizer"; size: 14 }
                            CustomText { content: "Audio bar overlay alongside the circular player"; size: 12; customColor: Colors.outline }
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

                // Visualizer bar count
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Visualizer Bars"; size: 14 }
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

            // ════════════════════════════════════════════════════════════
            // CLOCKS
            // ════════════════════════════════════════════════════════════
            SectionLabel { content: "Clocks" }

            ColumnLayout {
                Layout.fillWidth: true; Layout.topMargin: 6; spacing: 3

                // Digital clock
                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Digital Clock"; size: 14 }
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

                // Analog clock toggle
                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Analog Clock"; size: 14 }
                            CustomText { content: "Classic, minimal, or material-shape clock"; size: 12; customColor: Colors.outline }
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

                // Analog clock style
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Analog Style"; size: 14 }
                            CustomText { content: "Classic · Minimal · Shape"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30; Layout.preferredWidth: 120
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

            // ════════════════════════════════════════════════════════════
            // DATE
            // ════════════════════════════════════════════════════════════
            SectionLabel { content: "Date" }

            ColumnLayout {
                Layout.fillWidth: true; Layout.topMargin: 6; spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
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
                            CustomText { content: "Date Style"; size: 14 }
                            CustomText { content: "Default · Calendar · Pill · Split · Bold · Ghost · Accent · Inline"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30; Layout.preferredWidth: 140
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

            // ════════════════════════════════════════════════════════════
            // WEATHER
            // ════════════════════════════════════════════════════════════
            SectionLabel { content: "Weather" }

            ColumnLayout {
                Layout.fillWidth: true; Layout.topMargin: 6; spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Slanted Card"; size: 14 }
                            CustomText { content: "Primary-color slanted shape with temperature"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.widgets.showWeatherSlanted ?? false
                            onToggled: function(state) {
                                SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { showWeatherSlanted: state })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "3-Day Forecast"; size: 14 }
                            CustomText { content: "Compact card showing today + next 2 days"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.widgets.showWeatherForecast ?? false
                            onToggled: function(state) {
                                SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { showWeatherForecast: state })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Details Grid"; size: 14 }
                            CustomText { content: "Humidity · Wind · UV · Feels like"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.widgets.showWeatherDetails ?? false
                            onToggled: function(state) {
                                SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { showWeatherDetails: state })
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // PRODUCTIVITY
            // ════════════════════════════════════════════════════════════
            SectionLabel { content: "Productivity" }

            ColumnLayout {
                Layout.fillWidth: true; Layout.topMargin: 6; spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Pomodoro Timer"; size: 14 }
                            CustomText { content: "25 min focus · 5 min break · long break after 4"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.widgets.showPomodoro ?? false
                            onToggled: function(state) {
                                SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { showPomodoro: state })
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // SYSTEM
            // ════════════════════════════════════════════════════════════
            SectionLabel { content: "System" }

            ColumnLayout {
                Layout.fillWidth: true; Layout.topMargin: 6; spacing: 3

                // System monitor toggle
                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "System Monitor"; size: 14 }
                            CustomText { content: "CPU · RAM · GPU with network and disk"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.widgets.showSystemMonitor ?? false
                            onToggled: function(state) {
                                SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { showSystemMonitor: state })
                            }
                        }
                    }
                }

                // System monitor style
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Monitor Style"; size: 14 }
                            CustomText { content: "Default · Compact"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30; Layout.preferredWidth: 120
                            color: Colors.surfaceContainerHighest
                            currentVal: SettingsConfig.widgets.systemMonitorStyle ?? "default"
                            list: [{ name: "default" }, { name: "compact" }]
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== (SettingsConfig.widgets.systemMonitorStyle ?? "default"))
                                    SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { systemMonitorStyle: currentVal })
                            }
                        }
                    }
                }

                // Battery toggle
                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Battery Widget"; size: 14 }
                            CustomText { content: "Wave fill with charging animation"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.widgets.showBattery ?? false
                            onToggled: function(state) {
                                SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { showBattery: state })
                            }
                        }
                    }
                }

                // Battery style
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Battery Style"; size: 14 }
                            CustomText { content: "Default · Minimal"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30; Layout.preferredWidth: 120
                            color: Colors.surfaceContainerHighest
                            currentVal: SettingsConfig.widgets.batteryStyle ?? "default"
                            list: [{ name: "default" }, { name: "minimal" }]
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== (SettingsConfig.widgets.batteryStyle ?? "default"))
                                    SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { batteryStyle: currentVal })
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
