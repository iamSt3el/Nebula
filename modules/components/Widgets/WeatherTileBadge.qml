import QtQuick
import qs.modules.utils
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes

Item {
    id: root

    required property var wx

    implicitWidth: 40
    implicitHeight: 40

    MaterialShapes.ShapeCanvas {
        anchors.centerIn: parent
        width: Math.round(Math.min(root.width, root.height))
        height: width
        roundedPolygon: root.wx.shape
        color: Colors.primaryContainer
        animation: SpatialAnim { speed: "slow" }
    }

    MaterialIconSymbol {
        anchors.centerIn: parent
        content: root.wx.icon
        iconSize: Math.round(Math.min(root.width, root.height) * 0.5)
        fill: 1
        customColor: Colors.primaryContainerText
    }
}
