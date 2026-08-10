import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    readonly property var links: [
        { icon: "code",       label: "GitHub",       url: "https://github.com/iamSt3el/Nebula" },
        { icon: "bug_report", label: "Report issue", url: "https://github.com/iamSt3el/Nebula/issues/new" },
        { icon: "star",       label: "Star",         url: "https://github.com/iamSt3el/Nebula" }
    ]

    readonly property var facts: [
        { key: "Built with", value: "Quickshell" },
        { key: "Display",    value: "Wayland" },
        { key: "Compositor", value: "Hyprland" },
        { key: "Author",     value: "St3el" }
    ]

    ColumnLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 5
        spacing: 8

        // ── Identity ──────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 84
            radius: 20
            color: Colors.surfaceContainerHigh

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    Layout.alignment: Qt.AlignVCenter
                    radius: 16
                    color: Colors.primaryContainer

                    Image {
                        anchors.centerIn: parent
                        width: 32; height: 32
                        sourceSize: Qt.size(width, height)
                        source: IconUtil.getSystemIconPng("nebula")
                        fillMode: Image.PreserveAspectFit
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    RowLayout {
                        spacing: 8
                        CustomText {
                            content: "Nebula"; size: 20; weight: 700
                            customColor: Colors.primary
                        }
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: _ver.implicitWidth + 14
                            implicitHeight: 19
                            radius: 10
                            color: Colors.primaryContainer
                            CustomText {
                                id: _ver
                                anchors.centerIn: parent
                                content: "v0.2.0-beta"; size: 10; weight: 600
                                customColor: Colors.primary
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: "A modern desktop shell for Wayland"
                        size: 12; customColor: Colors.outline
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // ── Facts ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.facts
                delegate: Rectangle {
                    required property var modelData
                    // preferredWidth 1 + fillWidth forces equal columns; fillWidth
                    // alone only shares out surplus and they stay content-sized.
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 56
                    radius: 16
                    color: Colors.surfaceContainerHigh

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 3

                        CustomText {
                            Layout.fillWidth: true
                            content: modelData.key
                            size: 10; customColor: Colors.outline
                            horizontalAlignment: Text.AlignHCenter
                        }
                        CustomText {
                            Layout.fillWidth: true
                            content: modelData.value
                            size: 13; weight: 600
                            customColor: Colors.surfaceText
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // ── Links ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.links
                delegate: M3Button {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    size: "xsmall"
                    variant: "tonal"
                    icon: modelData.icon
                    label: modelData.label
                    onClicked: Quickshell.execDetached(["xdg-open", modelData.url])
                }
            }
        }
    }
}
