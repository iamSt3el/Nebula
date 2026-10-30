import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

CustomCard {
    id: info

    property string title: ""
    property string value: ""

    RowLayout {
        Layout.fillWidth: true
        spacing: 16

        CustomText {
            content: info.title
            size: 13
            customColor: Colors.outline
        }

        CustomText {
            Layout.fillWidth: true
            content: info.value
            size: 13
            elide: Text.ElideMiddle
            horizontalAlignment: Text.AlignRight
        }
    }
}
