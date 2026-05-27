pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtMultimedia

Singleton {
    id: root

    property list<NotificationItem> allNotifications: []
    property var groupedNotifications: []         // list of NotificationGroup objects
    property list<NotificationItem> popups: allNotifications.filter(n => n.popup)
    property int notificationsNumber: allNotifications.length
    property bool muted: false

    SoundEffect {
        id: notificationSound
        source: "../../notification.wav"
    }

    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        inlineReplySupported: true

        onNotification: notif => {
            notif.tracked = true
            notificationSound.play()

            var item = notifComp.createObject(root, {
                popup: !root.muted,
                notification: notif
            })

            root.allNotifications.push(item)
            root.allNotifications = root.allNotifications.slice()

            // Find existing group for this app
            var existingGroup = null
            for (var i = 0; i < root.groupedNotifications.length; i++) {
                if (root.groupedNotifications[i].appName === notif.appName) {
                    existingGroup = root.groupedNotifications[i]
                    break
                }
            }

            if (existingGroup) {
                existingGroup.notifications.push(item)
                existingGroup.notifications = existingGroup.notifications.slice()
                existingGroup.appIcon = notif.appIcon  // keep icon up-to-date
            } else {
                var group = groupComp.createObject(root, {
                    appName: notif.appName,
                    appIcon: notif.appIcon
                })
                group.notifications = [item]
                root.groupedNotifications.push(group)
                root.groupedNotifications = root.groupedNotifications.slice()
            }
        }
    }

    component NotificationItem: QtObject {
        id: notifItem

        property bool popup
        required property Notification notification
        readonly property string id: notification.id ?? null
        readonly property string summary: notification.summary ?? null
        readonly property string body: notification.body ?? null
        readonly property string appIcon: notification.appIcon ?? null
        readonly property string appName: notification.appName ?? null
        readonly property string image: notification.image
        readonly property int urgency: notification.urgency ?? null
        readonly property bool isLow: notification.urgency === NotificationUrgency.Low
        readonly property bool isNormal: notification.urgency === NotificationUrgency.Normal
        readonly property bool isCritical: notification.urgency === NotificationUrgency.Critical

        property Timer timer: Timer {
            running: true
            interval: 5000
            onTriggered: notifItem.popup = false
        }

        property real progress: 0
        NumberAnimation on progress {
            running: timer.running
            from: 0
            to: 1
            duration: timer.interval
        }
    }

    // One group per unique appName. `notifications` holds items newest-last
    // so that reversing in the view shows newest-first.
    component NotificationGroup: QtObject {
        property string appName: ""
        property string appIcon: ""
        property var notifications: []        // NotificationItem[]
        property bool isExpanded: false
        readonly property int count: notifications.length
        // Latest notification (shown in collapsed header)
        readonly property var latest: notifications.length > 0
            ? notifications[notifications.length - 1] : null
    }

    function clear() {
        root.allNotifications = []
        root.groupedNotifications = []
    }

    function removeNotification(notificationItem) {
        // Remove from flat list
        var idx = root.allNotifications.indexOf(notificationItem)
        if (idx > -1) {
            root.allNotifications.splice(idx, 1)
            root.allNotifications = root.allNotifications.slice()
        }

        // Remove from its group; drop the group when it becomes empty
        for (var i = 0; i < root.groupedNotifications.length; i++) {
            var group = root.groupedNotifications[i]
            var ni = group.notifications.indexOf(notificationItem)
            if (ni > -1) {
                group.notifications.splice(ni, 1)
                if (group.notifications.length === 0) {
                    root.groupedNotifications.splice(i, 1)
                    root.groupedNotifications = root.groupedNotifications.slice()
                } else {
                    group.notifications = group.notifications.slice()
                }
                break
            }
        }
    }

    // Dismiss every notification in a group at once
    function removeGroup(group) {
        for (var j = group.notifications.length - 1; j >= 0; j--) {
            var ni = root.allNotifications.indexOf(group.notifications[j])
            if (ni > -1)
                root.allNotifications.splice(ni, 1)
        }
        root.allNotifications = root.allNotifications.slice()

        var gi = root.groupedNotifications.indexOf(group)
        if (gi > -1) {
            root.groupedNotifications.splice(gi, 1)
            root.groupedNotifications = root.groupedNotifications.slice()
        }
    }

    function toggleMute() {
        root.muted = !root.muted
    }

    function sendNotification(summary, body, appName, appIcon) {
        notifSender.command = [
            "notify-send",
            "--app-name", appName || "Quickshell",
            "--icon", appIcon || "dialog-information",
            summary,
            body || ""
        ]
        notifSender.running = true
    }

    Process {
        id: notifSender
    }

    Component {
        id: notifComp
        NotificationItem {}
    }

    Component {
        id: groupComp
        NotificationGroup {}
    }
}
