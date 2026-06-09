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

            RowLayout {
                spacing: 10
                MaterialIconSymbol {
                    content: "neurology"
                    iconSize: 20
                }
                CustomText {
                    content: "AI"
                    size: 20
                    color: Colors.primary
                }
            }

            CustomText {
                Layout.topMargin: 30
                content: "Google Gemini"
                size: 18
                color: Colors.primary
            }
            CustomText {
                content: "Configure your Google AI API key"
                size: 14
                color: Colors.outline
            }

            Rectangle {
                Layout.topMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: apiCol.implicitHeight + 20
                radius: 15
                color: Colors.surfaceContainerHigh

                ColumnLayout {
                    id: apiCol
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10

                    RowLayout {
                        spacing: 8
                        MaterialIconSymbol {
                            content: "key"
                            iconSize: 18
                            color: Colors.primary
                        }
                        CustomText {
                            content: "API Key"
                            size: 14
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 10
                        color: Colors.surfaceContainer

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 6

                            TextInput {
                                id: apiKeyInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: SettingsConfig.ai.googleApiKey
                                echoMode: showKey.checked ? TextInput.Normal : TextInput.Password
                                color: Colors.surfaceVariantText
                                selectionColor: Colors.primary
                                font.pixelSize: 13
                                font.family: SettingsConfig.general.defaultFont
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true

                                onEditingFinished: {
                                    SettingsConfig.ai = Object.assign({}, SettingsConfig.ai, {googleApiKey: text})
                                }
                            }

                            Rectangle {
                                id: showKey
                                property bool checked: false
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 8
                                color: checked ? Colors.primary : "transparent"

                                Behavior on color { ColorAnimation { duration: 150 } }

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: parent.checked ? "visibility_off" : "visibility"
                                    iconSize: 16
                                    color: parent.checked ? Colors.primaryText : Colors.outline
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: showKey.checked = !showKey.checked
                                }
                            }
                        }
                    }

                    // Save button
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 10
                        color: Colors.primary

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialIconSymbol {
                                content: "save"
                                iconSize: 16
                                color: Colors.primaryText
                            }
                            CustomText {
                                content: "Save"
                                size: 13
                                color: Colors.primaryText
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                SettingsConfig.ai = Object.assign({}, SettingsConfig.ai, {googleApiKey: apiKeyInput.text})
                                savedNotice.visible = true
                                savedTimer.restart()
                            }
                        }
                    }

                    CustomText {
                        id: savedNotice
                        content: "API key saved!"
                        size: 12
                        color: Colors.primary
                        visible: false

                        Timer {
                            id: savedTimer
                            interval: 2000
                            onTriggered: savedNotice.visible = false
                        }
                    }
                }
            }

            // Info box
            Rectangle {
                Layout.topMargin: 15
                Layout.fillWidth: true
                Layout.preferredHeight: infoCol.implicitHeight + 20
                radius: 12
                color: Colors.surfaceContainer

                ColumnLayout {
                    id: infoCol
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 6

                    RowLayout {
                        spacing: 6
                        MaterialIconSymbol {
                            content: "info"
                            iconSize: 16
                            color: Colors.outline
                        }
                        CustomText {
                            content: "How to get an API key"
                            size: 13
                            color: Colors.outline
                        }
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: "1. Go to Google AI Studio (aistudio.google.com)\n2. Sign in with your Google account\n3. Click \"Get API key\" → \"Create API key\"\n4. Copy the key and paste it above"
                        size: 12
                        color: Colors.outline
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Rectangle {
                Layout.topMargin: 10
                Layout.bottomMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.outline
            }

            // Model info
            CustomText {
                content: "Model"
                size: 18
                color: Colors.primary
            }
            CustomText {
                content: "Currently using"
                size: 14
                color: Colors.outline
            }

            Rectangle {
                Layout.topMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                radius: 12
                color: Colors.surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10

                    MaterialIconSymbol {
                        content: "auto_awesome"
                        iconSize: 20
                        color: Colors.primary
                    }

                    ColumnLayout {
                        spacing: 2
                        CustomText {
                            content: "Gemini 3 Flash Preview"
                            size: 14
                        }
                        CustomText {
                            content: "Fast, efficient model"
                            size: 11
                            color: Colors.outline
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 22
                        radius: 6
                        color: Colors.primary

                        CustomText {
                            anchors.centerIn: parent
                            content: "Active"
                            size: 11
                            color: Colors.primaryText
                        }
                    }
                }
            }
        }
    }
}
