import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.platform
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    signal closed

    property int step: 0
    property bool appsVisited: false
    property string appliedKey: ""

    readonly property bool multiMonitor: Quickshell.screens.length > 1
    readonly property int lastStep: root.steps.length - 1

    readonly property string prettyDir: {
        const home = Quickshell.env("HOME") ?? ""
        const dir = SettingsConfig.general.wallpaperDir ?? (home + "/wallpaper")
        return home !== "" && dir.startsWith(home) ? "~" + dir.slice(home.length) : dir
    }

    readonly property var steps: [
        { label: "Wallpaper", title: "Pick a wallpaper",
          sub: "Everything in Nebula colours itself from it." },
        { label: "Colours",   title: "Tune the colours",
          sub: "Light or dark, and how bold the palette is." },
        { label: "Apps",      title: "Which apps follow your wallpaper?",
          sub: "Nebula writes a colour file for each app you pick and rewrites it every time the wallpaper changes." },
        { label: "You",       title: "Make it yours",
          sub: "Your picture, font and weather." },
        { label: "Features",  title: "Choose your features",
          sub: "Anything you leave off never runs. You can change this later in Settings › Features." },
        { label: "Shortcuts", title: "Bind your shortcuts",
          sub: "Nebula registers these. Your Hyprland config stays yours." },
        { label: "Finish",    title: "", sub: "" }
    ]

    readonly property string finishTitle: {
        if (!root.appsVisited)
            return "You're all set"
        if (themeApps.applying || !themeApps.applied)
            return "Applying the palette"
        const total = themeApps.resultList.length
        const ok = themeApps.okCount
        if (themeApps.failed.length > 0)
            return ok + " of " + total + " apps follow your wallpaper"
        return ok === 1 ? "1 app follows your wallpaper" : ok + " apps follow your wallpaper"
    }

    readonly property string finishSub: {
        if (!root.appsVisited)
            return "Change anything later in Settings, or run nebula setup again."
        if (themeApps.applying || !themeApps.applied)
            return "Writing a colour file for each app you picked."
        const n = themeApps.failed.length
        if (n === 1)
            return "One app needs a hand. Everything else is written and reloaded."
        if (n > 1)
            return n + " apps need a hand. Everything else is written and reloaded."
        return "Everything is written and reloaded."
    }

    readonly property string footerNote: {
        switch (root.step) {
        case 2: {
            const n = themeApps.pickedApps.length
            const r = themeApps.replaceCount
            let s = n === 1 ? "1 app picked." : n + " apps picked."
            if (r > 0)
                s += " " + r + (r === 1 ? " replaces a file" : " replace files") + " you already have. Nebula keeps a .bak copy first."
            return s
        }
        case 4:
            return "Copy a block into your Hyprland config."
        case 5:
            return "Run nebula setup to open this again."
        default:
            return ""
        }
    }

    function fileName(path) {
        const s = String(path ?? "")
        return s.substring(s.lastIndexOf("/") + 1)
    }

    function stepNote(i) {
        switch (i) {
        case 0:
            return root.fileName(Colors.sourceWallpaper || Colors.wallpaper)
        case 1: {
            const scheme = String(SettingsConfig.theme.matugenScheme ?? "scheme-content").replace("scheme-", "").replace(/-/g, " ")
            const mode = SettingsConfig.theme.matugenTheme ?? "dark"
            return scheme.charAt(0).toUpperCase() + scheme.slice(1) + " · " + mode
        }
        case 2:
            return themeApps.scanned ? themeApps.pickedApps.length + " picked" : "Detecting"
        case 3:
            return SettingsConfig.general.defaultFont ?? "Rubik"
        case 4:
            return "quickshell:<name>"
        default:
            return ""
        }
    }

    function go(i) {
        const next = Math.max(0, Math.min(root.lastStep, i))
        if (next === root.step)
            return
        if (next === 2)
            root.appsVisited = true
        root.step = next
        if (next === root.lastStep)
            root.maybeApply()
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
            if (root.step === root.lastStep)
                root.maybeApply()
        }
    }

    SetupApps {
        id: themeApps
    }

    Component.onCompleted: themeApps.scan()

    focus: true
    Keys.onEscapePressed: root.closed()

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

        RowLayout {
            anchors.fill: parent
            spacing: 0

            SetupRail {
                Layout.fillHeight: true
                Layout.preferredWidth: 264
                steps: root.steps
                current: root.step
                noteFor: i => root.stepNote(i)
                onStepClicked: i => root.go(i)
                onSkipClicked: root.closed()
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 28
                    Layout.leftMargin: 36
                    Layout.rightMargin: 22
                    spacing: 16

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        CustomText {
                            content: "STEP " + (root.step + 1) + " OF " + root.steps.length
                            size: 12
                            weight: 700
                            font.letterSpacing: 1.6
                            customColor: Colors.tertiary
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: root.step === root.lastStep ? root.finishTitle : root.steps[root.step].title
                            size: 32
                            weight: Font.Normal
                            family: SettingsConfig.general.displayFont ?? "Titan One"
                            elide: Text.ElideRight
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: root.step === root.lastStep ? root.finishSub : root.steps[root.step].sub
                            size: 14
                            weight: 400
                            customColor: Colors.surfaceVariantText
                            wrapMode: Text.WordWrap
                        }
                    }

                    M3IconButton {
                        Layout.alignment: Qt.AlignTop
                        icon: "close"
                        implicitWidth: 40
                        implicitHeight: 40
                        iconSize: 20
                        onClicked: root.closed()
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: 20
                    Layout.leftMargin: 36
                    Layout.rightMargin: 28
                    Layout.bottomMargin: 16

                    StackLayout {
                        id: stack
                        anchors.fill: parent
                        currentIndex: root.step

                        transform: Translate { id: shift }

                        ColumnLayout {
                            spacing: 16

                            WallpaperCarousel {
                                id: carousel
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(Math.max(160, Math.min(340, carousel.tileSize * 9 / 16)))
                                focalCount: 3
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                M3Button {
                                    size: "xsmall"
                                    variant: "tonal"
                                    icon: "folder_open"
                                    label: "Folder"
                                    onClicked: {
                                        GlobalStates.fileDialogOpen = true
                                        folderPicker.open()
                                    }
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    content: root.prettyDir
                                    size: 12
                                    weight: 400
                                    customColor: Colors.outline
                                    elide: Text.ElideMiddle
                                }

                                CustomText {
                                    content: ServiceWallpaper.wallpapers.length + " wallpapers"
                                    size: 12
                                    weight: 400
                                    customColor: Colors.outline
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }

                        SetupColoursPage {}

                        SetupAppsPage {
                            store: themeApps
                        }

                        SetupScroll {
                            id: youScroll

                            GridLayout {
                                width: youScroll.contentWidthAvail
                                columns: 2
                                columnSpacing: 12
                                rowSpacing: 12

                                TileProfile {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.alignment: Qt.AlignTop
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.alignment: Qt.AlignTop
                                    spacing: 12

                                    TileWeather {}

                                    TileDisplays { visible: root.multiMonitor }
                                }
                            }
                        }

                        SetupFeaturesPage {}

                        SetupScroll {
                            id: keysScroll

                            TileShortcuts {
                                width: keysScroll.contentWidthAvail
                            }
                        }

                        SetupFinishPage {
                            store: themeApps
                            appsVisited: root.appsVisited
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Colors.outlineVariant
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    Layout.leftMargin: 36
                    Layout.rightMargin: 22
                    spacing: 10

                    MaterialIconSymbol {
                        visible: root.step === 2 && themeApps.replaceCount > 0
                        content: "backup"
                        iconSize: 20
                        customColor: Colors.tertiary
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: root.footerNote
                        size: 13
                        weight: 400
                        customColor: Colors.surfaceVariantText
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }

                    M3Button {
                        visible: root.step > 0
                        size: "small"
                        variant: "outlined"
                        label: "Back"
                        onClicked: root.go(root.step - 1)
                    }

                    M3Button {
                        size: "small"
                        variant: "filled"
                        icon: root.step === root.lastStep ? "check" : "arrow_forward"
                        label: root.step === root.lastStep ? "Finish" : "Continue"
                        onClicked: {
                            if (root.step === root.lastStep)
                                root.closed()
                            else
                                root.go(root.step + 1)
                        }
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: pageIn
        NumberAnimation { target: stack; property: "opacity"; from: 0; to: 1; duration: M3Motion.effects.defaultDuration; easing.type: Easing.OutCubic }
        NumberAnimation { target: shift; property: "y"; from: 14; to: 0; duration: M3Motion.effects.defaultDuration + 80; easing.type: Easing.OutCubic }
    }
}
