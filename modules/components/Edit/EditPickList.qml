pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: list

    property var choices: []
    property var value: undefined
    signal picked(var value)

    Layout.fillWidth: true
    spacing: 2

    Repeater {
        model: list.choices

        delegate: EditSideRow {
            required property var modelData
            readonly property bool on: list.value === modelData.value
            icon: modelData.icon ?? ""
            label: modelData.label ?? String(modelData.value)
            lit: on
            chevron: on
            trailing: "check"
            onClicked: list.picked(modelData.value)
        }
    }
}
