import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: root.next !== null

    readonly property int horizon: BarLayout.opt(root.itemId, "days") ?? 30

    readonly property var next: {
        const today = ServiceClock.year + "-" + String(new Date().getMonth() + 1).padStart(2, "0") + "-" + ServiceClock.date
        if (parseInt(ServiceClock.year) !== ServiceClock.currentHolidayYear)
            return null
        const list = (ServiceClock.holidayData ?? []).filter(h => h.date >= today)
            .sort((a, b) => a.date < b.date ? -1 : a.date > b.date ? 1 : 0)
        if (!list.length)
            return null
        const d = new Date(list[0].date + "T00:00:00")
        const now = new Date()
        now.setHours(0, 0, 0, 0)
        const days = Math.round((d - now) / 86400000)
        if (days > root.horizon)
            return null
        return { name: list[0].name, date: d, days: days }
    }

    readonly property string when: {
        if (!root.next)
            return ""
        if (root.next.days === 0)
            return "Today"
        if (root.next.days === 1)
            return "Tomorrow"
        if (root.next.days < 7)
            return Qt.formatDate(root.next.date, "ddd")
        return Qt.formatDate(root.next.date, "ddd d MMM")
    }

    implicitWidth: row.implicitWidth + 10
    implicitHeight: 26
    radius: height / 2
    color: hov.containsMouse ? Colors.primaryContainer
         : root.next && root.next.days === 0 ? Colors.secondaryContainer : Colors.surfaceContainer
    Behavior on color { EffectsColorAnim {} }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        MaterialIconSymbol {
            anchors.verticalCenter: parent.verticalCenter
            content: "event"
            iconSize: 16
            customColor: hov.containsMouse ? Colors.primaryContainerText : Colors.secondary
        }
        CustomText {
            anchors.verticalCenter: parent.verticalCenter
            content: root.next ? root.next.name : ""
            size: 12
            weight: 600
            width: Math.min(implicitWidth, BarLayout.opt(root.itemId, "width") ?? 140)
            elide: Text.ElideRight
            customColor: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
        }
        CustomText {
            anchors.verticalCenter: parent.verticalCenter
            content: root.when
            size: 12
            weight: 500
            customColor: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceVariantText
        }
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.host) root.host.openPanel("calendar", root)
    }

    CustomToolTip {
        content: root.next ? root.next.name + " · " + Qt.formatDate(root.next.date, "dddd d MMMM")
                             + (root.next.days > 1 ? " · in " + root.next.days + " days" : "") : ""
        visible: hov.containsMouse
    }
}
