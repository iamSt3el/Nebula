import QtQuick
import qs.modules.utils
import qs.modules.customComponents

Rectangle {
    implicitWidth: badgeText.implicitWidth + 12
    implicitHeight: 18
    radius: 9
    color: Colors.tertiaryContainer

    CustomText {
        id: badgeText
        anchors.centerIn: parent
        content: "New"
        size: 10
        weight: 600
        customColor: Colors.tertiaryContainerText
    }
}
