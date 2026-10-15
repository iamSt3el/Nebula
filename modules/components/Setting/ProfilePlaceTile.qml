import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

CustomCard {
    id: tile
    property string icon: ""
    property string title: ""
    property string hint: ""
    property bool warn: false
    property bool checked: false
    property bool canToggle: true
    property string action: ""
    signal toggled(bool state)
    signal actionClicked()

    autoRadius: false
    topRadius: 22
    bottomRadius: 22
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: 150

    RowLayout {
        Layout.fillWidth: true

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 14
            color: Colors.surfaceContainerHighest
            MaterialIconSymbol {
                anchors.centerIn: parent
                content: tile.icon
                iconSize: 20
                customColor: Colors.primary
            }
        }

        Item { Layout.fillWidth: true }

        CustomToogle {
            visible: tile.canToggle && tile.action === ""
            isToggleOn: tile.checked
            onToggled: state => tile.toggled(state)
        }

        M3Button {
            visible: tile.action !== ""
            size: "xsmall"
            variant: "tonal"
            label: tile.action
            onClicked: tile.actionClicked()
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 4
        CustomText { Layout.fillWidth: true; content: tile.title; size: 14 }
        CustomText {
            Layout.fillWidth: true
            content: tile.hint
            size: 12
            customColor: tile.warn ? Colors.tertiary : Colors.outline
            wrapMode: Text.WordWrap
            lineHeight: 1.15
        }
        Item { Layout.fillHeight: true }
    }
}
