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
        { k: "uptime", v: ServiceProfile.uptimeText },
        { k: "packages", v: ServiceProfile.packages > 0 ? String(ServiceProfile.packages) : "—" },
        { k: "kernel", v: ServiceProfile.kernel.split("-")[0] || "—" }
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
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 14
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    CustomText {
                        Layout.fillWidth: true
                        content: ServiceProfile.user + "@" + (ServiceProfile.host || "localhost")
                        size: 14
                        weight: 800
                        elide: Text.ElideRight
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: ServiceProfile.osShort + " · " + ServiceProfile.desktop + " · " + ServiceProfile.shell
                        size: 11
                        weight: 600
                        customColor: Colors.surfaceVariantText
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 3

                Repeater {
                    model: root.facts

                    delegate: Rectangle {
                        id: kv
                        required property var modelData
                        required property int index
                        readonly property bool first: kv.index === 0
                        readonly property bool last: kv.index === root.facts.length - 1
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        implicitHeight: 46
                        topLeftRadius: kv.first ? 14 : 4
                        bottomLeftRadius: kv.first ? 14 : 4
                        topRightRadius: kv.last ? 14 : 4
                        bottomRightRadius: kv.last ? 14 : 4
                        color: Colors.surfaceContainerHigh

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            anchors.topMargin: 6
                            anchors.bottomMargin: 6
                            spacing: 0
                            CustomText { Layout.fillWidth: true; content: kv.modelData.v; size: 14; weight: 800; elide: Text.ElideRight }
                            CustomText { content: kv.modelData.k; size: 10; weight: 600; customColor: Colors.surfaceVariantText }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: root.swatches

                    delegate: Rectangle {
                        id: sw
                        required property color modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 14
                        topLeftRadius: sw.index === 0 ? 7 : 2
                        bottomLeftRadius: sw.index === 0 ? 7 : 2
                        topRightRadius: sw.index === root.swatches.length - 1 ? 7 : 2
                        bottomRightRadius: sw.index === root.swatches.length - 1 ? 7 : 2
                        color: sw.modelData
                    }
                }
            }
        }
    }
}
