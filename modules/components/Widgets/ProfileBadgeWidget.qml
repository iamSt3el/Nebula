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
            anchors.topMargin: 14
            anchors.leftMargin: parent.pad
            anchors.rightMargin: parent.pad
            anchors.bottomMargin: parent.pad
            spacing: 0

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 38
                implicitHeight: 7
                radius: 3.5
                color: Colors.surfaceContainerLowest
                border.width: 1
                border.color: Colors.outlineVariant
            }

            ProfileAvatar {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 14
                Layout.preferredWidth: 108
                Layout.preferredHeight: 108
                radius: 30
            }

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width
                Layout.topMargin: 12
                content: ServiceProfile.name
                size: 28
                weight: 400
                family: SettingsConfig.general.displayFont ?? "Titan One"
                renderType: Text.QtRendering
                elide: Text.ElideRight
            }

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                content: "@" + ServiceProfile.user
                size: 13
                weight: 400
                customColor: Colors.outline
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

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Colors.outlineVariant
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                spacing: 8

                ColumnLayout {
                    spacing: 1
                    CustomText { content: "Packages"; size: 10; weight: 400; customColor: Colors.outline }
                    CustomText { content: ServiceProfile.packages > 0 ? ServiceProfile.packages : "—"; size: 14; weight: 600 }
                }

                Item { Layout.fillWidth: true }

                ColumnLayout {
                    spacing: 1
                    CustomText { Layout.alignment: Qt.AlignRight; content: "Since"; size: 10; weight: 400; customColor: Colors.outline }
                    CustomText { Layout.alignment: Qt.AlignRight; content: ServiceProfile.sinceText; size: 14; weight: 600 }
                }
            }
        }
    }
}
