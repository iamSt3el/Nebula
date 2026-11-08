import QtQuick
import Nebula
import qs.modules.utils
import qs.modules.settings

WidgetHost {
    id: root

    property var rows: []
    property real blobSmoothing: 10

    readonly property real pad: 8
    readonly property real gap: 6
    readonly property real tileRadius: 16
    readonly property real nowRadius: 22
    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"

    readonly property WeatherTileData wx: data

    readonly property var blobs: root.rows.map(r => ({
        x: r[0] - root.pad, y: r[1] - root.pad,
        w: r[2] + root.pad * 2, h: r[3] + root.pad * 2,
        r: (r[4] ?? root.tileRadius) + root.pad
    }))

    backdropMask: maskTexture

    WeatherTileData {
        id: data
        preview: root.preview
    }

    BlobField {
        z: -2
        anchors.fill: parent
        blobs: root.blobs
        smoothing: root.blobSmoothing
        fillColor: WidgetSizes.cardColor
    }

    Item {
        width: 0
        height: 0
        clip: true

        ShaderEffectSource {
            id: maskTexture
            width: root.width
            height: root.height
            textureSize: Qt.size(root.width, root.height)
            sourceItem: maskBlob
            hideSource: true
            live: WidgetSizes.blurBackground
        }
    }

    BlobField {
        id: maskBlob
        z: -3
        width: root.width
        height: root.height
        blobs: root.blobs
        smoothing: root.blobSmoothing
        fillColor: "white"
    }
}
