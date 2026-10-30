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
    configKey: "calendarMoon"
    defaultPos: Qt.point(760, 100)
    tile: WidgetSizes.wide

    readonly property int startDay: (SettingsConfig.widgets.calendarMoonMonday ?? true) ? 1 : 0

    readonly property var now: {
        ServiceClock.hour
        return new Date()
    }
    readonly property real age: CalMath.moonAge(root.now)
    readonly property real illum: CalMath.moonIllum(root.age)
    readonly property string phase: CalMath.moonPhaseName(root.age)

    readonly property var nextEvent: {
        const toFull = CalMath.daysUntilAge(root.age, CalMath.FULL_AGE)
        const toNew = CalMath.daysUntilAge(root.age, 0)
        const full = toFull <= toNew
        const days = full ? toFull : toNew
        const when = new Date(root.now.getTime() + days * 86400000)
        return { full: full, days: days, date: when }
    }

    readonly property string nextLine: {
        const e = root.nextEvent
        const what = e.full ? "full" : "new"
        if (e.days < 0.75) return what + " moon tonight"
        return what + " " + Qt.formatDate(e.date, "ddd d")
    }

    readonly property var cells: {
        ServiceClock.date
        return ServiceClock.generateCalendarGrid(root.now.getFullYear(), root.now.getMonth(), root.startDay)
    }
    readonly property var moonDays: CalMath.moonDaysInMonth(root.now.getFullYear(), root.now.getMonth())
    readonly property int today: root.now.getDate()

    readonly property var weekLetters: {
        const base = ["S", "M", "T", "W", "T", "F", "S"]
        const out = []
        for (let i = 0; i < 7; i++)
            out.push(base[(i + root.startDay) % 7])
        return out
    }

    optionsComponent: Component {
        CalendarOptionList {
            model: [{ key: "calendarMoonMonday", label: "Start on Monday", sub: "Off starts the week on Sunday", def: true }]
        }
    }

    WidgetCard {
        anchors.fill: parent

        RowLayout {
            anchors.fill: parent
            anchors.margins: parent.pad
            anchors.leftMargin: parent.pad
            spacing: 14

            ColumnLayout {
                Layout.preferredWidth: 104
                Layout.maximumWidth: 104
                Layout.fillHeight: true
                spacing: 2

                Item {
                    id: moon
                    implicitWidth: 88
                    implicitHeight: 88
                    readonly property real r: 34

                    Rectangle {
                        anchors.centerIn: parent
                        width: moon.r * 2
                        height: width
                        radius: moon.r
                        color: Colors.surfaceContainerHighest
                    }
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: Colors.primary
                            PathSvg { path: CalMath.moonPath(44, 44, moon.r, root.age) }
                        }
                    }
                    Repeater {
                        model: [{ x: 10, y: -9, r: 5 }, { x: 16, y: 12, r: 3.5 }, { x: -2, y: 17, r: 4 }, { x: -14, y: -4, r: 3 }]
                        Rectangle {
                            required property var modelData
                            x: 44 + modelData.x - modelData.r
                            y: 44 + modelData.y - modelData.r
                            width: modelData.r * 2
                            height: width
                            radius: modelData.r
                            color: Qt.alpha(Colors.primaryText, 0.1)
                        }
                    }
                }

                Item { Layout.fillHeight: true }
                CustomText {
                    Layout.fillWidth: true
                    content: root.phase
                    size: 14
                    weight: 800
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    maximumLineCount: 2
                }
                CustomText {
                    Layout.fillWidth: true
                    content: Math.round(root.illum * 100) + "% · " + root.nextLine
                    size: 11
                    weight: 600
                    elide: Text.ElideRight
                    customColor: Colors.surfaceVariantText
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    CustomText {
                        content: ServiceClock.month
                        size: 13
                        weight: 800
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Repeater {
                        model: root.weekLetters
                        CustomText {
                            required property string modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            horizontalAlignment: Text.AlignHCenter
                            content: modelData
                            size: 10
                            weight: 700
                            customColor: Colors.surfaceVariantText
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    rowSpacing: 2
                    columnSpacing: 2

                    Repeater {
                        model: root.cells

                        delegate: Item {
                            id: cell
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 1

                            readonly property bool inMonth: cell.modelData.isCurrentMonth
                            readonly property int day: cell.modelData.day
                            readonly property bool isToday: cell.modelData.isToday
                            readonly property bool isFull: cell.inMonth && root.moonDays.full.indexOf(cell.day) >= 0
                            readonly property bool isNew: cell.inMonth && root.moonDays.fresh.indexOf(cell.day) >= 0
                            opacity: cell.inMonth ? 1 : 0

                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height, 22)
                                height: width
                                radius: width / 2
                                color: cell.isToday ? Colors.tertiaryContainer
                                    : cell.isNew ? Colors.surfaceContainerHighest : "transparent"
                                border.width: cell.isFull && !cell.isToday ? 2 : 0
                                border.color: Colors.tertiary
                            }

                            CustomText {
                                anchors.centerIn: parent
                                content: String(cell.day)
                                size: 11
                                weight: cell.isToday || cell.isFull ? 800 : 600
                                customColor: cell.isToday ? Colors.tertiaryContainerText
                                    : cell.day < root.today ? Colors.outline
                                    : Colors.surfaceText
                            }
                        }
                    }
                }
            }
        }
    }
}
