import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.LockScreen
import "../../MatrialShapes/" as MaterialShapes

Item {
    id: root
    anchors.fill: parent
    focus: true

    readonly property real u: Math.min(width / 1920, height / 1080)
    readonly property string shownName: SettingsConfig.profileName || Quickshell.env("USER") || "you"

    readonly property var actions: [
        { id: "lock", label: "Lock", icon: "lock", key: "L", shape: "square", verb: "Locking", instant: true,
          command: ["loginctl", "lock-session"] },
        { id: "sleep", label: "Sleep", icon: "bedtime", key: "S", shape: "circle", verb: "Going to sleep", instant: true,
          command: ["systemctl", "suspend"] },
        { id: "logout", label: "Log out", icon: "logout", key: "E", shape: "arch", verb: "Logging out", instant: false,
          command: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { id: "restart", label: "Restart", icon: "restart_alt", key: "R", shape: "cookie9", verb: "Restarting", instant: false,
          command: ["systemctl", "reboot"] },
        { id: "shutdown", label: "Shut down", icon: "power_settings_new", key: "P", shape: "clover4", verb: "Shutting down", instant: false,
          command: ["systemctl", "poweroff"] }
    ]

    property string pending: ""
    property int remaining: 10
    readonly property var pendingAction: root.actions.find(a => a.id === root.pending) ?? null
    readonly property bool counting: root.pending !== "" && root.remaining > 0

    readonly property var openApps: {
        const seen = []
        for (const t of ToplevelManager.toplevels.values) {
            const id = t.appId ?? ""
            if (id === "")
                continue
            const name = DesktopEntries.heuristicLookup(id)?.name ?? id
            if (seen.indexOf(name) < 0)
                seen.push(name)
        }
        return seen
    }
    readonly property string appsLine: {
        const a = root.openApps
        if (a.length === 0)
            return "Nothing else is open"
        if (a.length === 1)
            return a[0] + " is open and will close"
        if (a.length <= 4)
            return a.slice(0, -1).join(", ") + " and " + a[a.length - 1] + " will close"
        return a.slice(0, 3).join(", ") + " and " + (a.length - 3) + " more will close"
    }

    property string uptime: ""

    function close() {
        GlobalStates.shutdownWindow = false
    }

    function run(action) {
        GlobalStates.shutdownWindow = false
        Quickshell.execDetached(action.command)
    }

    function start(id) {
        const action = root.actions.find(a => a.id === id)
        if (!action || root.pending !== "")
            return
        if (action.instant) {
            root.run(action)
            return
        }
        root.remaining = 10
        root.pending = id
    }

    function cancel() {
        root.pending = ""
        root.remaining = 10
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (root.pending !== "")
                root.cancel()
            else
                root.close()
            event.accepted = true
            return
        }
        const k = event.text.toUpperCase()
        const action = root.actions.find(a => a.key === k)
        if (action) {
            root.start(action.id)
            event.accepted = true
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.counting
        onTriggered: {
            root.remaining--
            if (root.remaining <= 0 && root.pendingAction)
                root.run(root.pendingAction)
        }
    }

    Process {
        running: true
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = Math.floor(Number(text.split(" ")[0]) || 0)
                const h = Math.floor(s / 3600)
                const m = Math.floor((s % 3600) / 60)
                root.uptime = h > 0 ? "Up " + h + " h " + m + " m" : "Up " + m + " m"
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Image {
        anchors.fill: parent
        source: WallpaperTheme.wallpaperScreen
        sourceSize: Qt.size(1280, 720)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            autoPaddingEnabled: false
            brightness: -0.4
            saturation: 0.2
        }
        opacity: 0
        NumberAnimation on opacity { to: 1; duration: 400; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Colors.surface, 0.5)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.pending !== "" ? root.cancel() : root.close()
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 80 * root.u
        anchors.rightMargin: 80 * root.u
        anchors.topMargin: 60 * root.u
        spacing: 16 * root.u

        LockShapeImage {
            Layout.preferredWidth: 56 * root.u
            Layout.preferredHeight: 56 * root.u
            source: SettingsConfig.general.profile ?? ""
            shapeName: "circle"
            sourceSize: 128
        }

        ColumnLayout {
            spacing: 2 * root.u

            CustomText {
                content: root.shownName
                size: Math.round(20 * root.u)
                weight: 600
            }

            CustomText {
                content: Qt.formatDateTime(clock.date, "dddd, d MMMM · hh:mm")
                size: Math.round(15 * root.u)
                customColor: Colors.surfaceVariantText
            }
        }

        Item { Layout.fillWidth: true }

        ShutdownChip {
            u: root.u
            visible: ServiceUPower.powerLevel > 0
            icon: ServiceUPower.isCharging ? "battery_charging_full" : "battery_3_bar"
            text: Math.round(ServiceUPower.powerLevel * 100) + "%"
        }

        ShutdownChip {
            u: root.u
            visible: root.uptime !== ""
            icon: "schedule"
            text: root.uptime
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 230 * root.u
        spacing: 14 * root.u

        CustomText {
            Layout.alignment: Qt.AlignHCenter
            content: root.counting ? root.pendingAction.verb + " in " + root.remaining
                   : root.pending !== "" ? root.pendingAction.verb + "…"
                   : "See you soon, " + root.shownName
            family: SettingsConfig.general.displayFont ?? "Titan One"
            renderType: Text.QtRendering
            size: Math.round(84 * root.u)
            weight: 400
        }

        CustomText {
            Layout.alignment: Qt.AlignHCenter
            content: root.appsLine
            size: Math.round(21 * root.u)
            customColor: Colors.surfaceVariantText
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 470 * root.u
        spacing: 56 * root.u

        Repeater {
            model: root.actions

            delegate: Item {
                id: key
                required property var modelData
                required property int index
                readonly property bool mine: root.pending === key.modelData.id
                readonly property bool hot: key.modelData.id === "shutdown"
                readonly property real box: 210 * root.u
                property real enter: 0

                width: key.box
                height: key.box + 72 * root.u
                opacity: (root.pending !== "" && !key.mine ? 0.3 : 1) * key.enter
                Behavior on opacity { EffectsAnim {} }
                transform: Translate { y: (1 - key.enter) * 40 * root.u }

                SequentialAnimation on enter {
                    running: true
                    PauseAnimation { duration: 80 + key.index * 55 }
                    NumberAnimation { to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
                }

                Item {
                    id: shapeBox
                    width: key.box
                    height: key.box

                    MaterialShapes.ShapeCanvas {
                        id: shape
                        readonly property real grown: keyMouse.containsMouse && root.pending === "" ? 12 * root.u : 0
                        anchors.centerIn: parent
                        width: key.box + shape.grown
                        height: key.box + shape.grown
                        Behavior on width { SpatialAnim { speed: "fast" } }
                        Behavior on height { SpatialAnim { speed: "fast" } }
                        roundedPolygon: key.mine && root.counting ? "softBurst" : key.modelData.shape
                        color: key.mine || key.hot ? Colors.primary
                             : keyMouse.containsMouse ? Colors.surfaceContainerHighest : Qt.alpha(Colors.surfaceContainerHighest, 0.92)
                        Behavior on color { EffectsColorAnim {} }

                        RotationAnimator on rotation {
                            from: 0
                            to: 360
                            duration: 9000
                            loops: Animation.Infinite
                            running: key.mine && root.counting
                            onRunningChanged: if (!running) shape.rotation = 0
                        }
                    }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        visible: !(key.mine && root.counting)
                        content: key.modelData.icon
                        iconSize: Math.round(72 * root.u)
                        customColor: key.mine || key.hot ? Colors.primaryText : Colors.surfaceText
                    }

                    CustomText {
                        anchors.centerIn: parent
                        visible: key.mine && root.counting
                        content: String(root.remaining)
                        family: SettingsConfig.general.displayFont ?? "Titan One"
                        renderType: Text.QtRendering
                        size: Math.round(84 * root.u)
                        weight: 400
                        customColor: Colors.primaryText
                    }

                    MouseArea {
                        id: keyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.start(key.modelData.id)
                    }
                }

                RowLayout {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: shapeBox.bottom
                    anchors.topMargin: 22 * root.u
                    spacing: 10 * root.u

                    CustomText {
                        content: key.modelData.label
                        size: Math.round(22 * root.u)
                        weight: 600
                    }

                    ShutdownKeyCap { u: root.u; text: key.modelData.key }
                }
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 860 * root.u
        spacing: 14 * root.u
        visible: root.counting

        M3Button {
            size: "medium"
            variant: "tonal"
            label: "Cancel"
            onClicked: root.cancel()
        }

        M3Button {
            size: "medium"
            icon: root.pendingAction?.icon ?? ""
            label: (root.pendingAction?.label ?? "") + " now"
            onClicked: if (root.pendingAction) root.run(root.pendingAction)
        }
    }

    RowLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 52 * root.u
        spacing: 10 * root.u

        ShutdownKeyCap { u: root.u; text: "Esc" }

        CustomText {
            content: root.pending !== "" ? "cancel" : "close"
            size: Math.round(16 * root.u)
            customColor: Colors.surfaceVariantText
        }
    }
}
