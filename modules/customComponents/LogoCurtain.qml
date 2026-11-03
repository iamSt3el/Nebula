import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real logoSize: 100
    property real minSize: 100
    property real spin: 0
    property color color: "black"

    readonly property real reach: Math.ceil(Math.hypot(root.width, root.height) / 2 / Math.max(1, root.minSize) * 100 + 20)
    readonly property string cover: {
        const lo = 50 - root.reach, hi = 50 + root.reach
        return "M" + lo + " " + lo + "L" + hi + " " + lo + "L" + hi + " " + hi + "L" + lo + " " + hi + "Z"
    }
    readonly property string core: "M56.4 50A6.4 6.4 0 1 0 43.6 50A6.4 6.4 0 1 0 56.4 50Z"
    readonly property string arms: geometry.armPath(0) + geometry.armPath(1) + geometry.armPath(2)

    NebulaLogo {
        id: geometry
        width: 100
        height: 100
        visible: false
        segments: 240
        progress: 1
    }

    Shape {
        width: 100
        height: 100
        x: root.width / 2 - 50
        y: root.height / 2 - 50
        scale: root.logoSize / 100
        rotation: root.spin
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillRule: ShapePath.WindingFill
            fillColor: root.color
            strokeColor: "transparent"
            PathSvg { path: root.cover + root.arms + root.core }
        }
    }
}
