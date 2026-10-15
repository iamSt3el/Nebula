import QtQuick
import qs.modules.utils
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

Item {
    id: m

    property real value: 0
    property string shape: "cookie9"
    property bool filled: false
    property real angle: 0
    property string icon: ""
    property bool showIcon: true
    property real iconSize: 0
    property real iconAngle: 0
    property bool spins: false
    property color tone: Colors.primary
    property color track: "transparent"
    property color ground: Colors.surface
    property bool onPlate: false
    property color ink: Colors.surfaceText
    property color onTone: Colors.primaryText

    property real shown: Math.max(0, Math.min(1, m.value))
    Behavior on shown { SpatialAnim {} }
    readonly property real ring: Math.max(1.5, Math.round(m.width * 0.06))
    readonly property string poly: ShapeLibrary.get(m.shape) ?? ShapeLibrary.get("circle")

    MaterialShapes.ShapeCanvas {
        anchors.centerIn: parent
        width: m.filled ? m.width : m.width - 3 * m.ring
        height: width
        roundedPolygon: m.poly
        angle: m.angle
        color: m.track
        fillLevel: m.filled ? m.shown : -1
        levelColor: m.onPlate ? Qt.tint(m.ground, Qt.alpha(m.tone, 0.35)) : m.tone
    }

    MaterialShapes.ShapeCanvas {
        anchors.fill: parent
        visible: !m.filled
        roundedPolygon: m.poly
        angle: m.angle
        strokeProgress: m.shown
        strokeWidth: m.ring
        strokeColor: m.tone
        strokeTrackColor: Qt.alpha(Colors.outlineVariant, 0.7)
    }

    MeterIcon {}

    Item {
        visible: m.filled && !m.onPlate
        y: Math.round(m.height * (1 - m.shown))
        width: m.width
        height: m.height - y
        clip: true
        MeterIcon {
            dy: parent.y
            customColor: m.onTone
        }
    }

    component MeterIcon: MaterialIconSymbol {
        property real dy: 0
        readonly property real box: 2 * Math.round((m.iconSize > 0 ? m.iconSize : m.width * 0.5) / 2)
        x: Math.round((m.width - box) / 2)
        y: Math.round((m.height - box) / 2) - dy
        width: box
        height: box
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        visible: m.showIcon && m.icon !== ""
        rotation: m.iconAngle
        renderType: m.spins ? Text.QtRendering : Text.NativeRendering
        content: m.icon
        iconSize: box
        customColor: m.ink
    }
}
