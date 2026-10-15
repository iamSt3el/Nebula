import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

Rectangle {
    id: chip
    property string icon: ""
    property string text: ""
    property real u: 1
    implicitHeight: 44 * chip.u
    implicitWidth: chipRow.implicitWidth + 32 * chip.u
    radius: height / 2
    color: Qt.alpha(Colors.surfaceContainerHigh, 0.8)

    RowLayout {
        id: chipRow
        anchors.centerIn: parent
        spacing: 8 * chip.u

        MaterialIconSymbol {
            content: chip.icon
            iconSize: Math.round(21 * chip.u)
            customColor: Colors.primary
        }

        CustomText {
            content: chip.text
            size: Math.round(16 * chip.u)
            weight: 500
        }
    }
}
