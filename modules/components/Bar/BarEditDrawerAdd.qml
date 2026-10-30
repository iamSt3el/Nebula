import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.Edit

ColumnLayout {
    id: addPage
    required property Item host
    Layout.fillWidth: true
    spacing: 10
    visible: false

    Repeater {
        model: BarLayout.groups

        delegate: RowLayout {
            id: groupRow
            required property string modelData
            readonly property var chips: BarLayout.hiddenItems.filter(id => {
                const e = BarLayout.entry(id)
                return e && e.group === groupRow.modelData
            })

            Layout.fillWidth: true
            spacing: 12
            visible: groupRow.chips.length > 0

            CustomText {
                Layout.preferredWidth: 72
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 8
                content: groupRow.modelData
                size: 12
                weight: 600
                customColor: Colors.outline
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: groupRow.chips

                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        readonly property var entry: BarLayout.entry(chip.modelData)
                        readonly property bool multi: !!chip.entry && !!chip.entry.multi

                        width: chipRow.implicitWidth + 22
                        height: 32
                        radius: 16
                        color: chipArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                        border.width: 1
                        border.color: Qt.alpha(Colors.outline, chip.multi ? 0.5 : 0.3)
                        opacity: host.editor && host.editor.mode === "item" && host.editor.itemId === chip.modelData ? 0.3 : 1

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIconSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                content: chip.multi ? "add" : (chip.entry ? chip.entry.icon : "")
                                iconSize: 16
                            }
                            CustomText {
                                anchors.verticalCenter: parent.verticalCenter
                                content: chip.entry ? chip.entry.label : chip.modelData
                                size: 12
                                weight: 600
                            }
                        }

                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: host.editor && host.editor.mode === "item" ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                            property real sx: 0
                            property real sy: 0

                            onPressed: mouse => {
                                chipArea.sx = mouse.x
                                chipArea.sy = mouse.y
                            }
                            onPositionChanged: mouse => {
                                if (!chipArea.pressed)
                                    return
                                const e = host.editor
                                if (e.mode === "" && Math.hypot(mouse.x - chipArea.sx, mouse.y - chipArea.sy) > 4)
                                    e.beginItem(chip.modelData, "", -1, 32)
                                if (e.mode !== "") {
                                    const p = chipArea.mapToItem(null, mouse.x, mouse.y)
                                    e.update(p.x, p.y)
                                }
                            }
                            onReleased: if (host.editor.mode !== "") host.editor.finish()
                            onCanceled: host.editor.cancel()
                        }

                        CustomToolTip {
                            content: chip.multi ? "Drag onto the bar or dock to add another" : "Drag onto the bar or dock"
                            visible: chipArea.containsMouse && !chipArea.pressed
                        }
                    }
                }
            }
        }
    }

    CustomText {
        Layout.fillWidth: true
        visible: BarLayout.hiddenItems.length === 0
        content: "Every item is already on the bar or dock."
        size: 13
        customColor: Colors.outline
    }

    CustomText {
        Layout.fillWidth: true
        Layout.topMargin: 2
        wrapMode: Text.WordWrap
        content: "Drag an item onto the bar or dock. Click one that is already there to change its options."
        size: 12
        customColor: Colors.outline
    }
}
