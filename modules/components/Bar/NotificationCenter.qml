import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.customComponents
import qs.modules.utils
import qs.modules.services
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MatrialShapeFn

Item {
    id: root
    anchors.fill: parent

    signal notificationCenterClosed
    property bool active: false

    onActiveChanged: {
        if (!active) root.notificationCenterClosed()
    }

    opacity: 0
    scale: 0.8

    NumberAnimation on opacity { from: 0; to: 1; duration: 400; running: true }
    NumberAnimation on scale   { from: 0.8; to: 1; duration: 400; running: true }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // ── Header ───────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialIconSymbol {
                content: ServiceNotification.muted ? "notifications_off" : "notifications"
                iconSize: 18
                customColor: Colors.primary
                Behavior on customColor { ColorAnimation { duration: 150 } }
            }

            CustomText {
                content: "Notifications"
                size: 15
                weight: 700
            }

            // Count badge
            Rectangle {
                visible: ServiceNotification.allNotifications.length > 0
                implicitWidth: Math.max(countText.implicitWidth + 10, 20)
                implicitHeight: 18
                radius: 9
                color: Qt.alpha(Colors.primary, 0.15)

                CustomText {
                    id: countText
                    anchors.centerIn: parent
                    content: ServiceNotification.allNotifications.length.toString()
                    size: 11
                    weight: 700
                    customColor: Colors.primary
                }
            }

            Item { Layout.fillWidth: true }

            // DND toggle
            Rectangle {
                Layout.preferredHeight: 30
                Layout.preferredWidth: 30
                radius: 10
                color: ServiceNotification.muted ? Colors.primary
                     : (dndArea.containsMouse ? Colors.surfaceContainerHighest : "transparent")
                Behavior on color { ColorAnimation { duration: 150 } }

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: "notifications_off"
                    iconSize: 16
                    customColor: ServiceNotification.muted ? Colors.primaryText : Colors.surfaceVariantText
                    Behavior on customColor { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: dndArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ServiceNotification.toggleMute()
                }
            }

            // Clear all (only when there are notifications)
            Rectangle {
                Layout.preferredHeight: 30
                Layout.preferredWidth: 30
                radius: 10
                visible: ServiceNotification.allNotifications.length > 0
                color: clearArea.containsMouse ? Colors.surfaceContainerHighest : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: "delete_sweep"
                    iconSize: 16
                    customColor: Colors.surfaceVariantText
                }

                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ServiceNotification.clear()
                }
            }

            // Close panel
            Rectangle {
                Layout.preferredHeight: 30
                Layout.preferredWidth: 30
                radius: 10
                color: closeArea.containsMouse ? Colors.surfaceContainerHighest : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: "close"
                    iconSize: 16
                    customColor: Colors.surfaceVariantText
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.notificationCenterClosed()
                }
            }
        }

        // ── Empty state ──────────────────────────────────────────────────
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: ServiceNotification.groupedNotifications.length === 0
            visible: active
            sourceComponent: Item {
                anchors.fill: parent
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    MaterialShapes.ShapeCanvas {
                        Layout.alignment: Qt.AlignCenter
                        Layout.preferredHeight: 80
                        Layout.preferredWidth: 80
                        roundedPolygon: MatrialShapeFn.getSunny()
                        color: Colors.primaryText

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: ServiceNotification.muted ? "notifications_off" : "notifications"
                            iconSize: 26
                            customColor: Colors.primary
                        }
                    }

                    CustomText {
                        Layout.alignment: Qt.AlignCenter
                        content: ServiceNotification.muted ? "Do Not Disturb on" : "No notifications"
                        size: 14
                        weight: 600
                        customColor: Colors.outline
                    }

                    CustomText {
                        Layout.alignment: Qt.AlignCenter
                        content: ServiceNotification.muted ? "Notifications are silenced" : "You're all caught up"
                        size: 12
                        weight: 400
                        customColor: Colors.outline
                    }
                }
            }
        }

        // ── Notification list ────────────────────────────────────────────
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

                addDisplaced: Transition {
                    NumberAnimation { property: "y"; duration: 300; easing.type: Easing.OutQuad }
                }

                displaced: Transition {
                    NumberAnimation { property: "y"; duration: 300; easing.type: Easing.OutQuad }
                }

                delegate: Item {
                    id: delegateItem
                    width: notifList.width
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
