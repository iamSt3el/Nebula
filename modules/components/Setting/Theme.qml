import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Qt.labs.platform
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.WallpaperSelector
import QtQuick.Controls

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    component SchemeChip: Rectangle {
        id: chip
        required property var modelData
        readonly property string value: chip.modelData.name
        readonly property bool active: (SettingsConfig.theme.matugenScheme ?? "scheme-content") === chip.value
        readonly property bool kindle: chip.value === "scheme-kindle"
        readonly property var dots: chip.kindle ? ["#000000", "#eeeeee", "#ffffff"]
            : chip.active ? [Colors.primary, Colors.secondaryContainer, Colors.tertiary] : []
        readonly property string label: {
            const t = chip.value.replace("scheme-", "").replace(/-/g, " ")
            return t.charAt(0).toUpperCase() + t.slice(1)
        }
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
                content: chip.label
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
                const patch = chip.kindle ? { matugenScheme: chip.value, kindlePrevScheme: t.matugenScheme }
                                          : { matugenScheme: chip.value }
                SettingsConfig.theme = Object.assign({}, t, patch)
                ServiceWallpaper.reapply()
            }
        }
    }

    component PageThumb: Item {
        id: thumb
        property string mode: "light"
        readonly property bool dark: thumb.mode === "dark"
        readonly property bool active: (SettingsConfig.theme.matugenTheme ?? "dark") === thumb.mode
        readonly property bool kindle: KindleMode.active
        readonly property color page: thumb.kindle ? (thumb.dark ? "#000000" : "#ffffff")
            : Qt.tint(thumb.dark ? "#14120f" : "#fbf8f5", Qt.alpha(Colors.primary, 0.05))
        readonly property color card: thumb.kindle ? (thumb.dark ? "#222222" : "#eeeeee")
            : Qt.tint(thumb.dark ? "#2a2622" : "#ece6e0", Qt.alpha(Colors.primary, 0.1))
        readonly property color track: thumb.kindle ? (thumb.dark ? "#444444" : "#dddddd")
            : Qt.tint(thumb.dark ? "#3d3833" : "#dcd5ce", Qt.alpha(Colors.primary, 0.1))
        readonly property color ink: thumb.kindle ? (thumb.dark ? "#ffffff" : "#000000")
            : (thumb.dark ? "#ece4dc" : "#1e1b18")
        readonly property color accent: thumb.kindle ? thumb.ink : Colors.primary
        Layout.fillWidth: true
        Layout.maximumWidth: 260
        implicitHeight: 140

        Rectangle {
            id: thumbPage
            width: parent.width
            height: 110
            radius: 18
            color: thumb.page
            border.width: thumb.active ? 3 : 2
            border.color: thumb.active ? Colors.primary : Colors.outlineVariant
            clip: true

            Rectangle { x: 10; y: 8; width: 40; height: 10; radius: 5; color: thumb.card }
            Rectangle { x: (parent.width - width) / 2; y: 8; width: 30; height: 10; radius: 5; color: thumb.accent }
            Rectangle { x: parent.width - width - 10; y: 8; width: 60; height: 10; radius: 5; color: thumb.card }

            Rectangle {
                x: 10; y: 26
                width: 92; height: parent.height - 36
                radius: 10
                color: "transparent"
                border.width: 1.5
                border.color: thumb.ink
                Column {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4
                    Rectangle { width: parent.width; height: 22; radius: 6; color: thumb.accent }
                    Rectangle { width: parent.width; height: 14; radius: 5; color: thumb.card }
                    Rectangle { width: parent.width; height: 10; radius: 5; color: thumb.track }
                }
            }

            Column {
                x: parent.width - 58; y: 34
                spacing: 3
                Rectangle { width: 46; height: 28; radius: 8; color: thumb.ink }
                Rectangle { width: 46; height: 28; radius: 8; color: thumb.card }
            }
        }

        Row {
            anchors.top: thumbPage.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            MaterialIconSymbol { anchors.verticalCenter: parent.verticalCenter; visible: thumb.active; content: "check"; iconSize: 16 }
            CustomText { anchors.verticalCenter: parent.verticalCenter; content: thumb.kindle ? (thumb.dark ? "Dark page" : "Light page") : (thumb.dark ? "Dark" : "Light"); size: 13 }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: ServiceWallpaper.flipMode(thumb.mode)
        }
    }


    FolderDialog {
        id: folderPicker
        title: "Select wallpaper directory"
        onAccepted: {
            const path = folder.toString().replace(/^file:\/\//, "")
            SettingsConfig.general = Object.assign({}, SettingsConfig.general, { wallpaperDir: path })
            GlobalStates.fileDialogOpen = false
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }

    Flickable {
        id: pageFlick
        ScrollBar.vertical: CustomScrollBar {}
        anchors.fill: parent
        contentHeight: column.implicitHeight
        contentWidth: width
        clip: true

        ColumnLayout {
            id: column
            width: parent.width
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            anchors.topMargin: 5
            spacing: 0

            // ── Page header ──────────────────────────────────────────────
            // ── Current theme reference ──────────────────────────────────
            // Read-only summary of what the shell is actually rendering with:
            // the wallpaper the palette came from, and the key roles it
            // produced. Bound to Colors rather than WallpaperTheme so the card
            // follows whichever theme is active — DarkTheme and LightTheme both
            // report an empty wallpaper, which is the empty state below.
            CustomCard {
                id: themeRefCard
                Layout.topMargin: 16
                autoRadius: false; topRadius: 20; bottomRadius: 20

                readonly property string wpPath: Colors.wallpaper ?? ""
                readonly property bool hasWallpaper: wpPath.length > 0
                readonly property string wpName: hasWallpaper
                    ? wpPath.substring(wpPath.lastIndexOf("/") + 1)
                    : "No wallpaper"

                readonly property string mode:   SettingsConfig.theme.matugenTheme  ?? "dark"
                readonly property string scheme: SettingsConfig.theme.matugenScheme ?? "scheme-content"

                readonly property var swatchRoles: [
                    "primary",  "secondary",        "tertiary",    "error",
                    "surface",  "surfaceContainer", "surfaceText", "outline"
                ]

                // Wallpaper as a full-width hero. Rounded clip rather than a
                // Rectangle with clip:true — that clips to the bounding box and
                // leaves square corners on the image.
                ClippingRectangle {
                    Layout.fillWidth: true
                    implicitHeight: 150
                    radius: 16
                    color: Colors.surfaceContainerHighest

                    Image {
                        anchors.fill: parent
                        visible: themeRefCard.hasWallpaper
                        source: !themeRefCard.hasWallpaper ? ""
                            : KindleMode.wallpaper !== "keep" && WallpaperTheme.wallpaperScreen !== "" ? "file://" + WallpaperTheme.wallpaperScreen
                            : "file://" + themeRefCard.wpPath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        // Decoded at roughly display size; wallpapers are
                        // routinely 4K and this card shows a 150px-tall banner.
                        sourceSize: Qt.size(960, 360)
                    }

                    // Darkens the lower third only, so the name and chips stay
                    // legible over a bright wallpaper without dimming the image.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 78
                        visible: themeRefCard.hasWallpaper
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
                        }
                    }

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.bottomMargin: 12
                        visible: themeRefCard.hasWallpaper
                        spacing: 7

                        CustomText {
                            Layout.fillWidth: true
                            content: themeRefCard.wpName
                            size: 16; weight: 700
                            customColor: "#ffffff"
                            elide: Text.ElideMiddle
                        }

                        // Chips instead of a dot-separated run: the three values
                        // are independent facts, not one sentence.
                        RowLayout {
                            spacing: 6

                            Repeater {
                                model: [
                                    { text: Settings.activeTheme, icon: "" },
                                    { text: themeRefCard.mode, icon: themeRefCard.mode === "light" ? "light_mode" : "dark_mode" },
                                    { text: themeRefCard.scheme, icon: "" }
                                ]

                                delegate: Rectangle {
                                    id: chip
                                    required property var modelData
                                    implicitWidth: chipRow.implicitWidth + 18
                                    implicitHeight: 22
                                    radius: 11
                                    color: Qt.rgba(1, 1, 1, 0.18)

                                    RowLayout {
                                        id: chipRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        MaterialIconSymbol {
                                            visible: chip.modelData.icon.length > 0
                                            content: chip.modelData.icon
                                            iconSize: 13
                                            customColor: "#ffffff"
                                        }
                                        CustomText {
                                            content: chip.modelData.text
                                            size: 11
                                            customColor: "#ffffff"
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: !themeRefCard.hasWallpaper
                        spacing: 8

                        MaterialIconSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            content: "image"
                            iconSize: 28
                            customColor: Colors.outline
                        }
                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            content: Settings.activeTheme + " theme  ·  not wallpaper-derived"
                            size: 12
                            customColor: Colors.outline
                        }
                    }
                }

                // One connected bar rather than labelled tiles: the point of the
                // card is seeing the palette, and role names made the grid ragged
                // without telling you anything the colour didn't.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: themeRefCard.swatchRoles

                        delegate: Rectangle {
                            id: swatch
                            required property string modelData
                            required property int index

                            readonly property bool isFirst: index === 0
                            readonly property bool isLast: index === themeRefCard.swatchRoles.length - 1

                            Layout.fillWidth: true
                            implicitHeight: 40
                            color: Colors[swatch.modelData]

                            topLeftRadius:     isFirst ? 16 : 0
                            bottomLeftRadius:  isFirst ? 16 : 0
                            topRightRadius:    isLast  ? 16 : 0
                            bottomRightRadius: isLast  ? 16 : 0
                        }
                    }
                }
            }

            // ── Appearance ───────────────────────────────────────────────
            ColumnLayout {
                id: kindleSection
                Layout.fillWidth: true
                visible: KindleMode.active
                spacing: 0

                readonly property var appNames: ({
                    kitty: "kitty", tmux: "tmux", starship: "Starship", btop: "btop", hyprland: "Hyprland borders",
                    gtk3: "GTK 3", gtk4: "GTK 4", qt: "Qt", papirus: "Papirus folders", firefox: "Firefox and Zen",
                    obsidian: "Obsidian", waybar: "Waybar", nwgdock: "nwg-dock"
                })
                readonly property var followers: {
                    const ids = SettingsConfig.theme.themeApps
                    return Array.isArray(ids) ? ids.map(id => kindleSection.appNames[id] ?? id) : ["Every installed app"]
                }

                function setKindle(patch) {
                    SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, patch)
                }

                Timer {
                    id: kindleAnsiApply
                    interval: 400
                    onTriggered: ServiceWallpaper.applyTheme()
                }

                CustomText { Layout.topMargin: 16; content: "Kindle mode"; size: 13; customColor: Colors.primary }
                CustomText {
                    Layout.topMargin: 2
                    content: "Fixed e-ink greys for the shell and your apps"
                    size: 12
                    customColor: Colors.outline
                }

                GridLayout {
                    Layout.topMargin: 6
                    Layout.fillWidth: true
                    columns: kindleSection.width > 760 ? 2 : 1
                    columnSpacing: 12
                    rowSpacing: 3

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: 3

                        CustomCard {
                            autoRadius: false; topRadius: 20; bottomRadius: 20
                            ColumnLayout {
                                spacing: 2
                                CustomText { content: "Apps that follow"; size: 14 }
                                CustomText { content: "The same list as the theme's app colours"; size: 12; customColor: Colors.outline }
                            }
                            Flow {
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                spacing: 6
                                Repeater {
                                    model: kindleSection.followers
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

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: 3

                        CustomCard {
                            autoRadius: false; topRadius: 20; bottomRadius: 5
                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    CustomText { content: "Outlines instead of shadows"; size: 14 }
                                    CustomText { Layout.fillWidth: true; wrapMode: Text.WordWrap; content: "The bar, dock and panels get a 2 px edge and panel shadows switch off"; size: 12; customColor: Colors.outline }
                                }
                                CustomToogle {
                                    isToggleOn: SettingsConfig.theme.kindleOutlines ?? true
                                    onToggled: state => kindleSection.setKindle({ kindleOutlines: state })
                                }
                            }
                        }

                        CustomCard {
                            autoRadius: false; topRadius: 5; bottomRadius: 5
                            ColumnLayout {
                                spacing: 2
                                CustomText { content: "Wallpaper"; size: 14 }
                                CustomText {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    content: {
                                        const w = SettingsConfig.theme.kindleWallpaper ?? "blank"
                                        if (w === "eink") return ServiceWallpaper.gowallAvailable
                                            ? "Your wallpaper in the Kindle's 16 greys, through gowall"
                                            : "gowall isn't installed, so this falls back to greyscale"
                                        if (w === "grey") return "Your wallpaper, in greys"
                                        if (w === "keep") return "Your wallpaper, unchanged"
                                        return "A plain page behind the windows"
                                    }
                                    size: 12; customColor: Colors.outline
                                }
                            }
                            M3ButtonGroup {
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                fillWidth: true
                                model: [
                                    { value: "blank", label: "Blank page", icon: "description" },
                                    { value: "eink", label: "E-ink", icon: "gradient" },
                                    { value: "grey", label: "Greyscale", icon: "filter_b_and_w" },
                                    { value: "keep", label: "Keep mine", icon: "wallpaper" }
                                ]
                                activeCheck: v => (SettingsConfig.theme.kindleWallpaper ?? "blank") === v
                                onSegmentClicked: v => kindleSection.setKindle({ kindleWallpaper: v })
                            }
                        }

                        CustomCard {
                            autoRadius: false; topRadius: 5; bottomRadius: 5
                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    CustomText { content: "Grey app icons"; size: 14 }
                                    CustomText { Layout.fillWidth: true; wrapMode: Text.WordWrap; content: "Dock, launcher, tray, window title and notification icons lose their colour"; size: 12; customColor: Colors.outline }
                                }
                                CustomToogle {
                                    isToggleOn: SettingsConfig.theme.kindleGreyIcons ?? true
                                    onToggled: state => kindleSection.setKindle({ kindleGreyIcons: state })
                                }
                            }
                        }

                        CustomCard {
                            autoRadius: false; topRadius: 5; bottomRadius: 20
                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    CustomText { content: "Grey terminal colours"; size: 14 }
                                    CustomText {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        content: (SettingsConfig.theme.kindleGreyAnsi ?? false)
                                            ? "Terminal colours become grey tones"
                                            : "Terminals keep their normal colours"
                                        size: 12; customColor: Colors.outline
                                    }
                                }
                                CustomToogle {
                                    isToggleOn: SettingsConfig.theme.kindleGreyAnsi ?? false
                                    onToggled: state => {
                                        kindleSection.setKindle({ kindleGreyAnsi: state })
                                        kindleAnsiApply.restart()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            CustomText { Layout.topMargin: 24; content: "Appearance"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                // Wallpaper Directory
                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Wallpaper Directory"; size: 14 }
                            CustomText { content: "Wallpapers are picked randomly from this folder"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        RowLayout {
                            spacing: 4
                            Rectangle {
                                implicitHeight: 32; implicitWidth: 180
                                topLeftRadius: 16; bottomLeftRadius: 16
                                topRightRadius: 6;  bottomRightRadius: 6
                                color: Colors.surfaceContainerHighest
                                clip: true
                                CustomText {
                                    anchors.left: parent.left; anchors.leftMargin: 12
                                    anchors.right: parent.right; anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    content: SettingsConfig.general.wallpaperDir ?? (Quickshell.env("HOME") + "/wallpaper")
                                    size: 11
                                    elide: Text.ElideLeft
                                }
                            }
                            M3IconButton {
                                implicitHeight: 32; implicitWidth: 40
                                topLeftRadius: 6;   bottomLeftRadius: 6
                                topRightRadius: 16; bottomRightRadius: 16
                                icon: "folder_open"; iconSize: 18
                                onClicked: {
                                    GlobalStates.fileDialogOpen = true
                                    folderPicker.open()
                                }
                            }
                        }
                    }
                }

                // Theme Mode
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    ColumnLayout {
                        spacing: 2
                        CustomText { content: "Theme Mode"; size: 14 }
                        CustomText { content: "Click a page to switch between light and dark"; size: 12; customColor: Colors.outline }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        spacing: 14
                        Item { Layout.fillWidth: true }
                        PageThumb { mode: "light" }
                        PageThumb { mode: "dark" }
                        Item { Layout.fillWidth: true }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    visible: !ServiceWallpaper.gowallActive && !KindleMode.active
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Wallpaper Colours"; size: 14 }
                            CustomText {
                                content: themeSeeds.seeds.length > 1
                                    ? "Other themes hiding in this wallpaper — the first is picked automatically"
                                    : "This wallpaper has one clear colour"
                                size: 12; customColor: Colors.outline
                            }
                        }
                        Item { Layout.fillWidth: true }
                        SeedSwatches {
                            id: themeSeeds
                            path: ServiceWallpaper.currentSource
                            disc: 28
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    ColumnLayout {
                        spacing: 2
                        CustomText { content: "Colour scheme"; size: 14 }
                        CustomText {
                            content: KindleMode.active ? "Kindle ignores the wallpaper and uses fixed greys"
                                                       : "How colours are pulled from your wallpaper"
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

                // Transition Type
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Transition Type"; size: 14 }
                            CustomText { content: "Animation style when swapping wallpapers"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 30
                            color: Colors.surfaceContainerHighest
                            list: Settings.transitionTypes
                            Component.onCompleted: currentVal = Settings.transitionOrDefault(SettingsConfig.theme.transitionType)
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.theme.transitionType) {
                                    SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, { transitionType: currentVal })
                                }
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Workspace glide"; size: 14 }
                            CustomText {
                                content: SettingsConfig.general.wallpaperFill === "full"
                                    ? "Off while the whole wallpaper is shown"
                                    : "The wallpaper slides a little when you switch workspace"
                                size: 12; customColor: Colors.outline
                            }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.general.wallpaperGlide ?? true
                            onToggled: state => {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { wallpaperGlide: state })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Wallpaper fit"; size: 14 }
                            CustomText {
                                content: {
                                    const f = Settings.wallpaperFillOrDefault(SettingsConfig.general.wallpaperFill)
                                    if (f === "fill") return "Stretched to the screen edges"
                                    if (f === "full") return "The whole image, with bars where it doesn't reach"
                                    return "Covers the screen, trimming what doesn't fit"
                                }
                                size: 12; customColor: Colors.outline
                            }
                        }
                        Item { Layout.fillWidth: true }
                        M3ButtonGroup {
                            model: Settings.wallpaperFills
                            activeCheck: v => Settings.wallpaperFillOrDefault(SettingsConfig.general.wallpaperFill) === v
                            onSegmentClicked: v => {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { wallpaperFill: v })
                            }
                        }
                    }
                }
            }

            // ── Gowall ───────────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Gowall"; size: 13; customColor: Colors.primary }
            CustomText {
                Layout.topMargin: 2
                content: "Repaint the wallpaper — and your icons — with a fixed color palette"
                size: 12
                customColor: Colors.outline
            }

            ColumnLayout {
                id: gowallGroup
                Layout.topMargin: 6; Layout.fillWidth: true; spacing: 3

                readonly property string palette: SettingsConfig.theme.gowallTheme ?? "off"
                readonly property bool on: gowallGroup.palette !== "off"
                readonly property bool iconsOn: SettingsConfig.theme.gowallIcons ?? false
                readonly property bool inverted: SettingsConfig.theme.gowallInvert ?? false
                readonly property bool shellOn: SettingsConfig.theme.gowallShell ?? false

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Palette"; size: 14 }
                            CustomText {
                                size: 12
                                customColor: Colors.outline
                                content: {
                                    if (!ServiceWallpaper.gowallChecked) return "Checking for gowall…"
                                    if (!ServiceWallpaper.gowallAvailable) return "gowall is not installed"
                                    if (gowallGroup.palette === "match") return "Follows the colors the shell already uses"
                                    if (gowallGroup.on) return "Wallpaper and colors follow the " + gowallGroup.palette + " palette"
                                    return "Off — the wallpaper keeps its own colors"
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 30
                            color: Colors.surfaceContainerHighest
                            list: ServiceWallpaper.gowallOptions
                            Component.onCompleted: {
                                ServiceWallpaper.refreshGowallThemes(false)
                                currentVal = SettingsConfig.theme.gowallTheme ?? "off"
                                ServiceWallpaper.refreshIconPreview(currentVal)
                            }
                            onCurrentValChanged: {
                                if (!currentVal || currentVal === gowallGroup.palette) return
                                const turningOff = currentVal === "off"
                                SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, {
                                    gowallTheme: currentVal,
                                    gowallIcons: turningOff ? false : gowallGroup.iconsOn
                                })
                                if (turningOff && gowallGroup.iconsOn)
                                    ServiceWallpaper.restoreIconTheme()
                                ServiceWallpaper.refreshIconPreview(currentVal)
                                ServiceWallpaper.reapply()
                            }
                        }
                    }
                }

                // Invert stands on its own — a wallpaper can be flipped with no
                // palette at all, and with one it is flipped before the recolor.
                CustomCard {
                    autoRadius: false; topRadius: 5
                    bottomRadius: gowallGroup.on ? 5 : 20

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Invert colors"; size: 14 }
                            CustomText {
                                size: 12
                                customColor: Colors.outline
                                content: gowallGroup.inverted
                                    ? (gowallGroup.on ? "Wallpaper is flipped, then repainted" : "Wallpaper is flipped — daylight reads as night")
                                    : "Flip the wallpaper's colors — a day scene becomes night"
                            }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: gowallGroup.inverted
                            onToggled: state => {
                                SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, { gowallInvert: state })
                                ServiceWallpaper.reapply()
                            }
                        }
                    }
                }

                // Shell colors — the palette replaces Material You as the source
                // of the interface's own colors.
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    visible: gowallGroup.on

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Use palette for the shell"; size: 14 }
                            CustomText {
                                size: 12
                                customColor: Colors.outline
                                content: {
                                    if (gowallGroup.palette === "match")
                                        return "match already is the shell's palette"
                                    if (gowallGroup.shellOn)
                                        return "Interface colors come from " + gowallGroup.palette + ", not the wallpaper"
                                    return "Colors the interface from the palette instead of the wallpaper"
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: gowallGroup.shellOn
                            onToggled: state => {
                                SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, { gowallShell: state })
                                ServiceWallpaper.reapply()
                            }
                        }
                    }
                }

                // Icons — only meaningful once a palette is chosen, so it stays
                // out of the way until then.
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    visible: gowallGroup.on

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                spacing: 2
                                CustomText { content: "Recolor icons"; size: 14 }
                                CustomText {
                                    size: 12
                                    customColor: Colors.outline
                                    content: {
                                        if (ServiceWallpaper.iconBusy)
                                            return ServiceWallpaper.iconStatus
                                        if (!gowallGroup.iconsOn)
                                            return "Rebuild your icon theme in this palette (takes ~10s)"
                                        if (ServiceWallpaper.iconThemeName.length > 0)
                                            return "Using " + ServiceWallpaper.iconThemeName
                                        return "Icon theme follows the palette"
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                            CustomToogle {
                                isToggleOn: gowallGroup.iconsOn
                                onToggled: state => {
                                    SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, { gowallIcons: state })
                                    if (state) ServiceWallpaper.buildGowallIcons(false)
                                    else ServiceWallpaper.restoreIconTheme()
                                }
                            }
                        }

                        // Before / after on real icons from the theme in use.
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            spacing: 6
                            visible: ServiceWallpaper.iconPreview.length > 0

                            Repeater {
                                model: [
                                    { label: "Original", key: "before" },
                                    { label: gowallGroup.palette, key: "after" }
                                ]

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
                        }

                        M3WavyProgressBar {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 12
                            visible: ServiceWallpaper.iconBusy
                            progress: ServiceWallpaper.iconProgress
                            indeterminate: ServiceWallpaper.iconProgress <= 0
                        }
                    }
                }
            }



            // ── Wallhaven ─────────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Wallhaven"; size: 13; customColor: Colors.primary }

            CustomCard {
                Layout.topMargin: 6
                autoRadius: false; topRadius: 20; bottomRadius: 20

                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        spacing: 2
                        CustomText { content: "API Key"; size: 14 }
                        CustomText { content: "Optional — needed for adult content and faster searches"; size: 12; customColor: Colors.outline }
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: 220; implicitHeight: 32
                        radius: 10
                        color: Colors.surfaceContainerHighest

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 8
                            spacing: 6

                            MaterialIconSymbol { content: "key"; iconSize: 16; customColor: Colors.outline }

                            TextInput {
                                id: apiKeyInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: SettingsConfig.wallhaven.apiKey
                                color: Colors.inverseSurface
                                font.pixelSize: 13
                                clip: true
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                onEditingFinished: {
                                    SettingsConfig.wallhaven = Object.assign({}, SettingsConfig.wallhaven, { apiKey: text })
                                }
                            }

                            MaterialIconSymbol {
                                content: apiKeyInput.echoMode === TextInput.Password ? "visibility_off" : "visibility"
                                iconSize: 16
                                customColor: Colors.outline
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: apiKeyInput.echoMode = apiKeyInput.echoMode === TextInput.Password
                                               ? TextInput.Normal : TextInput.Password
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
    ScrollFade {
        anchors.fill: parent
        flickable: pageFlick
    }
}
