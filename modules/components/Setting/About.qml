import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
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
                MaterialIconSymbol { content: "info"; iconSize: 20 }
                CustomText { content: "About"; size: 20; customColor: Colors.primary }
            }

            // ── App info ─────────────────────────────────────────
            CustomCard {
                Layout.topMargin: 24
                autoRadius: false; topRadius: 20; bottomRadius: 20

                RowLayout {
                    spacing: 16

                    Rectangle {
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 60
                        Layout.alignment: Qt.AlignVCenter
                        radius: 18
                        color: Colors.primaryContainer

                        Image {
                            anchors.centerIn: parent
                            width: 36; height: 36
                            sourceSize: Qt.size(width, height)
                            source: IconUtil.getSystemIconPng("nebula")
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    ColumnLayout {
                        spacing: 3
                        CustomText { content: "Nebula"; size: 22; weight: 700; customColor: Colors.primary }
                        CustomText { content: "v0.2.0-beta"; size: 13; customColor: Colors.outline }
                        CustomText {
                            content: "A modern desktop shell for Wayland built with QuickShell"
                            size: 12; customColor: Colors.outline
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // ── Developer ────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Developer"; size: 13; customColor: Colors.primary }

            CustomCard {
                Layout.topMargin: 6
                autoRadius: false; topRadius: 20; bottomRadius: 20

                RowLayout {
                    spacing: 12

                    Rectangle {
                        implicitWidth: 48; implicitHeight: 48
                        radius: 24
                        color: Colors.primaryContainer

                        CustomText {
                            anchors.centerIn: parent
                            content: "S"; size: 20; weight: 700
                            customColor: Colors.primary
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        CustomText { content: "St3el"; size: 15; weight: 600 }
                        CustomText { content: "Developer & Designer"; size: 12; customColor: Colors.outline }
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            // ── Links ────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Links"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.topMargin: 6
                Layout.fillWidth: true
                spacing: 3

                Repeater {
                    model: [
                        { icon: "code",       label: "GitHub",          desc: "github.com/iamSt3el/Nebula", url: "https://github.com/iamSt3el/Nebula",          first: true,  last: false },
                        { icon: "bug_report", label: "Report Issue",    desc: "Open a bug report on GitHub", url: "https://github.com/iamSt3el/Nebula/issues/new", first: false, last: false },
                        { icon: "star",       label: "Star the Project", desc: "Show your support",         url: "https://github.com/iamSt3el/Nebula",          first: false, last: true  }
                    ]

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: linkRow.implicitHeight + 24
                        color: linkArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                        topLeftRadius:     modelData.first ? 20 : 5
                        topRightRadius:    modelData.first ? 20 : 5
                        bottomLeftRadius:  modelData.last  ? 20 : 5
                        bottomRightRadius: modelData.last  ? 20 : 5
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            id: linkRow
                            anchors.fill: parent
                            anchors.leftMargin: 14; anchors.rightMargin: 14
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: 10
                                color: Colors.surfaceContainerHighest

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: modelData.icon; iconSize: 17; customColor: Colors.primary
                                }
                            }

                            ColumnLayout {
                                spacing: 1
                                CustomText { content: modelData.label; size: 14 }
                                CustomText { content: modelData.desc; size: 11; customColor: Colors.outline }
                            }

                            Item { Layout.fillWidth: true }

                            MaterialIconSymbol {
                                content: "arrow_forward"; iconSize: 16; customColor: Colors.outline
                            }
                        }

                        MouseArea {
                            id: linkArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: Quickshell.execDetached(["xdg-open", modelData.url])
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
