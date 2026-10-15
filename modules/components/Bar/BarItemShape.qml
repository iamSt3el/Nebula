import QtQuick
import qs.modules.utils
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true
    readonly property bool verticalReady: true

    readonly property string shapeName: BarLayout.opt(root.itemId, "shape") ?? "cookie6"
    readonly property real size: BarLayout.opt(root.itemId, "size") ?? 18
    readonly property string role: BarLayout.opt(root.itemId, "role") ?? "primary"
    readonly property bool outlined: (BarLayout.opt(root.itemId, "fill") ?? "filled") === "outline"
    readonly property string motion: BarLayout.opt(root.itemId, "motion") ?? "none"
    readonly property real speed: BarLayout.opt(root.itemId, "speed") ?? 4
    readonly property int cycle: Math.round(12000 / Math.max(1, root.speed))

    implicitWidth: root.size + 8
    implicitHeight: root.size

    MaterialShapes.ShapeCanvas {
        id: canvas
        anchors.centerIn: parent
        width: root.size
        height: root.size
        roundedPolygon: ShapeLibrary.get(root.shapeName) ?? ShapeLibrary.get("circle")
        color: root.outlined ? "transparent" : BarLayout.roleColor(root.role)
        borderWidth: root.outlined ? 1.5 : 0
        borderColor: BarLayout.roleColor(root.role)

        transform: Rotation {
            origin.x: canvas.width / 2
            origin.y: canvas.height / 2
            angle: root.motion === "spin" ? spin.angle : 0
        }
    }

    QtObject {
        id: spin
        property real angle: 0
    }

    NumberAnimation {
        target: spin
        property: "angle"
        running: root.motion === "spin"
        from: 0
        to: 360
        duration: root.cycle
        loops: Animation.Infinite
    }

    SequentialAnimation {
        running: root.motion === "pulse"
        loops: Animation.Infinite

        NumberAnimation {
            target: canvas
            property: "opacity"
            from: 1
            to: 0.35
            duration: root.cycle / 2
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: canvas
            property: "opacity"
            from: 0.35
            to: 1
            duration: root.cycle / 2
            easing.type: Easing.InOutSine
        }
    }

    onMotionChanged: if (root.motion !== "pulse") canvas.opacity = 1
}
