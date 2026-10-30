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
    configKey: "countdowns"
    tile: WidgetSizes.strip
    resizable: true
    minSpan: Qt.size(3, 1.5)
    maxSpan: Qt.size(5, 1.5)
    defaultPos: Qt.point(365, 605)

    property bool adding: false
    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"

    readonly property var holiday: {
        ServiceClock.date
        const list = ServiceClock.holidayData ?? []
        let best = null
        for (const h of list) {
            if (!h || !h.date) continue
            const n = ServicePersonal.daysUntil(h.date, false)
            if (n < 0) continue
            if (!best || n < best.days) best = { name: h.localName || h.name || "Holiday", days: n, auto: true }
        }
        return best
    }

    readonly property var items: {
        ServiceClock.date
        if (root.preview) return [{ name: "Diwali", days: 16, auto: true }, { name: "Jaipur trip", days: 24, idx: 0 }, { name: "Mom's birthday", days: 41, idx: 1 }]
        const out = root.holiday ? [root.holiday] : []
        const own = ServicePersonal.countdowns.map((c, i) => ({ name: c.name, days: ServicePersonal.daysUntil(c.date, c.yearly), idx: i }))
            .filter(c => c.days >= 0)
        return out.concat(own).sort((a, b) => a.days - b.days)
    }
    readonly property var lead: root.items.length > 0 ? root.items[0] : null
    readonly property int restSlots: Math.max(1, root.cols - 2)
    readonly property var rest: root.items.slice(1, 1 + root.restSlots)

    function dayLabel(days) {
        ServiceClock.date
        const d = new Date()
        d.setDate(d.getDate() + days)
        return Qt.formatDate(d, "ddd d MMM")
    }

    component Field: Rectangle {
        id: field
        property alias input: ti
        property string hint: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: 12
        color: ti.activeFocus ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
        CustomText {
            anchors.verticalCenter: parent.verticalCenter
            x: 10
            visible: ti.text === ""
            content: field.hint
            size: 12
            customColor: Colors.outline
        }
        TextInput {
            id: ti
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: Colors.surfaceText
            font.pixelSize: 12
            font.family: SettingsConfig.general.defaultFont ?? "Rubik"
            onActiveFocusChanged: if (activeFocus) GlobalStates.widgetTextFocus = true
            Keys.onEscapePressed: {
                root.adding = false
                GlobalStates.widgetTextFocus = false
            }
        }
    }

    component RemoveButton: MaterialIconSymbol {
        id: rm
        property int idx: -1
        property bool show: false
        visible: rm.show && rm.idx >= 0 && !root.preview
        content: "close"
        iconSize: 14
        customColor: Colors.outline
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: ServicePersonal.removeCountdown(rm.idx)
        }
    }

    function tryAdd() {
        if (ServicePersonal.addCountdown(nameIn.text, dateIn.text)) {
            nameIn.text = ""
            dateIn.text = ""
            root.adding = false
            GlobalStates.widgetTextFocus = false
        } else {
            dateIn.forceActiveFocus()
        }
    }

    WidgetCard {
        id: card
        anchors.fill: parent

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Item {
                id: badge
                Layout.preferredWidth: card.height - 24
                Layout.fillHeight: true

                HoverHandler { id: badgeHover }

                MaterialShapes.ShapeCanvas {
                    anchors.fill: parent
                    rotation: 45
                    roundedPolygon: ShapeLibrary.get("cookie4")
                    color: root.lead ? Colors.tertiaryContainer : Colors.surfaceContainerHigh
                }

                Column {
                    anchors.centerIn: parent
                    visible: !!root.lead
                    CustomText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        content: !root.lead ? "" : root.lead.days === 0 ? "Today" : root.lead.days.toString()
                        family: root.display
                        size: !root.lead || root.lead.days === 0 ? 22 : (root.lead.days > 99 ? 30 : 40)
                        weight: 400
                        customColor: Colors.tertiaryContainerText
                    }
                    CustomText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !!root.lead && root.lead.days > 0
                        content: root.lead && root.lead.days === 1 ? "DAY" : "DAYS"
                        size: 11
                        weight: 800
                        customColor: Colors.tertiaryContainerText
                    }
                }

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    visible: !root.lead
                    content: "hourglass_empty"
                    iconSize: 30
                    customColor: Colors.outline
                }

                RemoveButton {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    idx: root.lead && root.lead.idx !== undefined ? root.lead.idx : -1
                    show: badgeHover.hovered
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2
                visible: !root.adding

                CustomText {
                    Layout.fillWidth: true
                    content: root.lead ? root.lead.name : "No dates yet"
                    size: 15
                    weight: 800
                    elide: Text.ElideRight
                }
                CustomText {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    content: root.lead ? root.dayLabel(root.lead.days) + (root.lead.auto ? " · holiday" : "")
                                       : "Add a trip, a birthday, a deadline"
                    size: 11
                    weight: 500
                    elide: Text.ElideRight
                    customColor: Colors.surfaceVariantText
                }

                Item { Layout.fillHeight: true }

                GridLayout {
                    Layout.fillWidth: true
                    columns: root.restSlots
                    columnSpacing: 2
                    rowSpacing: 2
                    visible: root.rest.length > 0

                    Repeater {
                        model: root.rest
                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            readonly property bool first: row.index === 0
                            readonly property bool last: row.index === root.rest.length - 1
                            topLeftRadius: row.first ? 12 : 4
                            bottomLeftRadius: row.first && root.restSlots > 1 ? 12 : 4
                            topRightRadius: row.last || root.restSlots === 1 ? 12 : 4
                            bottomRightRadius: row.last && root.restSlots > 1 ? 12 : 4
                            color: Colors.surfaceContainerHigh

                            HoverHandler { id: rowHover }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 6
                                CustomText {
                                    Layout.fillWidth: true
                                    content: row.modelData.name
                                    size: 12
                                    weight: 600
                                    elide: Text.ElideRight
                                }
                                RemoveButton {
                                    idx: row.modelData.idx ?? -1
                                    show: rowHover.hovered
                                }
                                CustomText {
                                    visible: !rowHover.hovered || row.modelData.idx === undefined || root.preview
                                    content: row.modelData.days === 0 ? "today" : row.modelData.days + " d"
                                    size: 12
                                    weight: 800
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    topLeftRadius: root.rest.length > 0 ? 4 : 12
                    topRightRadius: root.rest.length > 0 ? 4 : 12
                    bottomLeftRadius: 12
                    bottomRightRadius: 12
                    color: addArea.containsMouse ? Colors.surfaceContainerHigh : Qt.alpha(Colors.surfaceContainerHigh, 0.55)
                    Behavior on color { EffectsColorAnim {} }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        spacing: 4
                        MaterialIconSymbol { anchors.verticalCenter: parent.verticalCenter; content: "add"; iconSize: 16; customColor: Colors.primary }
                        CustomText { anchors.verticalCenter: parent.verticalCenter; content: "Add a date"; size: 12; weight: 700; customColor: Colors.primary }
                    }

                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.preview
                        cursorShape: Qt.PointingHandCursor
                        onEntered: GlobalStates.widgetTextFocus = true
                        onExited: if (!root.adding) GlobalStates.widgetTextFocus = false
                        onClicked: {
                            root.adding = true
                            nameIn.forceActiveFocus()
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6
                visible: root.adding

                Item { Layout.fillHeight: true }
                Field {
                    id: nameField
                    hint: "What’s coming?"
                    input.onAccepted: dateIn.forceActiveFocus()
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Field {
                        id: dateField
                        hint: "12 Oct"
                        input.onAccepted: root.tryAdd()
                    }
                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 17
                        color: Colors.primary
                        MaterialIconSymbol { anchors.centerIn: parent; content: "check"; iconSize: 18; customColor: Colors.primaryText }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.tryAdd() }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }

    readonly property Item nameIn: nameField.input
    readonly property Item dateIn: dateField.input
}
