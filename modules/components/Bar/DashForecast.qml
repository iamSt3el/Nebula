pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.customComponents

Item {
    id: root

    property var days: []

    readonly property int n: Math.max(1, root.days.length)
    readonly property real col: root.width / root.n
    readonly property real chartTop: 66
    readonly property real span: Math.max(20, root.height - root.chartTop - 32)
    readonly property real tMax: root.days.length ? Math.max(...root.days.map(d => d.hi)) : 1
    readonly property real tMin: root.days.length ? Math.min(...root.days.map(d => d.lo)) : 0
    readonly property real range: Math.max(4, root.tMax - root.tMin)

    function yOf(t) {
        return root.chartTop + 12 + (root.tMax - t) / root.range * (root.span - 12)
    }

    function points(key) {
        return root.days.map((d, i) => Qt.point(root.col * i + root.col / 2, root.yOf(d[key])))
    }

    Rectangle {
        visible: root.days.length > 0
        x: 2
        width: root.col - 4
        height: root.height
        radius: 18
        color: Colors.surfaceContainerHigh
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Colors.primary
            strokeWidth: 2.5
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline { path: root.points("hi") }
        }

        ShapePath {
            strokeColor: Colors.outline
            strokeWidth: 2.5
            fillColor: "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: [0.5, 2.5]
            capStyle: ShapePath.RoundCap
            PathPolyline { path: root.points("lo") }
        }
    }

    Repeater {
        model: root.days

        Item {
            id: day
            required property var modelData
            required property int index
            x: root.col * day.index
            width: root.col
            height: root.height

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                spacing: 6
                CustomText { anchors.horizontalCenter: parent.horizontalCenter; content: day.modelData.label; size: 12; weight: 700 }
                MaterialIconSymbol { anchors.horizontalCenter: parent.horizontalCenter; content: day.modelData.icon; iconSize: 22; fill: 1; customColor: Colors.tertiary }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.yOf(day.modelData.hi) - 24
                width: hiText.implicitWidth + 6
                height: 18
                radius: 4
                color: day.index === 0 ? Colors.surfaceContainerHigh : Colors.surfaceContainer

                CustomText { id: hiText; anchors.centerIn: parent; content: day.modelData.hi + "°"; size: 13; weight: 700 }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.yOf(day.modelData.hi) - 3
                width: 6
                height: 6
                radius: 3
                color: Colors.primary
            }

            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.yOf(day.modelData.lo) + 6
                content: day.modelData.lo + "°"
                size: 12
                weight: 500
                customColor: Colors.surfaceVariantText
            }
        }
    }
}
