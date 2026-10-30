import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

RowLayout {
    id: heading

    property string text: ""
    property string aside: ""

    Layout.fillWidth: true
    Layout.topMargin: 16
    Layout.bottomMargin: 3
    Layout.leftMargin: 6
    Layout.rightMargin: 6
    spacing: 8

    CustomText {
        Layout.fillWidth: true
        content: heading.text
        size: 13
        customColor: Colors.primary
    }

    CustomText {
        visible: heading.aside !== ""
        content: heading.aside
        size: 12
        customColor: Colors.outline
    }
}
