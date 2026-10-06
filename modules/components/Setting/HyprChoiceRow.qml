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
    property var model: []
    property var fallback: ""
    property var emptyValue: undefined

    readonly property var current: {
        const v = ServiceHyprConfig.value(row.path, row.fallback)
        return (v === "" || v === "[[EMPTY]]") && row.emptyValue !== undefined ? row.emptyValue : v
    }

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

        M3ButtonGroup {
            height: 32
            textSize: 12
            model: row.model
            activeCheck: function(value) { return String(row.current) === String(value) }
            onSegmentClicked: value => ServiceHyprConfig.set(row.path, value)
        }
    }
}
