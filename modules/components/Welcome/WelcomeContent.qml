import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.platform
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MaterialShapeFn

Item {
    id: root
    anchors.fill: parent

    signal closed

    property int step: 0
    property bool appsVisited: false
    property string appliedKey: ""

    readonly property int lastStep: root.steps.length - 1
    readonly property bool done: root.step === root.lastStep
    readonly property Item page: stack.children[root.step] ?? null

    readonly property var steps: [
        { shape: MaterialShapeFn.getCookie9Sided(), icon: "wallpaper",
          title: "Which wallpaper feels like home?",
          sub: "Every colour in Nebula comes from it, and you can swap it any time." },
        { shape: MaterialShapeFn.getSunny(), icon: "contrast",
          title: "Light or dark?",
          sub: "The shell and the apps you pick next switch together." },
        { shape: MaterialShapeFn.getFlower(), icon: "palette",
          title: "How much colour?",
          sub: "Calm keeps things mostly grey. Vivid lets the wallpaper's colour run through everything." },
        { shape: MaterialShapeFn.getClover4Leaf(), icon: "apps",
          title: "Which apps should match?",
          sub: "Picked apps get new colours every time the wallpaper changes." },
        { shape: MaterialShapeFn.getBurst(), icon: "interests",
          title: "What do you do here most?",
          sub: "Pick any. Each one turns on the parts of Nebula that help with it." },
        { shape: MaterialShapeFn.getPuffy(), icon: "person",
          title: "Who's this desktop for?",
          sub: "A picture and name for the lock screen, and a city for the weather. All optional." },
        { shape: MaterialShapeFn.getCookie6Sided(), icon: "keyboard",
          title: "Last one: your shortcuts",
          sub: "These four open the parts of Nebula you'll reach for every day." },
        { shape: MaterialShapeFn.getCookie12Sided(), icon: "check",
          title: "", sub: "" }
    ]

    readonly property string prettyDir: {
        const home = Quickshell.env("HOME") ?? ""
        const dir = SettingsConfig.general.wallpaperDir ?? (home + "/wallpaper")
        return home !== "" && dir.startsWith(home) ? "~" + dir.slice(home.length) : dir
    }

    readonly property string colourName: {
        const s = SettingsConfig.theme.matugenScheme ?? "scheme-content"
        const named = { "scheme-neutral": "Calm", "scheme-content": "Balanced", "scheme-vibrant": "Vivid" }
        if (named[s])
            return named[s]
        const t = s.replace("scheme-", "").replace(/-/g, " ")
        return t.charAt(0).toUpperCase() + t.slice(1)
    }

    readonly property string finishTitle: {
        if (!root.appsVisited || !themeApps.scanned)
            return "You're all set"
        if (themeApps.applying || !themeApps.applied)
            return "Applying your colours"
        const n = themeApps.failed.length
        if (n > 0)
            return themeApps.okCount + " of " + themeApps.resultList.length + " apps follow your wallpaper"
        return "You're all set"
    }

    readonly property string finishSub: {
        if (root.appsVisited && themeApps.scanned && (themeApps.applying || !themeApps.applied))
            return "Writing a colour file for each app you picked."
        const n = themeApps.failed.length
        if (root.appsVisited && n > 0)
            return (n === 1 ? "One app needs" : n + " apps need") + " a hand. Everything else is written and reloaded."
        return "Change anything later in Settings, or run nebula setup to answer these again."
    }

    readonly property var summary: {
        const mode = SettingsConfig.theme.matugenTheme ?? "dark"
        const on = Features.list.filter(f => Features.on(f.id)).length
        return [
            { icon: "wallpaper", text: root.fileName(Colors.sourceWallpaper || Colors.wallpaper) },
            { icon: "contrast",  text: (mode === "light" ? "Light" : "Dark") + ", " + root.colourName.toLowerCase() + " colour" },
            !root.appsVisited
                ? { icon: "apps", text: "Apps left as they were", ok: false }
                : themeApps.applied && themeApps.failed.length > 0
                    ? { icon: "apps", text: themeApps.okCount + " of " + themeApps.resultList.length + " apps follow your colours", ok: false }
                    : { icon: "apps", text: themeApps.pickedApps.length === 1 ? "1 app follows your colours" : themeApps.pickedApps.length + " apps follow your colours" },
            { icon: "widgets", text: on + " of " + Features.list.length + " features on" },
            keybindStore.active || keybindStore.coveredByUser
                ? { icon: "keyboard", text: keybindStore.active ? "Nebula's shortcuts are on" : "Shortcuts come from your config" }
                : keybindStore.adding
                    ? { icon: "keyboard", text: "Adding Nebula's shortcuts", ok: false }
                    : { icon: "keyboard", text: "Shortcuts left to your config", ok: false }
        ]
    }

    function fileName(path) {
        const s = String(path ?? "")
        return s.substring(s.lastIndexOf("/") + 1)
    }

    function go(i) {
        const next = Math.max(0, Math.min(root.lastStep, i))
        if (next === root.step)
            return
        if (next === 3)
            root.appsVisited = true
        root.step = next
        root.forceActiveFocus()
        if (next === root.lastStep) {
            root.maybeApply()
            keybindStore.apply()
        }
    }

    function maybeApply() {
        if (!root.appsVisited || !themeApps.scanned)
            return
        const key = themeApps.pickedIds.slice().sort().join(",")
        if (key === root.appliedKey && themeApps.applied)
            return
        root.appliedKey = key
        themeApps.apply()
    }

    Connections {
        target: themeApps
        function onScannedChanged() {
            if (root.done)
                root.maybeApply()
        }
    }

    SetupApps {
        id: themeApps
    }

    SetupPalettes {
        id: paletteStore
    }

    SetupKeybinds {
        id: keybindStore
    }

    Component.onCompleted: {
        themeApps.scan()
        paletteStore.load()
        root.forceActiveFocus()
    }

    focus: true

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.done)
                root.closed()
            else
                root.go(root.step + 1)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Escape) {
            if (root.step > 0 && !root.done)
                root.go(root.step - 1)
            else
                root.closed()
            event.accepted = true
            return
        }
        const n = event.key - Qt.Key_0
        if (n >= 1 && n <= 9 && root.page && root.page.pick && root.page.pick(n))
            event.accepted = true
    }

    onStepChanged: pageIn.restart()

    opacity: 0
    NumberAnimation on opacity { from: 0; to: 1; duration: 220; running: true }

    FolderDialog {
        id: folderPicker
        title: "Select wallpaper directory"
        onAccepted: {
            SettingsConfig.general = Object.assign({}, SettingsConfig.general, {
                wallpaperDir: folder.toString().replace(/^file:\/\//, "")
            })
            GlobalStates.fileDialogOpen = false
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }

    Rectangle {
        anchors.fill: parent
        radius: 26
        color: Colors.surface
        border.width: 1
        border.color: Colors.outlineVariant
        Behavior on color { EffectsColorAnim {} }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            Rectangle {
                id: art

                Layout.fillHeight: true
                Layout.preferredWidth: 380
                color: Colors.surfaceContainerLow
                topLeftRadius: 25
                bottomLeftRadius: 25
                Behavior on color { EffectsColorAnim {} }

                RowLayout {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 28
                    anchors.topMargin: 26
                    spacing: 10

                    NebulaLogo {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        color: Colors.primary
                    }

                    CustomText {
                        content: "Nebula"
                        size: 19
                        weight: Font.Normal
                        family: SettingsConfig.general.displayFont ?? "Titan One"
                    }
                }

                MaterialShapes.ShapeCanvas {
                    id: shape
                    anchors.centerIn: parent
                    width: 280
                    height: 280
                    roundedPolygon: root.steps[root.step].shape
                    color: Colors.primaryContainer
                    rotation: root.step * 24
                    animation: SpatialAnim { speed: "slow" }
                    Behavior on rotation { SpatialAnim { speed: "slow" } }
                }

                MaterialIconSymbol {
                    anchors.centerIn: shape
                    content: root.steps[root.step].icon
                    iconSize: 92
                    fill: 1
                    customColor: Colors.primaryContainerText
                }

                Row {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 28
                    anchors.bottomMargin: 26
                    spacing: 6
                    visible: !root.done

                    KeyCap {
                        visible: (root.page?.keyTo ?? 0) > 0
                        key: (root.page?.keyFrom ?? 1) === (root.page?.keyTo ?? 1) ? String(root.page?.keyTo ?? 1) : (root.page?.keyFrom ?? 1) + "–" + (root.page?.keyTo ?? 1)
                    }

                    CustomText {
                        visible: (root.page?.keyTo ?? 0) > 0
                        anchors.verticalCenter: parent.verticalCenter
                        content: "pick   "
                        size: 12
                        customColor: Colors.outline
                    }

                    KeyCap { key: "Enter" }

                    CustomText {
                        anchors.verticalCenter: parent.verticalCenter
                        content: "next   "
                        size: 12
                        customColor: Colors.outline
                    }

                    KeyCap { key: "Esc" }

                    CustomText {
                        anchors.verticalCenter: parent.verticalCenter
                        content: root.step === 0 ? "close" : "back"
                        size: 12
                        customColor: Colors.outline
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 28
                Layout.bottomMargin: 24
                Layout.leftMargin: 44
                Layout.rightMargin: 32
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    M3WavyProgressBar {
                        Layout.preferredWidth: 300
                        Layout.preferredHeight: 12
                        progress: (root.step + 1) / (root.lastStep + 1)
                        Behavior on progress { SpatialAnim {} }
                    }

                    CustomText {
                        content: root.done ? "Done" : (root.step + 1) + " of " + root.lastStep
                        size: 13
                        weight: 400
                        customColor: Colors.outline
                    }

                    Item { Layout.fillWidth: true }

                    M3Button {
                        visible: !root.done
                        size: "small"
                        variant: "text"
                        label: "Skip setup"
                        onClicked: root.closed()
                    }
                }

                ColumnLayout {
                    id: pageColumn

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: 26
                    spacing: 8

                    transform: Translate { id: shift }

                    CustomText {
                        Layout.fillWidth: true
                        content: root.done ? root.finishTitle : root.steps[root.step].title
                        size: 36
                        weight: Font.Normal
                        family: SettingsConfig.general.displayFont ?? "Titan One"
                        renderType: Text.QtRendering
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }

                    CustomText {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 14
                        content: root.done ? root.finishSub : root.steps[root.step].sub
                        size: 15
                        weight: 400
                        customColor: Colors.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    StackLayout {
                        id: stack

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: root.step

                        QuestionWallpaper {
                            folderLabel: root.prettyDir
                            onFolderRequested: {
                                GlobalStates.fileDialogOpen = true
                                folderPicker.open()
                            }
                        }

                        QuestionMode {
                            palettes: paletteStore
                        }

                        QuestionColour {
                            palettes: paletteStore
                        }

                        QuestionApps {
                            store: themeApps
                        }

                        QuestionInterests {}

                        QuestionYou {}

                        QuestionShortcuts {
                            keybinds: keybindStore
                        }

                        SetupFinishPage {
                            store: themeApps
                            appsVisited: root.appsVisited
                            summary: root.summary
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 14
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    M3Button {
                        visible: root.step > 0 && !root.done
                        size: "small"
                        variant: "outlined"
                        label: "Back"
                        onClicked: root.go(root.step - 1)
                    }

                    M3Button {
                        visible: root.done
                        size: "small"
                        variant: "outlined"
                        label: "Start over"
                        onClicked: root.go(0)
                    }

                    M3Button {
                        size: "medium"
                        variant: "filled"
                        icon: root.done ? "rocket_launch" : root.step === root.lastStep - 1 ? "check" : "arrow_forward"
                        label: root.done ? "Open my desktop" : root.step === root.lastStep - 1 ? "Finish" : "Continue"
                        onClicked: root.done ? root.closed() : root.go(root.step + 1)
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: pageIn
        NumberAnimation { target: pageColumn; property: "opacity"; from: 0; to: 1; duration: M3Motion.effects.defaultDuration; easing.type: Easing.OutCubic }
        NumberAnimation { target: shift; property: "y"; from: 16; to: 0; duration: M3Motion.effects.defaultDuration + 120; easing.type: Easing.OutCubic }
    }
}
