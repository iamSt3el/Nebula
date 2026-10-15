import QtQuick
import qs.modules.utils
import qs.modules.customComponents

Rectangle {
    id: cap
    property string text: ""
    property real u: 1
    implicitWidth: Math.max(28 * cap.u, capText.implicitWidth + 16 * cap.u)
    implicitHeight: 28 * cap.u
    radius: 8 * cap.u
    color: "transparent"
    border.width: 1
    border.color: Qt.alpha(Colors.surfaceVariantText, 0.35)

    CustomText {
        id: capText
        anchors.centerIn: parent
        content: cap.text
        size: Math.round(14 * cap.u)
        weight: 600
        customColor: Colors.surfaceVariantText
    }
}
