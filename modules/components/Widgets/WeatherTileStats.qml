import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MaterialShapeFn

WeatherTileHost {
    id: root
    configKey: "weatherTileStats"
    tile: Qt.size(WidgetSizes.span(2), WidgetSizes.span(2))
    defaultPos: Qt.point(1245, 165)

    readonly property real headH: 40
    readonly property real gridY: pad + headH + gap
    readonly property real cellW: (width - pad * 2 - gap) / 2
    readonly property real cellH: (height - gridY - pad - gap) / 2

    rows: [
        [pad, pad, width - pad * 2, headH],
        [pad + 3, gridY, width - pad * 2 - 6, cellH],
        [pad, gridY + cellH + gap, width - pad * 2, cellH]
    ]

    component Stat: Rectangle {
        id: stat
        property string label: ""
        property string value: ""
        property string unit: ""
        default property alias gauge: gaugeBox.data

        radius: root.tileRadius
        color: Colors.secondaryContainer

        CustomText {
            x: 11
            y: 9
            content: stat.label
            size: 11
            weight: 500
            customColor: Qt.alpha(Colors.secondaryContainerText, 0.85)
        }

        Item {
            id: gaugeBox
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 9
            anchors.topMargin: 8
            width: 24
            height: 24
        }

        CustomText {
            id: valueText
            x: 11
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 9
            content: stat.value
            size: 15
            weight: 700
            customColor: Colors.secondaryContainerText
        }

        CustomText {
            anchors.left: valueText.right
            anchors.leftMargin: 3
            anchors.baseline: valueText.baseline
            content: stat.unit
            size: 11
            weight: 500
            customColor: Qt.alpha(Colors.secondaryContainerText, 0.72)
        }
    }

    WeatherTileHeader {
        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        height: root.headH
        wx: root.wx
    }

    Stat {
        x: root.pad
        y: root.gridY
        width: root.cellW
        height: root.cellH
        label: "Feels"
        value: root.wx.feels + "°"

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: "thermostat"
            iconSize: 20
            fill: 1
            customColor: Colors.primary
        }
    }

    Stat {
        x: root.pad + root.cellW + root.gap
        y: root.gridY
        width: root.cellW
        height: root.cellH
        label: "Humidity"
        value: root.wx.humidity + "%"

        WeatherTileArc {
            anchors.fill: parent
            radius: 9
            lineWidth: 4
            gapAngle: 24
            progress: root.wx.humidity / 100
        }
    }

    Stat {
        x: root.pad
        y: root.gridY + root.cellH + root.gap
        width: root.cellW
        height: root.cellH
        label: "Wind"
        value: String(root.wx.wind)
        unit: root.wx.windUnit

        MaterialShapes.ShapeCanvas {
            anchors.centerIn: parent
            width: 18
            height: 18
            roundedPolygon: MaterialShapeFn.getArrow()
            color: Colors.primary
            rotation: root.wx.windDeg + 180
            Behavior on rotation { SpatialAnim { speed: "slow" } }
        }
    }

    Stat {
        x: root.pad + root.cellW + root.gap
        y: root.gridY + root.cellH + root.gap
        width: root.cellW
        height: root.cellH
        label: "UV"
        value: String(root.wx.uv)
        unit: root.wx.uvLabel

        Repeater {
            model: 5
            WeatherTileArc {
                required property int index
                anchors.fill: parent
                anchors.topMargin: 6
                radius: 10
                lineWidth: 3.5
                startAngle: 270 + index * 36 + 4
                sweep: 28
                gapAngle: 0
                progress: root.wx.uv > 0 && index <= Math.min(4, Math.floor(root.wx.uv / 2.4)) ? 1 : 0
            }
        }
    }
}
