import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.customComponents
import qs.modules.utils
import qs.modules.services
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MatrialShapeFn


Item{
    id: root
    anchors.fill: parent

    signal notificationCenterClosed
    property bool active: false//hoverHandler.hovered

    onActiveChanged:{
        if(!active) root.notificationCenterClosed()
    }

    opacity:0
    scale: 0.8

    NumberAnimation on opacity{
        from: 0
        to: 1
        duration: 400
        running: true
    }


    NumberAnimation on scale{
        from: 0.8
        to: 1
        duration: 400
        running: true
    }

    ColumnLayout{
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        // Rectangle{
        //     Layout.fillWidth: true
        //     Layout.preferredHeight: 50
        //     color: Colors.surfaceContainer
        //     radius: 
        //     RowLayout{
        //         anchors.fill: parent
        //         anchors.margins: 10
        //         spacing: 5
        //         MaterialIconSymbol{
        //             content: "notifications"
        //             iconSize: 18
        //         }
        //         CustomText{
        //             Layout.fillWidth: true
        //             content: "Notifications"
        //             size: 16
        //             weight: 600
        //         }
        //         MaterialIconSymbol{
        //             content: "close"
        //             iconSize: 20
        //             MouseArea{
        //                 anchors.fill: parent
        //                 cursorShape: Qt.PointingHandCursor
        //                 onClicked: root.notificationCenterClosed()
        //             }
        //         }
        //     }
        // }
        RowLayout{
            Layout.fillWidth: true
            spacing: 10

            CustomButton{
                Layout.preferredHeight: 30
                Layout.preferredWidth: 60
                icon: "notification_settings"
                iconSize: 20
            }

            Rectangle{
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: 20
                color: clearArea.containsMouse ? Colors.primary : Colors.surfaceContainerHighest

                CustomText{
                    anchors.centerIn: parent
                    content: "Clear all"
                    size: 14
                    color: clearArea.containsMouse ? Colors.primaryText : Colors.surfaceText
                }

                MouseArea{
                    id: clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ServiceNotification.clear()
                }

            }

            CustomButton{
                Layout.preferredHeight: 30
                Layout.preferredWidth: 60
                icon: "close"
                iconSize: 18
                onClicked: root.notificationCenterClosed()
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: ServiceNotification.groupedNotifications.length === 0
            visible: active
            sourceComponent: Item {
                anchors.fill: parent
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialShapes.ShapeCanvas {
                        Layout.alignment: Qt.AlignCenter
                        Layout.preferredHeight: 80
                        Layout.preferredWidth: 80
                        roundedPolygon: MatrialShapeFn.getSunny()
                        color: Colors.primaryText

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "notifications"
                            iconSize: 26
                            color: Colors.primary
                        }
                    }
                    CustomText {
                        Layout.alignment: Qt.AlignCenter
                        content: "No Notifications"
                        size: 16
                        color: Colors.outline
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: ServiceNotification.groupedNotifications.length > 0
            visible: active
            sourceComponent: ListView {
                id: notifList
                anchors.fill: parent
                spacing: 0
                clip: true

                // Flat list of NotificationItems built from groups (newest group first,
                // newest notification first within each group). Using allNotifications.length
                // as a reactive dependency so the model updates on every add/remove.
                model: ScriptModel {
                    values: {
                        var _ = ServiceNotification.allNotifications.length
                        var result = []
                        var groups = ServiceNotification.groupedNotifications
                        for (var i = groups.length - 1; i >= 0; i--) {
                            result = result.concat([...groups[i].notifications].reverse())
                        }
                        return result
                    }
                }

                add: Transition {
                    NumberAnimation { property: "x"; from: notifList.width; to: 0; duration: 300; easing.type: Easing.OutQuad }
                }

                // remove: Transition {
                //     ParallelAnimation {
                //         NumberAnimation { property: "opacity"; to: 0; duration: 200; easing.type: Easing.InQuad }
                //         NumberAnimation { property: "x"; to: notifList.width; duration: 200; easing.type: Easing.InQuad }
                //     }
                // }

                addDisplaced: Transition {
                    NumberAnimation { property: "y"; duration: 300; easing.type: Easing.OutQuad }
                }

                // removeDisplaced: Transition {
                //     NumberAnimation { property: "y"; duration: 350; easing.type: Easing.OutBack }
                // }

                displaced: Transition {
                    NumberAnimation { property: "y"; duration: 300; easing.type: Easing.OutQuad }
                }

                delegate: Item {
                    id: delegateItem
                    width: notifList.width
                    // Extra bottom gap after the last item in a group, tight within a group
                    height: notifItem.implicitHeight + (isGroupLast && index < notifList.count - 1 ? 8 : 2)

                    readonly property var prevNotif: index > 0 ? notifList.model.values[index - 1] : null
                    readonly property var nextNotif: index < notifList.count - 1 ? notifList.model.values[index + 1] : null
                    readonly property bool isGroupFirst: !prevNotif || prevNotif.appName !== modelData.appName
                    readonly property bool isGroupLast:  !nextNotif || nextNotif.appName !== modelData.appName

                    NotificationItemNew {
                        id: notifItem
                        width: parent.width
                        topRadius: delegateItem.isGroupFirst ? 18 : 2
                        bottomRadius: delegateItem.isGroupLast ? 18 : 2
                    }
                }
            }
        }

    }    
}
