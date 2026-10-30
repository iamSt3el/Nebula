pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Edit

EditKit.Card {
    id: shelf

    required property Item host
    required property Item capsuleItem

    readonly property bool wanted: shelf.host.shelfOpen && shelf.host.editing
    property real openT: shelf.wanted ? 1 : 0
    Behavior on openT {
        NumberAnimation {
            duration: shelf.wanted ? 520 : 400
            easing.type: Easing.BezierSpline
            easing.bezierCurve: shelf.wanted ? [0.2, 0, 0, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
        }
    }
    readonly property real fullW: Math.min(1180, shelf.host.width - 64)
    readonly property real fullX: (shelf.host.width - shelf.fullW) / 2
    readonly property real floorTop: shelf.host.surfBottom && shelf.host.surfBottom.visible && shelf.host.surfBottom.present
        ? shelf.host.surfBottom.bandRect.y : shelf.host.height
    readonly property real fullY: Math.max(16, Math.min(shelf.host.height - 360 - 24, shelf.floorTop - 360 - 14))
    readonly property real inT: Math.max(0, Math.min(1, (shelf.openT - 0.6) / 0.4))
    property real cardsT: 1

    onWantedChanged: {
        if (!shelf.wanted)
            return
        shelf.cardsT = 0
        cascade.restart()
        Qt.callLater(() => partSearch.forceActiveFocus())
    }

    SequentialAnimation {
        id: cascade
        PauseAnimation { duration: 380 }
        NumberAnimation { target: shelf; property: "cardsT"; from: 0; to: 1; duration: 640 }
    }

    visible: shelf.openT > 0.01
    opacity: Math.min(1, shelf.openT * 4)
    clip: true
    readonly property real startW: 360
    x: (shelf.host.width - shelf.startW) / 2 + (shelf.fullX - (shelf.host.width - shelf.startW) / 2) * shelf.openT
    y: shelf.fullY + 304 * (1 - shelf.openT)
    width: shelf.startW + (shelf.fullW - shelf.startW) * shelf.openT
    height: 56 + 304 * shelf.openT
    radius: 28 + 2 * shelf.openT
    border.width: shelf.dropping ? 2 : 1
    border.color: shelf.dropping ? Colors.error : Qt.alpha(Colors.outline, 0.18)

    readonly property bool dropping: shelf.host.editor !== null && shelf.host.editor.mode === "item"
                                     && shelf.host.editor.fromBlock !== "" && shelf.host.editor.overDrawer

    property string group: "All"
    readonly property string filter: GlobalStates.editAddQuery
    readonly property string needle: shelf.filter.trim().toLowerCase()
    readonly property var parts: BarLayout.hiddenItems.filter(id => {
        const e = BarLayout.entry(id)
        if (!e) return false
        if (shelf.needle !== "")
            return e.label.toLowerCase().indexOf(shelf.needle) >= 0 || (e.group ?? "").toLowerCase().indexOf(shelf.needle) >= 0
        return shelf.group === "All" || e.group === shelf.group
    })

    MouseArea {
        anchors.fill: parent
    }

    ColumnLayout {
        x: 20
        y: 16
        width: shelf.fullW - 40
        height: 324
        spacing: 14
        opacity: (shelf.dropping ? 0.25 : 1) * shelf.inT

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            EditAddTabs {
                current: "parts"
            }

            CustomText {
                Layout.fillWidth: true
                content: "drag onto any edge · + drops it after your selection"
                size: 12
                weight: 400
                customColor: Colors.outline
            }

            Rectangle {
                Layout.preferredWidth: 260
                implicitHeight: 40
                radius: 20
                color: Colors.surfaceContainerHigh
                border.width: 1
                border.color: partSearch.activeFocus ? Qt.alpha(Colors.primary, 0.7) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 8

                    MaterialIconSymbol {
                        content: "search"
                        iconSize: 16
                        customColor: Colors.outline
                    }

                    TextInput {
                        id: partSearch
                        Layout.fillWidth: true
                        clip: true
                        text: shelf.filter
                        font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                        font.pixelSize: 13
                        color: Colors.surfaceText
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: if (GlobalStates.editAddQuery !== partSearch.text) GlobalStates.editAddQuery = partSearch.text
                        Keys.onEscapePressed: {
                            if (partSearch.text !== "") partSearch.text = ""
                            else shelf.host.shelfOpen = false
                        }

                        CustomText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: partSearch.text === "" && !partSearch.activeFocus
                            content: "Search parts, widgets and tiles"
                            size: 13
                            customColor: Colors.outline
                        }
                    }
                }
            }

            EditKit.Pill {
                icon: "close"
                tip: "Close · Esc"
                onClicked: shelf.host.shelfOpen = false
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            ColumnLayout {
                Layout.preferredWidth: 160
                Layout.maximumWidth: 160
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignTop
                spacing: 2

                Repeater {
                    model: ["All"].concat(BarLayout.groups)

                    Rectangle {
                        id: grp
                        required property string modelData
                        readonly property bool on: shelf.needle === "" && shelf.group === grp.modelData
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 19
                        color: grp.on ? Colors.secondaryContainer
                            : grpArea.containsMouse ? Qt.alpha(Colors.surfaceText, 0.06) : "transparent"

                        CustomText {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            content: grp.modelData
                            size: 13
                            weight: grp.on ? 700 : 500
                            customColor: grp.on ? Colors.secondaryContainerText : Colors.surfaceVariantText
                        }

                        MouseArea {
                            id: grpArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                partSearch.text = ""
                                shelf.group = grp.modelData
                            }
                        }
                    }
                }
            }

            Flickable {
                id: partFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: partGrid.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: CustomScrollBar {}

                GridLayout {
                    id: partGrid
                    width: partFlick.width
                    columns: Math.max(2, Math.floor(partFlick.width / 230))
                    columnSpacing: 12
                    rowSpacing: 12

                    Repeater {
                        model: shelf.visible ? shelf.parts : []

                        Rectangle {
                            id: part
                            required property string modelData
                            required property int index
                            readonly property real delay: Math.floor(part.index / Math.max(1, partGrid.columns)) * 70
                                + (part.index % Math.max(1, partGrid.columns)) * 30
                            readonly property real landT: {
                                const t = Math.max(0, Math.min(1, (shelf.cardsT * 640 - part.delay) / 260))
                                return 1 - Math.pow(1 - t, 3)
                            }
                            transform: Translate { y: 12 * (1 - part.landT) }
                            readonly property var entry: BarLayout.entry(part.modelData)
                            readonly property bool multi: !!part.entry && !!part.entry.multi

                            Layout.fillWidth: true
                            Layout.preferredHeight: 126
                            radius: 20
                            color: partArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                            opacity: (shelf.host.editor && shelf.host.editor.mode === "item" && shelf.host.editor.itemId === part.modelData ? 0.35 : 1) * part.landT

                            Item {
                                id: partStub
                                visible: false
                                readonly property bool editing: false
                                readonly property real maxWidth: 220
                                readonly property real fixedWidth: 0
                                readonly property real iconSize: 0
                                readonly property real barH: 40
                                readonly property bool vertical: false
                                function hoverOpen(kind, item) {}
                                function openPanel(kind, item) {}
                                function closePanel() {}
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Rectangle {
                                    id: partPreview
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 58
                                    radius: 14
                                    color: Colors.surface
                                    clip: true

                                    Loader {
                                        id: partLoader
                                        readonly property bool wide: !!item && item.implicitWidth > partPreview.width - 24
                                        readonly property bool usable: status === Loader.Ready && !!item
                                            && item.implicitWidth >= 2 && item.shown !== false
                                        x: partLoader.wide ? 12 : Math.round((partPreview.width - width) / 2)
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: partLoader.usable
                                        enabled: false
                                        asynchronous: true
                                        active: !part.multi
                                        source: active ? BarLayout.urlFor(part.modelData) : ""
                                        onLoaded: {
                                            item.host = partStub
                                            if ("itemId" in item)
                                                item.itemId = part.modelData
                                        }
                                    }

                                    Rectangle {
                                        visible: partLoader.wide && partLoader.usable
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 40
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0; color: Qt.alpha(Colors.surface, 0) }
                                            GradientStop { position: 1; color: Colors.surface }
                                        }
                                    }

                                    MaterialIconSymbol {
                                        anchors.centerIn: parent
                                        visible: part.multi || !partLoader.usable
                                        content: part.entry ? part.entry.icon : "widgets"
                                        iconSize: 24
                                        customColor: Colors.primary
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        CustomText {
                                            Layout.fillWidth: true
                                            content: part.entry ? part.entry.label : part.modelData
                                            size: 13
                                            weight: 600
                                        }
                                        CustomText {
                                            Layout.fillWidth: true
                                            content: (part.entry ? part.entry.group : "") + (part.multi ? " · add many" : "")
                                            size: 11
                                            weight: 400
                                            customColor: Colors.surfaceVariantText
                                        }
                                    }

                                    EditKit.Pill {
                                        icon: "add"
                                        box: 32
                                        lit: true
                                        tip: "Add after the selected item"
                                        onClicked: shelf.host.addItem(part.modelData)
                                    }
                                }
                            }

                            MouseArea {
                                id: partArea
                                anchors.fill: parent
                                z: -1
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: shelf.host.editor && shelf.host.editor.mode === "item" ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                                property real sx: 0
                                property real sy: 0

                                onPressed: mouse => {
                                    partArea.sx = mouse.x
                                    partArea.sy = mouse.y
                                }
                                onPositionChanged: mouse => {
                                    if (!partArea.pressed)
                                        return
                                    const e = shelf.host.editor
                                    if (e.mode === "" && Math.hypot(mouse.x - partArea.sx, mouse.y - partArea.sy) > 4)
                                        e.beginItem(part.modelData, "", -1, 32)
                                    if (e.mode !== "") {
                                        const p = partArea.mapToItem(null, mouse.x, mouse.y)
                                        e.update(p.x, p.y)
                                    }
                                }
                                onReleased: if (shelf.host.editor.mode !== "") shelf.host.editor.finish()
                                onCanceled: shelf.host.editor.cancel()
                            }
                        }
                    }
                }

                CustomText {
                    anchors.centerIn: parent
                    visible: shelf.parts.length === 0
                    content: shelf.needle !== "" ? "Nothing matches that" : "Everything here is already on your bar"
                    size: 13
                    customColor: Colors.outline
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: shelf.dropping
        spacing: 8

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 56
            implicitHeight: 56
            radius: 28
            color: Colors.errorContainer
            MaterialIconSymbol {
                anchors.centerIn: parent
                content: "delete"
                iconSize: 26
                customColor: Colors.errorContainerText
            }
        }

        CustomText {
            Layout.alignment: Qt.AlignHCenter
            content: "Release to remove " + (shelf.host.editor ? shelf.host.editor.label : "")
            size: 15
            weight: 600
        }
    }
}
