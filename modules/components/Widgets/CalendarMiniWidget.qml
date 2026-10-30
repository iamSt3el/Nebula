pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

WidgetHost {
    id: root
    configKey: "calendarMini"
    defaultPos: Qt.point(420, 300)
    tile: WidgetSizes.small

    readonly property int startDay: (SettingsConfig.widgets.calendarMiniMonday ?? true) ? 1 : 0
    readonly property bool dimOther: SettingsConfig.widgets.calendarMiniDimOther ?? true
    readonly property int today: parseInt(ServiceClock.date)

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

    optionsComponent: Component {
        ColumnLayout {
            spacing: 3

            Repeater {
                model: [{ key: "calendarMiniMonday", label: "Start on Monday", sub: "Off starts the week on Sunday", def: true },
                        { key: "calendarMiniDimOther", label: "Dim other months", sub: "Leading and trailing days", def: true }]

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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: parent.pad
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                CustomText {
                    Layout.fillWidth: true
                    content: ServiceClock.month
                    size: 13
                    weight: 800
                }
                CustomText {
                    content: ServiceClock.year
                    size: 11
                    weight: 600
                    customColor: Colors.surfaceVariantText
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                rowSpacing: 1
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
                            size: 9
                            weight: 700
                            customColor: Colors.outline
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

                        readonly property bool today: cell.modelData.isToday
                        readonly property bool inMonth: cell.modelData.isCurrentMonth
                        readonly property bool past: cell.inMonth && !cell.today && cell.modelData.day < root.today
                        readonly property bool holiday: cell.inMonth && cell.modelData.isHoliday && !cell.today
                        readonly property real side: Math.min(cell.width, cell.height) + 2

                        MaterialShapes.ShapeCanvas {
                            anchors.centerIn: parent
                            width: cell.side
                            height: cell.side
                            visible: cell.today
                            roundedPolygon: ShapeLibrary.get("cookie9")
                            color: Colors.tertiaryContainer
                        }

                        CustomText {
                            anchors.centerIn: parent
                            content: cell.modelData.day
                            size: 11
                            weight: cell.today ? 800 : 600
                            customColor: cell.today ? Colors.tertiaryContainerText
                                : !cell.inMonth ? (root.dimOther ? Colors.outlineVariant : "transparent")
                                : cell.past ? Colors.outline
                                : Colors.surfaceText
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: 4
                            height: 4
                            radius: 2
                            visible: cell.holiday
                            color: cell.past ? Colors.outlineVariant : Colors.primary
                        }

                        CustomToolTip {
                            visible: cellHover.containsMouse && cell.modelData.isHoliday
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
