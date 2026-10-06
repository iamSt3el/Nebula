import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

CustomCard {
    id: row

    property string title: ""
    property string subtitle: ""
    property string path: ""
    property bool isNew: false

    readonly property bool on: !!ServiceHyprConfig.value(row.path, false)

    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                CustomText { content: row.title; size: 14 }
                HyprNewBadge { visible: row.isNew }
            }

            CustomText {
                visible: row.subtitle !== ""
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                content: row.subtitle
                size: 12
                customColor: Colors.outline
            }
        }

        Item { Layout.fillWidth: true }

        CustomToogle {
            isToggleOn: row.on
            onToggled: function(state) { ServiceHyprConfig.set(row.path, state) }
        }
    }
}
