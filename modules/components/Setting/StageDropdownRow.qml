import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

StageRow {
    id: row

    property var options: []
    property string current: ""
    property real dropdownWidth: 200
    signal picked(string name)

    readonly property var items: row.options.map(o => typeof o === "string" ? ({ name: o }) : o)

    CustomListNew {
        Layout.preferredWidth: row.dropdownWidth
        Layout.preferredHeight: 32
        color: Colors.surfaceContainerHighest
        currentVal: row.current
        list: row.items
        onListChildClicked: child => {
            if (child && child.name !== row.current)
                row.picked(child.name)
        }
    }
}
