import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import Qt.labs.platform
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.WallpaperSelector

Item {
    id: root
    anchors.fill: parent

    readonly property var theme: SettingsConfig.theme ?? ({})
    readonly property string scheme: root.theme.matugenScheme ?? "scheme-content"
    readonly property string schemeLabel: root.prettyScheme(root.scheme)
    readonly property string palette: root.theme.gowallTheme ?? "off"
    readonly property bool gowallOn: root.palette !== "off"
    readonly property bool iconsOn: root.theme.gowallIcons ?? false
    readonly property bool inverted: root.theme.gowallInvert ?? false
    readonly property bool shellOn: root.theme.gowallShell ?? false
    readonly property string wallpaperDir: SettingsConfig.general.wallpaperDir ?? (Quickshell.env("HOME") + "/wallpaper")
    readonly property string fill: Settings.wallpaperFillOrDefault(SettingsConfig.general.wallpaperFill)
    readonly property var appNames: ({
        kitty: "kitty", tmux: "tmux", starship: "Starship", btop: "btop", hyprland: "Hyprland borders",
        gtk3: "GTK 3", gtk4: "GTK 4", qt: "Qt", papirus: "Papirus folders", firefox: "Firefox and Zen",
        obsidian: "Obsidian", waybar: "Waybar", nwgdock: "nwg-dock"
    })
    readonly property var followers: {
        const ids = root.theme.themeApps
        return Array.isArray(ids) ? ids.map(id => root.appNames[id] ?? id) : ["Every installed app"]
    }

    function prettyScheme(s) {
        const t = String(s).replace("scheme-", "").replace(/-/g, " ")
        return t.charAt(0).toUpperCase() + t.slice(1)
    }

    function patchTheme(p) {
        SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, p)
    }

    function patchGeneral(p) {
        SettingsConfig.general = Object.assign({}, SettingsConfig.general, p)
    }

    function setKindle(on) {
        if (on === KindleMode.active)
            return
        const t = SettingsConfig.theme
        root.patchTheme(on ? { matugenScheme: "scheme-kindle", kindlePrevScheme: t.matugenScheme }
                           : { matugenScheme: t.kindlePrevScheme ?? "scheme-content" })
        ServiceWallpaper.reapply()
    }

    function setPalette(name) {
        if (!name || name === root.palette)
            return
        const turningOff = name === "off"
        root.patchTheme({ gowallTheme: name, gowallIcons: turningOff ? false : root.iconsOn })
        if (turningOff && root.iconsOn)
            ServiceWallpaper.restoreIconTheme()
        ServiceWallpaper.refreshIconPreview(name)
        ServiceWallpaper.reapply()
    }

    component SchemeChip: Rectangle {
        id: chip
        required property var modelData
        readonly property string value: chip.modelData.name
        readonly property bool active: root.scheme === chip.value
        readonly property bool kindle: chip.value === "scheme-kindle"
        readonly property var dots: chip.kindle ? ["#000000", "#eeeeee", "#ffffff"]
            : chip.active ? [Colors.primary, Colors.secondaryContainer, Colors.tertiary] : []
        Layout.fillWidth: true
        implicitHeight: 44
        radius: 14
        color: chip.active ? Colors.primary : chipArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainer

        Row {
            anchors.centerIn: parent
            spacing: 10
            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.dots.length > 0
                spacing: -5
                Repeater {
                    model: chip.dots
                    Rectangle {
                        required property var modelData
                        width: 16
                        height: 16
                        radius: 8
                        color: modelData
                        border.width: 1.5
                        border.color: Colors.outlineVariant
                    }
                }
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: root.prettyScheme(chip.value)
                size: 13
                customColor: chip.active ? Colors.primaryText : Colors.surfaceText
            }
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (chip.active)
                    return
                const t = SettingsConfig.theme
                root.patchTheme(chip.kindle ? { matugenScheme: chip.value, kindlePrevScheme: t.matugenScheme }
                                            : { matugenScheme: chip.value })
                ServiceWallpaper.reapply()
            }
        }
    }

    component Pin: Rectangle {
        id: pin
        property string number: ""
        property string label: ""
        property string target: ""
        implicitWidth: pinRow.implicitWidth + 16
        implicitHeight: 30
        radius: 15
        color: pinArea.containsMouse ? Qt.alpha(Colors.surfaceContainerHighest, 0.95) : Qt.alpha(Colors.surface, 0.86)

        Row {
            id: pinRow
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                radius: 11
                color: Colors.primary

                CustomText {
                    anchors.centerIn: parent
                    content: pin.number
                    size: 11
                    weight: 600
                    customColor: Colors.primaryText
                }
            }

            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: pin.label
                size: 12
                weight: 500
            }
        }

        MouseArea {
            id: pinArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: stages.push(pin.target)
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    FolderDialog {
        id: folderPicker
        title: "Select wallpaper directory"
        onAccepted: {
            root.patchGeneral({ wallpaperDir: folderPicker.folder.toString().replace(/^file:\/\//, "") })
            GlobalStates.fileDialogOpen = false
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }

    Timer {
        id: kindleAnsiApply
        interval: 400
        onTriggered: ServiceWallpaper.applyTheme()
    }

    readonly property var general: SettingsConfig.general ?? ({})
    readonly property string primary: root.general.primaryMonitor ?? ""
    readonly property var scales: [
        { value: "compact", label: "Compact" }, { value: "normal", label: "Normal" },
        { value: "large", label: "Large" }, { value: "xlarge", label: "X-Large" }
    ]
    readonly property var weights: [
        { value: "thin", label: "Thin" }, { value: "regular", label: "Regular" }, { value: "medium", label: "Medium" },
        { value: "semibold", label: "Semibold" }, { value: "bold", label: "Bold" }, { value: "extrabold", label: "Extrabold" }
    ]
    readonly property string fontWeight: root.general.fontWeight ?? "extrabold"

    function patch(p) {
        SettingsConfig.general = Object.assign({}, SettingsConfig.general, p)
    }

    function editBar() {
        GlobalStates.settingsOpen = false
        GlobalStates.openEdit("edges")
    }

    StageView {
        id: stages
        StagePage {
            stageId: "front"

            CustomCard {
                id: preview
                autoRadius: false; topRadius: 28; bottomRadius: 28

                readonly property string wpPath: Colors.wallpaper ?? ""
                readonly property bool hasWallpaper: wpPath.length > 0
                readonly property string wpName: hasWallpaper ? wpPath.substring(wpPath.lastIndexOf("/") + 1) : "No wallpaper"
                readonly property int wsCount: Math.max(1, Math.min(6, root.general.workspaceCount ?? 10))
                readonly property string greeting: clock.hours < 12 ? "Good morning" : clock.hours < 18 ? "Good afternoon" : "Good evening"

                ClippingRectangle {
                    id: desk
                    Layout.fillWidth: true
                    implicitHeight: 340
                    radius: 20
                    color: Colors.surfaceContainerHighest

                    Image {
                        anchors.fill: parent
                        visible: preview.hasWallpaper
                        source: !preview.hasWallpaper ? ""
                            : KindleMode.wallpaper !== "keep" && WallpaperTheme.wallpaperScreen !== "" ? "file://" + WallpaperTheme.wallpaperScreen
                            : "file://" + preview.wpPath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(1280, 680)
                    }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        visible: !preview.hasWallpaper
                        content: "image"
                        iconSize: 32
                        customColor: Colors.outline
                    }

                    Rectangle {
                        x: 12
                        y: 10
                        width: parent.width - 24
                        height: 30
                        radius: 15
                        color: Qt.alpha(Colors.surface, 0.9)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            MaterialIconSymbol { content: "apps"; iconSize: 15; fill: 1; customColor: Colors.primary }

                            Row {
                                spacing: 4
                                Repeater {
                                    model: preview.wsCount
                                    Rectangle {
                                        required property int index
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: index === 0 ? 18 : 8
                                        height: 8
                                        radius: 4
                                        color: index === 0 ? Colors.primary : index < 3 ? Colors.outline : Colors.outlineVariant
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            CustomText {
                                content: Qt.formatDateTime(clock.date, "ddd d MMM · hh:mm")
                                size: 11
                                weight: 500
                            }

                            Item { Layout.fillWidth: true }

                            MaterialIconSymbol { content: "lan"; iconSize: 14; fill: 1 }
                            MaterialIconSymbol { content: "volume_up"; iconSize: 14; fill: 1 }
                            MaterialIconSymbol { content: "battery_5_bar"; iconSize: 14; fill: 1 }
                        }
                    }

                    Rectangle {
                        id: deskPanel
                        x: 22
                        y: parent.height - height - 22
                        width: 236
                        height: deskPanelCol.implicitHeight + 28
                        radius: 20
                        color: Qt.alpha(Colors.surfaceContainer, 0.93)

                        ColumnLayout {
                            id: deskPanelCol
                            x: 16
                            y: 14
                            width: parent.width - 32
                            spacing: 6

                            CustomText {
                                Layout.fillWidth: true
                                content: preview.greeting
                                family: root.general.displayFont ?? "Rubik"
                                renderType: Text.QtRendering
                                size: 22
                                elide: Text.ElideRight
                            }

                            CustomText {
                                Layout.fillWidth: true
                                content: (root.general.defaultFont ?? "Rubik") + " sets every label. " + (root.general.displayFont ?? "Titan One") + " sets the big titles and numbers."
                                size: 12
                                wrapMode: Text.WordWrap
                                customColor: Colors.outline
                            }
                        }
                    }

                    Pin { x: Math.round(parent.width * 0.55); y: 150; number: "1"; label: "Wallpaper"; target: "wallpaper" }
                    Pin { x: parent.width - width - 22; y: 50; number: "2"; label: "Bar"; target: "bar" }
                    Pin { x: 40; y: 50; number: "3"; label: "Workspaces"; target: "workspaces" }
                    Pin { x: deskPanel.x + deskPanel.width - 30; y: deskPanel.y - height / 2; number: "4"; label: "Fonts"; target: "fonts" }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 14

                    Row {
                        spacing: -8
                        Repeater {
                            model: KindleMode.active ? ["#000000", "#555555", "#999999", "#dddddd", "#ffffff"]
                                : [Colors.primary, Colors.secondary, Colors.tertiaryContainer, Colors.primaryContainer, Colors.surfaceContainerHighest]
                            Rectangle {
                                required property var modelData
                                width: 30
                                height: 30
                                radius: 15
                                color: modelData
                                border.width: 3
                                border.color: Colors.surfaceContainerHigh
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 11
                        color: Colors.primary

                        CustomText {
                            anchors.centerIn: parent
                            content: "5"
                            size: 11
                            weight: 600
                            customColor: Colors.primaryText
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: schemeCol.implicitHeight

                        ColumnLayout {
                            id: schemeCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            CustomText {
                                Layout.fillWidth: true
                                content: KindleMode.active ? "Kindle greys" : root.schemeLabel + " colours"
                                size: 14
                                elide: Text.ElideRight
                            }

                            CustomText {
                                Layout.fillWidth: true
                                content: preview.hasWallpaper ? "Picked from the wallpaper" : Settings.activeTheme + " theme"
                                size: 12
                                elide: Text.ElideRight
                                customColor: Colors.outline
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: stages.push("colours")
                        }
                    }

                    M3ButtonGroup {
                        Layout.preferredHeight: 36
                        height: 36
                        textSize: 13
                        iconSize: 16
                        model: [{ value: "light", label: "Light", icon: "light_mode" }, { value: "dark", label: "Dark", icon: "dark_mode" }]
                        activeCheck: v => (root.theme.matugenTheme ?? "dark") === v
                        onSegmentClicked: v => ServiceWallpaper.flipMode(v)
                    }

                    M3Button {
                        variant: "tonal"
                        icon: "edit"
                        label: "Edit the bar"
                        onClicked: root.editBar()
                    }
                }
            }

            StageHeading { text: "Picture" }

            StageNavRow {
                icon: "wallpaper"
                badge: "1"
                title: "Wallpaper"
                subtitle: preview.wpName + " · " + root.fill + " · " + Settings.transitionOrDefault(root.theme.transitionType)
                target: "wallpaper"
            }

            StageNavRow {
                icon: "travel_explore"
                title: "Wallhaven"
                subtitle: "Search and download wallpapers online"
                value: (SettingsConfig.wallhaven.apiKey ?? "") !== "" ? "Key set" : "No key"
                target: "wallhaven"
            }

            StageNavRow {
                icon: "format_paint"
                title: "Gowall"
                subtitle: "Repaint the wallpaper and icons with a fixed palette"
                value: root.gowallOn ? root.palette : "Off"
                target: "gowall"
            }

            StageHeading { text: "Colour" }

            StageNavRow {
                icon: "palette"
                badge: "5"
                title: "Colours"
                subtitle: KindleMode.active ? "Kindle greys"
                    : root.schemeLabel + " scheme · " + (Array.isArray(root.theme.themeApps) ? root.followers.length + " apps follow it" : "every app follows it")
                target: "colours"
            }

            StageRow {
                icon: "menu_book"
                title: "Kindle mode"
                subtitle: "Fixed e-ink greys for the shell and your apps"
                target: "kindle"

                CustomToogle {
                    isToggleOn: KindleMode.active
                    onToggled: state => root.setKindle(state)
                }
            }

            StageHeading { text: "Text and bar" }

            StageNavRow {
                icon: "text_fields"
                badge: "4"
                title: "Fonts"
                subtitle: (root.general.defaultFont ?? "Rubik") + " · " + (root.general.displayFont ?? "Titan One")
                target: "fonts"
            }

            StageNavRow {
                icon: "toolbar"
                badge: "2"
                title: "Bar"
                subtitle: root.primary === "" ? "Full bar on every screen" : "Full bar on " + root.primary
                target: "bar"
            }

            StageNavRow {
                icon: "view_week"
                badge: "3"
                title: "Workspaces"
                subtitle: (root.general.workspaceCount ?? 10) + ((root.general.perMonitorWorkspaces ?? false) ? " · each screen has its own" : " · shared by every screen")
                target: "workspaces"
            }
        }

        StageLazy {
            stageId: "wallpaper"

            StagePage {
                stageId: "wallpaper"
                title: "Wallpaper"

                StageNavRow {
                    icon: "folder"
                    title: "Folder"
                    subtitle: "New wallpapers are picked at random from here"
                    value: root.wallpaperDir
                    onClicked: {
                        GlobalStates.fileDialogOpen = true
                        folderPicker.open()
                    }
                }

                StageDropdownRow {
                    icon: "animation"
                    title: "Transition"
                    subtitle: "Animation when the wallpaper changes"
                    options: Settings.transitionTypes
                    current: Settings.transitionOrDefault(root.theme.transitionType)
                    onPicked: name => root.patchTheme({ transitionType: name })
                }

                StageGap {}

                StageChoiceRow {
                    title: "Fit"
                    subtitle: root.fill === "fill" ? "Stretched to the screen edges"
                        : root.fill === "full" ? "The whole image, with bars where it doesn't reach"
                        : "Covers the screen, trimming what doesn't fit"
                    options: Settings.wallpaperFills
                    current: root.fill
                    onPicked: v => root.patchGeneral({ wallpaperFill: v })
                }

                StageSwitchRow {
                    title: "Workspace glide"
                    subtitle: root.fill === "full" ? "Off while the whole wallpaper is shown" : "The wallpaper slides a little when you switch workspace"
                    checked: SettingsConfig.general.wallpaperGlide ?? true
                    onToggled: on => root.patchGeneral({ wallpaperGlide: on })
                }
            }
        }

        StageLazy {
            stageId: "colours"

            StagePage {
                stageId: "colours"
                title: "Colours"

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    visible: !ServiceWallpaper.gowallActive && !KindleMode.active

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            CustomText { content: "Wallpaper colours"; size: 14 }
                            CustomText {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                content: themeSeeds.seeds.length > 1
                                    ? "Other themes hiding in this wallpaper; the first is picked automatically"
                                    : "This wallpaper has one clear colour"
                                size: 12; customColor: Colors.outline
                            }
                        }
                        SeedSwatches {
                            id: themeSeeds
                            path: ServiceWallpaper.currentSource
                            disc: 28
                        }
                    }
                }

                CustomCard {
                    autoRadius: false
                    topRadius: !ServiceWallpaper.gowallActive && !KindleMode.active ? 5 : 20
                    bottomRadius: 20

                    ColumnLayout {
                        spacing: 2
                        CustomText { content: "Colour scheme"; size: 14 }
                        CustomText {
                            content: KindleMode.active ? "Kindle ignores the wallpaper and uses fixed greys" : "How colours are pulled from your wallpaper"
                            size: 12; customColor: Colors.outline
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        columns: 3
                        columnSpacing: 6
                        rowSpacing: 6
                        Repeater {
                            model: Settings.matugen
                            SchemeChip {}
                        }
                    }
                }
            }
        }

        StageLazy {
            stageId: "kindle"

            StagePage {
                stageId: "kindle"
                title: "Kindle mode"

                StageSwitchRow {
                    icon: "menu_book"
                    title: "Kindle mode"
                    subtitle: "Fixed e-ink greys for the shell and your apps"
                    checked: KindleMode.active
                    onToggled: on => root.setKindle(on)
                }

                StageGap {}

                StageSwitchRow {
                    enabled: KindleMode.active
                    title: "Outlines instead of shadows"
                    subtitle: "The bar, dock and panels get a 2 px edge and panel shadows switch off"
                    checked: root.theme.kindleOutlines ?? true
                    onToggled: on => root.patchTheme({ kindleOutlines: on })
                }

                StageChoiceRow {
                    enabled: KindleMode.active
                    title: "Wallpaper"
                    subtitle: {
                        const w = root.theme.kindleWallpaper ?? "blank"
                        if (w === "eink")
                            return ServiceWallpaper.gowallAvailable ? "Your wallpaper in the Kindle's 16 greys, through gowall"
                                                                    : "gowall isn't installed, so this falls back to greyscale"
                        if (w === "grey")
                            return "Your wallpaper, in greys"
                        if (w === "keep")
                            return "Your wallpaper, unchanged"
                        return "A plain page behind the windows"
                    }
                    options: [
                        { value: "blank", label: "Blank page", icon: "description" },
                        { value: "eink", label: "E-ink", icon: "gradient" },
                        { value: "grey", label: "Greyscale", icon: "filter_b_and_w" },
                        { value: "keep", label: "Keep mine", icon: "wallpaper" }
                    ]
                    current: root.theme.kindleWallpaper ?? "blank"
                    onPicked: v => root.patchTheme({ kindleWallpaper: v })
                }

                StageSwitchRow {
                    enabled: KindleMode.active
                    title: "Grey app icons"
                    subtitle: "Dock, launcher, tray, window title and notification icons lose their colour"
                    checked: root.theme.kindleGreyIcons ?? true
                    onToggled: on => root.patchTheme({ kindleGreyIcons: on })
                }

                StageSwitchRow {
                    enabled: KindleMode.active
                    title: "Grey terminal colours"
                    subtitle: (root.theme.kindleGreyAnsi ?? false) ? "Terminal colours become grey tones" : "Terminals keep their normal colours"
                    checked: root.theme.kindleGreyAnsi ?? false
                    onToggled: on => {
                        root.patchTheme({ kindleGreyAnsi: on })
                        kindleAnsiApply.restart()
                    }
                }

                StageHeading { text: "Apps that follow" }

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 20

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: root.followers
                            Rectangle {
                                required property var modelData
                                width: appRow.implicitWidth + 24
                                height: 30
                                radius: 15
                                color: Colors.surfaceContainer
                                Row {
                                    id: appRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    MaterialIconSymbol { anchors.verticalCenter: parent.verticalCenter; content: "check"; iconSize: 15 }
                                    CustomText { anchors.verticalCenter: parent.verticalCenter; content: modelData; size: 12 }
                                }
                            }
                        }
                    }
                }
            }
        }

        StageLazy {
            stageId: "gowall"

            StagePage {
                stageId: "gowall"
                title: "Gowall"

                StageDropdownRow {
                    icon: "format_paint"
                    title: "Palette"
                    subtitle: {
                        if (!ServiceWallpaper.gowallChecked)
                            return "Checking for gowall…"
                        if (!ServiceWallpaper.gowallAvailable)
                            return "gowall is not installed"
                        if (root.palette === "match")
                            return "Follows the colours the shell already uses"
                        if (root.gowallOn)
                            return "Wallpaper and colours follow the " + root.palette + " palette"
                        return "Off; the wallpaper keeps its own colours"
                    }
                    options: ServiceWallpaper.gowallOptions
                    current: root.palette
                    Component.onCompleted: {
                        ServiceWallpaper.refreshGowallThemes(false)
                        ServiceWallpaper.refreshIconPreview(root.palette)
                    }
                    onPicked: name => root.setPalette(name)
                }

                StageSwitchRow {
                    title: "Invert colours"
                    subtitle: root.inverted ? (root.gowallOn ? "Wallpaper is flipped, then repainted" : "Wallpaper is flipped, so daylight reads as night")
                                            : "Flip the wallpaper's colours; a day scene becomes night"
                    checked: root.inverted
                    onToggled: on => {
                        root.patchTheme({ gowallInvert: on })
                        ServiceWallpaper.reapply()
                    }
                }

                StageSwitchRow {
                    visible: root.gowallOn
                    title: "Use the palette for the shell"
                    subtitle: root.palette === "match" ? "match already is the shell's palette"
                        : root.shellOn ? "Interface colours come from " + root.palette + ", not the wallpaper"
                        : "Colour the interface from the palette instead of the wallpaper"
                    checked: root.shellOn
                    onToggled: on => {
                        root.patchTheme({ gowallShell: on })
                        ServiceWallpaper.reapply()
                    }
                }

                StageSwitchRow {
                    visible: root.gowallOn
                    title: "Recolour icons"
                    subtitle: ServiceWallpaper.iconBusy ? ServiceWallpaper.iconStatus
                        : !root.iconsOn ? "Rebuild your icon theme in this palette (takes about 10 s)"
                        : ServiceWallpaper.iconThemeName.length > 0 ? "Using " + ServiceWallpaper.iconThemeName
                        : "Icon theme follows the palette"
                    checked: root.iconsOn
                    onToggled: on => {
                        root.patchTheme({ gowallIcons: on })
                        if (on)
                            ServiceWallpaper.buildGowallIcons(false)
                        else
                            ServiceWallpaper.restoreIconTheme()
                    }

                    below: [
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: ServiceWallpaper.iconPreview.length > 0

                            Repeater {
                                model: [{ label: "Original", key: "before" }, { label: root.palette, key: "after" }]

                                RowLayout {
                                    id: previewRow
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 8

                                    CustomText {
                                        Layout.preferredWidth: 64
                                        content: previewRow.modelData.label
                                        size: 11
                                        customColor: Colors.outline
                                        elide: Text.ElideRight
                                    }

                                    Repeater {
                                        model: ServiceWallpaper.iconPreview

                                        Image {
                                            required property var modelData
                                            Layout.preferredWidth: 34
                                            Layout.preferredHeight: 34
                                            source: "file://" + modelData[previewRow.modelData.key]
                                            sourceSize: Qt.size(68, 68)
                                            asynchronous: true
                                            smooth: true
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }

                                    Item { Layout.fillWidth: true }
                                }
                            }
                        },
                        M3WavyProgressBar {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 12
                            visible: ServiceWallpaper.iconBusy
                            progress: ServiceWallpaper.iconProgress
                            indeterminate: ServiceWallpaper.iconProgress <= 0
                        }
                    ]
                }
            }
        }

        StageLazy {
            stageId: "wallhaven"

            StagePage {
                stageId: "wallhaven"
                title: "Wallhaven"

                StageFieldRow {
                    icon: "key"
                    title: "API key"
                    subtitle: "Optional. Needed for adult content and faster searches"
                    fieldIcon: "key"
                    secret: true
                    allowEmpty: true
                    text: SettingsConfig.wallhaven.apiKey ?? ""
                    placeholder: "Paste your key"
                    onSubmitted: t => SettingsConfig.wallhaven = Object.assign({}, SettingsConfig.wallhaven, { apiKey: t })
                }
            }
        }

        StageLazy {
            stageId: "fonts"

            StagePage {
                stageId: "fonts"
                title: "Fonts"

                StageDropdownRow {
                    icon: "text_fields"
                    title: "Body font"
                    subtitle: "Applied to all UI text"
                    options: Settings.fonts
                    current: root.general.defaultFont ?? "Rubik"
                    onPicked: name => root.patch({ defaultFont: name })
                }

                StageDropdownRow {
                    icon: "format_size"
                    title: "Display font"
                    subtitle: "Clocks, dates and headings"
                    options: Settings.displayFonts
                    current: root.general.displayFont ?? "Titan One"
                    onPicked: name => root.patch({ displayFont: name })
                }

                StageGap {}

                StageChoiceRow {
                    title: "Font size"
                    subtitle: "Scale applied to all text"
                    options: root.scales
                    current: root.general.fontScale ?? "normal"
                    onPicked: v => root.patch({ fontScale: v })
                }

                StageDropdownRow {
                    title: "Font weight"
                    subtitle: "Default weight for body text"
                    options: root.weights.map(w => w.label)
                    current: root.weights.find(w => w.value === root.fontWeight)?.label ?? ""
                    onPicked: name => root.patch({ fontWeight: root.weights.find(w => w.label === name).value })
                }
            }
        }

        StageLazy {
            stageId: "bar"

            StagePage {
                stageId: "bar"
                title: "Bar"

                StageNavRow {
                    icon: "edit"
                    title: "Bar layout"
                    subtitle: "Move, add and style bar items in edit mode"
                    onClicked: root.editBar()
                }

                StageSwitchRow {
                    icon: "partly_cloudy_day"
                    title: "Weather panel"
                    subtitle: "Clicking the temperature opens the weather panel"
                    checked: root.general.barWeatherPanel ?? true
                    onToggled: on => root.patch({ barWeatherPanel: on })
                }

                StageGap {}

                StageChoiceRow {
                    title: "Main screen"
                    subtitle: root.primary === "" ? "Every screen shows the full bar" : root.primary + " shows the full bar; the others show a minimal one"
                    options: [{ value: "", label: "All", icon: "devices" }].concat(ServiceDisplay.monitorList.map(m => ({ value: m.name, label: m.name })))
                    current: root.primary
                    onPicked: v => root.patch({ primaryMonitor: v })
                }
            }
        }

        StageLazy {
            stageId: "workspaces"

            StagePage {
                stageId: "workspaces"
                title: "Workspaces"

                StageSliderRow {
                    title: "Workspace count"
                    subtitle: "How many the bar shows"
                    from: 1
                    to: 20
                    step: 1
                    current: root.general.workspaceCount ?? 10
                    onCommitted: v => root.patch({ workspaceCount: Math.round(v) })
                }

                StageSwitchRow {
                    title: "Each screen has its own"
                    subtitle: "A monitor shows only its own workspaces"
                    checked: root.general.perMonitorWorkspaces ?? false
                    onToggled: on => root.patch({ perMonitorWorkspaces: on })
                }
            }
        }
    }
}
