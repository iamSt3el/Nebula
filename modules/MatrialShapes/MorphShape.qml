import QtQuick
import "shapes/morph.js" as Morph
import "shapes/corner-rounding.js" as CornerRounding
import "geometry/offset.js" as Offset
import "material-shapes.js" as MaterialShapes

Canvas {
    id: root

    // --- Public API ---
    property color color: "#685496"
    property bool expanded: false

    // Upper (wide) section
    property real upperWidth: 0.8       // 0.0–1.0, how wide the top panel is
    property real upperHeight: 0.55     // 0.0–1.0, how tall the upper panel is

    // Lower (stem/square) section
    property real stemWidth: 0.15       // 0.0–1.0, how wide the stem/square is
    property real stemHeight: 0.25      // 0.0–1.0, how tall the stem section is

    // Corner rounding per section
    property real topRounding: 0.08
    property real topSmoothing: 0.3
    property real stepRounding: 0.05
    property real stepSmoothing: 0.3
    property real stemRounding: 0.03
    property real stemSmoothing: 0.3

    // Border
    property real borderWidth: 0
    property color borderColor: color

    // Animation (override to customize)
    property Animation animation: NumberAnimation {
        duration: 350
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]
    }

    // --- Internals ---
    property var _currentPolygon: expanded ? _makeExpanded() : _makeCollapsed()
    property var _prevPolygon: null
    property double _progress: 1
    property var _morph: new Morph.Morph(_currentPolygon, _currentPolygon)

    on_CurrentPolygonChanged: {
        delete root._morph
        root._morph = new Morph.Morph(root._prevPolygon ?? root._currentPolygon, root._currentPolygon)
        _morphBehavior.enabled = false
        root._progress = 0
        _morphBehavior.enabled = true
        root._progress = 1
        root._prevPolygon = root._currentPolygon
    }

    Behavior on _progress {
        id: _morphBehavior
        animation: root.animation
    }

    on_ProgressChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onColorChanged: requestPaint()
    onBorderWidthChanged: requestPaint()
    onBorderColorChanged: requestPaint()

    // --- Shape builders ---
    function _makeCollapsed() {
        var halfW = stemWidth / 2
        var halfH = stemHeight / 2
        var top = 1.0 - stemHeight
        var mid = top + halfH
        var round = new CornerRounding.CornerRounding(stemRounding, stemSmoothing)
        var e = 0.002
        return MaterialShapes.customPolygon([
            new MaterialShapes.PointNRound(new Offset.Offset(0.5 - halfW,     top),  round),
            new MaterialShapes.PointNRound(new Offset.Offset(0.5 + halfW,     top),  round),
            new MaterialShapes.PointNRound(new Offset.Offset(0.5 + halfW,     mid),  round),
            new MaterialShapes.PointNRound(new Offset.Offset(0.5 + halfW - e, mid),  round),
            new MaterialShapes.PointNRound(new Offset.Offset(0.5 + halfW,     1.0),  round),
            new MaterialShapes.PointNRound(new Offset.Offset(0.5 - halfW,     1.0),  round),
            new MaterialShapes.PointNRound(new Offset.Offset(0.5 - halfW + e, mid),  round),
            new MaterialShapes.PointNRound(new Offset.Offset(0.5 - halfW,     mid),  round),
        ], 1)
    }

    function _makeExpanded() {
        var stemHalf = stemWidth / 2
        var topHalf = upperWidth / 2
        var breakY = 1.0 - stemHeight
        var roundTop = new CornerRounding.CornerRounding(topRounding, topSmoothing)
        var roundStep = new CornerRounding.CornerRounding(stepRounding, stepSmoothing)
        var roundStem = new CornerRounding.CornerRounding(stemRounding, stemSmoothing)
        var panelTop = breakY - upperHeight
        return MaterialShapes.customPolygon([
            new MaterialShapes.PointNRound(new Offset.Offset(0.5 - topHalf,  panelTop), roundTop),
            new MaterialShapes.PointNRound(new Offset.Offset(0.5 + topHalf,  panelTop), roundTop),
            new MaterialShapes.PointNRound(new Offset.Offset(0.5 + topHalf,  breakY),   roundStep),
            new MaterialShapes.PointNRound(new Offset.Offset(0.5 + stemHalf, breakY),   roundStep),
            new MaterialShapes.PointNRound(new Offset.Offset(0.5 + stemHalf, 1.0),      roundStem),
            new MaterialShapes.PointNRound(new Offset.Offset(0.5 - stemHalf, 1.0),      roundStem),
            new MaterialShapes.PointNRound(new Offset.Offset(0.5 - stemHalf, breakY),   roundStep),
            new MaterialShapes.PointNRound(new Offset.Offset(0.5 - topHalf,  breakY),   roundStep),
        ], 1)
    }

    // --- Rendering ---
    // --- Rendering ---
    onPaint: {
        var ctx = getContext("2d")
        ctx.fillStyle = root.color
        ctx.clearRect(0, 0, width, height)
        if (!root._morph) return
        const cubics = root._morph.asCubics(root._progress)
        if (cubics.length === 0) return

        ctx.save()
        // FIX: Scale X and Y independently to fill the actual component size
        ctx.scale(root.width, root.height) 

        ctx.beginPath()
        ctx.moveTo(cubics[0].anchor0X, cubics[0].anchor0Y)
        for (const cubic of cubics) {
            ctx.bezierCurveTo(
                cubic.control0X, cubic.control0Y,
                cubic.control1X, cubic.control1Y,
                cubic.anchor1X, cubic.anchor1Y
            )
        }
        ctx.closePath()
        ctx.fill()

        if (root.borderWidth > 0) {
            ctx.strokeStyle = root.borderColor
            // Adjust border width relative to scale if needed, 
            // or use a simpler stroke approach
            ctx.lineWidth = root.borderWidth / Math.max(root.width, root.height)
            ctx.stroke()
        }

        ctx.restore()
    }
}
