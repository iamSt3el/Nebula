import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Rectangle {
    id: row

    required property var app
    property bool picked: false
    property int tint: 0

    signal toggled(bool on)

    readonly property var _fills: [Colors.secondaryContainer, Colors.tertiaryContainer, Colors.primaryContainer]
    readonly property var _inks: [Colors.secondaryContainerText, Colors.tertiaryContainerText, Colors.primaryContainerText]

    Layout.fillWidth: true
    implicitHeight: 52
    radius: 14
    color: hover.containsMouse ? Qt.alpha(Colors.surfaceText, 0.06) : Qt.alpha(Colors.surfaceText, 0)

    Behavior on color { ColorAnimation { duration: M3Motion.effects.fastDuration } }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.toggled(!row.picked)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 8
        spacing: 14

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 12
            color: row._fills[row.tint % 3]

            CustomText {
                anchors.centerIn: parent
                content: row.app.name.charAt(0).toUpperCase()
                size: 15
                weight: 700
                customColor: row._inks[row.tint % 3]
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            CustomText {
                Layout.fillWidth: true
                content: row.app.name
                size: 14
                weight: 500
            }

            CustomText {
                Layout.fillWidth: true
                content: row.app.note
                size: 11
                weight: 400
                customColor: Colors.outline
                elide: Text.ElideMiddle
            }
        }

        Rectangle {
            visible: row.app.replacesFile
            Layout.preferredHeight: 24
            Layout.preferredWidth: chipRow.implicitWidth + 18
            radius: 12
            color: Colors.tertiaryContainer

            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 4

                MaterialIconSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "backup"
                    iconSize: 15
                    customColor: Colors.tertiaryContainerText
                }

                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "Replaces file"
                    size: 11
                    weight: 500
                    customColor: Colors.tertiaryContainerText
                }
            }
        }

        Rectangle {
            visible: Boolean(row.app.skipped && row.app.skipped.length > 0)
            Layout.preferredHeight: 24
            Layout.preferredWidth: roChipRow.implicitWidth + 18
            radius: 12
            color: Colors.surfaceVariant

            Row {
                id: roChipRow
                anchors.centerIn: parent
                spacing: 4

                MaterialIconSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "lock"
                    iconSize: 15
                    customColor: Colors.surfaceVariantText
                }

                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "Read-only"
                    size: 11
                    weight: 500
                    customColor: Colors.surfaceVariantText
                }
            }
        }

        CustomToogle {
            id: toggle
            Layout.preferredWidth: 52
            Layout.preferredHeight: 32
            isToggleOn: row.picked
            onToggled: on => {
                row.toggled(on)
                toggle.isToggleOn = Qt.binding(() => row.picked)
            }
        }
    }
}
