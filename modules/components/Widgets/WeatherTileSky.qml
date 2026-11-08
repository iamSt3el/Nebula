import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MaterialShapeFn

WeatherTileHost {
    id: root
    configKey: "weatherTileSky"
    tile: Qt.size(WidgetSizes.span(3), WidgetSizes.span(1.5))
    defaultPos: Qt.point(475, 495)

    readonly property real leftW: 128
    readonly property real innerH: height - pad * 2
    readonly property real gridX: pad + leftW + gap
    readonly property real gridW: width - gridX - pad
    readonly property real cellW: (gridW - gap) / 2
    readonly property real cellH: (innerH - gap) / 2

    readonly property bool day: wx.riseMin >= 0 && wx.setMin >= 0 && wx.nowMin >= wx.riseMin && wx.nowMin <= wx.setMin
    readonly property real dayProgress: day ? (wx.nowMin - wx.riseMin) / Math.max(1, wx.setMin - wx.riseMin) : 0
    readonly property int minutesLeft: {
        if (wx.riseMin < 0 || wx.setMin < 0) return 0
        if (day) return wx.setMin - wx.nowMin
        return wx.nowMin > wx.setMin ? 1440 - wx.nowMin + wx.riseMin : wx.riseMin - wx.nowMin
    }

    rows: [
        [pad, pad, leftW, innerH],
        [gridX, pad + 6, gridW, innerH - 12]
    ]

    Rectangle {
        id: arcTile
        x: root.pad
        y: root.pad
        width: root.leftW
        height: root.innerH
        radius: root.tileRadius
        color: Colors.secondaryContainer

        readonly property real r: 44
        readonly property real cx: width / 2
        readonly property real cy: 62

        WeatherTileArc {
            x: arcTile.cx - width / 2
            y: arcTile.cy - height / 2
            width: arcTile.r * 2 + 10
            height: width
            radius: arcTile.r
            startAngle: 270
            sweep: 180
            lineWidth: 6
            gapAngle: 10
            progress: root.dayProgress
            trackColor: Qt.alpha(Colors.secondaryContainerText, 0.18)
        }

        MaterialShapes.ShapeCanvas {
            visible: root.day
            readonly property real a: (270 + root.dayProgress * 180) * Math.PI / 180
            width: 24
            height: 24
            x: Math.round(arcTile.cx + arcTile.r * Math.sin(a) - 12)
            y: Math.round(arcTile.cy - arcTile.r * Math.cos(a) - 12)
            roundedPolygon: MaterialShapeFn.getSunny()
            color: Colors.primary
        }

        CustomText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 46
            content: Math.floor(root.minutesLeft / 60) + "h " + String(root.minutesLeft % 60).padStart(2, "0") + "m"
            family: root.display
            size: 17
            weight: Font.Normal
            customColor: Colors.secondaryContainerText
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 74
            spacing: 4

            MaterialIconSymbol {
                visible: !root.day
                content: "bedtime"
                iconSize: 13
                fill: 1
                customColor: Qt.alpha(Colors.secondaryContainerText, 0.85)
            }
            CustomText {
                content: root.day ? "until sunset" : "until sunrise"
                size: 11
                weight: 500
                customColor: Qt.alpha(Colors.secondaryContainerText, 0.85)
            }
        }
    }

    Repeater {
        model: [
            { icon: "wb_twilight", label: "Sunrise", value: root.wx.clock(root.wx.riseMin) },
            { icon: "bedtime", label: "Sunset", value: root.wx.clock(root.wx.setMin) },
            { icon: "umbrella", label: "Rain", value: root.wx.rainPeak + "%" },
            { icon: "water_drop", label: "Humid", value: root.wx.humidity + "%" }
        ]

        Rectangle {
            id: fact
            required property var modelData
            required property int index

            x: root.gridX + (fact.index % 2) * (root.cellW + root.gap)
            y: root.pad + Math.floor(fact.index / 2) * (root.cellH + root.gap)
            width: root.cellW
            height: root.cellH
            radius: root.tileRadius
            color: Colors.surfaceContainerHigh

            ColumnLayout {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Row {
                    spacing: 4
                    MaterialIconSymbol {
                        content: fact.modelData.icon
                        iconSize: 14
                        fill: 1
                        customColor: Qt.alpha(Colors.surfaceText, 0.8)
                    }
                    CustomText {
                        content: fact.modelData.label
                        size: 11
                        weight: 500
                        customColor: Qt.alpha(Colors.surfaceText, 0.8)
                    }
                }
                CustomText {
                    content: fact.modelData.value
                    size: 13
                    weight: 700
                }
            }
        }
    }
}
