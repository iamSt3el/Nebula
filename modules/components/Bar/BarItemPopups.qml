import QtQuick
import qs.modules.services

BarButtonItem {
    id: root

    readonly property bool verticalReady: true
    readonly property int count: ServiceNotification.popups.length

    shown: BarLayout.anchorsOnly(root.host)
    icon: ServiceNotification.dnd ? "notifications_paused"
        : root.count > 0 ? "notifications_active" : "notifications"
    active: root.count > 0
    label: "Notifications"
    clickable: false
}
