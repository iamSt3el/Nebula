pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: sheet
    anchors.fill: parent
    property bool desktop: false

    readonly property bool open: GlobalStates.editKeysOpen && GlobalStates.editMode
    property real openT: sheet.open ? 1 : 0
    Behavior on openT { SpatialAnim { speed: "fast" } }
    visible: sheet.openT > 0.01

    readonly property var groups: sheet.desktop ? [
        { title: "Select", rows: [
            { keys: ["Tab", "⇧ Tab"], text: "Next / previous widget" },
            { keys: ["←", "↑", "→", "↓"], text: "Nearest widget that way" },
            { keys: ["1", "2"], text: "Edges / Desktop" }
        ] },
        { title: "Change", rows: [
            { keys: ["Alt", "arrows"], text: "Move one cell" },
            { keys: ["Enter"], text: "Options" },
            { keys: ["Del"], text: "Remove (undo brings it back)" },
            { keys: ["L"], text: "Lock or unlock" },
            { keys: ["A"], text: "Add sheet" }
        ] },
        { title: "Session", rows: [
            { keys: ["Ctrl", "Z"], text: "Undo · with ⇧ redo" },
            { keys: ["Space"], text: "Hold to peek" },
            { keys: ["Esc"], text: "Close card → deselect → leave" },
            { keys: ["Ctrl", "S"], text: "Done" }
        ] }
    ] : [
        { title: "Select", rows: [
            { keys: ["Tab", "⇧ Tab"], text: "Next / previous part" },
            { keys: ["arrows"], text: "Along the edge" },
            { keys: ["Backspace"], text: "Up a level: part → block → edge" },
            { keys: ["1", "2"], text: "Edges / Desktop" }
        ] },
        { title: "Change", rows: [
            { keys: ["Alt", "arrows"], text: "Move within the block" },
            { keys: ["Alt", "⇧", "arrows"], text: "Move to the next block" },
            { keys: ["Enter"], text: "Open its settings" },
            { keys: ["Del"], text: "Remove (undo brings it back)" },
            { keys: ["A"], text: "Add sheet" }
        ] },
        { title: "Session", rows: [
            { keys: ["Ctrl", "Z"], text: "Undo · with ⇧ redo" },
            { keys: ["Space"], text: "Hold to peek" },
            { keys: ["Esc"], text: "Close card → deselect → leave" },
            { keys: ["Ctrl", "S"], text: "Done" }
        ] }
    ]

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Colors.scrim, 0.35 * sheet.openT)

        MouseArea {
            anchors.fill: parent
            onClicked: GlobalStates.editKeysOpen = false
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(760, sheet.width - 48)
        height: body.implicitHeight + 44
        radius: 28
        color: Colors.surfaceContainer
        border.width: 1
        border.color: Qt.alpha(Colors.outline, 0.18)
        opacity: Math.min(1, sheet.openT * 1.4)
        scale: 0.94 + 0.06 * sheet.openT

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: body
            x: 22
            y: 22
            width: card.width - 44
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialIconSymbol {
                    content: "keyboard"
                    iconSize: 22
                    customColor: Colors.primary
                }
                CustomText {
                    Layout.fillWidth: true
                    content: "Keys in edit mode"
                    size: 18
                    weight: 600
                }
                CustomText {
                    content: "? toggles this"
                    size: 12
                    customColor: Colors.outline
                }
                M3IconButton {
                    icon: "close"
                    onClicked: GlobalStates.editKeysOpen = false
                }
            }

            Repeater {
                model: sheet.groups

                delegate: ColumnLayout {
                    id: grp
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8

                    CustomText {
                        content: grp.modelData.title
                        size: 13
                        weight: 600
                        customColor: Colors.primary
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 28
                        rowSpacing: 8

                        Repeater {
                            model: grp.modelData.rows

                            delegate: RowLayout {
                                id: krow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                spacing: 6

                                Repeater {
                                    model: krow.modelData.keys
                                    delegate: Rectangle {
                                        required property string modelData
                                        implicitWidth: Math.max(26, keyText.implicitWidth + 14)
                                        implicitHeight: 24
                                        radius: 7
                                        color: Colors.surfaceContainerHighest

                                        CustomText {
                                            id: keyText
                                            anchors.centerIn: parent
                                            content: parent.modelData
                                            size: 11
                                            weight: 600
                                        }
                                    }
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 4
                                    content: krow.modelData.text
                                    elide: Text.ElideRight
                                    size: 13
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
