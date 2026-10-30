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
    property bool bare: false

    readonly property int _sw: root.preview ? 640 : 1920
    readonly property int _sh: root.preview ? 360 : 1080
    readonly property int _blurMax: root.preview ? 24 : 64

    readonly property bool _veil: root.style === "veil"
    readonly property bool _bloom: root.style === "bloom"
    readonly property bool _deck: root.style === "deck"
    readonly property bool _tessera: root.style === "tessera"
    readonly property bool _window: root.style === "window"
    readonly property bool _carry: root.style === "carry"

    readonly property string _rawArt: root._deck && !LockSession.greeter && !root.preview
        ? (ServiceMusic.activeTrack?.artUrl ?? "") : ""
    readonly property string _art: backBest.bestUrl !== "" ? backBest.bestUrl : root._rawArt

    BestArt {
        id: backBest
        artUrl: root._rawArt
        trackKey: root._rawArt !== "" ? (ServiceMusic.activeTrack?.title ?? "") + "|" + (ServiceMusic.activeTrack?.artist ?? "") : ""
    }

    property real settle: root.animated && root._veil ? 1.06 : 1
    NumberAnimation on settle {
        running: root.animated && root._veil
        to: 1
        duration: 1800
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1, 1]
    }

    Rectangle {
        anchors.fill: parent
        color: root._window || root.bare ? "transparent"
             : root._tessera ? Colors.surface
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

        layer.enabled: !root._veil
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: root._blurMax
            autoPaddingEnabled: false
            saturation: root._deck ? 0.6 : root._carry ? 0.5 : 0.3
            brightness: root._deck ? (LockSession.light ? 0.3 : -0.45) : root._bloom ? -0.08
                      : root._carry ? (LockSession.light ? 0.22 : -0.38) : 0.0
        }
    }

    Wall {
        visible: !root._tessera && !root._window && !root.bare
        source: WallpaperTheme.wallpaperScreen
        layer.enabled: !root._veil
        transform: Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: root._deck || root._bloom || root._carry ? 1.15 : 1
            yScale: root._deck || root._bloom || root._carry ? 1.15 : 1
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
        visible: root._bloom
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            startX: 0; startY: 0

            fillGradient: RadialGradient {
                centerX: root.width * 0.5
                centerY: root.height * 0.45
                centerRadius: Math.max(root.width, root.height) * 0.62
                focalX: centerX
                focalY: centerY
                focalRadius: 0

                GradientStop { position: 0.0; color: Qt.alpha(Colors.surface, 0.35) }
                GradientStop { position: 0.45; color: Qt.alpha(Colors.surface, 0.55) }
                GradientStop { position: 1.0; color: Qt.alpha(Colors.surface, 0.84) }
            }

            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }
}
