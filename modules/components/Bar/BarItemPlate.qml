import QtQuick
import QtQuick.Effects
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

Item {
    id: root

    property string itemId: ""
    property real contentWidth: 0
    property real contentHeight: 0
    property real barH: 0
    property bool shown: false
    property bool turned: false
    property color fill: Colors.surface
    property string shapeOverride: ""
    property bool hovered: false
    readonly property color tone: root.hovered && root.shapeOverride === "" ? Colors.primaryContainer : root.fill

    readonly property real plateH: BarLayout.plateH(root.itemId, root.barH)
    readonly property real plateW: BarLayout.plateW(root.itemId, root.contentWidth, root.contentHeight, root.barH)
    readonly property string shapeName: root.shapeOverride !== "" ? root.shapeOverride
        : BarLayout.plateShape(root.itemId, root.contentWidth, root.contentHeight)
    readonly property real angle: BarLayout.itemStyle(root.itemId, "rotate", 0)
    readonly property real shadowSize: BarLayout.shadowReach
    readonly property real shadowAlpha: BarLayout.shadowAlpha
    readonly property real edgeW: KindleMode.outlines ? KindleMode.edge : 0

    visible: opacity > 0.01
    opacity: root.shown ? 1 : 0
    Behavior on opacity {
        EffectsAnim { speed: "fast" }
    }

    component Shade: MultiEffect {
        shadowEnabled: root.shadowSize > 0
        shadowColor: Qt.alpha(Colors.shadow, Math.min(1, root.shadowAlpha * 1.6))
        shadowBlur: 1
        blurMax: Math.max(1, Math.round(root.shadowSize))
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.plateW
        height: root.plateH
        visible: root.shapeName === ""
        radius: BarLayout.plateRadius(root.itemId, root.plateH)
        color: root.tone
        border.width: root.edgeW
        border.color: Colors.outline
        layer.enabled: visible && root.shadowSize > 0
        layer.effect: Shade {}

        Behavior on color {
            EffectsColorAnim {}
        }
    }

    Loader {
        anchors.centerIn: parent
        width: root.plateH
        height: root.plateH
        active: root.shapeName !== ""
        visible: active
        transform: Matrix4x4 {
            matrix: root.turned ? Qt.matrix4x4(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) : Qt.matrix4x4()
        }
        sourceComponent: MaterialShapes.ShapeCanvas {
            color: root.tone
            borderWidth: root.edgeW
            borderColor: Colors.outline
            roundedPolygon: ShapeLibrary.get(root.shapeName) ?? ShapeLibrary.get("circle")
            angle: root.angle
            layer.enabled: root.shadowSize > 0
            layer.effect: Shade {}

            Behavior on color {
                EffectsColorAnim {}
            }
        }
    }
}
