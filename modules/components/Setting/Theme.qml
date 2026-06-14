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

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

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

            // ── Header ───────────────────────────────────────────────────────
            RowLayout {
                spacing: 10
                MaterialIconSymbol { content: "palette"; iconSize: 20 }
                CustomText { content: "Theme"; size: 20; color: Colors.primary }
            }

            // ── Appearance section ────────────────────────────────────────────
            CustomText { Layout.topMargin: 30; content: "Appearance"; size: 18; color: Colors.primary }
            CustomText { content: "Personalize colors, wallpaper, and transitions"; size: 14; color: Colors.outline }

            // Wallpaper Directory
            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 0
                    CustomText { content: "Wallpaper Directory"; size: 16 }
                    CustomText { content: "Wallpapers are picked randomly from this folder"; size: 13; color: Colors.outline }
                }
                Item { Layout.fillWidth: true }
                RowLayout {
                    spacing: 4
                    Rectangle {
                        implicitHeight: 34
                        implicitWidth: 180
                        topLeftRadius: 15; bottomLeftRadius: 15
                        topRightRadius: 5; bottomRightRadius: 5
                        color: Colors.surfaceContainerHighest
                        clip: true
                        CustomText {
                            anchors.left: parent.left; anchors.leftMargin: 10
                            anchors.right: parent.right; anchors.rightMargin: 5
                            anchors.verticalCenter: parent.verticalCenter
                            content: SettingsConfig.general.wallpaperDir ?? "/home/steel/wallpaper"
                            size: 12
                        }
                    }
                    CustomButton {
                        implicitHeight: 34; implicitWidth: 40
                        topLeftRadius: 5; bottomLeftRadius: 5
                        topRightRadius: 15; bottomRightRadius: 15
                        icon: "folder_open"; iconSize: 18
                        onClicked: {
                            GlobalStates.fileDialogOpen = true
                            folderPicker.open()
                        }
                    }
                }
            }

            // Theme Mode
            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 0
                    CustomText { content: "Theme Mode"; size: 16 }
                    CustomText { content: "Switch between dark and light variants"; size: 13; color: Colors.outline }
                }
                Item { Layout.fillWidth: true }
                ButtonGroup {
                    model: Settings.themeModes.map(m => ({ value: m.name.toLowerCase(), label: m.name, icon: m.icon }))
                    activeCheck: function(v) { return SettingsConfig.theme.matugenTheme === v }
                    onSegmentClicked: function(v) {
                        SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, { matugenTheme: v })
                        Quickshell.execDetached([ServiceWallpaper.wallpaperScript, Colors.wallpaper, ServiceWallpaper.scheme, v, ServiceWallpaper.transitionType])
                    }
                }
            }

            // Matugen Scheme
            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 0
                    CustomText { content: "Matugen Scheme"; size: 16 }
                    CustomText { content: "Algorithm used to extract colors from your wallpaper"; size: 13; color: Colors.outline }
                }
                Item { Layout.fillWidth: true }
                CustomListNew {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 30
                    currentVal: SettingsConfig.theme.matugenScheme
                    list: Settings.matugen
                    onCurrentValChanged: {
                        if (currentVal) {
                            SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, { matugenScheme: currentVal })
                            Quickshell.execDetached([ServiceWallpaper.wallpaperScript, Colors.wallpaper, currentVal, SettingsConfig.theme.matugenTheme, ServiceWallpaper.transitionType])
                        }
                    }
                }
            }

            // Transition Type
            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 0
                    CustomText { content: "Transition Type"; size: 16 }
                    CustomText { content: "Animation style when swapping wallpapers"; size: 13; color: Colors.outline }
                }
                Item { Layout.fillWidth: true }
                CustomListNew {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 30
                    currentVal: SettingsConfig.theme.transitionType ?? "fade"
                    list: Settings.transitionTypes
                    onCurrentValChanged: {
                        if (currentVal) {
                            SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, { transitionType: currentVal })
                        }
                    }
                }
            }

            Rectangle {
                Layout.topMargin: 20; Layout.bottomMargin: 20
                Layout.fillWidth: true; Layout.preferredHeight: 1
                color: Colors.outline
            }

            // ── Wallhaven section ─────────────────────────────────────────────
            CustomText { content: "Wallhaven"; size: 18; color: Colors.primary }
            CustomText { content: "Search and download wallpapers from Wallhaven"; size: 14; color: Colors.outline }

            // API Key
            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 0
                    CustomText { content: "API Key"; size: 16 }
                    CustomText { content: "Optional — needed for adult content and faster searches"; size: 13; color: Colors.outline }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: 220; implicitHeight: 34
                    radius: 10
                    color: Colors.surfaceContainerHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 8
                        spacing: 6

                        MaterialIconSymbol { content: "key"; iconSize: 16; color: Colors.outline }

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
                            color: Colors.outline
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

            Item { Layout.preferredHeight: 16 }
        }
    }
}
