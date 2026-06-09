import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    implicitHeight: notifications.length > 0 ? innerItem.height + 20 : 0
    implicitWidth: 380
    anchors.right: parent.right
    anchors.bottom: parent.bottom

    Behavior on implicitHeight {
        NumberAnimation { easing.type: Easing.OutQuad; duration: 300 }
    }

    // property var notifications: ServiceNotification.popups
    //
    Item {
        id: innerItem
        width: 380
        height: list.contentHeight + 20
        anchors.bottom: parent.bottom
        anchors.right: parent.right

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 10
            orientation: Qt.Vertical
            model: ScriptModel { values: [...ServiceNotification.popups.reverse()]}
            spacing: 5
            interactive: false

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; from: list.width + 20; to: 0; duration: 350; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutQuad }
                }
            }


            addDisplaced: Transition{
                NumberAnimation{
                    property: "y,x"
                    duration: 300
                    easing.type: Easing.OutQuad
                }
            }

            move: Transition {
                NumberAnimation {
                    property: "y,x"
                    duration: 350
                    easing.type: Easing.OutQuad
                }
            }

            displaced: Transition {
                NumberAnimation {
                    property: "y,x"
                    duration: 350
                    easing.type: Easing.OutQuad
                }
            }


            delegate: Rectangle {
                id: popup
                required property var modelData
                required property real index
                implicitWidth: list.width
                implicitHeight: row.implicitHeight + 24
                radius: 18

                color: Colors.surfaceContainerHigh



                SequentialAnimation {
                    id: removeAnimation
                    PropertyAction { target: popup; property: "ListView.delayRemove"; value: true }

                    ParallelAnimation{
                        NumberAnimation { target: popup; property: "x"; to: list.width; duration: 350; easing.type: Easing.InCubic }
                        NumberAnimation { target: popup; property: "opacity"; from: 1; to: 0; duration: 250; easing.type: Easing.InQuad }
                    }
                    NumberAnimation { target: popup; property: "implicitHeight"; to: 0; duration: 250; easing.type: Easing.InCubic }

                    PropertyAction { target: popup; property: "ListView.delayRemove"; value: false }
                }
                ListView.onRemove: removeAnimation.start()

                RowLayout {
                    id: row
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: 12
                    spacing: 12

                    // App icon
                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        Layout.alignment: Qt.AlignTop
                        radius: 12
                        color: Qt.alpha(Colors.primary, 0.12)

                        Image {
                            anchors.fill: parent
                            anchors.margins: 7
                            source: IconUtil.getIconPath(popup.modelData.appIcon)
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    // Text content
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        // App name
                        CustomText {
                            content: popup.modelData.appName ?? ""
                            size: 11
                            weight: 600
                            color: Colors.primary
                            visible: (popup.modelData.appName ?? "").length > 0
                        }

                        // Summary
                        CustomText {
                            Layout.fillWidth: true
                            content: popup.modelData.summary
                            size: 14
                            weight: 700
                            elide: Text.ElideRight
                        }

                        // Body
                        Text {
                            Layout.fillWidth: true
                            text: popup.modelData.body
                            font.pixelSize: 13
                            font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                            color: Colors.outline
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            visible: (popup.modelData.body ?? "").length > 0
                            bottomPadding: 2
                        }
                    }

                    // Optional inline image
                    Loader {
                        active: !!popup.modelData.image
                        visible: active
                        Layout.preferredHeight: 52
                        Layout.preferredWidth: 52
                        Layout.alignment: Qt.AlignVCenter
                        sourceComponent: Rectangle {
                            radius: 10
                            clip: true
                            color: "transparent"
                            Image {
                                anchors.fill: parent
                                source: popup.modelData.image
                                sourceSize: Qt.size(width, height)
                                fillMode: Image.PreserveAspectCrop
                            }
                        }
                    }
                }
            }


        }
    }
}
