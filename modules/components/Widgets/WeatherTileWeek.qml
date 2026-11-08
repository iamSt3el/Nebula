import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

WeatherTileHost {
    id: root
    configKey: "weatherTileWeek"
    tile: Qt.size(WidgetSizes.span(4), WidgetSizes.span(1.5))
    defaultPos: Qt.point(805, 330)

    readonly property var list: wx.days.slice(0, 7)
    readonly property int count: Math.max(1, list.length)
    readonly property real slotW: (width - pad * 2 - gap * (count - 1)) / count
    readonly property int lo: list.length ? Math.min(...list.map(d => d.lo)) - 1 : 0
    readonly property int hi: list.length ? Math.max(...list.map(d => d.hi)) + 1 : 1
    readonly property real barH: 46

    rows: {
        const out = []
        for (let i = 0; i < count; i++)
            out.push([pad + i * (slotW + gap), pad, slotW, height - pad * 2])
        return out
    }

    function yOf(v) {
        return root.barH - (v - root.lo) / Math.max(1, root.hi - root.lo) * root.barH
    }

    Repeater {
        model: root.list

        Rectangle {
            id: day
            required property var modelData
            required property int index
            readonly property bool first: day.index === 0
            readonly property color ink: day.first ? Colors.primaryText : Colors.secondaryContainerText

            x: root.pad + day.index * (root.slotW + root.gap)
            y: root.pad
            width: root.slotW
            height: root.height - root.pad * 2
            radius: day.first ? root.nowRadius : root.tileRadius
            color: day.first ? Colors.primary : Colors.secondaryContainer

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 9
                anchors.bottomMargin: 9
                spacing: 0

                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: day.modelData.label
                    size: 11
                    weight: 500
                    customColor: Qt.alpha(day.ink, 0.85)
                }
                Item { Layout.fillHeight: true }
                MaterialIconSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    content: day.modelData.icon
                    iconSize: 18
                    fill: day.first ? 1 : 0
                    customColor: day.ink
                }
                Item { Layout.fillHeight: true }
                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: day.modelData.hi + "°"
                    size: 12
                    weight: 700
                    customColor: day.ink
                }
                Item { Layout.preferredHeight: 4 }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: root.barH
                    radius: 4
                    color: day.first ? Qt.alpha(Colors.primaryText, 0.22) : Colors.surfaceContainerHighest

                    Rectangle {
                        width: parent.width
                        y: root.yOf(day.modelData.hi)
                        height: Math.max(8, root.yOf(day.modelData.lo) - root.yOf(day.modelData.hi))
                        radius: 4
                        color: day.first ? Colors.primaryText : Colors.primary
                        Behavior on y { SpatialAnim {} }
                        Behavior on height { SpatialAnim {} }
                    }
                }
                Item { Layout.preferredHeight: 4 }
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
