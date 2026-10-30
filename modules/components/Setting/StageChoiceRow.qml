import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

StageRow {
    id: row

    property var options: []
    property var current
    property real dropdownWidth: 170
    signal picked(var value)

    function labelOf(o) {
        return o.label ?? String(o.value)
    }

    readonly property var items: row.options.map(o => ({ name: row.labelOf(o) }))
    readonly property string currentLabel: {
        const o = row.options.find(o => String(o.value) === String(row.current))
        return o ? row.labelOf(o) : ""
    }

    CustomListNew {
        Layout.preferredWidth: row.dropdownWidth
        Layout.preferredHeight: 32
        color: Colors.surfaceContainerHighest
        currentVal: row.currentLabel
        list: row.items
        onListChildClicked: child => {
            const o = row.options.find(o => row.labelOf(o) === child?.name)
            if (o && String(o.value) !== String(row.current))
                row.picked(o.value)
        }
    }
}
