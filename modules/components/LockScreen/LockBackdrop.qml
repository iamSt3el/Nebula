pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Widgets

Item {
    id: root

    property string style: "veil"
    property bool preview: false
    property bool animated: !root.preview

    readonly property int _sw: root.preview ? 640 : 1920
    readonly property int _sh: root.preview ? 360 : 1080
    readonly property int _blurMax: root.preview ? 24 : 64

    readonly property bool _veil: root.style === "veil"
    readonly property bool _bloom: root.style === "bloom"
    readonly property bool _orbit: root.style === "orbit"
    readonly property bool _darkroom: root.style === "darkroom"
    readonly property bool _deck: root.style === "deck"
    readonly property bool _tessera: root.style === "tessera"
    readonly property bool _tear: root.style === "tear"

    readonly property string _rawArt: root._deck && !LockSession.greeter && !root.preview
        ? (ServiceMusic.activeTrack?.artUrl ?? "") : ""
    readonly property string _art: backBest.bestUrl !== "" ? backBest.bestUrl : root._rawArt

    BestArt {
        id: backBest
        artUrl: root._rawArt
        trackKey: root._rawArt !== "" ? (ServiceMusic.activeTrack?.title ?? "") + "|" + (ServiceMusic.activeTrack?.artist ?? "") : ""
    }

    property real settle: root.animated && (root._veil || root._orbit) ? 1.06 : 1
    NumberAnimation on settle {
        running: root.animated && (root._veil || root._orbit)
        to: 1
        duration: 1800
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1, 1]
    }

    Rectangle {
        anchors.fill: parent
        color: root._tessera ? Colors.surface
             : root._darkroom ? (LockSession.light ? Qt.tint("#140e10", Qt.alpha(Colors.primary, 0.04)) : Qt.darker(Colors.surfaceContainerLowest, 1.25))
             : "black"
    }

    component Wall: Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root._sw
        sourceSize.height: root._sh
        asynchronous: true
        cache: true
        scale: root.settle

        layer.enabled: !root._veil && !root._orbit
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: root._blurMax
            autoPaddingEnabled: false
            saturation: root._darkroom ? 0.4 : root._deck ? 0.6 : root._tear ? 0.5 : 0.3
            brightness: root._deck ? (LockSession.light ? 0.3 : -0.45) : root._bloom ? -0.08 : root._tear ? -0.42 : 0.0
        }
    }

    Wall {
        visible: !root._tessera
        source: WallpaperTheme.wallpaperScreen
        opacity: root._darkroom ? 0.16 : 1
        layer.enabled: !root._veil && !root._orbit
        transform: Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: root._darkroom || root._deck || root._bloom || root._tear ? 1.15 : 1
            yScale: root._darkroom || root._deck || root._bloom || root._tear ? 1.15 : 1
        }
    }

    Wall {
        id: artWall
        visible: root._art !== "" && status === Image.Ready
        source: root._art
        opacity: visible ? 1 : 0
        Behavior on opacity { EffectsAnim { speed: "slow" } }
        sourceSize.width: 512
        sourceSize.height: 512
        transform: Scale { origin.x: root.width / 2; origin.y: root.height / 2; xScale: 1.3; yScale: 1.3 }
    }

    Rectangle {
        anchors.fill: parent
        visible: root._orbit
        color: LockSession.light ? Qt.alpha(Colors.surface, 0.3) : Qt.rgba(0, 0, 0, 0.18)
    }

    Rectangle {
        anchors.fill: parent
        visible: root._veil
        gradient: Gradient {
            GradientStop { position: 0.00; color: Qt.alpha(LockSession.shade, 0.30) }
            GradientStop { position: 0.18; color: Qt.alpha(LockSession.shade, 0.00) }
            GradientStop { position: 0.40; color: Qt.alpha(LockSession.shade, 0.00) }
            GradientStop { position: 0.64; color: Qt.alpha(LockSession.shade, 0.55) }
            GradientStop { position: 1.00; color: Qt.alpha(LockSession.shade, 0.92) }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root._deck
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(LockSession.shade, 0.20) }
            GradientStop { position: 0.7; color: Qt.alpha(LockSession.shade, 0.72) }
            GradientStop { position: 1.0; color: Qt.alpha(LockSession.shade, 0.78) }
        }
    }

    Shape {
        anchors.fill: parent
        visible: root._bloom || root._orbit
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            startX: 0; startY: 0

            fillGradient: RadialGradient {
                centerX: root.width * 0.5
                centerY: root.height * (root._orbit ? 0.44 : 0.45)
                centerRadius: root._orbit ? root.height * 0.86 : Math.max(root.width, root.height) * 0.62
                focalX: centerX
                focalY: centerY
                focalRadius: 0

                GradientStop { position: 0.0; color: root._orbit ? Qt.alpha(LockSession.shade, 0.10) : Qt.alpha(Colors.surface, 0.35) }
                GradientStop { position: 0.45; color: root._orbit ? Qt.alpha(LockSession.shade, 0.55) : Qt.alpha(Colors.surface, 0.55) }
                GradientStop { position: 1.0; color: root._orbit ? Qt.alpha(LockSession.shade, 0.94) : Qt.alpha(Colors.surface, 0.84) }
            }

            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }

    Shape {
        anchors.fill: parent
        visible: root._tear
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            startX: 0; startY: 0

            fillGradient: RadialGradient {
                centerX: root.width * 0.5
                centerY: root.height * 0.46
                centerRadius: root.height * 0.9
                focalX: centerX
                focalY: centerY
                focalRadius: 0
                GradientStop { position: 0.0; color: Qt.alpha(Colors.primary, 0.14) }
                GradientStop { position: 0.55; color: Qt.rgba(0.04, 0.03, 0.02, 0.35) }
                GradientStop { position: 1.0; color: Qt.rgba(0.02, 0.015, 0.01, 0.8) }
            }

            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }

    Shape {
        anchors.fill: parent
        visible: root._darkroom
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            startX: 0; startY: 0

            fillGradient: RadialGradient {
                centerX: root.width * 0.78
                centerY: root.height * 0.18
                centerRadius: root.width * 0.52
                focalX: centerX
                focalY: centerY
                focalRadius: 0
                GradientStop { position: 0.0; color: Qt.alpha(Colors.tertiary, 0.16) }
                GradientStop { position: 1.0; color: Qt.alpha(Colors.tertiary, 0.0) }
            }

            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }

    Canvas {
        anchors.fill: parent
        visible: root._darkroom && !root.preview
        opacity: 0.5
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            let seed = 7
            const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647 }
            for (let i = 0; i < 9000; i++) {
                ctx.fillStyle = rnd() > 0.5 ? "rgba(255,255,255,0.06)" : "rgba(0,0,0,0.18)"
                ctx.fillRect(rnd() * width, rnd() * height, 1.4, 1.4)
            }
        }
    }
}
