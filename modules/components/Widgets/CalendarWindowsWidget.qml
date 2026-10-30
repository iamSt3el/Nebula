pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import "calendarMath.js" as CalMath

WidgetHost {
    id: root
    configKey: "calendarWindows"
    defaultPos: Qt.point(420, 440)
    tile: WidgetSizes.large

    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"

    readonly property int startDay: (SettingsConfig.widgets.calendarWindowsMonday ?? true) ? 1 : 0
    readonly property bool showFooter: SettingsConfig.widgets.calendarWindowsFooter ?? true

    readonly property var cells: {
        ServiceClock.date
        const now = new Date()
        return ServiceClock.generateCalendarGrid(now.getFullYear(), now.getMonth(), root.startDay)
    }

    readonly property int today: parseInt(ServiceClock.date)

    readonly property int daysLeft: {
        ServiceClock.date
        const now = new Date()
        return ServiceClock.getDaysInMonth(now.getFullYear(), now.getMonth()) - now.getDate()
    }

    readonly property var weekLetters: {
        const base = ["S", "M", "T", "W", "T", "F", "S"]
        const out = []
        for (let i = 0; i < 7; i++)
            out.push(base[(i + root.startDay) % 7])
        return out
    }

    readonly property var nextHoliday: {
        ServiceClock.date
        const up = CalMath.upcomingHolidays(ServiceClock.holidayData, new Date(), 1)
        return up.length > 0 ? up[0] : null
    }

    optionsComponent: Component {
        CalendarOptionList {
            model: [{ key: "calendarWindowsMonday", label: "Start on Monday", sub: "Off starts the week on Sunday", def: true },
                    { key: "calendarWindowsFooter", label: "Show next holiday", sub: "A line under the building", def: true }]
        }
    }

    WidgetCard {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: parent.pad
            anchors.bottomMargin: parent.pad
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                CustomText {
                    content: ServiceClock.month
                    size: 24
                    weight: 400
                    family: root.display
                    renderType: Text.QtRendering
                }
                Item { Layout.fillWidth: true }
                CustomText {
                    content: root.daysLeft === 0 ? root.today + " lit · last tonight"
                                                 : root.today + " lit · " + root.daysLeft + " to go"
                    size: 12
                    weight: 600
                    customColor: Colors.surfaceVariantText
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: root.weekLetters
                    CustomText {
                        required property string modelData
                        Layout.fillWidth: true
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
                rowSpacing: 5
                columnSpacing: 6

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
                        readonly property bool isToday: cell.modelData.isToday
                        readonly property bool past: cell.inMonth && !cell.isToday && cell.modelData.day < root.today
                        readonly property bool holiday: cell.inMonth && cell.modelData.isHoliday
                        readonly property string holidayName: cell.holiday && cell.modelData.info.length > 0
                            ? cell.modelData.info[0].name : ""

                        opacity: cell.inMonth ? 1 : 0

                        Rectangle {
                            id: pane
                            anchors.fill: parent
                            radius: 10
                            color: cell.isToday ? Colors.tertiaryContainer
                                : cell.past ? Colors.primaryContainer
                                : Colors.surfaceContainerHigh

                            CustomText {
                                anchors.centerIn: parent
                                content: String(cell.modelData.day)
                                size: 11
                                weight: cell.isToday ? 800 : 600
                                customColor: cell.isToday ? Colors.tertiaryContainerText
                                    : cell.past ? Colors.primaryContainerText
                                    : Colors.surfaceVariantText
                            }

                            Rectangle {
                                visible: cell.holiday && !cell.past && !cell.isToday
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 4
                                width: 4
                                height: 4
                                radius: 2
                                color: Colors.primary
                            }
                        }

                        CustomToolTip {
                            visible: cellHover.containsMouse && cell.holidayName !== ""
                            content: cell.holidayName + " · " + cell.modelData.day
                        }

                        MouseArea {
                            id: cellHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                visible: root.showFooter
                spacing: 8

                CustomText {
                    Layout.fillWidth: true
                    content: root.nextHoliday ? "Next · " + root.nextHoliday.name : "No more holidays this year"
                    size: 12
                    weight: 600
                    elide: Text.ElideRight
                    customColor: Colors.surfaceVariantText
                }
                CustomText {
                    visible: root.nextHoliday !== null
                    content: root.nextHoliday
                        ? (root.nextHoliday.days === 1 ? "tomorrow" : "in " + root.nextHoliday.days + " days") : ""
                    size: 12
                    weight: 700
                }
            }
        }
    }
}
