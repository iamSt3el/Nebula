import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: card

    property var note: null
    property real maxHeight: 600
    property string shownId: ""
    readonly property color paper: card.note ? (ServiceNotes.colors[card.note.c] ?? ServiceNotes.colors.butter) : "transparent"
    readonly property color ink: "#2e2410"
    readonly property string display: SettingsConfig.general.displayFont || "Titan One"
    readonly property int done: card.note ? card.note.todo.filter(t => t[1]).length : 0

    implicitHeight: Math.min(card.maxHeight, head.implicitHeight + paperFlick.contentHeight + foot.implicitHeight + 64)
    height: implicitHeight

    onNoteChanged: {
        if (!card.note) {
            card.shownId = ""
            return
        }
        if (card.note.id === card.shownId)
            return
        card.shownId = card.note.id
        titleIn.text = card.note.title
        bodyIn.text = card.note.body
        if (card.note.title === "New note" && card.note.body === "") {
            titleIn.forceActiveFocus()
            titleIn.selectAll()
        } else {
            bodyIn.forceActiveFocus()
            bodyIn.cursorPosition = bodyIn.length
        }
    }

    Keys.onEscapePressed: ServiceNotes.openId = ""

    component InkButton: Rectangle {
        id: ib
        property string icon: ""
        property string tip: ""
        signal clicked()
        implicitWidth: 30
        implicitHeight: 30
        radius: 15
        color: ibArea.containsMouse ? Qt.alpha(card.ink, 0.1) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
        MaterialIconSymbol {
            anchors.centerIn: parent
            content: ib.icon
            iconSize: 18
            customColor: Qt.alpha(card.ink, 0.75)
        }
        MouseArea {
            id: ibArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.clicked()
        }
    }

    NotePaper {
        anchors.fill: parent
        paper: card.paper
        radius: 20
        fold: 26
        tape: true
    }

    RowLayout {
        id: head
        x: 16
        y: 16
        width: parent.width - 28
        spacing: 2

        Row {
            Layout.fillWidth: true
            spacing: 5
            Repeater {
                model: ServiceNotes.notes
                Rectangle {
                    id: dot
                    required property var modelData
                    readonly property bool current: card.note && dot.modelData.id === card.note.id
                    anchors.verticalCenter: parent.verticalCenter
                    width: dot.current ? 22 : 12
                    height: 12
                    radius: 6
                    color: ServiceNotes.colors[dot.modelData.c] ?? ServiceNotes.colors.butter
                    border.width: 1.5
                    border.color: Qt.alpha(card.ink, dot.current ? 0.7 : 0.28)
                    Behavior on width { SpatialAnim { speed: "fast" } }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ServiceNotes.openId = dot.modelData.id
                    }
                }
            }
        }

        InkButton {
            icon: "delete"
            onClicked: if (card.note) ServiceNotes.remove(card.note.id)
        }
        InkButton {
            icon: "close"
            onClicked: ServiceNotes.openId = ""
        }
    }

    Flickable {
        id: paperFlick
        x: 20
        anchors.top: head.bottom
        anchors.topMargin: 10
        width: parent.width - 40
        height: Math.min(paperFlick.contentHeight, card.maxHeight - head.implicitHeight - foot.implicitHeight - 64)
        contentWidth: width
        contentHeight: paperCol.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: paperCol
            width: paperFlick.width
            spacing: 8

            TextEdit {
                id: titleIn
                Layout.fillWidth: true
                font.family: card.display
                font.pixelSize: 21
                color: card.ink
                wrapMode: TextEdit.Wrap
                selectionColor: Qt.alpha(card.ink, 0.22)
                selectedTextColor: card.ink
                renderType: Text.QtRendering
                onTextChanged: {
                    if (!card.note || !activeFocus)
                        return
                    const t = text.replace(/[\r\n]+/g, " ")
                    if (t !== card.note.title)
                        ServiceNotes.update(card.note.id, { title: t })
                }
                Keys.onReturnPressed: bodyIn.forceActiveFocus()
                Keys.onEnterPressed: bodyIn.forceActiveFocus()
            }

            TextEdit {
                id: bodyIn
                Layout.fillWidth: true
                Layout.minimumHeight: 54
                font.family: "Rubik"
                font.pixelSize: 14
                color: Qt.alpha(card.ink, 0.92)
                wrapMode: TextEdit.Wrap
                selectionColor: Qt.alpha(card.ink, 0.22)
                selectedTextColor: card.ink
                onTextChanged: if (card.note && activeFocus && text !== card.note.body) ServiceNotes.update(card.note.id, { body: text })

                Text {
                    visible: bodyIn.text === "" && !bodyIn.activeFocus
                    text: "Write something…"
                    font.family: "Rubik"
                    font.pixelSize: 14
                    color: Qt.alpha(card.ink, 0.42)
                }
            }

            Repeater {
                model: card.note ? card.note.todo : []
                RowLayout {
                    id: item
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 9

                    Rectangle {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 1
                        radius: 9
                        color: item.modelData[1] ? Qt.alpha(card.ink, 0.75) : "transparent"
                        border.width: 1.8
                        border.color: Qt.alpha(card.ink, 0.6)
                        Behavior on color { ColorAnimation { duration: 140 } }
                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            visible: item.modelData[1]
                            content: "check"
                            iconSize: 13
                            customColor: card.paper
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ServiceNotes.setTodo(card.note.id, item.index, !item.modelData[1])
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: item.modelData[0]
                        font.family: "Rubik"
                        font.pixelSize: 14
                        font.strikeout: item.modelData[1]
                        color: Qt.alpha(card.ink, item.modelData[1] ? 0.5 : 0.92)
                        wrapMode: Text.WordWrap
                    }
                    MaterialIconSymbol {
                        visible: rowHover.hovered
                        content: "close"
                        iconSize: 15
                        customColor: Qt.alpha(card.ink, 0.55)
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ServiceNotes.removeTodo(card.note.id, item.index)
                        }
                    }
                    HoverHandler { id: rowHover }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                Rectangle {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    radius: 9
                    color: "transparent"
                    border.width: 1.5
                    border.color: Qt.alpha(card.ink, 0.3)
                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "add"
                        iconSize: 13
                        customColor: Qt.alpha(card.ink, 0.5)
                    }
                }
                TextInput {
                    id: todoIn
                    Layout.fillWidth: true
                    font.family: "Rubik"
                    font.pixelSize: 14
                    color: card.ink
                    clip: true
                    onAccepted: {
                        if (card.note) ServiceNotes.addTodo(card.note.id, text)
                        text = ""
                    }
                    Text {
                        visible: todoIn.text === "" && !todoIn.activeFocus
                        text: "Add a to-do"
                        font.family: "Rubik"
                        font.pixelSize: 14
                        color: Qt.alpha(card.ink, 0.42)
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: foot
        x: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: parent.width - 40 - 18
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(card.ink, 0.14)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: ServiceNotes.colorKeys
                Rectangle {
                    id: sw
                    required property string modelData
                    readonly property bool on: card.note && card.note.c === sw.modelData
                    implicitWidth: 18
                    implicitHeight: 18
                    radius: 9
                    color: ServiceNotes.colors[sw.modelData]
                    border.width: sw.on ? 2.5 : 1
                    border.color: Qt.alpha(card.ink, sw.on ? 0.75 : 0.25)
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -3
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (card.note) ServiceNotes.update(card.note.id, { c: sw.modelData })
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitHeight: 30
                implicitWidth: newRow.implicitWidth + 22
                radius: 15
                color: newArea.containsMouse ? Qt.alpha(card.ink, 0.9) : Qt.alpha(card.ink, 0.8)
                Row {
                    id: newRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialIconSymbol { anchors.verticalCenter: parent.verticalCenter; content: "add"; iconSize: 16; customColor: card.paper }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "New"
                        font.family: "Rubik"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: card.paper
                    }
                }
                MouseArea {
                    id: newArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const cur = card.note
                        const id = ServiceNotes.add(cur ? cur.side : undefined)
                        if (cur && (SettingsConfig.general.notesLayout ?? "stack") === "stack")
                            ServiceNotes.place(id, cur.side, cur.y + 0.0001)
                        else if (cur)
                            ServiceNotes.update(id, { y: Math.min(0.92, cur.y + 0.09) })
                        ServiceNotes.openId = id
                    }
                }
            }
        }

        Text {
            text: card.note ? "Edited " + ServiceNotes.ago(card.note.at)
                  + (card.note.todo.length ? " · " + card.done + " of " + card.note.todo.length + " done" : "") : ""
            font.family: "Rubik"
            font.pixelSize: 11
            font.weight: Font.Medium
            color: Qt.alpha(card.ink, 0.6)
        }
    }
}
