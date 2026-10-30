pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Rectangle {
    id: tip

    property bool desktop: false
    property bool allowed: true

    readonly property bool seen: SettingsConfig.general?.editTipSeen === true
    readonly property bool shown: tip.allowed && !tip.seen && GlobalStates.editMode && !GlobalStates.editKeysOpen

    readonly property var lines: tip.desktop ? [
        { icon: "ads_click", text: "Click a widget to change its style, size and options" },
        { icon: "drag_pan", text: "Drag to move it, pull its corner to resize" },
        { icon: "add", text: "Add puts a new widget in the next free spot" },
        { icon: "keyboard", text: "Press ? any time for every key" }
    ] : [
        { icon: "ads_click", text: "Click an item or a block to change it" },
        { icon: "drag_pan", text: "Drag to move it, even onto another edge" },
        { icon: "pan_tool_alt", text: "Select a block to drag its gap and corner handles" },
        { icon: "keyboard", text: "Press ? any time for every key" }
    ]

    function dismiss() {
        SettingsConfig.general = Object.assign({}, SettingsConfig.general, { editTipSeen: true })
    }

    property real showT: tip.shown ? 1 : 0
    Behavior on showT { SpatialAnim { speed: "fast" } }

    visible: tip.showT > 0.01
    opacity: Math.min(1, tip.showT * 1.4)
    scale: 0.96 + 0.04 * tip.showT
    width: body.implicitWidth + 40
    height: body.implicitHeight + 36
    radius: 28
    color: Colors.surfaceContainer
    border.width: 1
    border.color: Qt.alpha(Colors.outline, 0.18)

    MouseArea {
        anchors.fill: parent
    }

    ColumnLayout {
        id: body
        x: 20
        y: 18
        spacing: 12

        RowLayout {
            spacing: 12

            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: 14
                color: Colors.primaryContainer

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: "edit_square"
                    iconSize: 21
                    customColor: Colors.primaryContainerText
                }
            }

            ColumnLayout {
                spacing: 1

                CustomText {
                    content: "You're editing the real thing"
                    size: 16
                    weight: 600
                }

                CustomText {
                    content: "Every change shows up live. Undo and Discard put things back."
                    size: 12
                    customColor: Colors.surfaceVariantText
                }
            }
        }

        GridLayout {
            columns: 2
            columnSpacing: 22
            rowSpacing: 8

            Repeater {
                model: tip.lines

                delegate: RowLayout {
                    id: line
                    required property var modelData
                    spacing: 8

                    MaterialIconSymbol {
                        content: line.modelData.icon
                        iconSize: 18
                        customColor: Colors.primary
                    }

                    CustomText {
                        Layout.maximumWidth: 250
                        content: line.modelData.text
                        size: 13
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 6

            M3Button {
                size: "xsmall"
                variant: "tonal"
                icon: "keyboard"
                label: "Show keys"
                onClicked: GlobalStates.editKeysOpen = true
            }

            M3Button {
                size: "xsmall"
                icon: "check"
                label: "Got it"
                onClicked: tip.dismiss()
            }
        }
    }
}
