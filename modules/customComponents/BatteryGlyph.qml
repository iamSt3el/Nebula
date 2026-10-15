import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.modules.utils
import qs.modules.settings

Item {
    id: root

    property string kind: "cell"
    property real level: 0
    property bool charging: false
    property bool plugged: false
    property bool saver: false
    property bool missing: false
    property real size: 24
    property bool showNumber: true
    property bool mono: false
    property color ink: Colors.surfaceText
    property color ground: Colors.surface
    property real zapAngle: 0
    property real zapGlow: 0
    property bool armed: false

    Timer {
        interval: 1500
        running: true
        onTriggered: root.armed = true
    }

    onOnPowerChanged: if (root.onPower && root.armed) zap.restart()

    ParallelAnimation {
        id: zap
        SequentialAnimation {
            NumberAnimation { target: root; property: "zapAngle"; to: -25; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "zapAngle"; to: 10; duration: 180; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "zapAngle"; to: 0; duration: 250; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.36, 0.64, 1, 1, 1] }
        }
        SequentialAnimation {
            NumberAnimation { target: root; property: "zapGlow"; to: 0.6; duration: 90 }
            NumberAnimation { target: root; property: "zapGlow"; to: 0; duration: 430; easing.type: Easing.OutCubic }
        }
    }

    readonly property real u: root.size / 24
    readonly property int pct: Math.max(0, Math.min(100, Math.round(root.level * 100)))
    readonly property real shown: root.missing ? 0 : root.pct / 100
    readonly property bool onPower: root.charging || root.plugged
    readonly property bool low: !root.missing && !root.onPower && !root.saver && root.pct < 20
    readonly property bool critical: root.low && root.pct <= 15

    readonly property color baseFill: root.mono ? root.ink
        : root.low ? Colors.error
        : root.onPower ? Colors.primary
        : root.saver ? Colors.tertiary
        : root.ink
    readonly property color fillColor: root.baseFill
    readonly property color onFill: root.mono ? root.ground
        : root.low ? Colors.errorText
        : root.onPower ? Colors.primaryText
        : root.saver ? Colors.tertiaryText
        : root.ground
    readonly property color lineColor: root.missing ? Colors.outline
        : root.critical && !root.mono ? Colors.error : root.ink
    readonly property color trackColor: Qt.alpha(root.ink, 0.16)

    readonly property bool isCell: root.kind === "cell"
    readonly property bool isBars: root.kind === "bars"
    readonly property bool isTall: root.kind === "tall"
    readonly property bool isPill: root.kind === "pill"
    readonly property bool isRing: root.kind === "ring"
    readonly property bool outlined: root.isCell || root.isBars || root.isTall

    readonly property bool numberFits: root.isPill ? root.size >= 20 : root.size >= 26
    readonly property bool numberShown: root.showNumber && root.numberFits && !root.missing
        && (root.isPill || (root.isRing && !root.charging))
    readonly property bool knock: root.charging && root.outlined

    function p(v) {
        return v * root.u
    }

    function pts(list) {
        const out = []
        for (let i = 0; i < list.length; i += 2)
            out.push(Qt.point(list[i] * root.u, list[i + 1] * root.u))
        out.push(out[0])
        return out
    }

    readonly property var boltPoints: root.isTall ? root.pts([13.3, 8, 8.9, 14.2, 11.6, 14.2, 10.7, 18.6, 15.1, 12.4, 12.4, 12.4])
        : root.outlined ? root.pts([12.1, 6.6, 7.7, 12.9, 10.4, 12.9, 9.4, 17.4, 13.8, 11.1, 11.1, 11.1])
        : root.isPill ? (root.numberShown ? root.pts([9.1, 7, 5.6, 12.7, 7.9, 12.7, 7, 17, 10.6, 11.3, 8.3, 11.3])
                                          : root.pts([17.1, 7, 13.6, 12.7, 15.9, 12.7, 15, 17, 18.6, 11.3, 16.3, 11.3]))
        : root.pts([13.1, 6.8, 8.9, 12.7, 11.5, 12.7, 10.6, 17.2, 14.9, 11.3, 12.3, 11.3])


    readonly property real numX: root.isPill ? (root.charging ? 20.5 : 16) : 12
    readonly property real numPx: root.isPill ? root.p(10.5) : root.p(root.pct >= 100 ? 6.6 : 8)
    readonly property real levelRight: root.isPill ? root.p(1 + 30 * root.shown) : root.size

    implicitWidth: root.isPill ? Math.round(root.size * 1.5) : root.size
    implicitHeight: root.size

    Item {
        id: body
        anchors.fill: parent
        visible: root.outlined
        layer.enabled: root.knock
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: knockMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Rectangle {
            visible: !root.isTall
            x: root.p(0.875)
            y: root.p(5.875)
            width: root.p(19.75)
            height: root.p(12.25)
            radius: root.p(3.875)
            color: "transparent"
            border.width: root.p(1.75)
            border.color: root.lineColor
        }

        Rectangle {
            visible: !root.isTall
            x: root.p(21)
            y: root.p(10)
            width: root.p(1.75)
            height: root.p(4)
            radius: width / 2
            color: root.lineColor
        }

        Rectangle {
            visible: root.isCell && root.shown > 0
            x: root.p(3.75)
            y: root.p(8.75)
            width: root.p(Math.max(1.4, 14 * root.shown))
            height: root.p(6.5)
            radius: root.p(1.25)
            color: root.fillColor
            Behavior on width { SpatialAnim { speed: "fast" } }
        }

        Repeater {
            model: root.isBars ? 4 : 0

            Rectangle {
                required property int index
                x: root.p(3.75 + index * 3.725)
                y: root.p(8.75)
                width: root.p(2.83)
                height: root.p(6.5)
                radius: root.p(0.9)
                color: index < Math.ceil(root.shown * 4) ? root.fillColor : root.trackColor
                Behavior on color { EffectsColorAnim { speed: "fast" } }
            }
        }

        Rectangle {
            visible: root.isTall
            x: root.p(5.875)
            y: root.p(3.875)
            width: root.p(12.25)
            height: root.p(18.75)
            radius: root.p(3.625)
            color: "transparent"
            border.width: root.p(1.75)
            border.color: root.lineColor
        }

        Rectangle {
            visible: root.isTall
            x: root.p(9.5)
            y: root.p(1.75)
            width: root.p(5)
            height: root.p(2)
            radius: root.p(1)
            color: root.lineColor
        }

        Rectangle {
            readonly property real h: root.p(Math.max(1.4, 13 * root.shown))
            visible: root.isTall && root.shown > 0
            x: root.p(8.75)
            y: root.p(19.75) - h
            width: root.p(6.5)
            height: h
            radius: root.p(1.25)
            color: root.fillColor
        }

        Rectangle {
            visible: root.missing
            x: root.isTall ? root.p(11) : root.p(9.75)
            y: root.isTall ? root.p(12.25) : root.p(11)
            width: root.p(2)
            height: root.p(2)
            radius: width / 2
            color: root.lineColor
        }
    }

    Item {
        id: knockMask
        anchors.fill: parent
        visible: false
        layer.enabled: root.knock

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "white"
                strokeColor: "white"
                strokeWidth: root.p(3.2)
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: root.boltPoints }
            }
        }
    }

    Item {
        id: pill
        anchors.fill: parent
        visible: root.isPill

        Rectangle {
            x: root.p(1)
            y: root.p(4)
            width: root.p(30)
            height: root.p(16)
            radius: root.p(3.5)
            color: root.trackColor
        }

        Rectangle {
            x: root.p(32.5)
            y: root.p(9)
            width: root.p(2.5)
            height: root.p(6)
            radius: root.p(1)
            color: root.shown >= 1 ? root.fillColor : root.trackColor
        }

        Item {
            x: root.p(1)
            y: root.p(4)
            width: root.p(30 * root.shown)
            height: root.p(16)
            clip: true
            Behavior on width { SpatialAnim { speed: "fast" } }

            Rectangle {
                width: root.p(30)
                height: parent.height
                radius: root.p(3.5)
                color: root.fillColor
            }
        }

        Rectangle {
            visible: root.missing
            x: root.p(13)
            y: root.p(11)
            width: root.p(6)
            height: root.p(2)
            radius: height / 2
            color: Colors.outline
        }
    }

    Shape {
        anchors.fill: parent
        visible: root.isRing
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.trackColor
            strokeWidth: root.p(2.5)
            PathAngleArc {
                centerX: root.p(12)
                centerY: root.p(12)
                radiusX: root.p(9.25)
                radiusY: root.p(9.25)
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.shown > 0 ? root.fillColor : "transparent"
            strokeWidth: root.p(2.5)
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.p(12)
                centerY: root.p(12)
                radiusX: root.p(9.25)
                radiusY: root.p(9.25)
                startAngle: -90
                sweepAngle: 360 * Math.min(0.999, root.shown)
            }
        }
    }

    Rectangle {
        visible: root.missing && root.isRing
        x: root.p(9.5)
        y: root.p(11)
        width: root.p(5)
        height: root.p(2)
        radius: height / 2
        color: Colors.outline
    }

    Item {
        anchors.fill: parent
        Shape {
            visible: root.charging
            width: root.implicitWidth
            height: root.size
            rotation: root.zapAngle
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Qt.tint(root.isRing && !root.mono ? root.fillColor : root.ink, Qt.alpha("white", root.zapGlow))
                strokeColor: "transparent"
                PathPolyline { path: root.boltPoints }
            }
        }
        Text {
            visible: root.numberShown
            width: root.p(18)
            height: root.size
            x: root.p(root.numX) - width / 2
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.pct
            color: root.isRing && root.low && !root.mono ? Colors.error : root.ink
            font.family: SettingsConfig.general.defaultFont ?? "Rubik"
            font.pixelSize: Math.max(6, Math.round(root.numPx))
            font.weight: 700
            font.features: { "tnum": 1 }
            renderType: Text.NativeRendering
        }
    }

    Item {
        visible: root.isPill
        x: 0
        width: root.levelRight
        height: root.size
        clip: true

        Shape {
            visible: root.charging
            width: root.implicitWidth
            height: root.size
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: root.onFill
                strokeColor: "transparent"
                PathPolyline { path: root.boltPoints }
            }
        }
        Text {
            visible: root.numberShown
            width: root.p(18)
            height: root.size
            x: root.p(root.numX) - width / 2
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.pct
            color: root.onFill
            font.family: SettingsConfig.general.defaultFont ?? "Rubik"
            font.pixelSize: Math.max(6, Math.round(root.numPx))
            font.weight: 700
            font.features: { "tnum": 1 }
            renderType: Text.NativeRendering
        }
    }

    Rectangle {
        readonly property real d: Math.max(9, Math.round(root.size * 0.46))
        readonly property var at: root.isTall ? [0.74, 0.8] : root.isPill ? [0.86, 0.74]
            : root.outlined ? [0.8, 0.7] : [0.8, 0.8]
        opacity: (root.plugged || root.saver) && !root.charging ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { EffectsAnim { speed: "fast" } }
        rotation: root.zapAngle
        x: Math.round(root.implicitWidth * at[0] - d / 2)
        y: Math.round(root.size * at[1] - d / 2)
        width: d
        height: d
        radius: d / 2
        color: Qt.tint(root.mono ? root.ink : root.saver ? Colors.tertiary : Colors.primary, Qt.alpha("white", root.zapGlow))
        border.width: Math.max(1, root.p(1.4))
        border.color: root.ground

        MaterialIconSymbol {
            anchors.centerIn: parent
            renderType: Math.abs(root.zapAngle) > 0.01 ? Text.QtRendering : Text.NativeRendering
            content: root.saver ? "eco" : "power"
            iconSize: parent.d * 0.66
            customColor: root.mono ? root.ground : root.saver ? Colors.tertiaryText : Colors.primaryText
        }
    }
}
