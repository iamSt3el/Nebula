import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "profileBadge"
    tile: WidgetSizes.tall
    defaultPos: Qt.point(100, 400)

    WidgetCard {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 18
            anchors.leftMargin: parent.pad
            anchors.rightMargin: parent.pad
            anchors.bottomMargin: parent.pad
            spacing: 0

            ProfileAvatar {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 112
                Layout.preferredHeight: 112
                radius: 30
            }

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width
                Layout.topMargin: 12
                content: ServiceProfile.name
                size: 26
                weight: 400
                family: SettingsConfig.general.displayFont ?? "Titan One"
                renderType: Text.QtRendering
                elide: Text.ElideRight
            }

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                content: "@" + ServiceProfile.user
                size: 12
                weight: 600
                customColor: Colors.surfaceVariantText
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
                spacing: 6

                Repeater {
                    model: [ServiceProfile.osShort, ServiceProfile.desktop]

                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        implicitWidth: chipText.implicitWidth + 20
                        implicitHeight: 24
                        radius: 12
                        color: Colors.secondaryContainer

                        CustomText {
                            id: chipText
                            anchors.centerIn: parent
                            content: chip.modelData
                            size: 11
                            weight: 600
                            customColor: Colors.secondaryContainerText
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 3

                Repeater {
                    model: [{ v: ServiceProfile.packages > 0 ? String(ServiceProfile.packages) : "—", k: "packages" },
                            { v: ServiceProfile.sinceText, k: "since" }]

                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 46
                        topLeftRadius: tile.index === 0 ? 14 : 4
                        bottomLeftRadius: tile.index === 0 ? 14 : 4
                        topRightRadius: tile.index === 1 ? 14 : 4
                        bottomRightRadius: tile.index === 1 ? 14 : 4
                        color: Colors.surfaceContainerHigh

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 9
                            anchors.rightMargin: 4
                            anchors.topMargin: 6
                            anchors.bottomMargin: 6
                            spacing: 0
                            CustomText { Layout.fillWidth: true; content: tile.modelData.v; size: 13; weight: 800; elide: Text.ElideRight }
                            CustomText { content: tile.modelData.k; size: 10; weight: 600; customColor: Colors.surfaceVariantText }
                        }
                    }
                }
            }
        }
    }
}
