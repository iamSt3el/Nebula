import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

WeatherTileHost {
    id: root
    configKey: "weatherTileThermo"
    tile: Qt.size(WidgetSizes.span(3), WidgetSizes.span(1.5))
    defaultPos: Qt.point(475, 330)

    readonly property real headH: 40
    readonly property real rowY: pad + headH + gap
    readonly property int count: 6
    readonly property real slotW: (width - pad * 2 - gap * (count - 1)) / count
    readonly property var slots: wx.hours.slice(0, count)
    readonly property int lo: Math.min(...slots.map(s => s.temp)) - 2
    readonly property int hi: Math.max(...slots.map(s => s.temp)) + 1

    rows: {
        const out = [[pad, pad, width - pad * 2, headH]]
        for (let i = 0; i < count; i++)
            out.push([pad + i * (slotW + gap), rowY, slotW, height - rowY - pad])
        return out
    }

    WeatherTileHeader {
        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        height: root.headH
        wx: root.wx
        trailingIcon: "water_drop"
        trailing: root.wx.ready ? root.wx.humidity + "%" : ""
    }

    Repeater {
        model: root.slots

        Rectangle {
            id: slot
            required property var modelData
            required property int index
            readonly property bool isNow: slot.modelData.now
            readonly property real level: Math.max(0, Math.min(1, (slot.modelData.temp - root.lo) / Math.max(1, root.hi - root.lo)))

            x: root.pad + slot.index * (root.slotW + root.gap)
            y: root.rowY
            width: root.slotW
            height: root.height - root.rowY - root.pad
            radius: slot.isNow ? root.nowRadius : root.tileRadius
            color: slot.isNow ? Colors.primary : Colors.surfaceContainerHigh
            clip: true

            Rectangle {
                visible: !slot.isNow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * slot.level
                topLeftRadius: 12
                topRightRadius: 12
                bottomLeftRadius: root.tileRadius
                bottomRightRadius: root.tileRadius
                color: Colors.secondaryContainer
                Behavior on height { SpatialAnim {} }
            }

            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 8
                content: slot.isNow ? "Now" : slot.modelData.h12
                size: 11
                weight: 500
                customColor: slot.isNow ? Colors.primaryText : Qt.alpha(Colors.surfaceText, 0.8)
            }

            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 9
                content: slot.modelData.temp + "°"
                size: 13
                weight: 700
                customColor: slot.isNow ? Colors.primaryText : Colors.secondaryContainerText
            }
        }
    }
}
