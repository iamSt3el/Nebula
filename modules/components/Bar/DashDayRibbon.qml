pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property DashWeather wx: null

    readonly property real pad: 10
    readonly property real skyTop: 10
    readonly property real skyH: Math.max(60, root.height - 70)
    readonly property real horizon: root.skyTop + root.skyH
    readonly property real nowH: { ServiceClock.minute; const d = new Date(); return d.getHours() + d.getMinutes() / 60 }
    readonly property real bootH: {
        ServiceClock.minute
        if (ServiceProfile.bootAt <= 0)
            return -1
        const b = new Date(ServiceProfile.bootAt)
        const d = new Date()
        const midnight = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
        return ServiceProfile.bootAt < midnight ? 0 : b.getHours() + b.getMinutes() / 60
    }
    readonly property bool hasSun: !!root.wx && root.wx.sunriseH >= 0 && root.wx.sunsetH > root.wx.sunriseH
    readonly property var temps: {
        if (!root.wx)
            return []
        const out = root.wx.dayHours()
        const tomorrow = (root.wx.days[1]?.hourly ?? [])[0]
        if (tomorrow)
            out.push({ hour: 24, temp: root.wx.tempOf(tomorrow) })
        return out
    }

    function xOf(h) {
        return root.pad + h / 24 * (root.width - 2 * root.pad)
    }

    Rectangle {
        x: root.pad
        y: root.skyTop
        width: root.width - 2 * root.pad
        height: root.skyH
        radius: 14
        color: Colors.surfaceContainerHigh
    }

    Shape {
        anchors.fill: parent
        visible: root.hasSun
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Colors.tertiaryContainer
            strokeWidth: 2.5
            fillColor: Qt.alpha(Colors.tertiaryContainer, 0.14)
            startX: root.xOf(root.wx?.sunriseH ?? 6)
            startY: root.horizon
            PathQuad {
                x: root.xOf(root.wx?.sunsetH ?? 18)
                y: root.horizon
                controlX: (root.xOf(root.wx?.sunriseH ?? 6) + root.xOf(root.wx?.sunsetH ?? 18)) / 2
                controlY: 2 * (root.skyTop + 12) - root.horizon
            }
        }
    }

    Rectangle {
        x: root.pad
        y: root.horizon - 1
        width: root.width - 2 * root.pad
        height: 1.5
        color: Colors.outlineVariant
    }

    Repeater {
        model: root.hasSun ? [{ h: root.wx.sunriseH, label: root.wx.sunrise, left: true }, { h: root.wx.sunsetH, label: root.wx.sunset, left: false }] : []

        Item {
            id: mark
            required property var modelData

            Rectangle {
                x: root.xOf(mark.modelData.h) - 4
                y: root.horizon - 4
                width: 8
                height: 8
                radius: 4
                color: Colors.tertiaryContainer
            }

            CustomText {
                x: mark.modelData.left ? root.xOf(mark.modelData.h) - width - 8 : root.xOf(mark.modelData.h) + 8
                y: root.horizon - height - 2
                content: mark.modelData.label.replace(/\s*[AP]M$/i, "")
                size: 11
                weight: 500
                customColor: Colors.surfaceVariantText
            }
        }
    }

    Rectangle {
        visible: root.bootH >= 0
        x: root.xOf(Math.max(0, root.bootH))
        y: root.horizon + 8
        width: Math.max(10, root.xOf(root.nowH) - x)
        height: 10
        radius: 5
        color: Colors.primary
    }

    CustomText {
        visible: root.bootH >= 0
        readonly property real at: root.xOf(Math.max(0, root.bootH))
        x: at - width - 8 >= root.pad ? at - width - 8 : root.xOf(root.nowH) + 10
        y: root.horizon + 13 - height / 2
        content: root.bootH <= 0 ? "Up " + ServiceProfile.uptimeText : "Up since " + Qt.formatTime(new Date(ServiceProfile.bootAt), "hh:mm")
        size: 11
        weight: 500
        customColor: Colors.surfaceVariantText
    }

    Rectangle {
        x: root.xOf(root.nowH) - 1
        y: root.skyTop + 12
        width: 2
        height: root.horizon + 20 - y
        color: Colors.tertiary
    }

    Rectangle {
        x: root.xOf(root.nowH) - width / 2
        y: root.skyTop - 2
        width: 50
        height: 20
        radius: 10
        color: Colors.tertiary

        CustomText {
            anchors.centerIn: parent
            content: "Now"
            size: 11
            weight: 700
            customColor: Colors.tertiaryText
        }
    }

    Repeater {
        model: [0, 3, 6, 9, 12, 15, 18, 21, 24]

        Column {
            id: tick
            required property int modelData
            readonly property var t: root.temps.find(e => e.hour === tick.modelData) ?? null

            x: tick.modelData === 0 ? root.pad : tick.modelData === 24 ? root.width - root.pad - width : root.xOf(tick.modelData) - width / 2
            y: root.horizon + 26
            spacing: 2

            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                content: (tick.modelData < 10 ? "0" : "") + tick.modelData
                size: 11
                weight: 500
                customColor: Colors.surfaceVariantText
            }

            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !!tick.t
                content: tick.t ? tick.t.temp : ""
                size: 12
                weight: 700
            }
        }
    }
}
