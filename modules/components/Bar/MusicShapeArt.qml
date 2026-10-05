import QtQuick
import QtQuick.Effects
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes

Item {
    id: root

    property int decode: 128
    property bool round: false
    property real dim: 0

    readonly property string artUrl: ServiceMusic.activeTrack?.artUrl ?? ""
    readonly property var shapes: ["cookie9", "clover4", "sunny", "cookie7", "flower", "puffy",
                                   "softBurst", "gem", "cookie12", "clover8", "pebble", "cookie6"]
    readonly property string trackShape: {
        const key = (ServiceMusic.activeTrack?.title ?? "") + "\u0001" + (ServiceMusic.activeTrack?.artist ?? "")
        let h = 7
        for (let i = 0; i < key.length; i++)
            h = (h * 31 + key.charCodeAt(i)) >>> 0
        return root.shapes[h % root.shapes.length]
    }
    readonly property string shape: root.round ? "circle" : root.trackShape

    Item {
        id: shapeMaskItem
        anchors.fill: parent
        visible: false
        layer.enabled: true

        MaterialShapes.ShapeCanvas {
            anchors.fill: parent
            roundedPolygon: root.shape
            color: "white"
        }
    }

    Item {
        id: artLayer
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: shapeMaskItem
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            saturation: -0.6 * root.dim
            brightness: -0.2 * root.dim
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.surfaceContainerHighest
        }

        Image {
            id: img
            anchors.fill: parent
            source: root.artUrl
            sourceSize.width: root.decode
            sourceSize.height: root.decode
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: root.artUrl !== ""
        }

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: "music_note"
            iconSize: Math.round(root.width * 0.45)
            customColor: Colors.outline
            visible: root.artUrl === ""
        }
    }
}
