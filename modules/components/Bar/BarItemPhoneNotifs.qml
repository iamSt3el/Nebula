import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool hideEmpty: BarLayout.opt(root.itemId, "hideEmpty") === true
    readonly property bool shown: ServicePhone.ready && (!root.hideEmpty || root.count > 0)
    readonly property bool iconSizable: true
    readonly property real box: BarLayout.boxFor(root.itemId, root.host)
    readonly property real iconPx: BarLayout.iconPxFor(root.itemId, root.box, 18)
    readonly property real plate: BarLayout.platePxFor(root.box, root.iconPx, 18, 28)
    readonly property bool open: !!root.host && root.host.panelKind === "phoneNotifs"
    readonly property int count: ServicePhone.notifications.length
    readonly property bool vertical: !!root.host && root.host.vertical === true
    readonly property bool verticalReady: true
    readonly property bool alertOn: BarLayout.opt(root.itemId, "peek") !== false
    readonly property bool tonal: root.count > 0 && !ServicePhone.muted
    readonly property bool hot: hov.containsMouse || root.open
    readonly property bool alerting: root.alertOn && !root.open && !ServicePhone.muted && ServicePhone.unread > 0
    readonly property bool ringing: root.alerting && ServicePhone.peek !== null
    readonly property color plateColor: root.hot ? Colors.primaryContainer
        : root.alerting ? Colors.primary
        : root.tonal ? Colors.secondaryContainer : Qt.alpha(Colors.secondaryContainer, 0)
    readonly property bool plateless: BarLayout.chipHovers(root.itemId, root.implicitWidth,
                                                           root.implicitHeight) && !root.tonal && !root.alerting
    readonly property bool plateOn: root.plateColor.a > 0.01
    readonly property color ink: root.hot ? Colors.primaryContainerText
        : root.alerting ? Colors.primaryText
        : root.tonal ? Colors.secondaryContainerText : Colors.surfaceVariantText

    implicitWidth: root.tonal && !root.vertical ? idle.implicitWidth + root.plate - root.iconPx : root.plate
    implicitHeight: root.vertical && root.tonal ? Math.max(root.plate, idle.implicitHeight + 10) : root.plate
    radius: Math.min(width, height) / 2
    color: root.plateless ? "transparent" : root.plateColor
    Behavior on implicitWidth { SpatialAnim { speed: "fast" } }
    Behavior on color { EffectsColorAnim { speed: "fast" } }

    Rectangle {
        id: ring
        property real spread: 0
        z: -1
        anchors.centerIn: parent
        width: root.width + 2 * ring.spread
        height: root.height + 2 * ring.spread
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Colors.primary
        opacity: 0
        visible: root.ringing

        SequentialAnimation {
            running: root.ringing
            loops: Animation.Infinite
            onStopped: { ring.spread = 0; ring.opacity = 0 }
            ParallelAnimation {
                NumberAnimation { target: ring; property: "spread"; from: 0; to: 6; duration: 900; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring; property: "opacity"; from: 0.8; to: 0; duration: 900; easing.type: Easing.OutCubic }
            }
            PauseAnimation { duration: 250 }
        }
    }

    Grid {
        id: idle
        anchors.centerIn: parent
        spacing: root.vertical ? 2 : 7
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        Behavior on opacity { EffectsAnim { speed: "fast" } }

        MaterialIconSymbol {
            content: ServicePhone.muted ? "notifications_off" : root.alerting ? "mark_chat_unread" : "chat"
            iconSize: root.iconPx
            customColor: root.ink
        }

        Rectangle {
            visible: root.tonal
            implicitWidth: Math.max(18, badge.implicitWidth + 8)
            implicitHeight: 18
            radius: 9
            color: root.hot ? Colors.primaryContainerText : root.alerting ? Colors.primaryText : Colors.primary
            Behavior on color { EffectsColorAnim { speed: "fast" } }

            CustomText {
                id: badge
                anchors.centerIn: parent
                content: root.count > 99 ? "99+" : String(root.count)
                size: 11
                weight: 700
                customColor: root.hot ? Colors.primaryContainer : root.alerting ? Colors.primary : Colors.primaryText
            }
        }
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            ServicePhone.peek = null
            if (mouse.button === Qt.RightButton)
                ServicePhone.mute(ServicePhone.muted ? 0 : 3600000)
            else if (mouse.button === Qt.MiddleButton)
                ServicePhone.dismissAll()
            else if (root.host)
                root.host.openPanel("phoneNotifs", root)
        }
    }

    CustomToolTip {
        content: (root.count === 0 ? "Nothing new from " : root.count === 1 ? "1 notification from " : root.count + " notifications from ")
            + ServicePhone.label + (ServicePhone.muted ? ", muted" : ServicePhone.unread > 0 ? ", " + ServicePhone.unread + " new" : "")
        detail: ServicePhone.muted ? "Right-click to unmute" : "Right-click to mute for an hour"
        visible: hov.containsMouse && !root.open
    }
}
