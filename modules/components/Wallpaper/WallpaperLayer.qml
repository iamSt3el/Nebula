import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.services

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell:wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: root.isPrimary && root.enabled && !ServiceGameMode.hideWidgets

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    readonly property int screenW: modelData.width
    readonly property int screenH: modelData.height

    readonly property bool enabled: SettingsConfig.parallax?.enabled ?? true
    readonly property real strength: SettingsConfig.parallax?.strength ?? 0.2
    readonly property real quality: SettingsConfig.parallax?.quality ?? 0.3

    readonly property string wallpaperPath: WallpaperTheme.wallpaper

    readonly property string depthPath: ServiceWallpaper.depthMapPath

    property bool depthLoaded: false
    readonly property bool depthReady: root.depthLoaded

    readonly property bool isPrimary: {
        const pm = SettingsConfig.general.primaryMonitor ?? ""
        const screens = Quickshell.screens
        if (pm !== "" && screens.some(s => s.name === pm))
            return root.modelData.name === pm
        return root.modelData === screens[0]
    }

    readonly property string mode: SettingsConfig.parallax?.mode ?? "cursor"

    readonly property bool interactive: root.isPrimary && root.enabled
                                        && root.depthReady && root.mode === "cursor"

    property bool _cavaHeld: false

    function _syncCava() {
        const want = root.visible && root.enabled && root.mode === "music"
        if (want && !root._cavaHeld) {
            ServiceCava.retain()
            root._cavaHeld = true
        } else if (!want && root._cavaHeld) {
            ServiceCava.release()
            root._cavaHeld = false
        }
    }

    onModeChanged:    root._syncCava()
    onEnabledChanged: root._syncCava()
    onVisibleChanged: root._syncCava()
    Component.onCompleted:   root._syncCava()
    Component.onDestruction: if (root._cavaHeld) ServiceCava.release()

    readonly property real musicIntensity: SettingsConfig.parallax?.musicIntensity ?? 0.6

    readonly property real musicLevel: {
        if (root.mode !== "music") return 0
        const d = ServiceCava.cavaData
        if (!d || d.length === 0) return 0
        let peak = 0
        for (var i = 0; i < d.length; i++)
            if (d[i] > peak) peak = d[i]
        return Math.min(1, peak)
    }

    property real phase: 0
    property real energy: 0

    readonly property real _orbitSpeed: 2 * Math.PI / 24

    FrameAnimation {
        running: root.visible && root.enabled && root.mode !== "cursor"
        onTriggered: {
            const dt = Math.min(0.1, frameTime)

            if (root.mode === "music") {
                const target = root.musicLevel
                const k = target > root.energy ? 0.45 : 0.15
                root.energy += (target - root.energy) * k
            } else if (root.energy !== 0) {
                root.energy = 0
            }

            root.phase += dt * root._orbitSpeed
            if (root.phase > 2 * Math.PI) root.phase -= 2 * Math.PI
        }
    }

    property bool swapping: false

    onWallpaperPathChanged: {
        root.swapping = true
        swapTimer.restart()
    }

    Timer {
        id: swapTimer
        interval: 4200
        repeat: false
        onTriggered: root.swapping = false
    }

    property real parallaxMix: (root.depthReady && !root.swapping) ? 1 : 0
    Behavior on parallaxMix {
        NumberAnimation { duration: 700; easing.type: Easing.OutCubic }
    }

    mask: Region {
        x: 0
        y: 0
        width:  root.interactive ? root.width  : 0
        height: root.interactive ? root.height : 0
    }

    readonly property bool cursorLive:
        root.interactive && GlobalStates.desktopCursorActive && root.width > 0 && root.height > 0

    property real offsetX: {
        if (!root.enabled) return 0
        if (root.mode === "music") return 0
        if (root.mode === "drift") return Math.sin(root.phase)
        return root.cursorLive ? (GlobalStates.desktopCursorX / root.width) * 2 - 1 : 0
    }

    property real offsetY: {
        if (!root.enabled) return 0
        if (root.mode === "music") return root.energy * root.musicIntensity
        if (root.mode === "drift") return Math.cos(root.phase) * 0.6
        return root.cursorLive ? (GlobalStates.desktopCursorY / root.height) * 2 - 1 : 0
    }

    Behavior on offsetX {
        enabled: root.mode === "cursor"
        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
    }
    Behavior on offsetY {
        enabled: root.mode === "cursor"
        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
    }

    Loader {
        id: stack
        anchors.fill: parent
        active: root.isPrimary && root.enabled && !ServiceGameMode.hideWidgets
        visible: active

        onActiveChanged: if (!active) root.depthLoaded = false

        sourceComponent: Item {
            Item {
                id: srcItem
                anchors.fill: parent

                Image {
                    anchors.fill: parent
                    source: root.wallpaperPath !== "" ? "file://" + root.wallpaperPath : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: root.screenW
                    sourceSize.height: root.screenH
                    asynchronous: true
                    cache: false
                }
            }

            Item {
                id: depthItem
                anchors.fill: parent

                Image {
                    id: depthImage
                    anchors.fill: parent
                    source: root.depthPath !== "" ? "file://" + root.depthPath : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: root.screenW
                    sourceSize.height: root.screenH
                    asynchronous: true
                    cache: false
                    onStatusChanged: root.depthLoaded = (status === Image.Ready)
                    Component.onCompleted: root.depthLoaded = (status === Image.Ready)
                }
            }

            Item {
                width: 0
                height: 0
                clip: true

                ShaderEffectSource {
                    id: srcTex
                    sourceItem: srcItem
                    hideSource: true
                    width: root.width
                    height: root.height
                    textureSize: Qt.size(root.screenW, root.screenH)
                }

                ShaderEffectSource {
                    id: depthTex
                    sourceItem: depthItem
                    hideSource: true
                    width: root.width
                    height: root.height
                    textureSize: Qt.size(root.screenW, root.screenH)
                }
            }

            ShaderEffect {
                anchors.fill: parent

                opacity: root.swapping ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 250 } }

                property variant source: srcTex
                property variant depthMap: depthTex
                property real offsetX: root.offsetX * root.parallaxMix
                property real offsetY: root.offsetY * root.parallaxMix
                property real parallaxStrength: root.strength
                property real aspectRatio: root.screenH > 0 ? root.screenW / root.screenH : 1.0
                property real quality: root.quality

                fragmentShader: Qt.resolvedUrl("../../../shaders/qsb/parallax.frag.qsb")
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true

        onPositionChanged: mouse => {
            GlobalStates.desktopCursorX = mouse.x
            GlobalStates.desktopCursorY = mouse.y
            GlobalStates.desktopCursorActive = true
        }
        onExited: GlobalStates.desktopCursorActive = false
    }
}
