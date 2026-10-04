import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MatrialShapeFn

Item {
    id: root

    property real maxHeight: 640
    readonly property int count: ServiceNotification.allNotifications.length
    readonly property bool isEmpty: ServiceNotification.groupedNotifications.length === 0
    readonly property bool dnd: ServiceNotification.dnd
    readonly property real until: ServiceNotification.muteUntil
    readonly property string mode: !root.dnd ? "" : root.until <= 0 ? "on"
        : root.until === root.morning ? "morning" : "hour"

    property real morning: root.nextMorning()
    property bool counted: false

    readonly property real fixedHeight: header.implicitHeight + dndCard.implicitHeight + 12 + 8 + 12 + 12
    readonly property real listRoom: Math.max(140, root.maxHeight - root.fixedHeight)
    readonly property real listHeight: root.isEmpty ? 140
        : Math.min(root.listRoom, Math.max(140, notifList.contentHeight + notifList.shelfRise))

    implicitWidth: 400
    implicitHeight: root.fixedHeight + root.listHeight

    function nextMorning() {
        const d = new Date()
        d.setHours(8, 0, 0, 0)
        if (d.getTime() <= Date.now())
            d.setDate(d.getDate() + 1)
        return d.getTime()
    }

    function hhmm(ms) {
        const d = new Date(ms)
        return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0")
    }

    readonly property string status: {
        if (!root.dnd)
            return "Popups and sounds are on"
        if (root.until <= 0)
            return "On until you turn it off"
        const sameDay = new Date(root.until).toDateString() === new Date().toDateString()
        return "On until " + root.hhmm(root.until) + (sameDay ? "" : " tomorrow")
    }

    function pick(value) {
        root.morning = root.nextMorning()
        if (value === "hour")
            ServiceNotification.setDnd(true, Date.now() + 3600000)
        else if (value === "morning")
            ServiceNotification.setDnd(true, root.morning)
        else
            ServiceNotification.setDnd(true, 0)
    }

    function syncCount() {
        const want = root.visible
        if (want === root.counted)
            return
        root.counted = want
        GlobalStates.notificationCenterCount += want ? 1 : -1
    }

    onVisibleChanged: root.syncCount()
    Component.onCompleted: {
        root.morning = root.nextMorning()
        root.syncCount()
    }
    Component.onDestruction: if (root.counted) GlobalStates.notificationCenterCount--

    RowLayout {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        anchors.leftMargin: 16
        spacing: 8

        MaterialIconSymbol {
            content: root.dnd ? "notifications_paused" : "notifications"
            iconSize: 20
            customColor: Colors.primary
        }

        CustomText {
            content: "Notifications"
            size: 15
            weight: 700
        }

        Rectangle {
            visible: root.count > 0
            implicitWidth: Math.max(countText.implicitWidth + 12, 22)
            implicitHeight: 20
            radius: 10
            color: Qt.alpha(Colors.primary, 0.16)

            CustomText {
                id: countText
                anchors.centerIn: parent
                content: String(root.count)
                size: 11
                weight: 700
                customColor: Colors.primary
            }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            visible: root.count > 0
            implicitWidth: clearRow.implicitWidth + 24
            implicitHeight: 32
            radius: 16
            color: Colors.surfaceContainerHigh

            RowLayout {
                id: clearRow
                anchors.centerIn: parent
                spacing: 5

                MaterialIconSymbol {
                    content: "clear_all"
                    iconSize: 16
                    customColor: Colors.surfaceVariantText
                }

                CustomText {
                    content: "Clear all"
                    size: 12
                    weight: 600
                    customColor: Colors.surfaceVariantText
                }
            }

            RippleEffect {
                anchors.fill: parent
                radius: parent.radius
                hoverColor: Qt.alpha(Colors.primary, 0.10)
                rippleColor: Qt.alpha(Colors.primary, 0.22)
                onClicked: ServiceNotification.clear()
            }
        }
    }

    Rectangle {
        id: dndCard
        anchors { left: parent.left; right: parent.right; top: header.bottom; topMargin: 12; leftMargin: 12; rightMargin: 12 }
        implicitHeight: dndCol.implicitHeight + 24
        radius: 20
        color: root.dnd ? Colors.secondaryContainer : Colors.surfaceContainer
        Behavior on color { EffectsColorAnim {} }

        ColumnLayout {
            id: dndCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 12
                    color: root.dnd ? Colors.primary : Colors.surfaceContainerHighest
                    Behavior on color { EffectsColorAnim {} }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: root.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                        iconSize: 19
                        customColor: root.dnd ? Colors.primaryText : Colors.surfaceVariantText
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    CustomText {
                        content: "Do Not Disturb"
                        size: 13
                        weight: 600
                        customColor: root.dnd ? Colors.secondaryContainerText : Colors.surfaceText
                    }

                    CustomText {
                        content: root.status
                        size: 11
                        customColor: root.dnd ? Colors.secondaryContainerText : Colors.surfaceVariantText
                        opacity: 0.85
                    }
                }

                Item { Layout.fillWidth: true }

                CustomToogle {
                    id: dndSwitch
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 28
                    isToggleOn: root.dnd
                    onToggled: state => {
                        ServiceNotification.setDnd(state, 0)
                        dndSwitch.isToggleOn = Qt.binding(() => root.dnd)
                    }
                }
            }

            M3ButtonGroup {
                Layout.fillWidth: true
                fillWidth: true
                height: 32
                textSize: 12
                inactiveColor: root.dnd ? Qt.alpha(Colors.surface, 0.35) : Colors.surfaceContainerHighest
                model: [
                    { value: "hour",    label: "1 hour" },
                    { value: "morning", label: "Until " + root.hhmm(root.morning) },
                    { value: "on",      label: "Until off" }
                ]
                activeCheck: value => value === root.mode
                onSegmentClicked: value => value === root.mode ? ServiceNotification.setDnd(false) : root.pick(value)
            }
        }
    }

    Item {
        id: body
        anchors { left: parent.left; right: parent.right; top: dndCard.bottom; topMargin: 8; leftMargin: 12; rightMargin: 12 }
        height: root.listHeight

        NotificationList {
            id: notifList
            anchors.fill: parent
            visible: !root.isEmpty
        }

        ColumnLayout {
            anchors.centerIn: parent
            visible: root.isEmpty
            spacing: 8

            MaterialShapes.ShapeCanvas {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                roundedPolygon: MatrialShapeFn.getSunny()
                color: Colors.surfaceContainerHigh

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: root.dnd ? "notifications_paused" : "done_all"
                    iconSize: 22
                    customColor: Colors.primary
                }
            }

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: "You're all caught up"
                size: 13
                weight: 600
            }

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: root.dnd ? "New ones will wait here quietly" : "New notifications will show up here"
                size: 11
                customColor: Colors.outline
            }
        }
    }
}
