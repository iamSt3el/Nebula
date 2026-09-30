import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.services

Scope {
    id: root

    required property var ripple

    readonly property string source: WallpaperTheme.wallpaperScreen !== "" ? "file://" + WallpaperTheme.wallpaperScreen : ""
    readonly property var effects: ({
        ink: { mode: 0, duration: 1600 },
        ember: { mode: 1, duration: 1900 },
        shatter: { mode: 2, duration: 1700 },
        hex: { mode: 3, duration: 1600 },
        shockwave: { mode: 4, duration: 1300 },
        vortex: { mode: 5, duration: 1500 },
        light: { mode: 6, duration: 1800 },
        melt: { mode: 7, duration: 1700 },
        blinds: { mode: 8, duration: 1500 },
        glitch: { mode: 9, duration: 900 },
        mosaic: { mode: 10, duration: 1400 }
    })
    readonly property bool glideOn: (SettingsConfig.general.wallpaperGlide ?? true) && !ServiceGameMode.active
    readonly property real overscan: root.glideOn ? 0.25 : 0
    readonly property int glideSpan: {
        let top = 1
        for (const w of Hyprland.workspaces.values)
            if (w.id > top) top = w.id
        return Math.max(5, Math.min(10, top))
    }

    readonly property string transition: {
        const t = SettingsConfig.theme.transitionType ?? ""
        return t === "none" || t === "random" || root.effects[t] ? t : "ink"
    }

    // How the image is fitted to the screen. "crop" fills the screen and cuts
    // the overflow, "fit" shows the whole image and letterboxes, "stretch"
    // distorts to fill, "tile" repeats. A portrait photo on a landscape screen
    // loses a lot to "crop", which is why this is user-selectable now.
    readonly property string fillModeName: SettingsConfig.theme.wallpaperFill ?? "crop"
    readonly property var fillModes: ({
        crop:    Image.PreserveAspectCrop,
        fit:     Image.PreserveAspectFit,
        stretch: Image.Stretch,
        tile:    Image.Tile
    })
    readonly property int fillMode: fillModes[fillModeName] ?? Image.PreserveAspectCrop

    // How the image is fitted to the screen. "crop" fills the screen and cuts
    // the overflow, "fit" shows the whole image and letterboxes, "stretch"
    // distorts to fill, "tile" repeats. A portrait photo on a landscape screen
    // loses a lot to "crop", which is why this is user-selectable now.
    readonly property string fillModeName: SettingsConfig.theme.wallpaperFill ?? "crop"
    readonly property var fillModes: ({
        crop:    Image.PreserveAspectCrop,
        fit:     Image.PreserveAspectFit,
        stretch: Image.Stretch,
        tile:    Image.Tile
    })
    readonly property int fillMode: fillModes[fillModeName] ?? Image.PreserveAspectCrop

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            anchors { top: true; left: true; right: true; bottom: true }
            color: "black"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell:wallpaper"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            property bool aFront: true
            readonly property Image frontImg: win.aFront ? imgA : imgB
            readonly property Image backImg: win.aFront ? imgB : imgA
            readonly property string wanted: root.source
            property real progress: 0
            property real swapMode: 0
            property vector2d swapOrigin: Qt.vector2d(width / 2, height / 2)
            property real swapSeed: 0

            readonly property var hmon: Hyprland.monitorFor(win.modelData)
            readonly property int liveWs: win.hmon?.activeWorkspace?.id ?? 1
            property int glideWs: 1
            onLiveWsChanged: if (win.liveWs > 0) win.glideWs = win.liveWs
            Component.onCompleted: {
                if (win.liveWs > 0) win.glideWs = win.liveWs
                win.load()
            }

            property real glide: (Math.min(win.glideWs, root.glideSpan) - 1) / (root.glideSpan - 1)
            Behavior on glide {
                NumberAnimation {
                    duration: 700
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1, 1]
                }
            }
            readonly property real imgWidth: win.width * (1 + root.overscan)
            readonly property real imgX: -win.glide * win.width * root.overscan

            function viewFor(img) {
                const nw = img.implicitWidth, nh = img.implicitHeight
                if (nw <= 0 || nh <= 0 || img.width <= 0 || img.height <= 0)
                    return Qt.vector4d(0, 0, 1, 1)
                const s = Math.max(img.width / nw, img.height / nh)
                const cx = img.width / (nw * s), cy = img.height / (nh * s)
                return Qt.vector4d((1 - cx) / 2 - img.x / img.width * cx, (1 - cy) / 2,
                                   win.width / img.width * cx, win.height / img.height * cy)
            }

            onWantedChanged: win.load()

            function load() {
                if (win.wanted === "")
                    return
                if (swap.running) {
                    swap.stop()
                    win.finish()
                }
                if (win.frontImg.source.toString() === win.wanted) {
                    win.backImg.source = ""
                    return
                }
                if (win.frontImg.status !== Image.Ready) {
                    win.frontImg.source = win.wanted
                    return
                }
                win.backImg.source = win.wanted
                if (win.backImg.status === Image.Ready)
                    win.begin()
            }

            function ready(img) {
                if (img === win.backImg && img.source.toString() === win.wanted && !swap.running)
                    win.begin()
            }

            function begin() {
                let t = root.transition
                if (t === "none") {
                    win.finish()
                    return
                }
                if (t === "random") {
                    const names = Object.keys(root.effects)
                    t = names[Math.floor(Math.random() * names.length)]
                }
                const fx = root.effects[t]
                win.swapMode = fx.mode
                win.swapOrigin = Qt.vector2d(win.width * (0.2 + Math.random() * 0.6), win.height * (0.2 + Math.random() * 0.6))
                win.swapSeed = Math.random() * 10
                swap.duration = fx.duration
                win.progress = 0
                swap.start()
            }

            function finish() {
                win.aFront = !win.aFront
                win.progress = 0
                win.backImg.source = ""
            }

            NumberAnimation {
                id: swap
                target: win
                property: "progress"
                from: 0
                to: 1
                onFinished: win.finish()
            }

            Image {
                id: imgA
                x: win.imgX
                width: win.imgWidth
                height: win.height
                visible: win.frontImg === imgA && !swap.running
                fillMode: root.fillMode
                asynchronous: true
                cache: false
                onStatusChanged: if (status === Image.Ready) win.ready(imgA)
            }

            Image {
                id: imgB
                x: win.imgX
                width: win.imgWidth
                height: win.height
                visible: win.frontImg === imgB && !swap.running
                fillMode: root.fillMode
                asynchronous: true
                cache: false
                onStatusChanged: if (status === Image.Ready) win.ready(imgB)
            }

            ShaderEffect {
                anchors.fill: parent
                visible: swap.running
                property vector2d itemSize: Qt.vector2d(width, height)
                property real progress: win.progress
                property real mode: win.swapMode
                property vector2d origin: win.swapOrigin
                property real time: win.progress * swap.duration / 1000
                property real seed: win.swapSeed
                property color accent: Colors.primary
                property vector4d fromView: win.viewFor(win.frontImg)
                property vector4d toView: win.viewFor(win.backImg)
                property var fromTex: win.frontImg
                property var toTex: win.backImg
                fragmentShader: Qt.resolvedUrl("../../../shaders/qsb/wallswap.frag.qsb")
            }

            ShaderEffect {
                anchors.fill: parent
                visible: root.ripple.moving && root.ripple.monitorName === win.modelData.name
                    && win.frontImg.status === Image.Ready
                property vector2d itemSize: Qt.vector2d(width, height)
                property vector4d r0: root.ripple.uniformFor(0)
                property vector4d r1: root.ripple.uniformFor(1)
                property vector4d r2: root.ripple.uniformFor(2)
                property vector4d r3: root.ripple.uniformFor(3)
                property vector4d r4: root.ripple.uniformFor(4)
                property vector4d r5: root.ripple.uniformFor(5)
                property vector4d r6: root.ripple.uniformFor(6)
                property vector4d r7: root.ripple.uniformFor(7)
                property vector4d r8: root.ripple.uniformFor(8)
                property vector4d r9: root.ripple.uniformFor(9)
                property color tint: Colors.primary
                property real strength: root.ripple.strength
                property vector4d view: win.viewFor(win.frontImg)
                property var source: win.frontImg
                fragmentShader: Qt.resolvedUrl("../../../shaders/qsb/ripple.frag.qsb")
            }
        }
    }
}
