import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

StageRow {
    id: row

    property string text: ""
    property string placeholder: ""
    property string fieldIcon: ""
    property real fieldWidth: 220
    property bool secret: false
    property bool allowEmpty: false
    readonly property alias typed: input.text
    signal submitted(string text)
    signal accepted()

    function clear() {
        input.text = ""
    }

    function focusField() {
        input.forceActiveFocus()
    }

    Rectangle {
        Layout.preferredWidth: row.fieldWidth
        Layout.preferredHeight: 36
        radius: 12
        color: Colors.surfaceContainerHighest
        border.width: input.activeFocus ? 2 : 0
        border.color: Colors.primary

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 6

            MaterialIconSymbol {
                visible: row.fieldIcon !== ""
                content: row.fieldIcon
                iconSize: 16
                customColor: Colors.outline
            }

            TextInput {
                id: input
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: row.text
                color: Colors.surfaceText
                selectionColor: Colors.primary
                selectedTextColor: Colors.primaryText
                font.pixelSize: 13
                font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                echoMode: row.secret ? TextInput.Password : TextInput.Normal
                clip: true
                verticalAlignment: TextInput.AlignVCenter
                onAccepted: row.accepted()
                onEditingFinished: {
                    const t = input.text.trim()
                    if ((t.length > 0 || row.allowEmpty) && t !== row.text)
                        row.submitted(t)
                }

                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === "" && !input.activeFocus
                    content: row.placeholder
                    size: 13
                    customColor: Colors.outline
                }
            }
        }
    }
}
