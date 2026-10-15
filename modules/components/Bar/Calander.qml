import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MatrialSHapeFn

ColumnLayout {
    id: root
    anchors.fill: parent
    anchors.margins: 10
    spacing: 10

    property int currentYear:  new Date().getFullYear()
    property int currentMonth: new Date().getMonth()

    readonly property var cells: ServiceClock.generateCalendarGrid(root.currentYear, root.currentMonth)
    readonly property bool compact: root.width > 0 && root.width < 340
    readonly property real railW: Math.max(118, Math.min(170, 118 + (root.width - 380) * 0.25))
    readonly property real gridScale: {
        const w = root.compact ? root.width : root.width - root.railW - 10
        const h = root.height - (root.compact ? 58 : 0)
        return Math.max(1, Math.min(1.35, Math.min(w / 252, h / 380)))
    }
    readonly property bool onToday: root.currentYear === new Date().getFullYear()
                                    && root.currentMonth === new Date().getMonth()

    onCurrentYearChanged:  ServiceClock.ensureHolidaysForYear(currentYear)
    Component.onCompleted: ServiceClock.ensureHolidaysForYear(currentYear)

    function step(by) {
        let m = root.currentMonth + by
        let y = root.currentYear
        while (m < 0)  { m += 12; y-- }
        while (m > 11) { m -= 12; y++ }
        root.currentMonth = m
        root.currentYear = y
    }

    function backToToday() {
        const now = new Date()
        root.currentYear = now.getFullYear()
        root.currentMonth = now.getMonth()
    }

    component NavButton: Rectangle {
        id: nav
        property string glyph: ""
        signal tapped

        implicitWidth: 30
        implicitHeight: 30
        radius: 15
        color: navHov.containsMouse ? Colors.surfaceContainerHighest : Qt.alpha(Colors.surfaceContainerHighest, 0)
        Behavior on color { EffectsColorAnim {} }

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: nav.glyph
            iconSize: 19
            customColor: navHov.containsMouse ? Colors.surfaceText : Colors.outline
        }

        MouseArea {
            id: navHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.tapped()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        visible: root.compact
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            radius: 16
            color: Colors.surfaceContainerHigh

            CustomText {
                anchors.centerIn: parent
                content: ServiceClock.date
                size: 24
                weight: 800
                renderType: Text.QtRendering
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            CustomText {
                Layout.fillWidth: true
                content: ServiceClock.day
                size: 12
                weight: 700
                customColor: Colors.primary
                elide: Text.ElideRight
            }
            CustomText {
                Layout.fillWidth: true
                content: ServiceClock.month + " " + ServiceClock.year
                size: 12
                customColor: Colors.outline
                elide: Text.ElideRight
            }
        }

        TodayButton {
            Layout.preferredWidth: 72
            Layout.alignment: Qt.AlignVCenter
        }
    }

    component TodayButton: Rectangle {
        implicitHeight: 28
        radius: 14
        color: todayHov.containsMouse || root.onToday ? Colors.primary
                                                      : Colors.surfaceContainerHighest
        Behavior on color { EffectsColorAnim {} }

        CustomText {
            anchors.centerIn: parent
            content: "Today"
            size: 12
            weight: 700
            customColor: todayHov.containsMouse || root.onToday ? Colors.primaryText
                                                                 : Colors.surfaceText
        }

        MouseArea {
            id: todayHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backToToday()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10

        Rectangle {
            Layout.preferredWidth: root.railW
            Layout.fillHeight: true
            visible: !root.compact
            radius: 18
            color: Colors.surfaceContainerHigh

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 0

                Item { Layout.fillHeight: true }

                CustomText {
                    Layout.fillWidth: true
                    content: ServiceClock.day
                    size: 12
                    weight: 700
                    customColor: Colors.primary
                    elide: Text.ElideRight
                }

                CustomText {
                    Layout.topMargin: 2
                    content: ServiceClock.date
                    size: Math.round(56 * root.railW / 118)
                    weight: 800
                    renderType: Text.QtRendering
                    lineHeight: 0.92
                }

                CustomText {
                    Layout.topMargin: 6
                    Layout.fillWidth: true
                    content: ServiceClock.month
                    size: 13
                    customColor: Colors.surfaceText
                    elide: Text.ElideRight
                }

                CustomText {
                    Layout.fillWidth: true
                    content: ServiceClock.year
                    size: 12
                    customColor: Colors.outline
                }

                Item { Layout.fillHeight: true }

                TodayButton {
                    Layout.fillWidth: true
                }
            }
        }

        // The grid sits straight on the panel — no card of its own
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                CustomText {
                    Layout.fillWidth: true
                    content: ServiceClock.getMonthName(root.currentMonth)
                    size: Math.round(17 * root.gridScale)
                    weight: 700
                    elide: Text.ElideRight
                }

                CustomText {
                    Layout.rightMargin: 4
                    content: root.currentYear.toString()
                    size: Math.round(12 * root.gridScale)
                    customColor: Colors.outline
                }

                NavButton {
                    glyph: "chevron_left"
                    onTapped: root.step(-1)
                }
                NavButton {
                    glyph: "chevron_right"
                    onTapped: root.step(1)
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 7
                columnSpacing: 0
                rowSpacing: 0

                Repeater {
                    model: ["S", "M", "T", "W", "T", "F", "S"]

                    Item {
                        required property string modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: Math.round(22 * root.gridScale)

                        CustomText {
                            anchors.centerIn: parent
                            content: parent.modelData
                            size: Math.round(11 * root.gridScale)
                            weight: 700
                            customColor: (parent.index === 0 || parent.index === 6) ? Colors.primary
                                                                                   : Colors.outline
                        }
                    }
                }
            }

            GridLayout {
                id: dayGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                columnSpacing: 0
                rowSpacing: 0

                Repeater {
                    model: root.cells

                    Item {
                        id: cell
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        readonly property bool isWeekend: (cell.index % 7 === 0) || (cell.index % 7 === 6)
                        readonly property real side: Math.min(cell.width, cell.height) - 4

                        MaterialShapes.ShapeCanvas {
                            anchors.centerIn: parent
                            width: cell.side
                            height: cell.side
                            roundedPolygon: MatrialSHapeFn.getGem()
                            color: cell.modelData.isToday ? Colors.primary
                                 : dateHov.containsMouse  ? Colors.surfaceContainerHighest
                                 : "transparent"
                        }

                        CustomText {
                            anchors.centerIn: parent
                            content: cell.modelData.day ? cell.modelData.day.toString() : ""
                            size: Math.round(13 * root.gridScale)
                            weight: cell.modelData.isToday ? 800 : 500
                            customColor: cell.modelData.isToday         ? Colors.primaryText
                                       : !cell.modelData.isCurrentMonth ? Qt.alpha(Colors.surfaceText, 0.22)
                                       : cell.isWeekend                 ? Colors.primary
                                       : Colors.surfaceText
                            Behavior on customColor { EffectsColorAnim {} }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: cell.modelData.isHoliday && cell.modelData.isCurrentMonth
                                     && !!cell.modelData.day
                            width: Math.round(4 * root.gridScale)
                            height: width
                            radius: width / 2
                            color: cell.modelData.isToday ? Colors.primaryText : Colors.primary
                        }

                        MouseArea {
                            id: dateHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: cell.modelData.day ? Qt.PointingHandCursor : Qt.ArrowCursor
                        }

                        CustomToolTip {
                            content: (cell.modelData.isHoliday && cell.modelData.info
                                      && cell.modelData.info.length > 0)
                                     ? cell.modelData.info.map(h => h.name).join("\n") : ""
                            visible: cell.modelData.isHoliday && dateHov.containsMouse
                        }
                    }
                }
            }
        }
    }
}
