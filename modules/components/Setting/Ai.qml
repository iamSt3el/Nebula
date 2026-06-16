import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

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

            // ── Page header ──────────────────────────────────────
            RowLayout {
                spacing: 10
                MaterialIconSymbol { content: "neurology"; iconSize: 20 }
                CustomText { content: "AI"; size: 20; customColor: Colors.primary }
            }

            // ── Google Gemini ────────────────────────────────────
            CustomText { Layout.topMargin: 24; content: "Google Gemini"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.topMargin: 6
                Layout.fillWidth: true
                spacing: 3

                // API Key
                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "API Key"; size: 14 }
                            CustomText { content: "Required to use the AI assistant"; size: 12; customColor: Colors.outline }
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
                                    text: SettingsConfig.ai.googleApiKey
                                    echoMode: showKey.checked ? TextInput.Normal : TextInput.Password
                                    color: Colors.inverseSurface
                                    selectionColor: Colors.primary
                                    font.pixelSize: 13
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    onEditingFinished: {
                                        SettingsConfig.ai = Object.assign({}, SettingsConfig.ai, { googleApiKey: text })
                                        savedNotice.visible = true
                                        savedTimer.restart()
                                    }
                                }

                                Rectangle {
                                    id: showKey
                                    property bool checked: false
                                    implicitWidth: 24; implicitHeight: 24
                                    radius: 6
                                    color: checked ? Colors.primary : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    MaterialIconSymbol {
                                        anchors.centerIn: parent
                                        content: parent.checked ? "visibility_off" : "visibility"
                                        iconSize: 15
                                        customColor: parent.checked ? Colors.primaryText : Colors.outline
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: showKey.checked = !showKey.checked
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: savedNotice.visible

                        MaterialIconSymbol { content: "check_circle"; iconSize: 14; customColor: Colors.primary }
                        CustomText {
                            id: savedNotice
                            content: "API key saved"
                            size: 12; customColor: Colors.primary
                            visible: false
                            Timer {
                                id: savedTimer
                                interval: 2000
                                onTriggered: savedNotice.visible = false
                            }
                        }
                    }
                }

                // How to get a key
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20

                    RowLayout {
                        spacing: 8
                        MaterialIconSymbol { content: "info"; iconSize: 16; customColor: Colors.outline }
                        CustomText { content: "How to get an API key"; size: 13; customColor: Colors.outline }
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: "1. Go to aistudio.google.com\n2. Sign in with your Google account\n3. Click \"Get API key\" → \"Create API key\"\n4. Copy the key and paste it above"
                        size: 12
                        customColor: Colors.outline
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ── Model ────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Model"; size: 13; customColor: Colors.primary }

            CustomCard {
                Layout.topMargin: 6
                autoRadius: false; topRadius: 20; bottomRadius: 20

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    MaterialIconSymbol { content: "auto_awesome"; iconSize: 20; customColor: Colors.primary }

                    ColumnLayout {
                        spacing: 2
                        CustomText { content: "Gemini 2.0 Flash"; size: 14 }
                        CustomText { content: "Fast, efficient model for all requests"; size: 12; customColor: Colors.outline }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: 54; implicitHeight: 24
                        radius: 12
                        color: Colors.primaryContainer

                        CustomText {
                            anchors.centerIn: parent
                            content: "Active"
                            size: 11
                            customColor: Colors.primary
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
