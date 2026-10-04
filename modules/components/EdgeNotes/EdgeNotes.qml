import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Scope {
    id: scope

    readonly property var screen: {
        const pm = SettingsConfig.general?.primaryMonitor ?? ""
        return Quickshell.screens.find(s => s.name === pm) ?? Quickshell.screens[0]
    }
    readonly property bool hidden: {
        const mon = Hyprland.monitors.values.find(m => m.name === scope.screen?.name)
        return !!mon?.activeWorkspace?.hasFullscreen || ServiceGameMode.hideWidgets
    }

    readonly property bool stacked: (SettingsConfig.general.notesLayout ?? "stack") === "stack"
    readonly property string anchorAt: SettingsConfig.general.notesAnchor ?? "top"
    readonly property int offset: SettingsConfig.general.notesOffset ?? 200
    readonly property int gap: SettingsConfig.general.notesGap ?? 12
    readonly property int cardWidth: SettingsConfig.general.notesCardWidth ?? 340
    readonly property string display: SettingsConfig.general.displayFont || "Titan One"
    readonly property color ink: "#2e2410"

    Connections {
        target: ServiceNotes
        function onRequestOpen(id) { ServiceNotes.openId = id }
    }

    Variants {
        model: ["L", "R"]

        delegate: PanelWindow {
            id: win
            required property string modelData
            readonly property string side: win.modelData
            readonly property bool onRight: win.side === "R"
            readonly property var mine: ServiceNotes.notes.filter(n => n.side === win.side)
            readonly property var ordered: win.mine.slice().sort((a, b) => a.y - b.y)
            readonly property var openNote: {
                const n = ServiceNotes.find(ServiceNotes.openId)
                return n && n.side === win.side ? n : null
            }
            readonly property real edgeW: 20
            readonly property real chipH: 46
            readonly property real stackH: win.ordered.length * win.chipH + Math.max(0, win.ordered.length - 1) * scope.gap
            readonly property real stackTop: {
                const want = scope.anchorAt === "bottom" ? win.height - scope.offset - win.stackH
                    : scope.anchorAt === "middle" ? (win.height - win.stackH) / 2
                    : scope.offset
                return Math.max(52, Math.min(win.height - 12 - win.stackH, want))
            }
            property string peekId: ""
            property bool stripHover: false
            property int dropIndex: -1

            screen: scope.screen
            visible: ServiceNotes.loaded && !scope.hidden && (win.mine.length > 0 || win.side === ServiceNotes.defaultSide)
            anchors {
                top: true
                bottom: true
                left: !win.onRight
                right: win.onRight
            }
            implicitWidth: scope.cardWidth + 80
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell:notes"
            WlrLayershell.keyboardFocus: win.openNote ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            mask: Region {
                Region { item: chipBox }
                Region { item: peekCard.visible ? peekCard : nothingBox }
                Region { item: full.visible ? full : nothingBox }
            }

            Item { id: nothingBox; width: 0; height: 0 }

            function edgeX(w) {
                return win.onRight ? win.width - w : 0
            }
            function inwardX(w) {
                return win.onRight ? win.width - win.edgeW - 12 - w : win.edgeW + 12
            }
            function clampY(y, h) {
                return Math.max(52, Math.min(win.height - h - 12, y))
            }
            function centerY(n) {
                if (!n)
                    return 0
                if (!scope.stacked)
                    return n.y * win.height
                const i = win.ordered.findIndex(o => o.id === n.id)
                return win.stackTop + Math.max(0, i) * (win.chipH + scope.gap) + win.chipH / 2
            }

            Item {
                id: chipBox
                readonly property var ys: win.ordered.map(n => win.centerY(n))
                readonly property real topY: win.ordered.length ? Math.min(...chipBox.ys) - 34 : win.height * 0.22 - 14
                readonly property real bottomY: win.ordered.length ? Math.max(...chipBox.ys) + 60 : win.height * 0.22 + 34
                x: win.edgeX(win.edgeW + 10)
                y: chipBox.topY
                width: win.edgeW + 10
                height: chipBox.bottomY - chipBox.topY

                HoverHandler { onHoveredChanged: win.stripHover = hovered }
            }

            Repeater {
                model: win.ordered

                Item {
                    id: chip
                    required property var modelData
                    readonly property bool open: ServiceNotes.openId === chip.modelData.id
                    readonly property bool hot: chipArea.containsMouse || chip.open || chipArea.dragging
                    readonly property int done: chip.modelData.todo.filter(t => t[1]).length
                    property real dragY: -1

                    width: chip.hot ? 16 : 10
                    height: win.chipH
                    x: win.edgeX(width)
                    y: (chip.dragY >= 0 ? chip.dragY : win.centerY(chip.modelData)) - height / 2
                    z: chipArea.dragging ? 2 : 1
                    Behavior on width { SpatialAnim { speed: "fast" } }
                    Behavior on y { enabled: !chipArea.dragging; SpatialAnim {} }

                    Rectangle {
                        anchors.fill: parent
                        color: ServiceNotes.colors[chip.modelData.c] ?? ServiceNotes.colors.butter
                        topLeftRadius: win.onRight ? 8 : 0
                        bottomLeftRadius: win.onRight ? 8 : 0
                        topRightRadius: win.onRight ? 0 : 8
                        bottomRightRadius: win.onRight ? 0 : 8
                        antialiasing: true
                        layer.enabled: chip.hot
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.rgba(0, 0, 0, 0.35)
                            shadowBlur: 0.6
                            shadowHorizontalOffset: win.onRight ? -2 : 2
                            autoPaddingEnabled: true
                        }
                    }

                    Rectangle {
                        width: 2
                        height: parent.height - 16
                        radius: 1
                        x: win.onRight ? 3 : parent.width - 5
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.alpha(scope.ink, 0.18)
                        visible: chip.hot
                    }

                    Rectangle {
                        width: 4
                        height: 4
                        radius: 2
                        x: win.onRight ? 3 : parent.width - 7
                        y: parent.height - 9
                        visible: !chip.hot && chip.modelData.todo.length > 0
                        color: Qt.alpha(scope.ink, chip.done === chip.modelData.todo.length ? 0.25 : 0.6)
                    }

                    MouseArea {
                        id: chipArea
                        property real pressX: 0
                        property real pressY: 0
                        property bool dragging: false
                        anchors.fill: parent
                        anchors.leftMargin: win.onRight ? -10 : 0
                        anchors.rightMargin: win.onRight ? 0 : -10
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: chipArea.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        onContainsMouseChanged: {
                            if (containsMouse && !chipArea.dragging) {
                                peekDelay.target = chip.modelData.id
                                peekDelay.restart()
                            } else if (win.peekId === chip.modelData.id) {
                                peekDelay.stop()
                                win.peekId = ""
                            }
                        }
                        onPressed: mouse => {
                            chipArea.pressX = mouse.x
                            chipArea.pressY = mouse.y
                            chipArea.dragging = false
                        }
                        onPositionChanged: mouse => {
                            if (!pressed)
                                return
                            if (!chipArea.dragging && Math.hypot(mouse.x - chipArea.pressX, mouse.y - chipArea.pressY) > 6) {
                                chipArea.dragging = true
                                win.peekId = ""
                            }
                            if (chipArea.dragging) {
                                const p = mapToItem(win.contentItem, mouse.x, mouse.y)
                                chip.dragY = Math.max(win.height * 0.06, Math.min(win.height * 0.95, p.y))
                            }
                        }
                        onReleased: mouse => {
                            if (chipArea.dragging) {
                                const p = mapToItem(win.contentItem, mouse.x, mouse.y)
                                const winLeft = win.onRight ? (win.screen?.width ?? 1920) - win.width : 0
                                const gx = winLeft + p.x
                                const half = (win.screen?.width ?? 1920) / 2
                                const side = gx < half ? "L" : "R"
                                if (scope.stacked) {
                                    const row = win.ordered.filter(o => o.id !== chip.modelData.id)
                                    let before = row.length
                                    for (let i = 0; i < row.length; i++)
                                        if (chip.dragY < win.centerY(row[i])) { before = i; break }
                                    const lo = before > 0 ? row[before - 1].y : 0
                                    const hi = before < row.length ? row[before].y : 1
                                    ServiceNotes.place(chip.modelData.id, side, (lo + hi) / 2)
                                } else {
                                    ServiceNotes.update(chip.modelData.id, { y: chip.dragY / win.height, side: side })
                                }
                                chip.dragY = -1
                                chipArea.dragging = false
                                return
                            }
                            peekDelay.stop()
                            win.peekId = ""
                            ServiceNotes.openId = chip.open ? "" : chip.modelData.id
                        }
                    }
                }
            }

            Rectangle {
                width: 24
                height: 24
                radius: 12
                x: win.onRight ? win.width - 28 : 4
                y: chipBox.bottomY - 28
                visible: win.stripHover || addArea.containsMouse
                color: addArea.containsMouse ? Colors.primary : Colors.surfaceContainerHigh
                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: "add"
                    iconSize: 16
                    customColor: addArea.containsMouse ? Colors.primaryText : Colors.surfaceVariantText
                }
                MouseArea {
                    id: addArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ServiceNotes.openId = ServiceNotes.add(win.side)
                }
            }

            Timer {
                id: peekDelay
                property string target: ""
                interval: 160
                onTriggered: if (ServiceNotes.openId !== peekDelay.target) win.peekId = peekDelay.target
            }

            Item {
                id: peekCard
                readonly property var note: ServiceNotes.find(win.peekId)
                readonly property int done: peekCard.note ? peekCard.note.todo.filter(t => t[1]).length : 0
                readonly property color paper: peekCard.note ? (ServiceNotes.colors[peekCard.note.c] ?? ServiceNotes.colors.butter) : "transparent"
                visible: !!peekCard.note
                width: 250
                height: peekCol.implicitHeight + 30
                x: win.inwardX(width)
                y: peekCard.note ? win.clampY(win.centerY(peekCard.note) - 28, height) : 0

                NotePaper {
                    anchors.fill: parent
                    paper: peekCard.paper
                    fold: 16
                }

                ColumnLayout {
                    id: peekCol
                    x: 16
                    y: 14
                    width: parent.width - 32
                    spacing: 5

                    Text {
                        Layout.fillWidth: true
                        text: peekCard.note?.title ?? ""
                        font.family: scope.display
                        font.pixelSize: 16
                        color: scope.ink
                        wrapMode: Text.Wrap
                        renderType: Text.QtRendering
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: peekCard.note?.body ?? ""
                        font.family: "Rubik"
                        font.pixelSize: 12
                        color: Qt.alpha(scope.ink, 0.85)
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        lineHeight: 1.15
                    }
                    Repeater {
                        model: peekCard.note ? peekCard.note.todo.slice(0, 3) : []
                        RowLayout {
                            id: pt
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 7
                            Rectangle {
                                Layout.preferredWidth: 12
                                Layout.preferredHeight: 12
                                radius: 6
                                color: pt.modelData[1] ? Qt.alpha(scope.ink, 0.7) : "transparent"
                                border.width: 1.5
                                border.color: Qt.alpha(scope.ink, 0.55)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: pt.modelData[0]
                                font.family: "Rubik"
                                font.pixelSize: 12
                                font.strikeout: pt.modelData[1]
                                color: Qt.alpha(scope.ink, pt.modelData[1] ? 0.5 : 0.85)
                                elide: Text.ElideRight
                            }
                        }
                    }
                    Text {
                        Layout.topMargin: 2
                        text: peekCard.note ? ServiceNotes.ago(peekCard.note.at)
                              + (peekCard.note.todo.length ? " · " + peekCard.done + "/" + peekCard.note.todo.length + " done" : "") : ""
                        font.family: "Rubik"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Qt.alpha(scope.ink, 0.6)
                    }
                }
            }

            NoteCard {
                id: full
                note: win.openNote
                visible: !!win.openNote
                width: scope.cardWidth
                x: win.inwardX(width)
                y: win.openNote ? win.clampY(win.centerY(win.openNote) - 44, height) : 0
                maxHeight: win.height - 80
            }
        }
    }
}
