import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

WeatherTileHost {
    id: root
    configKey: "weatherTileList"
    tile: Qt.size(WidgetSizes.span(2), WidgetSizes.span(3))
    defaultPos: Qt.point(1245, 495)

    readonly property real headH: 40
    readonly property real listY: pad + headH + gap
    readonly property real listH: height - listY - pad
    readonly property int count: 6
    readonly property real rowGap: 3
    readonly property real rowH: (listH - rowGap * (count - 1)) / count
    readonly property var slots: wx.hours.slice(0, count)
    readonly property int lo: slots.length ? Math.min(...slots.map(s => s.temp)) : 0
    readonly property int hi: slots.length ? Math.max(...slots.map(s => s.temp)) : 1

    rows: [
        [pad, pad, width - pad * 2, headH],
        [pad + 3, listY, width - pad * 2 - 6, listH]
    ]

    WeatherTileHeader {
        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        height: root.headH
        wx: root.wx
    }

    Repeater {
        model: root.slots

        Rectangle {
            id: line
            required property var modelData
            required property int index
            readonly property bool isNow: line.modelData.now
            readonly property bool first: line.index === 0
            readonly property bool last: line.index === root.slots.length - 1
            readonly property color ink: line.isNow ? Colors.primaryText : Colors.secondaryContainerText
            readonly property real level: (line.modelData.temp - root.lo) / Math.max(1, root.hi - root.lo)

            x: root.pad
            y: root.listY + line.index * (root.rowH + root.rowGap)
            width: root.width - root.pad * 2
            height: root.rowH
            topLeftRadius: line.isNow ? root.nowRadius : line.first ? root.tileRadius : 6
            topRightRadius: topLeftRadius
            bottomLeftRadius: line.isNow ? root.nowRadius : line.last ? root.tileRadius : 6
            bottomRightRadius: bottomLeftRadius
            color: line.isNow ? Colors.primary : Colors.secondaryContainer

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                CustomText {
                    Layout.preferredWidth: 30
                    content: line.isNow ? "Now" : line.modelData.h12
                    size: 11
                    weight: 500
                    customColor: Qt.alpha(line.ink, 0.85)
                }
                MaterialIconSymbol {
                    content: line.modelData.icon
                    iconSize: 18
                    fill: line.isNow ? 1 : 0
                    customColor: line.ink
                }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 10

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Qt.alpha(line.ink, line.isNow ? 0.25 : 0.18)
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.round(line.level * (parent.width - width))
                        width: 10
                        height: 10
                        radius: 5
                        color: line.isNow ? Colors.primaryText : Colors.primary
                        Behavior on x { SpatialAnim {} }
                    }
                }
                CustomText {
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignRight
                    content: line.modelData.temp + "°"
                    size: 13
                    weight: 700
                    customColor: line.ink
                }
            }
        }
    }
}
