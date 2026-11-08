import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

WeatherTileHost {
    id: root
    configKey: "weatherTileDays"
    tile: Qt.size(WidgetSizes.span(3), WidgetSizes.span(1.5))
    defaultPos: Qt.point(805, 165)

    readonly property real headH: 34
    readonly property real rowY: pad + headH + gap
    readonly property var list: wx.days.slice(0, 5)
    readonly property string trend: {
        if (root.list.length < 3) return ""
        return root.list[2].hi > root.list[0].hi ? "Warming up" : root.list[2].hi < root.list[0].hi ? "Cooling down" : "Steady"
    }

    rows: [
        [pad, pad, width - pad * 2, headH],
        [pad + 3, rowY, width - pad * 2 - 6, height - rowY - pad]
    ]

    Rectangle {
        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        height: root.headH
        radius: root.tileRadius
        color: Colors.secondaryContainer

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 14
            spacing: 8

            MaterialIconSymbol {
                content: "calendar_month"
                iconSize: 17
                fill: 1
                customColor: Colors.secondaryContainerText
            }
            CustomText {
                Layout.fillWidth: true
                content: "Next " + root.list.length + " days"
                size: 13
                weight: 700
                customColor: Colors.secondaryContainerText
            }
            CustomText {
                content: root.trend
                size: 12
                weight: 500
                customColor: Qt.alpha(Colors.secondaryContainerText, 0.75)
            }
        }
    }

    RowLayout {
        x: root.pad
        y: root.rowY
        width: root.width - root.pad * 2
        height: root.height - root.rowY - root.pad
        spacing: root.gap

        Repeater {
            model: root.list

            Rectangle {
                id: day
                required property var modelData
                required property int index
                readonly property bool first: day.index === 0
                readonly property color ink: day.first ? Colors.primaryText : Colors.secondaryContainerText

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: day.first ? root.nowRadius : root.tileRadius
                color: day.first ? Colors.primary : Colors.secondaryContainer

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: day.modelData.label
                        size: 11
                        weight: 500
                        customColor: Qt.alpha(day.ink, 0.85)
                    }
                    MaterialIconSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        content: day.modelData.icon
                        iconSize: 20
                        fill: day.first ? 1 : 0
                        customColor: day.ink
                    }
                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: day.modelData.hi + "°"
                        size: 13
                        weight: 700
                        customColor: day.ink
                    }
                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: day.modelData.lo + "°"
                        size: 11
                        weight: 500
                        customColor: Qt.alpha(day.ink, 0.72)
                    }
                }
            }
        }
    }
}
