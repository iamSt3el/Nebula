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

    property string tab: "colour"

    readonly property bool gowallOn: (SettingsConfig.theme.gowallTheme ?? "off") !== "off"
    readonly property string gowallPalette: SettingsConfig.theme.gowallTheme ?? "off"

    function nearest(vals, cur) {
        let best = 0
        for (let i = 1; i < vals.length; i++)
            if (Math.abs(vals[i] - cur) < Math.abs(vals[best] - cur))
                best = i
        return best
    }

    function setTheme(patch) {
        SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, patch)
    }


    component SettingCard: CustomCard {
        id: sc
        property string title: ""
        property string sub: ""
        property Component trailing: null
        autoRadius: false
        topRadius: 5
        bottomRadius: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                CustomText {
                    Layout.fillWidth: true
                    content: sc.title
                    size: 13
                }

                CustomText {
                    Layout.fillWidth: true
                    visible: sc.sub !== ""
                    content: sc.sub
                    size: 11
                    weight: 400
                    customColor: Colors.outline
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }
            }

            Loader {
                active: sc.trailing !== null
                visible: active
                sourceComponent: sc.trailing
            }
        }
    }

    component SliderCard: CustomCard {
        id: slc
        property string title: ""
        property int stepCount: 0
        property var stepLabels: []
        property int currentStep: -1
        signal stepPicked(int step)
        autoRadius: false
        topRadius: 5
        bottomRadius: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            CustomText {
                Layout.preferredWidth: 96
                content: slc.title
                size: 13
            }

            M3Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                stepCount: slc.stepCount
                stepLabels: slc.stepLabels
                currentStep: slc.currentStep
                onStepChanged: step => slc.stepPicked(step)
            }
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        M3ButtonGroup {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            fillWidth: true
            iconSize: 15
            textSize: 11
            model: [
                { value: "colour",   label: "Colour",   icon: "palette" },
                { value: "gowall",   label: "Gowall",   icon: "format_paint" },
                { value: "source",   label: "Source",   icon: "folder" }
            ]
            activeCheck: v => root.tab === v
            onSegmentClicked: v => root.tab = v
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: pages.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: CustomScrollBar {}

            Item {
                id: pages
                width: flick.width
                implicitHeight: {
                    switch (root.tab) {
                    case "gowall":   return gowallPage.implicitHeight
                    case "source":   return sourcePage.implicitHeight
                    }
                    return colourPage.implicitHeight
                }

                ColumnLayout {
                    id: colourPage
                    width: parent.width
                    visible: root.tab === "colour"
                    spacing: 3

                    SettingCard {
                        topRadius: 20
                        title: "Current palette"
                        sub: (SettingsConfig.theme.matugenScheme ?? "scheme-content") + " · "
                             + (SettingsConfig.theme.matugenTheme ?? "dark")

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Repeater {
                                model: [Colors.primary, Colors.secondary, Colors.tertiary,
                                        Colors.primaryContainer, Colors.secondaryContainer,
                                        Colors.tertiaryContainer]

                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    topLeftRadius: index === 0 ? 14 : 6
                                    bottomLeftRadius: index === 0 ? 14 : 6
                                    topRightRadius: index === 5 ? 14 : 6
                                    bottomRightRadius: index === 5 ? 14 : 6
                                    color: modelData
                                    Behavior on color { EffectsColorAnim {} }
                                }
                            }
                        }
                    }

                    SettingCard {
                        title: "Theme mode"
                        trailing: M3ButtonGroup {
                            model: Settings.themeModes.map(m => ({ value: m.name.toLowerCase(), label: m.name, icon: m.icon }))
                            activeCheck: v => SettingsConfig.theme.matugenTheme === v
                            onSegmentClicked: v => ServiceWallpaper.flipMode(v)
                        }
                    }

                    SettingCard {
                        title: "Colour scheme"
                        sub: "How colours are pulled from the wallpaper"

                        CustomListNew {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            color: Colors.surfaceContainerHighest
                            list: Settings.matugen
                            Component.onCompleted: currentVal = SettingsConfig.theme.matugenScheme
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.theme.matugenScheme) {
                                    root.setTheme({ matugenScheme: currentVal })
                                    ServiceWallpaper.reapply()
                                }
                            }
                        }
                    }

                    SettingCard {
                        bottomRadius: 5
                        title: "Transition"
                        sub: "Animation when the wallpaper changes"

                        CustomListNew {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            color: Colors.surfaceContainerHighest
                            list: Settings.transitionTypes
                            Component.onCompleted: currentVal = Settings.transitionOrDefault(SettingsConfig.theme.transitionType)
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.theme.transitionType)
                                    root.setTheme({ transitionType: currentVal })
                            }
                        }
                    }

                    SettingCard {
                        bottomRadius: 5
                        title: "Workspace glide"
                        sub: SettingsConfig.general.wallpaperFill === "full"
                            ? "Off while the whole wallpaper is shown"
                            : "The wallpaper slides a little when you switch workspace"
                        trailing: CustomToogle {
                            isToggleOn: SettingsConfig.general.wallpaperGlide ?? true
                            onToggled: state => {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { wallpaperGlide: state })
                            }
                        }
                    }

                    SettingCard {
                        bottomRadius: 20
                        title: "Fit"
                        sub: "Crop covers, Fill stretches, Full shows the whole image"
                        trailing: M3ButtonGroup {
                            model: Settings.wallpaperFills
                            activeCheck: v => Settings.wallpaperFillOrDefault(SettingsConfig.general.wallpaperFill) === v
                            onSegmentClicked: v => {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { wallpaperFill: v })
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: gowallPage
                    width: parent.width
                    visible: root.tab === "gowall"
                    spacing: 3

                    SettingCard {
                        topRadius: 20
                        title: "Palette"
                        sub: {
                            if (!ServiceWallpaper.gowallChecked) return "Checking for gowall…"
                            if (!ServiceWallpaper.gowallAvailable) return "gowall is not installed"
                            if (root.gowallPalette === "match") return "Follows the colours the shell already uses"
                            if (root.gowallOn) return "Wallpaper follows the " + root.gowallPalette + " palette"
                            return "Off: the wallpaper keeps its own colours"
                        }

                        CustomListNew {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            color: Colors.surfaceContainerHighest
                            list: ServiceWallpaper.gowallOptions
                            Component.onCompleted: {
                                ServiceWallpaper.refreshGowallThemes(false)
                                currentVal = root.gowallPalette
                                ServiceWallpaper.refreshIconPreview(currentVal)
                            }
                            onCurrentValChanged: {
                                if (!currentVal || currentVal === root.gowallPalette)
                                    return
                                const turningOff = currentVal === "off"
                                const iconsOn = SettingsConfig.theme.gowallIcons ?? false
                                root.setTheme({ gowallTheme: currentVal, gowallIcons: turningOff ? false : iconsOn })
                                if (turningOff && iconsOn)
                                    ServiceWallpaper.restoreIconTheme()
                                ServiceWallpaper.refreshIconPreview(currentVal)
                                ServiceWallpaper.reapply()
                            }
                        }
                    }

                    SettingCard {
                        bottomRadius: root.gowallOn ? 5 : 20
                        title: "Invert colours"
                        sub: (SettingsConfig.theme.gowallInvert ?? false)
                             ? "Wallpaper is flipped, day reads as night"
                             : "Flip the wallpaper's colours"
                        trailing: CustomToogle {
                            isToggleOn: SettingsConfig.theme.gowallInvert ?? false
                            onToggled: state => {
                                root.setTheme({ gowallInvert: state })
                                ServiceWallpaper.reapply()
                            }
                        }
                    }

                    SettingCard {
                        visible: root.gowallOn
                        title: "Use palette for the shell"
                        sub: root.gowallPalette === "match" ? "match already is the shell's palette"
                             : "Interface colours come from the palette"
                        trailing: CustomToogle {
                            isToggleOn: SettingsConfig.theme.gowallShell ?? false
                            onToggled: state => {
                                root.setTheme({ gowallShell: state })
                                ServiceWallpaper.reapply()
                            }
                        }
                    }

                    SettingCard {
                        visible: root.gowallOn
                        bottomRadius: 20
                        title: "Recolor icons"
                        sub: {
                            if (ServiceWallpaper.iconBusy) return ServiceWallpaper.iconStatus
                            if (!(SettingsConfig.theme.gowallIcons ?? false)) return "Rebuild the icon theme in this palette (~10 s)"
                            if (ServiceWallpaper.iconThemeName.length > 0) return "Using " + ServiceWallpaper.iconThemeName
                            return "Icon theme follows the palette"
                        }
                        trailing: CustomToogle {
                            isToggleOn: SettingsConfig.theme.gowallIcons ?? false
                            onToggled: state => {
                                root.setTheme({ gowallIcons: state })
                                if (state) ServiceWallpaper.buildGowallIcons(false)
                                else ServiceWallpaper.restoreIconTheme()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: ServiceWallpaper.iconPreview.length > 0

                            Repeater {
                                model: [{ label: "Original", key: "before" }, { label: root.gowallPalette, key: "after" }]

                                RowLayout {
                                    id: previewRow
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 6

                                    CustomText {
                                        Layout.preferredWidth: 56
                                        content: previewRow.modelData.label
                                        size: 10
                                        customColor: Colors.outline
                                    }

                                    Repeater {
                                        model: ServiceWallpaper.iconPreview.slice(0, 6)

                                        Image {
                                            required property var modelData
                                            Layout.preferredWidth: 30
                                            Layout.preferredHeight: 30
                                            source: "file://" + modelData[previewRow.modelData.key]
                                            sourceSize: Qt.size(60, 60)
                                            asynchronous: true
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


                ColumnLayout {
                    id: sourcePage
                    width: parent.width
                    visible: root.tab === "source"
                    spacing: 3

                    SettingCard {
                        topRadius: 20
                        title: "Folder"
                        sub: ServiceWallpaper.cacheModel.count + " wallpapers"

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 32
                                topLeftRadius: 16
                                bottomLeftRadius: 16
                                topRightRadius: 6
                                bottomRightRadius: 6
                                color: Colors.surfaceContainerHighest
                                clip: true

                                CustomText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    content: ServiceWallpaper.wallpaperDir
                                    size: 11
                                    elide: Text.ElideLeft
                                }
                            }

                            M3IconButton {
                                implicitHeight: 32
                                implicitWidth: 40
                                topLeftRadius: 6
                                bottomLeftRadius: 6
                                topRightRadius: 16
                                bottomRightRadius: 16
                                icon: "folder_open"
                                iconSize: 18
                                onClicked: {
                                    GlobalStates.fileDialogOpen = true
                                    folderPicker.open()
                                }
                            }
                        }
                    }

                    SettingCard {
                        title: "Rescan folder"
                        sub: "Pick up wallpapers added outside the shell"
                        trailing: M3IconButton {
                            implicitHeight: 32
                            implicitWidth: 40
                            icon: "refresh"
                            iconSize: 18
                            onClicked: ServiceWallpaper.refresh()
                        }
                    }

                    SettingCard {
                        bottomRadius: 20
                        title: "Wallhaven API key"
                        sub: "Optional. Needed for adult content and faster searches"

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 32
                            radius: 16
                            color: Colors.surfaceContainerHighest

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
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
                                    onEditingFinished: SettingsConfig.wallhaven = Object.assign({}, SettingsConfig.wallhaven, { apiKey: text })
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
            }
        }
    }
}
