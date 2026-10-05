import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "profileDay"
    tile: Qt.size(WidgetSizes.span(4), WidgetSizes.span(2))
    resizable: true
    minSpan: Qt.size(4, 2)
    maxSpan: Qt.size(6, 2)
    defaultPos: Qt.point(365, 165)

    readonly property var stats: [
        { label: "Screen time", value: ServiceProfile.span(ServiceProfile.screenMs),
          note: ServiceProfile.topApp ? ServiceProfile.appName(ServiceProfile.topApp.id) + " " + ServiceProfile.span(ServiceProfile.topApp.ms) : "Nothing yet" },
        { label: "Commits", value: ServiceProfile.commitsToday + " today", note: ServiceProfile.commitsWeek + " this week" },
        { label: "Uptime", value: ServiceProfile.uptimeText, note: "since " + ServiceProfile.bootText }
    ]

    WidgetCard {
        id: card
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: card.pad
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ProfileAvatar {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    radius: 18
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    CustomText {
                        content: ServiceProfile.greeting
                        size: 13
                        weight: 400
                        customColor: Colors.surfaceVariantText
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: ServiceProfile.name
                        size: 26
                        weight: 400
                        family: SettingsConfig.general.displayFont ?? "Titan One"
                        renderType: Text.QtRendering
                        elide: Text.ElideRight
                    }
                }

                ColumnLayout {
                    spacing: 2

                    CustomText {
                        Layout.alignment: Qt.AlignRight
                        content: Qt.formatTime(new Date(ServiceProfile.now), "h:mm AP")
                        size: 20
                        weight: 600
                    }

                    CustomText {
                        Layout.alignment: Qt.AlignRight
                        content: Qt.formatDate(new Date(ServiceProfile.now), "dddd, d MMM")
                        size: 12
                        weight: 400
                        customColor: Colors.outline
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: root.stats

                    delegate: Rectangle {
                        id: tileBox
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        implicitHeight: 54
                        radius: WidgetSizes.nestedRadius(card.width)
                        color: Colors.surfaceContainerHigh

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            anchors.topMargin: 7
                            anchors.bottomMargin: 7
                            spacing: 1

                            CustomText { content: tileBox.modelData.label; size: 10; weight: 400; customColor: Colors.outline }
                            CustomText { Layout.fillWidth: true; content: tileBox.modelData.value; size: 15; weight: 600; elide: Text.ElideRight }
                            CustomText { Layout.fillWidth: true; content: tileBox.modelData.note; size: 10; weight: 400; customColor: Colors.surfaceVariantText; elide: Text.ElideRight }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Item {
                id: bar
                Layout.fillWidth: true
                implicitHeight: 10

                Rectangle {
                    anchors.fill: parent
                    radius: 5
                    color: Colors.surfaceContainerHighest
                }

                Repeater {
                    model: ServiceProfile.timeline

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        x: modelData.x * bar.width
                        width: Math.max(4, modelData.w * bar.width)
                        height: bar.height
                        radius: 5
                        color: index === ServiceProfile.timeline.length - 1 ? Colors.primary : Colors.primaryContainer
                    }
                }

                Rectangle {
                    x: ServiceProfile.dayFrac * bar.width - 1
                    y: -3
                    width: 2
                    height: bar.height + 6
                    radius: 1
                    color: Colors.surfaceText
                }
            }

            Item {
                id: axis
                Layout.fillWidth: true
                Layout.topMargin: -7
                implicitHeight: 12

                Repeater {
                    model: ["12 AM", "6 AM", "12 PM", "6 PM", "12 AM"]

                    delegate: CustomText {
                        required property string modelData
                        required property int index
                        x: Math.max(0, Math.min(axis.width - width, index / 4 * axis.width - width / 2))
                        content: modelData
                        size: 10
                        weight: 400
                        customColor: Colors.outline
                    }
                }
            }
        }
    }
}
