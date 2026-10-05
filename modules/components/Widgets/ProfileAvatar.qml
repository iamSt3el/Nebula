import QtQuick
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

ClippingRectangle {
    id: root

    color: Colors.primaryContainer

    MaterialIconSymbol {
        anchors.centerIn: parent
        visible: pic.status !== Image.Ready
        content: "person"
        iconSize: Math.round(root.width * 0.5)
        fill: 1
        customColor: Colors.primaryContainerText
    }

    Image {
        id: pic
        anchors.fill: parent
        source: ServiceProfile.avatar
        sourceSize.width: 256
        sourceSize.height: 256
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
    }
}
