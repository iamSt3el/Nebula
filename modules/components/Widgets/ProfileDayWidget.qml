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

    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"
    readonly property var stats: [
        { label: "screen time", value: ServiceProfile.span(ServiceProfile.screenMs) },
        { label: ServiceProfile.commitsToday === 1 ? "commit today" : "commits today", value: String(ServiceProfile.commitsToday) },
        { label: "uptime", value: ServiceProfile.uptimeText }
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
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 16
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    CustomText {
                        content: ServiceProfile.greeting
                        size: 12
                        weight: 600
                        customColor: Colors.surfaceVariantText
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: ServiceProfile.name
                        size: 20
                        weight: 400
                        family: root.display
                        renderType: Text.QtRendering
                        elide: Text.ElideRight
                    }
                }

                ColumnLayout {
                    spacing: 2

                    CustomText {
                        Layout.alignment: Qt.AlignRight
                        content: Qt.formatTime(new Date(ServiceProfile.now), "h:mm")
                        size: 28
                        weight: 400
                        family: root.display
                        renderType: Text.QtRendering
                    }

                    CustomText {
                        Layout.alignment: Qt.AlignRight
                        content: Qt.formatTime(new Date(ServiceProfile.now), "AP") + " · " + Qt.formatDate(new Date(ServiceProfile.now), "ddd d MMM")
                        size: 11
                        weight: 600
                        customColor: Colors.surfaceVariantText
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 28

                Repeater {
                    model: root.stats

                    delegate: ColumnLayout {
                        id: stat
                        required property var modelData
                        spacing: 0

                        CustomText { content: stat.modelData.value; size: 17; weight: 800 }
                        CustomText { content: stat.modelData.label; size: 11; weight: 600; customColor: Colors.surfaceVariantText }
                    }
                }

                Item { Layout.fillWidth: true }
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
                    x: ServiceProfile.dayFrac * bar.width - width / 2
                    y: (bar.height - height) / 2
                    width: 20
                    height: 20
                    radius: 10
                    color: Colors.tertiary
                    border.width: 4
                    border.color: WidgetSizes.cardColor
                }
            }

            Item {
                id: axis
                Layout.fillWidth: true
                Layout.topMargin: -4
                implicitHeight: 13

                Repeater {
                    model: ["12 AM", "Noon", "12 AM"]

                    delegate: CustomText {
                        required property string modelData
                        required property int index
                        x: Math.max(0, Math.min(axis.width - width, index / 2 * axis.width - width / 2))
                        content: modelData
                        size: 11
                        weight: 600
                        customColor: Colors.surfaceVariantText
                    }
                }
            }
        }
    }
}
