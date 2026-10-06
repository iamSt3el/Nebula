import QtQuick
import qs.modules.utils
import qs.modules.customComponents

Rectangle {
    id: root

    property var notif: null
    property real size: 34

    readonly property string key: root.notif ? (root.notif.app || root.notif.title || "?") : "?"
    readonly property int tone: {
        let h = 0
        for (let i = 0; i < root.key.length; i++)
            h = (h * 31 + root.key.charCodeAt(i)) % 3
        return h
    }
    readonly property bool hasIcon: !!root.notif && root.notif.icon !== "" && pic.status === Image.Ready

    implicitWidth: root.size
    implicitHeight: root.size
    radius: root.size / 2
    color: root.hasIcon ? "transparent"
        : root.tone === 0 ? Colors.primaryContainer : root.tone === 1 ? Colors.primary : Colors.tertiaryContainer

    CustomText {
        anchors.centerIn: parent
        visible: !root.hasIcon
        content: root.key.charAt(0).toUpperCase()
        size: Math.round(root.size * 0.42)
        weight: 700
        customColor: root.tone === 0 ? Colors.primaryContainerText
            : root.tone === 1 ? Colors.primaryText : Colors.tertiaryContainerText
    }

    RoundedImage {
        id: pic
        anchors.fill: parent
        radius: root.size / 2
        source: root.notif ? root.notif.icon : ""
        sourceSize: Qt.size(96, 96)
    }
}
