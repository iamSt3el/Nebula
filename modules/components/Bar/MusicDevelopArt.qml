import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property real progress: 0
    property real cornerRadius: 12
    property int decode: 160
    property bool showSeam: true

    readonly property string artUrl: ServiceMusic.activeTrack?.artUrl ?? ""
    readonly property real shown: Math.max(0, Math.min(1, root.progress))

    ClippingRectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: Colors.surfaceContainerHighest

        Image {
            id: grey
            anchors.fill: parent
            source: root.artUrl
            sourceSize.width: root.decode
            sourceSize.height: root.decode
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: grey
            saturation: -1
            brightness: -0.08
            contrast: -0.15
            visible: root.artUrl !== "" && grey.status === Image.Ready
        }

        Item {
            width: parent.width * root.shown
            height: parent.height
            clip: true
            visible: root.artUrl !== ""

            Image {
                width: grey.width
                height: grey.height
                source: root.artUrl
                sourceSize.width: root.decode
                sourceSize.height: root.decode
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Rectangle {
            x: Math.round(parent.width * root.shown) - 1
            width: 2
            height: parent.height
            color: Colors.primary
            visible: root.showSeam && root.artUrl !== "" && root.shown > 0.005 && root.shown < 0.995
        }
    }

    MaterialIconSymbol {
        anchors.centerIn: parent
        content: "music_note"
        iconSize: Math.round(Math.min(root.width, root.height) * 0.5)
        customColor: Colors.outline
        visible: root.artUrl === ""
    }
}
