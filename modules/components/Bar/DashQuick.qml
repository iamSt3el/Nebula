pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property var actions: null
    signal opened(string key)

    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"
    readonly property real battery: Math.max(0, Math.min(1, ServiceUPower.powerLevel ?? 0))

    readonly property var small: [
        { key: "caffeine", icon: "coffee", label: "Stay awake", on: ServiceIdleInhibit.active },
        { key: "game", icon: "sports_esports", label: "Game mode", on: ServiceGameMode.active },
        { key: "mic", icon: ServicePipewire.micMuted ? "mic_off" : "mic", label: ServicePipewire.micMuted ? "Microphone muted" : "Microphone on", on: !ServicePipewire.micMuted },
        { key: "capture", icon: "screenshot_region", label: "Screenshot", on: false },
        { key: "lock", icon: "lock", label: "Lock", on: false },
        { key: "power", icon: "power_settings_new", label: "Power menu", on: false }
    ]

    function press(key) {
        if (!root.actions) return
        if (key === "lock") root.actions.lock()
        else if (key === "power") root.actions.power()
        else root.actions.fire(key)
    }

    implicitWidth: 400
    implicitHeight: col.implicitHeight + 32

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            spacing: 10

            CustomText {
                content: ServiceClock.hour + ":" + ServiceClock.minute
                family: root.displayFamily
                size: 34
                weight: 400
            }

            CustomText {
                Layout.fillWidth: true
                content: Qt.formatDate(new Date(), "ddd d MMM")
                size: 13
                weight: 500
                customColor: Colors.surfaceVariantText
            }

            Rectangle {
                implicitWidth: batRow.implicitWidth + 20
                implicitHeight: 30
                radius: 15
                color: Colors.surfaceContainerHigh

                RowLayout {
                    id: batRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIconSymbol {
                        content: ServiceUPower.isCharging ? "battery_charging_full" : root.battery > 0.9 ? "battery_full" : "battery_5_bar"
                        iconSize: 16
                        customColor: Colors.primary
                    }

                    CustomText {
                        content: Math.round(root.battery * 100) + "%"
                        size: 12
                        weight: 800
                    }
                }
            }

            M3IconButton {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                icon: "settings"
                iconSize: 20
                onClicked: root.actions?.settings()
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 6
            rowSpacing: 6

            Repeater {
                model: root.actions ? root.actions.pick(["wifi", "bluetooth", "dnd", "reading"]) : []

                DashToggle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    variant: "wide"
                    info: modelData
                    expandable: modelData.key === "wifi" || modelData.key === "bluetooth" || modelData.key === "reading"
                    onClicked: root.actions.fire(modelData.key)
                    onOpened: root.opened(modelData.key)
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: root.small

                Rectangle {
                    id: chip

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 56
                    radius: chip.modelData.on ? 18 : height / 2
                    color: chip.modelData.on ? Colors.primary : Colors.surfaceContainerHigh
                    Behavior on radius { SpatialAnim { speed: "fast" } }
                    Behavior on color { EffectsColorAnim {} }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: chip.modelData.icon
                        iconSize: 24
                        fill: chip.modelData.on ? 1 : 0
                        customColor: chip.modelData.on ? Colors.primaryText
                            : chip.modelData.key === "power" ? Colors.error : Colors.surfaceText
                    }

                    RippleEffect {
                        id: chipRipple
                        anchors.fill: parent
                        radius: chip.radius
                        hoverColor: Qt.alpha(chip.modelData.on ? Colors.primaryText : Colors.surfaceText, 0.08)
                        rippleColor: Qt.alpha(chip.modelData.on ? Colors.primaryText : Colors.surfaceText, 0.16)
                        onClicked: root.press(chip.modelData.key)
                    }

                    CustomToolTip {
                        content: chip.modelData.label
                        visible: chipRipple.containsMouse
                    }
                }
            }
        }

        CustomCard {
            autoRadius: false
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                DashSliderRow { Layout.fillWidth: true; kind: "brightness"; showIcon: true }
                DashSliderRow { Layout.fillWidth: true; kind: "volume"; showIcon: true }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
