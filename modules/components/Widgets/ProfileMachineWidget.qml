import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "profileMachine"
    tile: WidgetSizes.wide
    resizable: true
    minSpan: Qt.size(3, 2)
    maxSpan: Qt.size(4, 2)
    defaultPos: Qt.point(915, 400)

    readonly property var facts: [
        { k: "Kernel", v: ServiceProfile.kernel.replace(/-\d+$/, "") || "—" },
        { k: "Desktop", v: ServiceProfile.desktop },
        { k: "Shell", v: ServiceProfile.shell },
        { k: "Packages", v: ServiceProfile.packages > 0 ? String(ServiceProfile.packages) : "—" },
        { k: "Uptime", v: ServiceProfile.uptimeText },
        { k: "Theme", v: "Nebula" }
    ]

    readonly property var swatches: [Colors.primary, Colors.primaryContainer, Colors.secondary, Colors.secondaryContainer,
                                     Colors.tertiaryContainer, Colors.error, Colors.outline, Colors.surfaceContainerHighest]

    WidgetCard {
        id: card
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: card.pad
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ProfileAvatar {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 18
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    CustomText {
                        Layout.fillWidth: true
                        textFormat: Text.StyledText
                        content: "<font color=\"" + Colors.primary + "\">" + ServiceProfile.user + "</font>"
                               + "<font color=\"" + Colors.outline + "\">@</font>" + (ServiceProfile.host || "localhost")
                        size: 15
                        weight: 600
                        elide: Text.ElideRight
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: ServiceProfile.os + (ServiceProfile.since ? " · since " + ServiceProfile.sinceText : "")
                        size: 11
                        weight: 400
                        customColor: Colors.outline
                        elide: Text.ElideRight
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 8
                columnSpacing: 10

                Repeater {
                    model: root.facts

                    delegate: ColumnLayout {
                        id: kv
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        Layout.maximumWidth: Infinity
                        spacing: 1

                        CustomText { content: kv.modelData.k; size: 10; weight: 400; customColor: Colors.outline }
                        CustomText { Layout.fillWidth: true; content: kv.modelData.v; size: 13; weight: 600; elide: Text.ElideRight }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.swatches

                    delegate: Rectangle {
                        required property color modelData
                        Layout.fillWidth: true
                        implicitHeight: 14
                        radius: 7
                        color: modelData
                    }
                }
            }
        }
    }
}
