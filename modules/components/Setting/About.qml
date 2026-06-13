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

            RowLayout {
                spacing: 10
                MaterialIconSymbol {
                    content: "info"
                    iconSize: 20
                }

                CustomText {
                    content: "About"
                    size: 20
                    color: Colors.primary
                }
            }

            // ── App Info ──────────────────────────────────
            Rectangle {
                Layout.topMargin: 20
                Layout.fillWidth: true
                Layout.preferredHeight: appCol.implicitHeight + 30
                radius: 15
                color: Colors.surfaceContainerHigh

                ColumnLayout {
                    id: appCol
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 5

                    RowLayout{
                        Image{
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            sourceSize: Qt.size(width, height)
                            source: IconUtil.getSystemIconPng("nebula")
                            fillMode: Image.PreserveAspectFit
                            
                        }
                        CustomText {
                            content: "Nebula"
                            size: 24
                            weight: 700
                            color: Colors.primary
                        }
                    }
                    CustomText {
                        content: "v0.1.0-beta"
                        size: 14
                        color: Colors.outline
                    }
                    CustomText {
                        Layout.topMargin: 5
                        content: "A modern desktop shell for Wayland built with QuickShell"
                        size: 13
                        color: Colors.outline
                    }
                }
            }

            // ── Developer ─────────────────────────────────
            CustomText {
                Layout.topMargin: 20
                content: "Developer"
                size: 18
                color: Colors.primary
            }
            CustomText {
                content: "The person behind Nebula"
                size: 14
                color: Colors.outline
            }

            Rectangle {
                Layout.topMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: devRow.implicitHeight + 20
                radius: 15
                color: Colors.surfaceContainerHigh

                RowLayout {
                    id: devRow
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 50
                        radius: 25
                        color: Colors.primary

                        CustomText {
                            anchors.centerIn: parent
                            content: "S"
                            size: 22
                            weight: 700
                            color: Colors.primaryText
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        CustomText {
                            content: "St3el"
                            size: 16
                            weight: 600
                        }
                        CustomText {
                            content: "Developer & Designer"
                            size: 12
                            color: Colors.outline
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            // ── Links ─────────────────────────────────────
            CustomText {
                Layout.topMargin: 20
                content: "Links"
                size: 18
                color: Colors.primary
            }
            CustomText {
                content: "Source code, issues, and updates"
                size: 14
                color: Colors.outline
            }

            ColumnLayout {
                Layout.topMargin: 10
                Layout.fillWidth: true
                spacing: 5

                Repeater {
                    model: [
                        {
                            icon: "code",
                            label: "GitHub",
                            desc: "github.com/St3el"
                        },
                        {
                            icon: "bug_report",
                            label: "Report Issue",
                            desc: "Open a bug report on GitHub"
                        },
                        {
                            icon: "star",
                            label: "Star the Project",
                            desc: "Show your support"
                        }
                    ]

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 45
                        radius: 10
                        color: linkArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            MaterialIconSymbol {
                                content: modelData.icon
                                iconSize: 18
                                color: Colors.primary
                            }

                            ColumnLayout {
                                spacing: 0
                                CustomText {
                                    content: modelData.label
                                    size: 14
                                }
                                CustomText {
                                    content: modelData.desc
                                    size: 11
                                    color: Colors.outline
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            MaterialIconSymbol {
                                content: "arrow_forward"
                                iconSize: 16
                                color: Colors.outline
                            }
                        }

                        MouseArea {
                            id: linkArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                        }
                    }
                }
            }
        }
    }
}
