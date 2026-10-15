import QtQuick
import qs.modules.utils
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

Item {
    id: root

    property string itemId: ""
    property real contentWidth: 0
    property real contentHeight: 0
    property real barH: 0
    property bool shown: true
    property color plateColor: "transparent"
    property bool hovered: false
    property bool turned: false

    readonly property bool tinted: BarLayout.itemStyle(root.itemId, "tint", "none") !== "none"
    readonly property bool shaped: BarLayout.chipShaped(root.itemId, root.contentWidth, root.contentHeight)
    readonly property real chipWidth: BarLayout.chipW(root.itemId, root.contentWidth, root.contentHeight, root.barH)
    readonly property real chipHeight: BarLayout.chipH(root.itemId, root.contentHeight, root.barH, root.contentWidth)
    readonly property bool platePainted: root.plateColor.a > 0.01
    readonly property color chipColor: BarLayout.chipColor(root.itemId, root.hovered)
    readonly property color fillColor: root.hovered || !root.platePainted ? root.chipColor : root.plateColor

    Rectangle {
        anchors.centerIn: parent
        width: root.chipWidth
        height: root.chipHeight
        visible: root.tinted && root.shown && !root.shaped
        radius: BarLayout.chipRadius(root.itemId, height)
        color: root.fillColor

        Behavior on color {
            EffectsColorAnim {}
        }
    }

    Loader {
        anchors.centerIn: parent
        width: root.chipHeight
        height: root.chipHeight
        active: root.tinted && root.shown && root.shaped
        visible: active
        transform: Matrix4x4 {
            matrix: root.turned ? Qt.matrix4x4(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) : Qt.matrix4x4()
        }
        sourceComponent: MaterialShapes.ShapeCanvas {
            color: root.fillColor
            roundedPolygon: ShapeLibrary.get(BarLayout.chipShape(root.itemId)) ?? ShapeLibrary.get("circle")

            Behavior on color {
                EffectsColorAnim {}
            }
        }
    }
}
