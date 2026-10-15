import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Scope {
    id: edge

    readonly property string mode: SettingsConfig.notifications?.edgeLight ?? "important"
    readonly property var apps: SettingsConfig.notifications?.edgeLightApps ?? []

    property bool running: false
    property color tint: Colors.primary
    property string monitorName: ""
    property int serial: 0
    property string title: ""
    property string body: ""
    property string icon: ""

    function hueFor(name) {
        let h = 0
        const s = String(name || "")
        for (let i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) % 360
        return h / 360
    }

    function wants(item) {
        if (edge.mode === "off")
            return false
        if (SettingsConfig.notifications?.doNotDisturb ?? false)
            return false
        if (ServiceGameMode.active)
            return false
        if (item.isCritical)
            return true
        if (edge.mode === "all")
            return !item.isLow
        const list = Array.from(edge.apps ?? [])
        return list.some(a => String(a).toLowerCase() === String(item.appName ?? "").toLowerCase())
    }

    function flash(color, title, body, icon) {
        edge.tint = color
        edge.title = title ?? ""
        edge.body = body ?? ""
        edge.icon = icon ?? ""
        edge.monitorName = Hyprland.focusedMonitor?.name ?? (Quickshell.screens[0]?.name ?? "")
        edge.serial++
        edge.running = true
    }

    Connections {
        target: ServiceNotification
        function onArrived(item) {
            if (!edge.wants(item))
                return
            const icon = item.image && item.image !== "" ? item.image
                       : item.appIcon ? IconUtil.themeIcon(item.appIcon, true) : ""
            edge.flash(item.isCritical ? Colors.error : Qt.hsla(edge.hueFor(item.appName), 0.62, 0.72, 1),
                       item.summary || item.appName || "Notification", item.body ?? "", icon)
        }
    }

    IpcHandler {
        target: "edgelight"
        function test(): void { edge.flash(Colors.primary, "Edge light", "This is how an important notification arrives", "") }
    }

    Loader {
        active: edge.running
        visible: active

        sourceComponent: PanelWindow {
            id: win
            screen: Quickshell.screens.find(s => s.name === edge.monitorName) ?? Quickshell.screens[0]
            anchors { top: true; left: true; right: true; bottom: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:edgelight"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            readonly property var tune: SettingsConfig.notifications?.edgeLightTune ?? ({})
            readonly property real thick: tune.thick ?? 5
            readonly property real glowPx: tune.glow ?? 70
            readonly property real glowA: (tune.glowA ?? 45) / 100
            readonly property int dur: Math.round((tune.dur ?? 2.4) * 1000)
            readonly property int turns: tune.turns ?? 2
            readonly property real tail: tune.tail ?? 23

            property real angle: 0
            property real sweep: 0
            property real wash: 0
            property bool pillOpen: false

            Connections {
                target: edge
                function onSerialChanged() { anim.restart() }
            }

            SequentialAnimation {
                id: anim
                running: true
                onStarted: win.pillOpen = true
                onFinished: edge.running = false
                ParallelAnimation {
                    NumberAnimation { target: win; property: "angle"; from: 0; to: win.turns * Math.PI * 2; duration: win.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1] }
                    SequentialAnimation {
                        NumberAnimation { target: win; property: "sweep"; from: 0; to: 1; duration: win.dur * 0.12 }
                        PauseAnimation { duration: win.dur * 0.68 }
                        NumberAnimation { target: win; property: "sweep"; to: 0; duration: win.dur * 0.2 }
                    }
                    SequentialAnimation {
                        NumberAnimation { target: win; property: "wash"; from: 0; to: win.glowA; duration: win.dur * 0.25; easing.type: Easing.OutQuad }
                        NumberAnimation { target: win; property: "wash"; to: 0; duration: win.dur * 0.75; easing.type: Easing.InOutQuad }
                    }
                }
                ScriptAction { script: win.pillOpen = false }
                PauseAnimation { duration: 700 }
            }

            ShaderEffect {
                anchors.fill: parent
                property vector2d itemSize: Qt.vector2d(width, height)
                property color tint: edge.tint
                property real angle: win.angle
                property real sweep: win.sweep
                property real wash: win.wash
                property real thick: win.thick
                property real glow: win.glowPx
                property real radius: 16
                property real tailA: (100 - win.tail * 1.6) / 100
                property real tailB: (100 - win.tail * 0.6) / 100
                fragmentShader: Qt.resolvedUrl("../../../shaders/qsb/edgelight.frag.qsb")
            }

            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                y: 6
                width: win.pillOpen ? Math.min(360, win.width - 40) : 96
                height: win.pillOpen ? 56 : 28
                radius: height / 2
                color: "#000000"
                opacity: win.pillOpen ? 1 : 0
                Behavior on width { SpatialAnim { speed: "fast" } }
                Behavior on height { SpatialAnim { speed: "fast" } }
                Behavior on opacity { EffectsAnim { speed: "fast" } }

                Rectangle {
                    id: avatar
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 18
                    color: edge.tint
                    opacity: win.pillOpen ? 1 : 0
                    Behavior on opacity { EffectsAnim {} }

                    IconImage {
                        anchors.centerIn: parent
                        visible: edge.icon !== ""
                        implicitSize: 22
                        source: edge.icon
                    }
                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        visible: edge.icon === ""
                        content: "notifications"
                        iconSize: 20
                        fill: 1
                        customColor: "#1b140c"
                    }
                }

                Column {
                    x: avatar.x + avatar.width + 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: pill.width - x - 18
                    opacity: win.pillOpen && pill.width > 200 ? 1 : 0
                    Behavior on opacity { EffectsAnim {} }
                    CustomText {
                        width: parent.width
                        content: edge.title
                        size: 13
                        weight: 600
                        customColor: "#ffffff"
                        elide: Text.ElideRight
                    }
                    CustomText {
                        width: parent.width
                        visible: edge.body !== ""
                        content: edge.body.replace(/<[^>]*>/g, "")
                        size: 11
                        customColor: "#bbbbbb"
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }
        }
    }
}
