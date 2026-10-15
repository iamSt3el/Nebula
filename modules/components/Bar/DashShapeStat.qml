import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

ColumnLayout {
    id: root

    property real value: 0
    property string shape: "cookie12"
    property string icon: ""
    property string label: ""
    property string text: Math.round(root.value * 100) + "%"
    property real maxSize: 92
    readonly property real size: Math.max(56, Math.min(root.maxSize, root.width - 6))
    property color tone: Colors.primary
    property real shown: Math.max(0, Math.min(1, root.value))
    Behavior on shown { SpatialAnim {} }

    spacing: 6

    Item {
        Layout.fillWidth: true
        implicitWidth: 56
        implicitHeight: root.size

        MaterialShapes.ShapeCanvas {
            anchors.centerIn: parent
            width: root.size * 0.74
            height: width
            roundedPolygon: ShapeLibrary.get(root.shape)
            color: Colors.surfaceContainerHighest
        }

        MaterialShapes.ShapeCanvas {
            anchors.centerIn: parent
            width: root.size
            height: root.size
            roundedPolygon: ShapeLibrary.get(root.shape)
            strokeProgress: root.shown
            strokeWidth: 5
            strokeColor: root.tone
            strokeTrackColor: Qt.alpha(Colors.outlineVariant, 0.7)
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0

            MaterialIconSymbol {
                Layout.alignment: Qt.AlignHCenter
                content: root.icon
                iconSize: Math.round(root.size * 0.21)
                fill: 1
                customColor: root.tone
            }

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: root.text
                size: Math.round(root.size * 0.18)
                weight: 800
            }
        }
    }

    CustomText {
        Layout.alignment: Qt.AlignHCenter
        content: root.label
        size: 11
        weight: 800
        customColor: Colors.outline
    }
}
