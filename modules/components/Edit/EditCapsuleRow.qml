pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

RowLayout {
    id: row
    spacing: 4

    property var actions: []
    property string addLabel: "Add"
    property bool addLit: false
    property bool historyOpen: false
    property bool moreOpen: false
    property bool discardArmed: false
    signal add
    signal action(string key)

    readonly property var layers: [
        { value: "edges",     label: "Edges",     icon: "dock_to_left" },
        { value: "desktop",   label: "Desktop",   icon: "widgets" }
    ]

    function closeAll() {
        if (row.moreOpen) {
            row.moreOpen = false
            return true
        }
        if (row.historyOpen) {
            row.historyOpen = false
            return true
        }
        if (row.discardArmed) {
            row.discardArmed = false
            return true
        }
        return false
    }

    Timer {
        id: disarm
        interval: 3500
        onTriggered: row.discardArmed = false
    }

    Connections {
        target: GlobalStates
        function onEditModeChanged() {
            row.discardArmed = false
            row.historyOpen = false
            row.moreOpen = false
        }
        function onEditLayerChanged() {
            row.historyOpen = false
            row.moreOpen = false
        }
    }

    Rectangle {
        implicitHeight: 44
        implicitWidth: layerRow.implicitWidth + 6
        radius: 22
        color: Colors.surfaceContainerLow

        Row {
            id: layerRow
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: row.layers

                delegate: Rectangle {
                    id: seg
                    required property var modelData
                    required property int index
                    readonly property bool on: GlobalStates.editLayer === seg.modelData.value
                    width: segRow.implicitWidth + 26
                    height: 38
                    radius: segArea.pressed ? 12 : 19
                    color: seg.on ? Colors.primary
                        : segArea.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
                    Behavior on color { EffectsColorAnim { speed: "fast" } }
                    Behavior on radius { SpatialAnim { speed: "fast" } }

                    RowLayout {
                        id: segRow
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialIconSymbol {
                            content: seg.modelData.icon
                            iconSize: 17
                            customColor: seg.on ? Colors.primaryText : Colors.surfaceVariantText
                        }

                        CustomText {
                            content: seg.modelData.label
                            size: 13
                            weight: seg.on ? 700 : 500
                            customColor: seg.on ? Colors.primaryText : Colors.surfaceText
                        }
                    }

                    MouseArea {
                        id: segArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: GlobalStates.editLayer = seg.modelData.value
                    }

                    CustomToolTip {
                        content: (seg.index === 0 ? "Edit the bar and dock" : "Edit desktop widgets") + " · key " + (seg.index + 1)
                        visible: segArea.containsMouse && !seg.on
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.leftMargin: 4
        Layout.rightMargin: 2
        implicitWidth: 1
        implicitHeight: 24
        color: Colors.outlineVariant
    }

    EditPill {
        icon: "add"
        label: row.addLabel
        tonal: !row.addLit
        lit: row.addLit
        tip: GlobalStates.editLayer === "desktop" ? "Add a widget · A" : "Add items and blocks · A"
        onClicked: row.add()
    }

    EditPill {
        icon: "undo"
        usable: EditSession.canUndo
        lit: row.historyOpen
        tip: EditSession.canUndo ? "Undo: " + EditSession.undoLabel + " · hold for the list" : ""
        onClicked: EditSession.undo()
        onHeld: row.historyOpen = !row.historyOpen
    }

    EditPill {
        icon: "redo"
        usable: EditSession.canRedo
        tip: EditSession.canRedo ? "Redo: " + EditSession.redoLabel : ""
        onClicked: EditSession.redo()
    }

    Repeater {
        model: row.actions

        delegate: EditPill {
            required property var modelData
            icon: modelData.icon ?? ""
            label: modelData.label ?? ""
            lit: modelData.lit ?? false
            danger: modelData.danger ?? false
            alarm: modelData.alarm ?? false
            tip: modelData.tip ?? ""
            onClicked: row.action(modelData.key)
        }
    }

    readonly property real moreX: morePill.x + morePill.width / 2

    EditPill {
        id: morePill
        icon: "more_horiz"
        lit: row.moreOpen
        tonal: row.moreOpen
        tip: "More: keys, peek, settings"
        onClicked: {
            row.historyOpen = false
            row.moreOpen = !row.moreOpen
        }
    }

    EditPill {
        icon: row.discardArmed ? "warning" : ""
        label: row.discardArmed
            ? "Discard " + EditSession.changes + (EditSession.changes === 1 ? " change?" : " changes?")
            : "Discard"
        alarm: row.discardArmed
        usable: EditSession.changes > 0 || row.discardArmed
        tip: row.discardArmed ? "Press again to put everything back · Esc cancels" : "Put everything back as it was when you opened edit mode"
        onClicked: {
            if (!row.discardArmed) {
                row.discardArmed = true
                disarm.restart()
                return
            }
            row.discardArmed = false
            disarm.stop()
            EditSession.discard()
        }
    }

    EditPill {
        icon: "check"
        label: "Done"
        filled: true
        tip: "Ctrl+S"
        onClicked: GlobalStates.closeEdit()
    }
}
