import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

Item {
    id: root
    anchors.fill: parent

    property string style: "sheet"

    property int vy: new Date().getFullYear()
    property int vm: new Date().getMonth()
    property var selDate: root.midnight(new Date())
    property var hoverDate: null

    readonly property var todayDate: {
        ServiceClock.date
        return root.midnight(new Date())
    }
    readonly property var cells: ServiceClock.generateCalendarGrid(root.vy, root.vm)
    readonly property int rows: Math.ceil(root.cells.length / 7)
    readonly property bool onToday: root.vy === new Date().getFullYear() && root.vm === new Date().getMonth()
    readonly property var dayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    readonly property var gridStart: root.cells.length ? root.cellDate(root.cells[0]) : new Date()
    readonly property var dayMap: {
        const map = {}
        const from = root.gridStart.getTime()
        const to = from + root.cells.length * 86400000
        for (const c of root.cells) {
            if (c.isHoliday && c.info)
                for (const h of c.info)
                    root.push(map, root.keyOf(root.cellDate(c)), { title: h.name, time: "", holiday: true })
        }
        const evs = ServiceEvents.between(from, to, false)
        for (const e of evs) {
            const s = Math.max(from, ServiceEvents.startMs(e))
            const end = Math.min(to, Math.max(ServiceEvents.endMs(e), s + 1))
            const time = e.allDay ? "" : Qt.formatTime(new Date(ServiceEvents.startMs(e)), "hh:mm")
            for (let t = root.midnight(new Date(s)).getTime(); t < end; t += 86400000)
                root.push(map, root.keyOf(new Date(t)), { title: e.title, time: time, holiday: false })
        }
        return map
    }

    Component.onCompleted: {
        ServiceClock.ensureHolidaysForYear(root.vy)
        ServiceEvents.retain()
    }
    Component.onDestruction: ServiceEvents.release()
    onVyChanged: ServiceClock.ensureHolidaysForYear(root.vy)

    function midnight(d) {
        return new Date(d.getFullYear(), d.getMonth(), d.getDate())
    }
    function cellDate(c) {
        return new Date(c.year, c.monthIndex, c.day)
    }
    function keyOf(d) {
        return d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate()
    }
    function push(map, k, v) {
        if (!map[k])
            map[k] = []
        map[k].push(v)
    }
    function itemsOn(d) {
        return d ? (root.dayMap[root.keyOf(d)] ?? []) : []
    }
    function eventCount(d) {
        return root.itemsOn(d).filter(i => !i.holiday).length
    }
    function holidayOn(d) {
        const h = root.itemsOn(d).find(i => i.holiday)
        return h ? h.title : ""
    }
    function same(a, b) {
        return !!a && !!b && a.getTime() === b.getTime()
    }
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        const day = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - day)
        const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil(((t - y0) / 86400000 + 1) / 7)
    }
    function relative(d) {
        const n = Math.round((d.getTime() - root.todayDate.getTime()) / 86400000)
        if (n === 0) return "Today"
        if (n === 1) return "Tomorrow"
        if (n === -1) return "Yesterday"
        return n > 0 ? "In " + n + " days" : (-n) + " days ago"
    }
    function step(by) {
        let m = root.vm + by
        let y = root.vy
        while (m < 0) { m += 12; y-- }
        while (m > 11) { m -= 12; y++ }
        root.vm = m
        root.vy = y
    }
    function goToday() {
        const n = new Date()
        root.vy = n.getFullYear()
        root.vm = n.getMonth()
        root.selDate = root.midnight(n)
    }
    function pick(d) {
        root.selDate = d
        if (d.getMonth() !== root.vm || d.getFullYear() !== root.vy) {
            root.vy = d.getFullYear()
            root.vm = d.getMonth()
        }
    }

    component NavButton: Rectangle {
        id: nav
        property string glyph: ""
        signal tapped
        implicitWidth: 30
        implicitHeight: 30
        radius: 15
        color: navArea.containsMouse ? Colors.surfaceContainerHighest : Qt.alpha(Colors.surfaceContainerHighest, 0)
        Behavior on color { EffectsColorAnim {} }
        MaterialIconSymbol {
            anchors.centerIn: parent
            content: nav.glyph
            iconSize: 19
            customColor: navArea.containsMouse ? Colors.surfaceText : Colors.outline
        }
        MouseArea {
            id: navArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.tapped()
        }
    }

    component TodayButton: Rectangle {
        implicitWidth: 64
        implicitHeight: 28
        radius: 14
        color: tdArea.containsMouse || root.onToday ? Colors.primary : Colors.surfaceContainerHighest
        Behavior on color { EffectsColorAnim {} }
        CustomText {
            anchors.centerIn: parent
            content: "Today"
            size: 12
            weight: 700
            customColor: tdArea.containsMouse || root.onToday ? Colors.primaryText : Colors.surfaceText
        }
        MouseArea {
            id: tdArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.goToday()
        }
    }

    component Header: RowLayout {
        property bool hero: false
        spacing: 2
        CustomText {
            Layout.fillWidth: !parent.hero
            content: ServiceClock.getMonthName(root.vm)
            size: parent.hero ? 26 : 16
            weight: parent.hero ? 400 : 700
            family: parent.hero ? (SettingsConfig.general.displayFont ?? "Titan One") : (SettingsConfig.general.defaultFont ?? "Rubik")
            renderType: parent.hero ? Text.QtRendering : Text.NativeRendering
            customColor: parent.hero ? Colors.primary : Colors.surfaceText
            elide: Text.ElideRight
        }
        CustomText {
            Layout.fillWidth: parent.hero
            Layout.leftMargin: 6
            Layout.rightMargin: 4
            content: root.vy.toString()
            size: 13
            customColor: Colors.outline
        }
        NavButton { glyph: "chevron_left"; onTapped: root.step(-1) }
        NavButton { glyph: "chevron_right"; onTapped: root.step(1) }
        TodayButton { Layout.leftMargin: 4 }
    }

    component WeekdayRow: RowLayout {
        spacing: 0
        Repeater {
            model: ["S", "M", "T", "W", "T", "F", "S"]
            CustomText {
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                horizontalAlignment: Text.AlignHCenter
                content: modelData
                size: 11
                weight: 600
                customColor: Colors.outline
            }
        }
    }

    component DayCell: Item {
        id: dc
        required property var modelData
        readonly property var date: root.cellDate(dc.modelData)
        readonly property bool isToday: root.same(dc.date, root.todayDate)
        readonly property bool other: !dc.modelData.isCurrentMonth
        readonly property bool holiday: dc.modelData.isHoliday && !dc.other
        readonly property int events: dc.other ? 0 : root.eventCount(dc.date)
        readonly property bool selected: root.same(dc.date, root.selDate)
        readonly property bool hovered: dcArea.containsMouse
        property bool dots: true
        property bool plain: false

        Layout.fillWidth: true
        Layout.fillHeight: true

        Rectangle {
            visible: !dc.plain
            anchors.centerIn: parent
            width: Math.min(parent.width - 4, 40)
            height: Math.min(parent.height - 2, 36)
            radius: height / 2
            color: dc.isToday ? Colors.primary : dc.hovered ? Colors.surfaceContainerHigh : Qt.alpha(Colors.surfaceContainerHigh, 0)
            border.width: dc.selected && !dc.isToday ? 1.5 : 0
            border.color: Colors.primary
            Behavior on color { EffectsColorAnim {} }
        }

        CustomText {
            anchors.centerIn: parent
            content: dc.modelData.day.toString()
            size: 13
            weight: dc.isToday ? 800 : 500
            customColor: dc.plain ? Colors.surfaceText
                       : dc.isToday ? Colors.primaryText
                       : dc.other ? Qt.alpha(Colors.surfaceText, 0.22)
                       : dc.holiday ? Colors.tertiary : Colors.surfaceText
        }

        Row {
            visible: dc.dots && !dc.plain
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(2, (parent.height - 36) / 2 + 3)
            spacing: 2
            Repeater {
                model: Math.min(2, dc.events)
                Rectangle { width: 4; height: 4; radius: 2; color: dc.isToday ? Colors.primaryText : Colors.primary }
            }
            Rectangle {
                visible: dc.holiday
                width: 4; height: 4; radius: 2
                color: dc.isToday ? Colors.primaryText : Colors.tertiary
            }
        }

        MouseArea {
            id: dcArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pick(dc.date)
            onContainsMouseChanged: root.hoverDate = containsMouse ? dc.date : (root.same(root.hoverDate, dc.date) ? null : root.hoverDate)
        }

        CustomToolTip {
            content: root.itemsOn(dc.date).map(i => i.title + (i.time ? " " + i.time : "")).join("\n")
            visible: dc.hovered && !dc.other && root.style !== "shapes" && content !== ""
        }
    }

    Loader {
        anchors.fill: parent
        anchors.margins: 12
        sourceComponent: root.style === "weeks" ? weeksComp : root.style === "shapes" ? shapesComp : sheetComp
    }

    Component {
        id: sheetComp
        ColumnLayout {
            spacing: 6
            Header { Layout.fillWidth: true }
            WeekdayRow { Layout.fillWidth: true }
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                columnSpacing: 0
                rowSpacing: 0
                Repeater {
                    model: root.cells
                    DayCell {}
                }
            }

            Rectangle {
                id: sheet
                readonly property var items: root.itemsOn(root.selDate)
                readonly property bool isToday: root.same(root.selDate, root.todayDate)
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(76, sheetCol.implicitHeight + 24)
                radius: 18
                color: Colors.surfaceContainerLow

                Rectangle {
                    id: badge
                    x: 12
                    y: 12
                    width: 52
                    height: 52
                    radius: 16
                    color: sheet.isToday ? Colors.primary : Colors.surfaceContainerHighest
                    Behavior on color { EffectsColorAnim {} }
                    Column {
                        anchors.centerIn: parent
                        CustomText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            content: root.selDate.getDate().toString()
                            size: 21
                            weight: 800
                            renderType: Text.QtRendering
                            customColor: sheet.isToday ? Colors.primaryText : Colors.surfaceText
                        }
                        CustomText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            content: ServiceClock.getMonthName(root.selDate.getMonth()).slice(0, 3)
                            size: 10
                            customColor: sheet.isToday ? Qt.alpha(Colors.primaryText, 0.75) : Colors.outline
                        }
                    }
                }

                ColumnLayout {
                    id: sheetCol
                    x: 78
                    y: 12
                    width: parent.width - 90
                    spacing: 3

                    CustomText {
                        Layout.fillWidth: true
                        content: root.dayNames[root.selDate.getDay()] + " " + root.selDate.getDate() + " " + ServiceClock.getMonthName(root.selDate.getMonth())
                        size: 13
                        weight: 600
                        elide: Text.ElideRight
                    }
                    CustomText {
                        content: root.relative(root.selDate) + ", week " + root.isoWeek(root.selDate)
                        size: 11
                        customColor: Colors.outline
                    }
                    Repeater {
                        model: sheet.items.slice(0, 3)
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            spacing: 8
                            MaterialIconSymbol {
                                content: modelData.holiday ? "celebration" : "event"
                                iconSize: 15
                                fill: 1
                                customColor: modelData.holiday ? Colors.tertiary : Colors.primary
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: modelData.title
                                size: 12
                                customColor: Colors.surfaceVariantText
                                elide: Text.ElideRight
                            }
                            CustomText {
                                visible: modelData.time !== ""
                                content: modelData.time
                                size: 11
                                customColor: Colors.outline
                            }
                        }
                    }
                    CustomText {
                        visible: sheet.items.length > 3
                        content: "+" + (sheet.items.length - 3) + " more"
                        size: 11
                        customColor: Colors.outline
                    }
                    CustomText {
                        visible: sheet.items.length === 0
                        Layout.topMargin: 2
                        content: "Nothing planned"
                        size: 12
                        customColor: Colors.outline
                    }
                }
            }
        }
    }

    Component {
        id: weeksComp
        ColumnLayout {
            spacing: 6
            Header { Layout.fillWidth: true }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property real rowH: (height - 20) / root.rows
                readonly property int todayRow: {
                    for (let i = 0; i < root.cells.length; i++)
                        if (root.same(root.cellDate(root.cells[i]), root.todayDate))
                            return Math.floor(i / 7)
                    return -1
                }

                Rectangle {
                    visible: parent.todayRow >= 0
                    x: 0
                    y: 20 + parent.todayRow * parent.rowH + 2
                    width: parent.width
                    height: parent.rowH - 4
                    radius: height / 2
                    color: Qt.alpha(Colors.secondaryContainer, 0.6)
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    ColumnLayout {
                        Layout.preferredWidth: 28
                        Layout.maximumWidth: 28
                        Layout.fillWidth: false
                        Layout.fillHeight: true
                        spacing: 0
                        CustomText {
                            Layout.preferredHeight: 20
                            Layout.alignment: Qt.AlignHCenter
                            content: "W"
                            size: 11
                            weight: 600
                            customColor: Colors.outline
                        }
                        Repeater {
                            model: root.rows
                            Item {
                                required property int index
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                CustomText {
                                    anchors.centerIn: parent
                                    content: root.isoWeek(root.cellDate(root.cells[index * 7 + 1])).toString()
                                    size: 10
                                    customColor: Colors.outline
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0
                        WeekdayRow {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            columns: 7
                            columnSpacing: 0
                            rowSpacing: 0
                            Repeater {
                                model: root.cells
                                DayCell {}
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                spacing: 6

                readonly property var weekDays: {
                    const t = root.todayDate
                    const start = new Date(t.getFullYear(), t.getMonth(), t.getDate() - t.getDay())
                    return Array.from({ length: 7 }, (_, i) => new Date(start.getFullYear(), start.getMonth(), start.getDate() + i))
                }
                readonly property int nEvents: weekDays.reduce((a, d) => a + root.eventCount(d), 0)
                readonly property int nHolidays: weekDays.filter(d => root.holidayOn(d) !== "").length

                CustomText {
                    Layout.fillWidth: true
                    textFormat: Text.StyledText
                    content: "Week <b>" + root.isoWeek(root.todayDate) + "</b>, " + parent.nEvents + " event" + (parent.nEvents === 1 ? "" : "s")
                             + (parent.nHolidays > 0 ? ", " + parent.nHolidays + " holiday" + (parent.nHolidays === 1 ? "" : "s") : "") + " this week"
                    size: 11
                    customColor: Colors.surfaceVariantText
                    elide: Text.ElideRight
                }
                Rectangle { width: 6; height: 6; radius: 3; color: Colors.primary }
                CustomText { content: "event"; size: 10; customColor: Colors.outline }
                Rectangle { width: 6; height: 6; radius: 3; color: Colors.tertiary }
                CustomText { content: "holiday"; size: 10; customColor: Colors.outline }
            }
        }
    }

    Component {
        id: shapesComp
        ColumnLayout {
            spacing: 6
            Header {
                Layout.fillWidth: true
                hero: true
            }
            WeekdayRow { Layout.fillWidth: true }
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                columnSpacing: 0
                rowSpacing: 0
                Repeater {
                    model: root.cells
                    Item {
                        id: sc
                        required property var modelData
                        readonly property var date: root.cellDate(sc.modelData)
                        readonly property bool other: !sc.modelData.isCurrentMonth
                        readonly property bool isToday: root.same(sc.date, root.todayDate)
                        readonly property bool holiday: sc.modelData.isHoliday && !sc.other
                        readonly property bool hasEvents: !sc.other && root.eventCount(sc.date) > 0
                        readonly property bool selected: root.same(sc.date, root.selDate)
                        readonly property bool marked: !sc.other && (sc.isToday || sc.holiday || sc.hasEvents || sc.selected || scArea.containsMouse)
                        readonly property real side: Math.min(width, height, 44) - (sc.isToday ? 2 : sc.holiday ? 6 : 12)
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        readonly property bool shaped: sc.isToday || sc.holiday

                        Rectangle {
                            anchors.centerIn: parent
                            width: sc.side
                            height: sc.side
                            radius: width / 2
                            visible: sc.marked && !sc.shaped
                            color: sc.hasEvents ? Colors.secondaryContainer
                                 : sc.selected ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                            Behavior on color { EffectsColorAnim {} }
                        }

                        Loader {
                            anchors.centerIn: parent
                            width: sc.side
                            height: sc.side
                            active: sc.shaped
                            visible: active
                            sourceComponent: MaterialShapes.ShapeCanvas {
                                roundedPolygon: ShapeLibrary.get(sc.isToday ? "cookie12" : "softBurst")
                                color: sc.isToday ? Colors.primary : Colors.tertiary

                                RotationAnimator on rotation {
                                    from: 0
                                    to: 360
                                    duration: 24000
                                    loops: Animation.Infinite
                                    running: sc.isToday && root.visible
                                }
                            }
                        }

                        CustomText {
                            anchors.centerIn: parent
                            content: sc.modelData.day.toString()
                            size: 13
                            weight: sc.isToday || sc.holiday ? 800 : 500
                            customColor: sc.other ? Qt.alpha(Colors.surfaceText, 0.22)
                                       : sc.isToday ? Colors.primaryText
                                       : sc.holiday ? Colors.tertiaryText
                                       : Colors.surfaceText
                        }

                        MouseArea {
                            id: scArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pick(sc.date)
                            onContainsMouseChanged: root.hoverDate = containsMouse ? sc.date : (root.same(root.hoverDate, sc.date) ? null : root.hoverDate)
                        }
                    }
                }
            }

            Rectangle {
                readonly property var shown: root.hoverDate ?? root.selDate
                readonly property var items: root.itemsOn(shown)
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 14
                color: Colors.surfaceContainerLow

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8
                    MaterialIconSymbol {
                        visible: parent.parent.items.length > 0
                        content: parent.parent.items.length && parent.parent.items[0].holiday ? "celebration" : "event"
                        iconSize: 16
                        fill: 1
                        customColor: parent.parent.items.length && parent.parent.items[0].holiday ? Colors.tertiary : Colors.primary
                    }
                    CustomText {
                        Layout.fillWidth: true
                        content: parent.parent.items.length
                                 ? parent.parent.items.map(i => i.title + (i.time ? " at " + i.time : "")).join(", ")
                                 : root.dayNames[parent.parent.shown.getDay()].slice(0, 3) + " " + parent.parent.shown.getDate() + " "
                                   + ServiceClock.getMonthName(parent.parent.shown.getMonth()) + ", nothing on"
                        size: 12
                        customColor: parent.parent.items.length ? Colors.surfaceVariantText : Colors.outline
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
