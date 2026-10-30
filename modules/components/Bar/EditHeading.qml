import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

ColumnLayout {
    id: head

    property string content: ""
    property int size: 12
    property color customColor: Colors.primary
    readonly property bool isHeading: true

    readonly property bool hasAbove: head.above(head)

    function above(item) {
        const p = item.parent
        if (!p)
            return false
        const ch = p.children
        for (let i = 0; i < ch.length; i++) {
            if (ch[i] === item)
                break
            if (ch[i].visible && ch[i].implicitHeight > 0)
                return true
        }
        return p.isSection === true && head.above(p)
    }

    spacing: 12

    Rectangle {
        visible: head.hasAbove
        Layout.fillWidth: true
        Layout.topMargin: 2
        implicitHeight: 1
        color: Colors.outlineVariant
    }

    CustomText {
        Layout.fillWidth: true
        content: head.content
        size: 12
        weight: 600
        customColor: Colors.primary
    }
}
