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

            // ── Page header ──────────────────────────────────────────────
            RowLayout {
                spacing: 10
                MaterialIconSymbol { content: "palette"; iconSize: 20 }
                CustomText { content: "Theme"; size: 20; customColor: Colors.primary }
            }

            // ── Appearance ───────────────────────────────────────────────
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
                            CustomButton {
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
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Theme Mode"; size: 14 }
                            CustomText { content: "Switch between dark and light variants"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        ButtonGroup {
                            model: Settings.themeModes.map(m => ({ value: m.name.toLowerCase(), label: m.name, icon: m.icon }))
                            activeCheck: function(v) { return SettingsConfig.theme.matugenTheme === v }
                            onSegmentClicked: function(v) {
                                SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, { matugenTheme: v })
                                ServiceWallpaper.applyTheme()
                            }
                        }
                    }
                }

                // Matugen Scheme
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Matugen Scheme"; size: 14 }
                            CustomText { content: "Algorithm used to extract colors from your wallpaper"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 30
                            color: Colors.surfaceContainerHighest
                            list: Settings.matugen
                            Component.onCompleted: currentVal = SettingsConfig.theme.matugenScheme
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.theme.matugenScheme) {
                                    SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, { matugenScheme: currentVal })
                                    Quickshell.execDetached([ServiceWallpaper.wallpaperScript, Colors.wallpaper, currentVal, SettingsConfig.theme.matugenTheme, ServiceWallpaper.transitionType])
                                }
                            }
                        }
                    }
                }

                // Transition Type
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
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
                            Component.onCompleted: currentVal = SettingsConfig.theme.transitionType ?? "fade"
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.theme.transitionType) {
                                    SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, { transitionType: currentVal })
                                }
                            }
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
}
