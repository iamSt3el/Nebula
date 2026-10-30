import QtQuick
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.customComponents

LockPart {
    id: tile

    property var r: ({ x: 0, y: 0, w: 0, h: 0 })
    property color fill: Colors.surfaceContainerHigh
    property real tl: 44
    property real tr: 44
    property real bl: 44
    property real br: 44
    property bool preview: false
    default property alias content: box.data

    x: tile.r.x
    y: tile.r.y
    width: tile.r.w
    height: tile.r.h
    fromScale: 0.92
    exitScale: 0.95
    exitDy: 0
    dur: 480
    outDur: 260
    fade: 1.6

    Behavior on x { enabled: !tile.preview; SpatialAnim {} }
    Behavior on y { enabled: !tile.preview; SpatialAnim {} }
    Behavior on width { enabled: !tile.preview; SpatialAnim {} }
    Behavior on height { enabled: !tile.preview; SpatialAnim {} }

    ClippingRectangle {
        id: box
        width: tile.width
        height: tile.height
        color: tile.fill
        topLeftRadius: tile.tl
        topRightRadius: tile.tr
        bottomLeftRadius: tile.bl
        bottomRightRadius: tile.br
    }
}
