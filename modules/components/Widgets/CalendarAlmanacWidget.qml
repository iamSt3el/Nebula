pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "calendarAlmanac"
    defaultPos: Qt.point(880, 300)
    tile: WidgetSizes.wide

    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"
    readonly property int today: parseInt(ServiceClock.date)

    readonly property int startDay: (SettingsConfig.widgets.calendarAlmanacMonday ?? true) ? 1 : 0
    readonly property bool dimOther: SettingsConfig.widgets.calendarAlmanacDimOther ?? true

    readonly property var cells: {
        ServiceClock.date
        const now = new Date()
        return ServiceClock.generateCalendarGrid(now.getFullYear(), now.getMonth(), root.startDay)
    }

    readonly property var weekLetters: {
        const base = ["S", "M", "T", "W", "T", "F", "S"]
        const out = []
        for (let i = 0; i < 7; i++)
            out.push(base[(i + root.startDay) % 7])
        return out
    }

    readonly property string todayInfo: {
        for (let i = 0; i < root.cells.length; i++)
            if (root.cells[i].isToday && root.cells[i].isHoliday)
                return root.cells[i].info ?? ""
        return ""
    }

    readonly property int weekNumber: {
        ServiceClock.date
        const now = new Date()
        const t = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        t.setDate(t.getDate() - ((t.getDay() + 6) % 7) + 3)
        const first = new Date(t.getFullYear(), 0, 4)
        first.setDate(first.getDate() - ((first.getDay() + 6) % 7) + 3)
        return 1 + Math.round((t.getTime() - first.getTime()) / 604800000)
    }

    optionsComponent: Component {
        ColumnLayout {
            spacing: 3

            Repeater {
                model: [{ key: "calendarAlmanacMonday", label: "Start on Monday", sub: "Off starts the week on Sunday", def: true },
                        { key: "calendarAlmanacDimOther", label: "Dim other months", sub: "Leading and trailing days", def: true }]

                delegate: CustomCard {
                    id: optRow
                    required property var modelData
                    required property int index

                    autoRadius: false
                    topRadius: optRow.index === 0 ? 18 : 5
                    bottomRadius: optRow.index === 1 ? 18 : 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            CustomText { content: optRow.modelData.label; size: 13 }
                            CustomText {
                                Layout.fillWidth: true
                                content: optRow.modelData.sub
                                size: 11
                                customColor: Colors.outline
                                wrapMode: Text.Wrap
                                elide: Text.ElideNone
                            }
                        }

                        CustomToogle {
                            isToggleOn: SettingsConfig.widgets[optRow.modelData.key] ?? optRow.modelData.def
                            onToggled: state => {
                                const o = {}
                                o[optRow.modelData.key] = state
                                SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, o)
                            }
                        }
                    }
                }
            }
        }
    }

    WidgetCard {
        anchors.fill: parent

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            ColumnLayout {
                Layout.preferredWidth: 100
                Layout.fillHeight: true
                spacing: 0

                CustomText {
                    content: ServiceClock.month
                    size: 12
                    weight: 700
                    customColor: Colors.surfaceVariantText
                }

                CustomText {
                    Layout.topMargin: 2
                    content: String(root.today)
                    size: 54
                    weight: 400
                    family: root.display
                    renderType: Text.QtRendering
                }

                CustomText {
                    Layout.topMargin: 2
                    content: ServiceClock.day
                    size: 13
                    weight: 800
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.preferredWidth: Math.min(chipText.implicitWidth + 20, 100)
                    Layout.preferredHeight: 24
                    radius: 12
                    color: root.todayInfo !== "" ? Colors.tertiaryContainer : Colors.secondaryContainer

                    CustomText {
                        id: chipText
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 16)
                        content: root.todayInfo !== "" ? root.todayInfo : "Week " + root.weekNumber
                        size: 11
                        weight: 800
                        elide: Text.ElideRight
                        customColor: root.todayInfo !== "" ? Colors.tertiaryContainerText : Colors.secondaryContainerText
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                rowSpacing: 0
                columnSpacing: 1

                Repeater {
                    model: root.weekLetters

                    delegate: Item {
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 13

                        CustomText {
                            anchors.centerIn: parent
                            content: parent.modelData
                            size: 10
                            weight: 700
                            customColor: Colors.surfaceVariantText
                        }
                    }
                }

                Repeater {
                    model: root.cells

                    delegate: Item {
                        id: cell
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        readonly property bool isToday: cell.modelData.isToday
                        readonly property bool holiday: cell.modelData.isHoliday
                        readonly property bool past: cell.modelData.isCurrentMonth && !cell.isToday && cell.modelData.day < root.today
                        readonly property real side: Math.min(cell.width, cell.height)

                        Rectangle {
                            anchors.centerIn: parent
                            visible: cell.isToday
                            width: Math.min(cell.side + 2, 22)
                            height: width
                            radius: width / 2
                            color: Colors.tertiaryContainer
                        }

                        CustomText {
                            id: dayText
                            anchors.centerIn: parent
                            content: cell.modelData.day
                            size: 11
                            weight: cell.isToday ? 800 : 600
                            customColor: cell.isToday ? Colors.tertiaryContainerText
                                : !cell.modelData.isCurrentMonth ? (root.dimOther ? Colors.outlineVariant : "transparent")
                                : cell.past ? Colors.outline
                                : Colors.surfaceText
                        }

                        Rectangle {
                            visible: cell.holiday && cell.modelData.isCurrentMonth && !cell.isToday
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: 4
                            height: 4
                            radius: 2
                            color: cell.past ? Colors.outlineVariant : Colors.primary
                        }

                        CustomToolTip {
                            visible: cellHover.containsMouse && cell.holiday
                                && (cell.modelData.info ?? "") !== ""
                            content: cell.modelData.info ?? ""
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
        }
    }
}
