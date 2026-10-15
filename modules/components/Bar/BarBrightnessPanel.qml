import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    readonly property var monitors: ServiceBrightness.monitors

    implicitWidth: 340
    implicitHeight: column.implicitHeight + 24

    component ValueChip: Rectangle {
        id: vchip
        property string label: ""
        implicitWidth: 48
        implicitHeight: 30
        radius: 10
        color: Colors.surfaceContainerHighest
        CustomText {
            anchors.centerIn: parent
            content: vchip.label
            size: 12
            weight: 600
        }
    }

    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 3

        CustomText {
            Layout.leftMargin: 4
            Layout.bottomMargin: 2
            content: root.monitors.length > 1 ? "Displays" : "Display"
            size: 12
            weight: 600
            customColor: Colors.primary
        }

        Repeater {
            model: root.monitors

            delegate: CustomCard {
                id: card
                required property var modelData
                required property int index
                readonly property bool internal: /^(eDP|LVDS|DSI)/i.test(card.modelData.screen?.name ?? "")
                readonly property bool live: card.modelData.ready

                autoRadius: false
                topRadius: card.index === 0 ? 20 : 5
                bottomRadius: card.index === root.monitors.length - 1 ? 20 : 5

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 10
                            color: Colors.secondaryContainer

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: card.internal ? "laptop" : "desktop_windows"
                                iconSize: 17
                                customColor: Colors.secondaryContainerText
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            CustomText {
                                Layout.fillWidth: true
                                content: (card.modelData.screen?.model && card.modelData.screen.model !== "Unknown") ? card.modelData.screen.model
                                    : (card.internal ? "Built-in display" : "External display")
                                size: 12
                                weight: 600
                                elide: Text.ElideRight
                            }

                            CustomText {
                                Layout.fillWidth: true
                                content: (card.modelData.screen?.name ?? "") + (card.live ? "" : " · reading…")
                                size: 10
                                customColor: Colors.outline
                            }
                        }

                        Rectangle {
                            visible: card.modelData.isDdc
                            implicitWidth: ddcText.implicitWidth + 14
                            implicitHeight: 22
                            radius: 11
                            color: Colors.surfaceContainerHighest

                            CustomText {
                                id: ddcText
                                anchors.centerIn: parent
                                content: "DDC"
                                size: 10
                                weight: 700
                                customColor: Colors.outline
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        M3Slider {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            enabled: card.live
                            opacity: card.live ? 1 : 0.5
                            icon: card.modelData.brightness > 0.66 ? "brightness_7"
                                : card.modelData.brightness > 0.33 ? "brightness_6" : "brightness_5"
                            iconAtEnd: true
                            showStopIndicator: false
                            trackOuterCorner: 12
                            trackHeight: 32
                            handleHeight: 40
                            handleWidth: 6
                            pressedHandleWidth: 4
                            handleGap: 4
                            progress: card.modelData.brightness ?? 0
                            onMoved: card.modelData.setBrightness(Math.max(0.01, progress))
                        }

                        ValueChip {
                            label: Math.round((card.modelData.brightness ?? 0) * 100) + "%"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: card.modelData.hasContrast
                        spacing: 10

                        M3Slider {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            enabled: card.live
                            opacity: card.live ? 1 : 0.5
                            icon: "contrast"
                            iconAtEnd: true
                            showStopIndicator: false
                            trackOuterCorner: 12
                            trackHeight: 32
                            handleHeight: 40
                            handleWidth: 6
                            pressedHandleWidth: 4
                            handleGap: 4
                            progress: card.modelData.contrast ?? 0
                            onMoved: card.modelData.setContrast(progress)
                        }

                        ValueChip {
                            label: Math.round((card.modelData.contrast ?? 0) * 100) + "%"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: card.modelData.colorPresets.length > 0
                        spacing: 6

                        CustomText {
                            Layout.leftMargin: 4
                            content: "Color preset"
                            size: 10
                            weight: 600
                            customColor: Colors.outline
                        }

                        M3ButtonGroup {
                            Layout.fillWidth: true
                            fillWidth: true
                            Layout.preferredHeight: 32
                            enabled: card.live
                            opacity: card.live ? 1 : 0.5
                            model: card.modelData.colorPresets.map(v => ({
                                        value: v,
                                        label: ServiceBrightness.presetLabel(v)
                                    }))
                            activeCheck: v => v === card.modelData.colorPreset
                            onSegmentClicked: v => card.modelData.setColorPreset(v)
                        }
                    }
                }
            }
        }
    }
}
