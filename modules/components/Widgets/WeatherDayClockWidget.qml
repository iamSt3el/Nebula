import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "weatherDayClock"
    tile: WidgetSizes.small
    defaultPos: Qt.point(805, 165)

    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"

    function minutesOf(str) {
        const m = String(str ?? "").match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i)
        if (!m) return -1
        let h = parseInt(m[1])
        if (m[3].toUpperCase() === "PM" && h !== 12) h += 12
        if (m[3].toUpperCase() === "AM" && h === 12) h = 0
        return h * 60 + parseInt(m[2])
    }

    readonly property int riseMin: root.preview ? 392 : root.minutesOf(ServiceWeather.astronomy?.sunrise)
    readonly property int setMin: root.preview ? 1070 : root.minutesOf(ServiceWeather.astronomy?.sunset)
    readonly property bool hasData: root.riseMin >= 0 && root.setMin > root.riseMin
    readonly property int nowMin: {
        ServiceClock.minute
        if (root.preview) return 661
        const d = new Date()
        return d.getHours() * 60 + d.getMinutes()
    }
    readonly property bool night: root.nowMin < root.riseMin || root.nowMin >= root.setMin

    function deg(min) {
        return min / 1440 * 360 + 90
    }

    function span(mins) {
        const m = Math.max(0, Math.round(mins))
        const h = Math.floor(m / 60)
        return h > 0 ? h + " h " + (m % 60) + " m" : (m % 60) + " m"
    }

    readonly property string headline: {
        if (!root.hasData) return "—"
        if (root.nowMin < root.riseMin) return root.span(root.riseMin - root.nowMin)
        if (root.nowMin >= root.setMin) return root.span(root.riseMin + 1440 - root.nowMin)
        return root.span(root.setMin - root.nowMin)
    }

    WidgetCard {
        id: card
        anchors.fill: parent

        Item {
            id: dial
            anchors.centerIn: parent
            width: Math.min(card.width, card.height)
            height: width
            visible: root.hasData

            readonly property real c: dial.width / 2
            readonly property real r: dial.width / 2 - 26
            readonly property real stroke: 12
            readonly property real gapDeg: 7

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Colors.surfaceContainerHighest
                    strokeWidth: dial.stroke
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: dial.c
                        centerY: dial.c
                        radiusX: dial.r
                        radiusY: dial.r
                        startAngle: root.deg(root.setMin) + dial.gapDeg
                        sweepAngle: (1440 - (root.setMin - root.riseMin)) / 1440 * 360 - dial.gapDeg * 2
                    }
                }
                ShapePath {
                    strokeColor: Colors.primary
                    strokeWidth: dial.stroke
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: dial.c
                        centerY: dial.c
                        radiusX: dial.r
                        radiusY: dial.r
                        startAngle: root.deg(root.riseMin)
                        sweepAngle: (root.setMin - root.riseMin) / 1440 * 360
                    }
                }
            }

            Rectangle {
                readonly property real a: root.deg(root.nowMin) * Math.PI / 180
                x: dial.c + dial.r * Math.cos(a) - width / 2
                y: dial.c + dial.r * Math.sin(a) - height / 2
                width: 22
                height: 22
                radius: 11
                color: Colors.tertiary
                border.width: 4
                border.color: card.color
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 4
            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                content: root.headline
                family: root.display
                size: 24
                weight: 400
            }
            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                content: !root.hasData ? "no sun data" : root.night ? "until sunrise" : "until sunset"
                size: 12
                weight: 600
                customColor: Colors.surfaceVariantText
            }
        }
    }
}
