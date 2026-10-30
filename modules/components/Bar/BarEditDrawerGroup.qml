import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.Edit

ColumnLayout {
    id: groupSection
    required property Item host
    readonly property bool isSection: true
    Layout.fillWidth: true
    visible: host.groupPage
    spacing: 8

    component Chip: Rectangle {
        id: bchip
        property var entry: null
        property bool adding: false
        signal activated

        width: bchipRow.implicitWidth + 20
        height: 30
        radius: 15
        color: bchipArea.containsMouse ? Colors.surfaceContainerHighest
                                       : Colors.surfaceContainerHigh
        border.width: 1
        border.color: Qt.alpha(Colors.outline, 0.3)

        Row {
            id: bchipRow
            anchors.centerIn: parent
            spacing: 5

            MaterialIconSymbol {
                anchors.verticalCenter: parent.verticalCenter
                content: bchip.adding ? "add" : (bchip.entry ? bchip.entry.icon : "")
                iconSize: 15
                customColor: bchip.adding ? Colors.primary : Colors.surfaceText
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: bchip.entry ? bchip.entry.label : ""
                size: 12
                weight: 600
            }
            MaterialIconSymbol {
                anchors.verticalCenter: parent.verticalCenter
                visible: !bchip.adding
                content: "close"
                iconSize: 14
                customColor: bchipArea.containsMouse ? Colors.error : Colors.outline
            }
        }

        MouseArea {
            id: bchipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bchip.activated()
        }
    }

    component ChipArrow: Rectangle {
        id: arrow
        property string glyph: ""
        property bool enabled: true
        signal tapped

        width: 22
        height: 24
        radius: 8
        color: arrowArea.containsMouse && arrow.enabled ? Colors.primaryContainer : Qt.alpha(Colors.primaryContainer, 0)
        opacity: arrow.enabled ? 1 : 0.3
        Behavior on color { EffectsColorAnim {} }

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: arrow.glyph
            iconSize: 16
            customColor: arrowArea.containsMouse && arrow.enabled ? Colors.primaryContainerText
                                                                  : Colors.surfaceText
        }

        MouseArea {
            id: arrowArea
            anchors.fill: parent
            enabled: arrow.enabled
            visible: arrow.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arrow.tapped()
        }
    }

    component MemberChip: Rectangle {
        id: mchip
        property var entry: null
        property bool canLeft: false
        property bool canRight: false
        signal moveLeft
        signal moveRight
        signal removed

        width: mchipRow.implicitWidth + 12
        height: 32
        radius: 16
        color: Colors.surfaceContainerHigh
        border.width: 1
        border.color: Qt.alpha(Colors.outline, 0.3)

        Row {
            id: mchipRow
            anchors.centerIn: parent
            spacing: 2

            ChipArrow {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "chevron_left"
                enabled: mchip.canLeft
                onTapped: mchip.moveLeft()
            }

            MaterialIconSymbol {
                anchors.verticalCenter: parent.verticalCenter
                content: mchip.entry ? mchip.entry.icon : ""
                iconSize: 15
                customColor: Colors.surfaceText
            }

            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 5
                rightPadding: 3
                content: mchip.entry ? mchip.entry.label : ""
                size: 12
                weight: 600
            }

            ChipArrow {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "chevron_right"
                enabled: mchip.canRight
                onTapped: mchip.moveRight()
            }

            ChipArrow {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "close"
                onTapped: mchip.removed()
            }
        }
    }

    EditHeading {
        Layout.fillWidth: true
        Layout.topMargin: 10
        visible: host.groupPage
        content: "Group"
        size: 13
        customColor: Colors.primary
    }
    ColumnLayout {
        id: drawerGroup5
        Layout.fillWidth: true
        visible: host.groupPage
        spacing: 8
        EditRow {
            visible: host.groupPage
            CustomText {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: host.groupPage
                content: "Items in this group"
                size: 13
                customColor: Colors.primary
            }
        }
        EditRow {
            visible: host.groupPage
            Flow {
                Layout.fillWidth: true
                visible: host.groupPage
                spacing: 6

                Repeater {
                    model: host.groupMembers

                    delegate: MemberChip {
                        required property string modelData
                        required property int index
                        entry: BarLayout.entry(modelData)
                        canLeft: index > 0
                        canRight: index < host.groupMembers.length - 1
                        onMoveLeft: BarLayout.moveInGroup(host.selected, modelData, -1)
                        onMoveRight: BarLayout.moveInGroup(host.selected, modelData, 1)
                        onRemoved: BarLayout.removeFromGroup(host.selected, modelData)
                    }
                }
            }
        }
        EditRow {
            visible: host.groupPage && host.groupMembers.length === 0
            CustomText {
                Layout.fillWidth: true
                visible: host.groupPage && host.groupMembers.length === 0
                wrapMode: Text.WordWrap
                content: "Empty. Add items below, then give the group a tint."
                size: 12
                customColor: Colors.outline
            }
        }
        EditRow {
            visible: host.groupPage
            CustomText {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: host.groupPage
                content: "Add"
                size: 13
                customColor: Colors.primary
            }
        }
        EditRow {
            visible: host.groupPage
            Flow {
                Layout.fillWidth: true
                visible: host.groupPage
                spacing: 6

                Repeater {
                    model: host.groupCandidates

                    delegate: Chip {
                        required property string modelData
                        entry: BarLayout.entry(modelData)
                        adding: true
                        onActivated: BarLayout.addToGroup(host.selected, modelData)
                    }
                }
            }
        }
    }
}
