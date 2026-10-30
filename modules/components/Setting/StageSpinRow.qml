import QtQuick
import QtQuick.Layouts
import qs.modules.customComponents

StageRow {
    id: row

    property int from: 0
    property int to: 100
    property int step: 1
    property int current: 0
    property string suffix: ""
    signal stepped(int value)

    CustomSpinBox {
        value: row.current
        min: row.from
        limit: row.to
        inc: row.step
        suffix: row.suffix
        onValChanged: if (val !== row.current) row.stepped(val)
    }
}
