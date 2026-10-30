pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import "calendarMath.js" as CalMath

WidgetHost {
    id: root
    configKey: "calendarYear"
    defaultPos: Qt.point(760, 440)
    tile: WidgetSizes.large

    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"
    readonly property bool showHolidays: SettingsConfig.widgets.calendarYearHolidays ?? true

    readonly property var now: {
        ServiceClock.date
        return new Date()
    }
    readonly property int year: root.now.getFullYear()
    readonly property int yearDays: CalMath.daysInYear(root.year)
    readonly property int dayNum: CalMath.dayOfYear(root.now)

    readonly property var months: {
        const out = []
        let acc = 0
        for (let m = 0; m < 12; m++) {
            const n = new Date(root.year, m + 1, 0).getDate()
            out.push({ m: m, start: acc, days: n, letter: "JFMAMJJASOND"[m] })
            acc += n
        }
        return out
    }

    readonly property var upcoming: CalMath.upcomingHolidays(ServiceClock.holidayData, root.now, 8)

    readonly property var nextHoliday: root.upcoming.length > 0 ? root.upcoming[0] : null

    function angleOf(dayIndex) {
        return -90 + 360 * dayIndex / root.yearDays
    }

    optionsComponent: Component {
        CalendarOptionList {
            model: [{ key: "calendarYearHolidays", label: "Show holidays", sub: "The next one by name under the count", def: true }]
        }
    }

    WidgetCard {
        anchors.fill: parent

        Item {
            id: wheel
            anchors.fill: parent

            readonly property real cx: wheel.width / 2
            readonly property real cy: wheel.height / 2
            readonly property real r: Math.min(wheel.width, wheel.height) / 2 - 28
            readonly property real gap: 7.5

            Repeater {
                model: root.months

                Shape {
                    id: seg
                    required property var modelData
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    readonly property real a0: root.angleOf(seg.modelData.start) + wheel.gap / 2
                    readonly property real sweep: 360 * seg.modelData.days / root.yearDays - wheel.gap
                    readonly property bool done: seg.modelData.m < root.now.getMonth()
                    readonly property bool current: seg.modelData.m === root.now.getMonth()

                    ShapePath {
                        strokeColor: seg.done ? Colors.primary : Colors.surfaceContainerHighest
                        strokeWidth: 14
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathAngleArc {
                            centerX: wheel.cx
                            centerY: wheel.cy
                            radiusX: wheel.r
                            radiusY: wheel.r
                            startAngle: seg.a0
                            sweepAngle: seg.sweep
                        }
                    }

                    ShapePath {
                        strokeColor: seg.current ? Colors.primary : "transparent"
                        strokeWidth: 14
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathAngleArc {
                            centerX: wheel.cx
                            centerY: wheel.cy
                            radiusX: wheel.r
                            radiusY: wheel.r
                            startAngle: seg.a0
                            sweepAngle: Math.max(0.1, Math.min(seg.sweep, 360 * root.now.getDate() / root.yearDays - wheel.gap / 2))
                        }
                    }
                }
            }

            Item {
                readonly property real a: root.angleOf(root.dayNum - 0.5) * Math.PI / 180
                x: wheel.cx + wheel.r * Math.cos(a)
                y: wheel.cy + wheel.r * Math.sin(a)

                Rectangle {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    radius: 12
                    color: Colors.tertiary
                    border.width: 4
                    border.color: WidgetSizes.cardColor
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0

                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: String(root.dayNum)
                    size: 60
                    weight: 400
                    family: root.display
                    renderType: Text.QtRendering
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 62
                }
                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: "of " + root.year + " · " + (root.yearDays - root.dayNum) + " to go"
                    size: 13
                    weight: 600
                    customColor: Colors.surfaceVariantText
                }
                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    Layout.maximumWidth: wheel.r * 1.4
                    visible: root.showHolidays && root.nextHoliday !== null
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    maximumLineCount: 2
                    content: root.nextHoliday ? root.nextHoliday.name : ""
                    size: 12
                    weight: 700
                }
                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.showHolidays && root.nextHoliday !== null
                    content: root.nextHoliday ? (root.nextHoliday.days === 1 ? "tomorrow" : "in " + root.nextHoliday.days + " days") : ""
                    size: 11
                    weight: 600
                    customColor: Colors.surfaceVariantText
                }
            }
        }
    }
}
