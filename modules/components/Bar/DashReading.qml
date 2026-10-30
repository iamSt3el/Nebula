pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    signal backClicked
    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.bottomMargin: 2
            spacing: 10

            M3IconButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                icon: "chevron_backward"
                iconSize: 20
                onClicked: root.backClicked()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                CustomText {
                    Layout.fillWidth: true
                    content: "Reading"
                    family: root.displayFamily
                    renderType: Text.QtRendering
                    size: 22
                    weight: 400
                }

                CustomText {
                    Layout.fillWidth: true
                    content: ServiceReading.active ? ServiceReading.filterName + " on every app" : "Off"
                    size: 12
                    weight: 400
                    customColor: Colors.surfaceVariantText
                }
            }

            CustomToogle {
                Layout.rightMargin: 4
                isToggleOn: ServiceReading.active
                onToggled: s => ServiceReading.setEnabled(s)
            }
        }

        Repeater {
            model: ServiceReading.filters

            Rectangle {
                id: card

                required property var modelData
                readonly property bool chosen: ServiceReading.filter === card.modelData.id
                readonly property bool lit: card.chosen && ServiceReading.active
                readonly property color ink: card.lit ? Colors.primaryContainerText : Colors.surfaceText
                readonly property color subInk: card.lit ? Colors.primaryContainerText : Colors.surfaceVariantText

                Layout.fillWidth: true
                implicitHeight: cardCol.implicitHeight + 28
                radius: 20
                color: card.lit ? Colors.primaryContainer : Colors.surfaceContainerHigh
                Behavior on color { EffectsColorAnim {} }

                ColumnLayout {
                    id: cardCol
                    x: 14
                    y: 14
                    width: parent.width - 28
                    spacing: 14

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: head.implicitHeight

                        RowLayout {
                            id: head
                            width: parent.width
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                Layout.alignment: Qt.AlignTop
                                radius: 12
                                color: card.modelData.swatch[0]
                                border.width: 1
                                border.color: Qt.alpha(Colors.outline, 0.35)

                                CustomText {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -2
                                    content: "Aa"
                                    size: 15
                                    weight: 700
                                    customColor: card.modelData.swatch[1]
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 6
                                    width: 16
                                    height: 3
                                    radius: 1.5
                                    color: card.modelData.swatch[2]
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                CustomText {
                                    Layout.fillWidth: true
                                    content: card.modelData.name
                                    size: 14
                                    weight: 800
                                    customColor: card.ink
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    content: card.modelData.blurb
                                    size: 12
                                    weight: 500
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideNone
                                    customColor: card.subInk
                                }
                            }

                            MaterialIconSymbol {
                                Layout.alignment: Qt.AlignTop
                                visible: card.lit
                                content: "check_circle"
                                iconSize: 20
                                fill: 1
                                customColor: Colors.primary
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            anchors.margins: -8
                            radius: 14
                            hoverColor: Qt.alpha(card.ink, 0.06)
                            rippleColor: Qt.alpha(card.ink, 0.14)
                            onClicked: ServiceReading.choose(card.modelData.id)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: card.chosen
                        spacing: 8

                        Repeater {
                            model: card.chosen ? card.modelData.params : []

                            ColumnLayout {
                                id: knob

                                required property var modelData
                                readonly property real current: ServiceReading.value(knob.modelData.key)

                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    CustomText { Layout.fillWidth: true; content: knob.modelData.label; size: 12; weight: 700; customColor: card.ink }
                                    CustomText { content: ServiceReading.format(knob.modelData.key, knob.current); size: 12; weight: 700; customColor: card.subInk }
                                }

                                M3Slider {
                                    id: slider
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    from: knob.modelData.min
                                    to: knob.modelData.max
                                    progress: (knob.current - knob.modelData.min) / (knob.modelData.max - knob.modelData.min)
                                    valueText: ServiceReading.format(knob.modelData.key, slider.value)
                                    onMoved: v => ServiceReading.setParam(knob.modelData.key, v)
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
