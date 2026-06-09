import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings

Item {
    id: root
    anchors.fill: parent

    signal toggleTodo

    // ── Enter animation ────────────────────────────────────────────
    opacity: 0
    scale: 0.9
    NumberAnimation on opacity { from: 0; to: 1; duration: 350; running: true }
    NumberAnimation on scale   { from: 0.9; to: 1; duration: 350; easing.type: Easing.OutQuad; running: true }

    // ── Close on hover leave ───────────────────────────────────────
    property bool active: hoverHandler.hovered
    onActiveChanged: { if (!active) root.toggleTodo() }
    HoverHandler { id: hoverHandler }

    Component.onCompleted: todoInput.forceActiveFocus()

    // ── Local state ────────────────────────────────────────────────
    property string filterStatus: "all"
    property int newPriority: 0

    readonly property var visibleTodos: {
        const t = ServiceTodo.todos
        if (filterStatus === "active")    return t.filter(x => !x.completed)
        if (filterStatus === "completed") return t.filter(x =>  x.completed)
        return t
    }

    // Priority accent color helper
    function priorityColor(p) {
        switch (p) {
            case 3: return Colors.error
            case 2: return Colors.secondary
            case 1: return Colors.tertiary
            default: return Colors.outline
        }
    }

    // ── Root layout ────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // ── Header ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: Colors.surfaceContainer
            radius: 18

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 10

                MaterialIconSymbol {
                    content: "checklist"
                    iconSize: 22
                    color: Colors.primary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    CustomText {
                        content: "Tasks"
                        size: 15
                        weight: 700
                    }

                    CustomText {
                        content: ServiceTodo.stats.active + " active · " + ServiceTodo.stats.completed + " done"
                            + (ServiceTodo.stats.overdue > 0 ? " · " + ServiceTodo.stats.overdue + " overdue" : "")
                        size: 10
                        weight: 600
                        customColor: ServiceTodo.stats.overdue > 0 ? Colors.error : Colors.outline
                    }
                }

                // Overdue badge
                Rectangle {
                    Layout.preferredWidth: Math.max(overdueText.implicitWidth + 10, 22)
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter
                    visible: ServiceTodo.stats.overdue > 0
                    radius: 10
                    color: Qt.alpha(Colors.error, 0.18)

                    CustomText {
                        id: overdueText
                        anchors.centerIn: parent
                        content: "!" + ServiceTodo.stats.overdue
                        size: 10
                        weight: 700
                        customColor: Colors.error
                    }
                }

                // Active badge
                Rectangle {
                    Layout.preferredWidth: Math.max(activeText.implicitWidth + 10, 22)
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter
                    visible: ServiceTodo.stats.active > 0
                    radius: 10
                    color: Colors.primary

                    CustomText {
                        id: activeText
                        anchors.centerIn: parent
                        content: ServiceTodo.stats.active + ""
                        size: 10
                        weight: 700
                        customColor: Colors.primaryText
                    }
                }

                MaterialIconSymbol {
                    content: "close"
                    iconSize: 18
                    color: Colors.outline

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleTodo()
                    }
                }
            }
        }

        // ── Add input ──────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            color: Colors.surfaceContainer
            radius: 18

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8

                // Priority picker — click to cycle
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    radius: 14
                    color: root.newPriority === 0
                        ? Colors.surfaceContainerHigh
                        : Qt.alpha(root.priorityColor(root.newPriority), 0.2)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: ServiceTodo.priorityIcon(root.newPriority)
                        iconSize: 14
                        color: root.newPriority === 0
                            ? Colors.outline
                            : root.priorityColor(root.newPriority)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.newPriority = (root.newPriority + 1) % 4
                    }
                }

                TextInput {
                    id: todoInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    focus: true
                    color: Colors.surfaceText
                    font.pixelSize: 13
                    font.family: SettingsConfig.general.defaultFont
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Add a new task…"
                        font: parent.font
                        color: Colors.outline
                        visible: parent.text.length === 0 && !parent.activeFocus
                    }

                    Keys.onReturnPressed: {
                        if (todoInput.text.trim() !== "") {
                            ServiceTodo.addTodo(todoInput.text.trim(), "", root.newPriority, [], "")
                            todoInput.text = ""
                            root.newPriority = 0
                        }
                    }
                }

                // Add button
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    radius: 15
                    color: addArea.containsMouse ? Colors.primary : Colors.surfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "add"
                        iconSize: 17
                        color: addArea.containsMouse ? Colors.primaryText : Colors.surfaceText
                    }

                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (todoInput.text.trim() !== "") {
                                ServiceTodo.addTodo(todoInput.text.trim(), "", root.newPriority, [], "")
                                todoInput.text = ""
                                root.newPriority = 0
                            }
                        }
                    }
                }
            }
        }

        // ── Filter chips ───────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: Colors.surfaceContainer
            radius: 16

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                Repeater {
                    model: [
                        { label: "All",    key: "all",       count: ServiceTodo.stats.total    },
                        { label: "Active", key: "active",    count: ServiceTodo.stats.active   },
                        { label: "Done",   key: "completed", count: ServiceTodo.stats.completed }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: root.filterStatus === modelData.key
                            ? Colors.primary
                            : chipArea.containsMouse
                                ? Qt.alpha(Colors.primary, 0.18)
                                : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            CustomText {
                                content: modelData.label
                                size: 11
                                weight: root.filterStatus === modelData.key ? 700 : 600
                                customColor: root.filterStatus === modelData.key
                                    ? Colors.primaryText : Colors.surfaceText
                            }

                            CustomText {
                                content: modelData.count + ""
                                size: 10
                                weight: 700
                                customColor: root.filterStatus === modelData.key
                                    ? Qt.alpha(Colors.primaryText, 0.7) : Colors.outline
                                visible: modelData.count > 0
                            }
                        }

                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.filterStatus = modelData.key
                        }
                    }
                }
            }
        }

        // ── Todo list ──────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Colors.surfaceContainer
            radius: 18
            clip: true

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: root.visibleTodos

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: 60
                            radius: 14
                            color: rowHover.hovered
                                ? Colors.surfaceContainerHighest
                                : Colors.surfaceContainerHigh
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: rowHover }

                            // Priority left stripe
                            Rectangle {
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.topMargin: 10
                                anchors.bottomMargin: 10
                                anchors.left: parent.left
                                anchors.leftMargin: 5
                                width: 3
                                radius: 2
                                visible: modelData.priority > 0
                                color: root.priorityColor(modelData.priority)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: modelData.priority > 0 ? 14 : 10
                                anchors.rightMargin: 10
                                anchors.topMargin: 8
                                anchors.bottomMargin: 8
                                spacing: 10

                                CustomCheckbox {
                                    Layout.alignment: Qt.AlignVCenter
                                    checkState: modelData.completed

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ServiceTodo.toggleComplete(modelData.id)
                                    }
                                }

                                // Title + metadata column
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 3

                                    CustomText {
                                        Layout.fillWidth: true
                                        content: modelData.title
                                        size: 13
                                        weight: 600
                                        customColor: modelData.completed ? Colors.outline : Colors.surfaceText
                                        font.strikeout: modelData.completed
                                        elide: Text.ElideRight
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        // Created date
                                        CustomText {
                                            content: "Created " + ServiceTodo.formatDate(modelData.createdAt)
                                            size: 10
                                            weight: 500
                                            customColor: Colors.outline
                                        }

                                        // Due date chip
                                        Rectangle {
                                            Layout.preferredHeight: 15
                                            Layout.preferredWidth: dueLabel.implicitWidth + 10
                                            radius: 8
                                            visible: modelData.dueDate !== ""
                                            color: ServiceTodo.isOverdue(modelData)
                                                ? Qt.alpha(Colors.error, 0.18)
                                                : ServiceTodo.isDueToday(modelData)
                                                    ? Qt.alpha(Colors.tertiary, 0.18)
                                                    : Qt.alpha(Colors.outline, 0.12)

                                            CustomText {
                                                id: dueLabel
                                                anchors.centerIn: parent
                                                content: ServiceTodo.dueDateLabel(modelData.dueDate)
                                                size: 9
                                                weight: 700
                                                customColor: ServiceTodo.isOverdue(modelData)
                                                    ? Colors.error
                                                    : ServiceTodo.isDueToday(modelData)
                                                        ? Colors.tertiary
                                                        : Colors.outline
                                            }
                                        }
                                    }
                                }

                                // Priority badge
                                Rectangle {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 11
                                    visible: modelData.priority > 0
                                    color: Qt.alpha(root.priorityColor(modelData.priority), 0.15)

                                    MaterialIconSymbol {
                                        anchors.centerIn: parent
                                        content: ServiceTodo.priorityIcon(modelData.priority)
                                        iconSize: 12
                                        color: root.priorityColor(modelData.priority)
                                    }
                                }

                                // Delete
                                MaterialIconSymbol {
                                    Layout.alignment: Qt.AlignVCenter
                                    content: "delete"
                                    iconSize: 16
                                    color: Colors.error
                                    opacity: deleteHover.hovered ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 120 } }

                                    HoverHandler { id: deleteHover }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ServiceTodo.removeTodo(modelData.id)
                                    }
                                }
                            }
                        }
                    }

                    // Empty state
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 100
                        visible: root.visibleTodos.length === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            MaterialIconSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                content: root.filterStatus === "completed" ? "task_alt" : "checklist"
                                iconSize: 36
                                color: Colors.outlineVariant
                            }

                            CustomText {
                                Layout.alignment: Qt.AlignHCenter
                                content: root.filterStatus === "completed" ? "Nothing done yet" : "All clear!"
                                size: 13
                                weight: 600
                                customColor: Colors.outline
                            }

                            CustomText {
                                Layout.alignment: Qt.AlignHCenter
                                content: root.filterStatus === "all" ? "Add a task above to get started" : ""
                                size: 11
                                weight: 500
                                customColor: Colors.outlineVariant
                                visible: content !== ""
                            }
                        }
                    }
                }
            }
        }

        // ── Footer: clear completed ────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            visible: ServiceTodo.stats.completed > 0
            color: Colors.surfaceContainer
            radius: 16

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14

                CustomText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    content: ServiceTodo.stats.completed + " task" + (ServiceTodo.stats.completed !== 1 ? "s" : "") + " completed"
                    size: 11
                    weight: 600
                    customColor: Colors.outline
                }

                CustomText {
                    Layout.alignment: Qt.AlignVCenter
                    content: "Clear"
                    size: 11
                    weight: 700
                    customColor: Colors.error

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ServiceTodo.clearCompleted()
                    }
                }
            }
        }
    }
}
