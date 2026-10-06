import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true
    readonly property real roundT: root.host && root.host.roundT !== undefined ? root.host.roundT : 0

    readonly property int week: {
        if (ServiceClock.date === "")
            return 0
        const d = new Date()
        d.setHours(0, 0, 0, 0)
        d.setDate(d.getDate() + 3 - (d.getDay() + 6) % 7)
        const w1 = new Date(d.getFullYear(), 0, 4)
        return 1 + Math.round(((d - w1) / 86400000 - 3 + (w1.getDay() + 6) % 7) / 7)
    }

    implicitWidth: label.implicitWidth + 14
    implicitHeight: 20
    radius: 6 + (height / 2 - 6) * root.roundT
    color: Colors.secondaryContainer

    CustomText {
        id: label
        anchors.centerIn: parent
        content: "W" + root.week
        size: 11
        weight: 700
        font.features: { "tnum": 1 }
        customColor: Colors.secondaryContainerText
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
    }

    CustomToolTip {
        content: "Week " + root.week + " of " + ServiceClock.year
        visible: hov.containsMouse
    }
}
