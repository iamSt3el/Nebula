import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

WeatherTileHost {
    id: root
    configKey: "weatherTileHourly"
    tile: Qt.size(WidgetSizes.span(3), WidgetSizes.span(1.5))
    defaultPos: Qt.point(475, 165)

    readonly property real headH: 40
    readonly property real rowY: pad + headH + gap

    rows: [
        [pad, pad, width - pad * 2, headH],
        [pad + 3, rowY, width - pad * 2 - 6, height - rowY - pad]
    ]

    WeatherTileHeader {
        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        height: root.headH
        wx: root.wx
        trailing: root.wx.ready ? "↑" + root.wx.hi + "° ↓" + root.wx.lo + "°" : ""
    }

    RowLayout {
        x: root.pad
        y: root.rowY
        width: root.width - root.pad * 2
        height: root.height - root.rowY - root.pad
        spacing: root.gap

        Repeater {
            model: root.wx.hours.slice(0, 5)

            Rectangle {
                id: slot
                required property var modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: slot.modelData.now ? root.nowRadius : root.tileRadius
                color: slot.modelData.now ? Colors.primary : Colors.secondaryContainer
                readonly property color ink: slot.modelData.now ? Colors.primaryText : Colors.secondaryContainerText

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 5

                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: slot.modelData.now ? "Now" : slot.modelData.h24
                        size: 11
                        weight: 500
                        customColor: Qt.alpha(slot.ink, 0.85)
                    }
                    MaterialIconSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        content: slot.modelData.icon
                        iconSize: 20
                        fill: slot.modelData.now ? 1 : 0
                        customColor: slot.ink
                    }
                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: slot.modelData.temp + "°"
                        size: 13
                        weight: 700
                        customColor: slot.ink
                    }
                }
            }
        }
    }
}
