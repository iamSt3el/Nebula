pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.LockScreen as L
import qs.modules.services

Item {
    id: root
    anchors.fill: parent

    readonly property var cfg: SettingsConfig.lockscreen ?? ({})
    readonly property var greeterCfg: SettingsConfig.greeter ?? ({})
    readonly property string activeLayout: L.LockCatalog.normalize(root.cfg.layout)
    readonly property string activeGreeter: L.LockCatalog.normalize(root.greeterCfg.layout)
    property bool greeterInstalled: false
    readonly property var clockFaces: [
        { value: "off", label: "Off", icon: "block" },
        { value: "display", label: "Display", icon: "content_cut" },
        { value: "stencil", label: "Stencil", icon: "texture" },
        { value: "matrix", label: "Matrix", icon: "grid_on" }
    ]
    readonly property string clockScreen: root.cfg.clockScreen ?? "display"
    readonly property var fieldStyles: [
        { value: "split", label: "Split", icon: "splitscreen_right" },
        { value: "classic", label: "Classic", icon: "password" }
    ]
    readonly property var toggles: [
        { key: "showDate", icon: "calendar_today", label: "Date", blurb: "Day and full date under the clock" },
        { key: "showStatus", icon: "battery_full", label: "Status", blurb: "Weather, battery, network, notifications" },
        { key: "showMusic", icon: "music_note", label: "Music", blurb: "Now playing and transport controls" },
        { key: "showPower", icon: "power_settings_new", label: "Power", blurb: "Sleep, restart and shut down" }
    ]
    readonly property int shownCount: root.toggles.filter(t => root.cfg[t.key] ?? true).length

    function patch(o) {
        const base = Object.assign({}, SettingsConfig.lockscreen)
        delete base.clockStyle
        base.layout = L.LockCatalog.normalize(base.layout)
        SettingsConfig.lockscreen = Object.assign(base, o)
    }

    Process {
        running: true
        command: ["bash", "-c",
            "systemctl is-enabled greetd >/dev/null 2>&1 "
            + "&& grep -rqs -e greeter.qml /etc/greetd/ "
            + "&& echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: root.greeterInstalled = text.trim() === "yes"
        }
    }

    component PreviewCard: Rectangle {
        id: card

        property string layoutStyle: ""
        property bool greeter: false
        default property alias actions: actionRow.data
        readonly property var entry: L.LockCatalog.entry(card.layoutStyle)

        Layout.fillWidth: true
        implicitHeight: cardCol.implicitHeight + 16
        radius: 28
        color: Colors.surfaceContainer

        ColumnLayout {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 10

            ClippingRectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: width * 0.5625
                radius: 20
                color: "black"

                L.LockPreview {
                    anchors.fill: parent
                    layoutStyle: card.layoutStyle
                    greeter: card.greeter
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 4
                Layout.bottomMargin: 4
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    CustomText { content: card.entry.label; size: 16; weight: 700; customColor: Colors.primary }
                    CustomText { Layout.fillWidth: true; content: card.entry.blurb; size: 12; elide: Text.ElideRight; customColor: Colors.outline }
                }

                RowLayout {
                    id: actionRow
                    spacing: 8
                }
            }
        }
    }

    readonly property var sleep: SettingsConfig.sleep ?? ({})
    readonly property var stages: [
        { key: "dim", icon: "brightness_low", title: "Dim the screen", subtitle: "Drops the backlight; restores on any input" },
        { key: "lock", icon: "lock", title: "Lock", subtitle: "Shows the lock screen" },
        { key: "screenOff", icon: "desktop_access_disabled", title: "Screen off", subtitle: "Powers the display down without suspending" },
        { key: "suspend", icon: "bedtime", title: "Suspend", subtitle: "Sleeps the machine; locks first" }
    ]

    function patchSleep(key, value) {
        const p = {}
        p[key] = value
        SettingsConfig.sleep = Object.assign({}, SettingsConfig.sleep, p)
    }

    function on(key) {
        return root.sleep[key + "Enabled"] ?? false
    }

    function minutes(key) {
        return root.sleep[key + "Minutes"] ?? 10
    }

    readonly property bool orderOk: {
        let last = 0
        for (const s of root.stages) {
            if (!root.on(s.key))
                continue
            if (root.minutes(s.key) < last)
                return false
            last = root.minutes(s.key)
        }
        return true
    }

    readonly property var lastStage: {
        for (let i = root.stages.length - 1; i >= 0; i--)
            if (root.on(root.stages[i].key))
                return root.stages[i]
        return null
    }

    readonly property string summary: {
        const parts = []
        for (const s of root.stages)
            if (root.on(s.key))
                parts.push(s.title.toLowerCase() + " at " + root.minutes(s.key) + " min")
        return parts.length ? parts.join(", ") : "Nothing happens when you step away"
    }

    readonly property var shortNames: ({ dim: "Dim", lock: "Lock", screenOff: "Screen off", suspend: "Suspend" })

    component LockLine: Item {
        id: line
        property string icon: ""
        property string title: ""
        property string value: ""
        property string target: ""
        signal activated()
        Layout.fillWidth: true
        implicitHeight: 42

        RippleEffect {
            anchors.fill: parent
            radius: 14
            onClicked: {
                if (line.target !== "")
                    stageView.push(line.target)
                line.activated()
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 4
            spacing: 12

            MaterialIconSymbol { content: line.icon; iconSize: 20; fill: 1; customColor: Colors.primary }

            CustomText {
                Layout.fillWidth: true
                content: line.title
                size: 14
                elide: Text.ElideRight
            }

            CustomText {
                Layout.maximumWidth: 170
                content: line.value
                size: 13
                elide: Text.ElideRight
                customColor: Colors.outline
            }

            MaterialIconSymbol { content: "chevron_right"; iconSize: 20; customColor: Colors.outline }
        }
    }

    StageView {
        id: stageView

        StagePage {
            stageId: "front"

            CustomCard {
                autoRadius: false; topRadius: 28; bottomRadius: 28

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.leftMargin: 6
                    spacing: 14

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        CustomText {
                            content: "WHEN YOU STEP AWAY"
                            size: 11
                            weight: 500
                            customColor: Colors.outline
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: !root.lastStage ? "Always awake"
                                : root.lastStage.key === "suspend" ? "Asleep after " + root.minutes("suspend") + " min"
                                : root.lastStage.title + " after " + root.minutes(root.lastStage.key) + " min"
                            family: SettingsConfig.general.displayFont ?? "Rubik"
                            renderType: Text.QtRendering
                            size: 28
                            elide: Text.ElideRight
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: root.summary.charAt(0).toUpperCase() + root.summary.slice(1)
                            size: 13
                            wrapMode: Text.WordWrap
                            customColor: Colors.outline
                        }
                    }

                    M3Button {
                        Layout.alignment: Qt.AlignTop
                        icon: "lock"
                        label: "Lock now"
                        onClicked: {
                            GlobalStates.settingsOpen = false
                            GlobalStates.lockRequested()
                        }
                    }
                }

                Item {
                    id: timeline
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    implicitHeight: 124

                    readonly property real trackY: 62
                    property string dragKey: ""
                    property int dragMin: 0
                    property int frozenSpan: 0
                    readonly property int fitSpan: {
                        let m = 0
                        for (const s of root.stages)
                            if (root.on(s.key))
                                m = Math.max(m, root.minutes(s.key))
                        return Math.max(15, Math.ceil(m * 1.15 / 5) * 5)
                    }
                    readonly property int span: timeline.frozenSpan > 0 ? timeline.frozenSpan : timeline.fitSpan

                    function minutesOf(key) {
                        return key === timeline.dragKey ? timeline.dragMin : root.minutes(key)
                    }
                    readonly property int tickStep: timeline.span <= 40 ? 5 : timeline.span <= 80 ? 10 : 20
                    readonly property var marks: {
                        const on = root.stages.filter(s => root.on(s.key))
                        return on.filter(s => s.key !== "lock").concat(on.filter(s => s.key === "lock"))
                    }

                    function pos(min) {
                        return Math.round(min / timeline.span * timeline.width)
                    }

                    Rectangle {
                        x: 0
                        y: timeline.trackY - 4
                        width: parent.width
                        height: 8
                        radius: 4
                        color: Colors.surfaceContainerHighest
                    }

                    Rectangle {
                        visible: root.lastStage !== null
                        x: 0
                        y: timeline.trackY - 4
                        width: root.lastStage ? timeline.pos(Math.max(...timeline.marks.map(m => timeline.minutesOf(m.key)))) : 0
                        height: 8
                        radius: 4
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Colors.primaryContainer }
                            GradientStop { position: 0.4; color: Colors.primary }
                            GradientStop { position: 1.0; color: Colors.secondary }
                        }
                    }

                    CustomText {
                        visible: root.lastStage === null
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: timeline.trackY - 34
                        content: "Switch on a step below to place it here"
                        size: 12
                        customColor: Colors.outline
                    }

                    Rectangle {
                        x: -7
                        y: timeline.trackY - 7
                        width: 14
                        height: 14
                        radius: 7
                        color: Colors.surfaceText
                        border.width: 3
                        border.color: Colors.surfaceContainerHigh
                    }

                    Repeater {
                        model: timeline.marks

                        Item {
                            id: mark
                            required property var modelData
                            readonly property bool isLock: mark.modelData.key === "lock"
                            readonly property bool dragging: timeline.dragKey === mark.modelData.key
                            readonly property real cx: timeline.pos(timeline.minutesOf(mark.modelData.key))
                            x: mark.cx - width / 2
                            y: 0
                            z: mark.dragging ? 2 : mark.isLock ? 1 : 0
                            width: 120
                            height: timeline.height

                            CustomText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: mark.isLock ? timeline.trackY + 30 : timeline.trackY - 42
                                content: root.shortNames[mark.modelData.key] + " · " + timeline.minutesOf(mark.modelData.key) + (mark.isLock || mark.dragging ? " min" : "")
                                size: 12
                                weight: mark.isLock ? 600 : 500
                                customColor: mark.isLock ? Colors.primary : Colors.surfaceText
                            }

                            Rectangle {
                                id: node
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: timeline.trackY - height / 2
                                width: (mark.isLock ? 48 : 36) + (mark.dragging ? 6 : nodeArea.containsMouse ? 4 : 0)
                                height: width
                                radius: mark.isLock ? 16 : 18
                                color: mark.isLock ? Colors.primary : Colors.surfaceContainerHighest
                                border.width: 4
                                border.color: Colors.surfaceContainerHigh

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: mark.modelData.icon
                                    iconSize: mark.isLock ? 22 : 18
                                    fill: 1
                                    customColor: mark.isLock ? Colors.primaryText : Colors.primary
                                }

                                Behavior on width { SpatialAnim { speed: "fast" } }

                                MouseArea {
                                    id: nodeArea
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                                    function minuteAt(mouse) {
                                        const px = nodeArea.mapToItem(timeline, mouse.x, mouse.y).x
                                        return Math.max(1, Math.min(120, Math.round(px / Math.max(1, timeline.width) * timeline.span)))
                                    }

                                    onPressed: mouse => {
                                        timeline.frozenSpan = timeline.fitSpan
                                        timeline.dragMin = root.minutes(mark.modelData.key)
                                        timeline.dragKey = mark.modelData.key
                                    }
                                    onPositionChanged: mouse => {
                                        if (!pressed)
                                            return
                                        const m = nodeArea.minuteAt(mouse)
                                        if (m >= timeline.span && timeline.span < 120)
                                            timeline.frozenSpan = Math.min(120, timeline.span + 5)
                                        timeline.dragMin = m
                                    }
                                    onReleased: {
                                        const key = timeline.dragKey
                                        const value = timeline.dragMin
                                        timeline.dragKey = ""
                                        timeline.frozenSpan = 0
                                        if (key !== "" && value !== root.minutes(key))
                                            root.patchSleep(key + "Minutes", value)
                                    }
                                    onCanceled: {
                                        timeline.dragKey = ""
                                        timeline.frozenSpan = 0
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: Math.floor(timeline.span / timeline.tickStep) + 1

                        CustomText {
                            required property int index
                            readonly property real cx: timeline.pos(index * timeline.tickStep)
                            x: Math.max(0, Math.min(timeline.width - width, cx - width / 2))
                            y: timeline.height - height
                            content: index * timeline.tickStep + (index === Math.floor(timeline.span / timeline.tickStep) ? " min" : "")
                            size: 11
                            customColor: Colors.outline
                        }
                    }
                }

                Rectangle {
                    visible: !root.orderOk
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: 16
                    color: Qt.alpha(Colors.error, 0.13)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 10

                        MaterialIconSymbol { content: "warning"; iconSize: 18; customColor: Colors.error }
                        CustomText {
                            Layout.fillWidth: true
                            content: "A later step fires before an earlier one, so it will never run."
                            size: 12
                            customColor: Colors.error
                        }
                    }
                }

                Rectangle {
                    id: lockCard
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    implicitHeight: lockRow.implicitHeight + 24
                    radius: 22
                    color: Colors.surfaceContainer

                    Rectangle {
                        visible: root.on("lock")
                        x: Math.max(18, Math.min(lockCard.width - 32, 10 + timeline.pos(root.minutes("lock")) - 7))
                        y: -7
                        width: 14
                        height: 14
                        radius: 3
                        rotation: 45
                        color: lockCard.color
                    }

                    RowLayout {
                        id: lockRow
                        x: 12
                        y: 12
                        width: parent.width - 24
                        spacing: 14

                        ClippingRectangle {
                            Layout.preferredWidth: 236
                            Layout.preferredHeight: 133
                            radius: 16
                            color: "black"

                            Loader {
                                id: previewLoader
                                anchors.fill: parent
                                active: false
                                sourceComponent: L.LockPreview {
                                    layoutStyle: root.activeLayout
                                }

                                Timer {
                                    interval: 520
                                    running: root.visible && !previewLoader.active
                                    onTriggered: previewLoader.active = true
                                }

                                opacity: previewLoader.status === Loader.Ready ? 1 : 0
                                Behavior on opacity { EffectsAnim { speed: "fast" } }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0

                            CustomText {
                                Layout.leftMargin: 8
                                Layout.bottomMargin: 4
                                content: "THE LOCK SCREEN"
                                size: 11
                                weight: 500
                                customColor: Colors.outline
                            }

                            LockLine {
                                icon: "style"
                                title: "Style"
                                value: L.LockCatalog.entry(root.activeLayout).label
                                onActivated: GlobalStates.lockSelectorOpen = true
                            }

                            LockLine {
                                icon: "schedule"
                                title: "Clock screen first"
                                value: root.clockFaces.find(f => f.value === root.clockScreen)?.label ?? ""
                                target: "clock"
                            }

                            LockLine {
                                icon: "checklist"
                                title: "Shows"
                                value: root.toggles.filter(t => root.cfg[t.key] ?? true).map(t => t.label).join(", ") || "Just the clock"
                                target: "elements"
                            }
                        }
                    }
                }
            }

            StageHeading { text: "Each step" }

            Repeater {
                model: root.stages

                StageRow {
                    id: stepRow
                    required property var modelData
                    readonly property string key: stepRow.modelData.key
                    icon: stepRow.modelData.icon
                    tonal: stepRow.key === "lock" && root.on("lock")
                    title: stepRow.modelData.title
                    subtitle: !root.on(stepRow.key) ? stepRow.modelData.subtitle
                        : "After " + root.minutes(stepRow.key) + " min"
                            + (stepRow.key === "dim" ? " · down to " + (root.sleep.dimLevel ?? 10) + "% · any input restores it"
                            : stepRow.key === "suspend" ? " · locks first" : "")
                    target: stepRow.key

                    CustomToogle {
                        isToggleOn: root.on(stepRow.key)
                        onToggled: state => root.patchSleep(stepRow.key + "Enabled", state)
                    }
                }
            }

            StageHeading { text: "More" }

            StageNavRow {
                visible: root.greeterInstalled
                icon: "login"
                title: "Login screen"
                subtitle: "Shown by greetd before you sign in"
                value: L.LockCatalog.entry(root.activeGreeter).label
                target: "login"
            }

            StageNavRow {
                icon: "build"
                title: "Rewrite the idle config"
                subtitle: "If the steps stop firing after a Hyprland update"
                target: "advanced"
            }
        }

        StageLazy {
            stageId: "clock"

            StagePage {
                stageId: "clock"
                title: "Clock screen"

                StageNote {
                    content: "A full-screen clock shows first. Any key, click or mouse movement brings up the lock screen; Esc on an empty password or 20 seconds idle goes back."
                }

                StageChoiceRow {
                    title: "Clock"
                    options: root.clockFaces
                    current: root.clockScreen
                    onPicked: v => root.patch({ clockScreen: v })
                }
            }
        }

        StageLazy {
            stageId: "elements"

            StagePage {
                stageId: "elements"
                title: "On the lock screen"

                Repeater {
                    model: root.toggles

                    StageSwitchRow {
                        required property var modelData
                        icon: modelData.icon
                        title: modelData.label
                        subtitle: modelData.blurb
                        checked: root.cfg[modelData.key] ?? true
                        onToggled: on => {
                            const o = {}
                            o[modelData.key] = on
                            root.patch(o)
                        }
                    }
                }

                StageChoiceRow {
                    title: "Password field"
                    options: root.fieldStyles
                    current: root.cfg.field ?? "split"
                    onPicked: v => root.patch({ field: v })
                }
            }
        }

        StageLazy {
            stageId: "login"

            StagePage {
                stageId: "login"
                title: "Login screen"

                StageNote {
                    content: "Shown by greetd before you sign in. It is a login screen only, so it has no music, weather, battery or network."
                }

                Loader {
                    Layout.fillWidth: true
                    active: root.greeterInstalled
                    visible: active
                    sourceComponent: PreviewCard {
                        layoutStyle: root.activeGreeter
                        greeter: true

                        M3Button {
                            icon: "style"
                            label: "Choose style"
                            onClicked: GlobalStates.lockSelectorOpen = true
                        }
                    }
                }
            }
        }

        Repeater {
            model: root.stages

            StagePage {
                id: stagePage
                required property var modelData
                stageId: modelData.key
                title: modelData.title

                StageSwitchRow {
                    icon: stagePage.modelData.icon
                    title: stagePage.modelData.title
                    subtitle: stagePage.modelData.subtitle
                    checked: root.on(stagePage.modelData.key)
                    onToggled: on => root.patchSleep(stagePage.modelData.key + "Enabled", on)
                }

                StageSliderRow {
                    enabled: root.on(stagePage.modelData.key)
                    opacity: enabled ? 1 : 0.5
                    title: "After"
                    subtitle: "Minutes without any input"
                    from: 1
                    to: 120
                    step: 1
                    current: root.minutes(stagePage.modelData.key)
                    format: v => Math.round(v) + " min"
                    onCommitted: v => root.patchSleep(stagePage.modelData.key + "Minutes", Math.round(v))
                }

                StageSliderRow {
                    visible: stagePage.modelData.key === "dim"
                    title: "Dimmed brightness"
                    subtitle: "Backlight while dimmed; avoid 0 on OLED screens"
                    from: 5
                    to: 100
                    step: 5
                    current: root.sleep.dimLevel ?? 10
                    format: v => Math.round(v) + "%"
                    onCommitted: v => root.patchSleep("dimLevel", Math.round(v))
                }
            }
        }

        StageLazy {
            stageId: "advanced"

            StagePage {
                stageId: "advanced"
                title: "Advanced"

                StageNote {
                    content: "Changes apply by themselves. Rewrite the config if the idle stages stopped working, for example after a Hyprland update."
                }

                StageNavRow {
                    icon: "restart_alt"
                    title: "Rewrite config now"
                    subtitle: "Regenerates hypridle.conf and restarts it"
                    onClicked: ServiceIdle.apply()
                }
            }
        }
    }
}
