import QtQuick
import QtQuick.Effects
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.components.Widgets
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

Item {
    id: root

    property url source: ""
    property string shapeName: "circle"
    property real shapeRotation: 0
    property color fallbackColor: Colors.primaryContainer
    property string fallbackIcon: "person"
    property color fallbackIconColor: Colors.primaryContainerText
    property int sourceSize: 256
    property real imageScale: 1
    property string trackKey: ""

    readonly property url _src: root.trackKey !== "" && best.bestUrl !== "" ? best.bestUrl : root.source

    readonly property bool hasImage: String(root._src) !== "" && img.status === Image.Ready

    BestArt {
        id: best
        artUrl: root.trackKey !== "" ? String(root.source) : ""
        trackKey: root.trackKey
    }

    implicitWidth: 96
    implicitHeight: 96

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.mipmap: true

        MaterialShapes.ShapeCanvas {
            anchors.fill: parent
            rotation: root.shapeRotation
            roundedPolygon: ShapeLibrary.get(root.shapeName) ?? ShapeLibrary.get("circle")
            color: "white"
        }
    }

    Item {
        id: art
        anchors.fill: parent
        visible: false

        Image {
            id: img
            anchors.centerIn: parent
            width: parent.width * root.imageScale
            height: parent.height * root.imageScale
            source: root._src
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            onStatusChanged: if (status === Image.Error && root.trackKey !== "") best.reset()
            sourceSize.width: root.sourceSize
            sourceSize.height: root.sourceSize
            asynchronous: true
            cache: true
        }
    }

    MaterialShapes.ShapeCanvas {
        anchors.fill: parent
        visible: !root.hasImage
        rotation: root.shapeRotation
        roundedPolygon: ShapeLibrary.get(root.shapeName) ?? ShapeLibrary.get("circle")
        color: root.fallbackColor

        MaterialIconSymbol {
            anchors.centerIn: parent
            rotation: -root.shapeRotation
            content: root.fallbackIcon
            iconSize: Math.round(root.width * 0.42)
            customColor: root.fallbackIconColor
        }
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.hasImage
        source: art
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
