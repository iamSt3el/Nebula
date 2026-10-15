import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true
    readonly property bool iconSizable: true
    readonly property real box: BarLayout.boxFor(root.itemId, root.host)
    readonly property real iconPx: BarLayout.iconPxFor(root.itemId, root.box, 18)
    readonly property bool open: !!root.host && root.host.panelKind === "notifications"
    readonly property bool dnd: ServiceNotification.dnd
    readonly property int count: ServiceNotification.notificationsNumber
    readonly property color plateColor: hov.containsMouse || root.open ? Colors.primaryContainer : Qt.alpha(Colors.primaryContainer, 0)
    property int peek: -1
    property real wheelAcc: 0

    readonly property var peeked: root.peek >= 0 && root.peek < root.count
        ? ServiceNotification.allNotifications[root.count - 1 - root.peek] : null

    readonly property string tip: {
        if (root.peeked)
            return (root.peek + 1) + "/" + root.count + "  " + (root.peeked.appName || "App") + ": " + (root.peeked.summary || root.peeked.body || "")
        const head = root.count === 0 ? "No notifications" : root.count === 1 ? "1 notification" : root.count + " notifications"
        return head + (root.dnd ? ", Do Not Disturb on" : "")
    }
    readonly property bool plateless: BarLayout.chipHovers(root.itemId, root.implicitWidth,
                                                           root.implicitHeight)
    readonly property bool plateOn: root.plateColor.a > 0.01
    readonly property real plate: BarLayout.platePxFor(root.box, root.iconPx, 18, 28)

    implicitWidth: root.plate
    implicitHeight: root.plate
    radius: root.plate / 2
    color: root.plateless ? Qt.alpha(root.plateColor, 0) : root.plateColor
    Behavior on color { ColorAnimation { duration: 150 } }

    MaterialIconSymbol {
        anchors.centerIn: parent
        content: root.dnd ? "notifications_paused" : root.count > 0 ? "notifications_active" : "notifications"
        iconSize: root.iconPx
        customColor: hov.containsMouse || root.open ? Colors.primaryContainerText
                   : root.count > 0 && !root.dnd ? Colors.primary : Colors.surfaceText
        Behavior on customColor { ColorAnimation { duration: 150 } }
    }

    Rectangle {
        visible: root.count > 0 && !root.dnd
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: -1
        anchors.rightMargin: -1
        width: badgeText.implicitWidth + 4
        height: 12
        radius: 6
        color: Colors.primary

        CustomText {
            id: badgeText
            anchors.centerIn: parent
            content: ServiceNotification.notificationsNumber > 9
                     ? "9+" : String(ServiceNotification.notificationsNumber)
            size: 8; weight: 700
            customColor: Colors.primaryText
        }
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onContainsMouseChanged: if (!containsMouse) root.peek = -1
        onClicked: mouse => {
            root.peek = -1
            if (mouse.button === Qt.RightButton)
                ServiceNotification.setDnd(!root.dnd, 0)
            else if (mouse.button === Qt.MiddleButton)
                ServiceNotification.clear()
            else if (root.host)
                root.host.openPanel("notifications", root)
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (root.count === 0)
                return
            root.wheelAcc += event.angleDelta.y
            if (Math.abs(root.wheelAcc) < 120)
                return
            const step = root.wheelAcc < 0 ? 1 : -1
            root.wheelAcc = 0
            root.peek = Math.max(-1, Math.min(Math.min(root.count, 5) - 1, root.peek + step))
        }
    }

    CustomToolTip {
        content: root.tip
        visible: hov.containsMouse && !root.open
    }
}
