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
            property string hoverId: ""
            property string peekShownId: ""
            property string fullShownId: ""
            property bool busy: false
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
                            const id = chip.modelData.id
                            if (containsMouse && !chipArea.dragging) {
                                win.hoverId = id
                                peekHide.stop()
                                if (win.peekId !== "" || win.peekShownId !== "") {
                                    peekDelay.stop()
                                    win.peekId = ServiceNotes.openId !== id ? id : ""
                                    return
                                }
                                peekDelay.target = id
                                peekDelay.restart()
                                return
                            }
                            if (win.hoverId === id)
                                win.hoverId = ""
                            if (peekDelay.target === id)
                                peekDelay.stop()
                            if (win.peekId === id)
                                peekHide.restart()
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
                            peekHide.stop()
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
                onTriggered: {
                    if (win.hoverId === peekDelay.target && ServiceNotes.openId !== peekDelay.target)
                        win.peekId = peekDelay.target
                }
            }

            Timer {
                id: peekHide
                interval: 140
                onTriggered: if (win.hoverId === "") win.peekId = ""
            }

            onPeekIdChanged: Qt.callLater(win.sync)
            onOpenNoteChanged: Qt.callLater(win.sync)

            function sync() {
                if (win.busy)
                    return
                if (win.peekId !== "" && !ServiceNotes.find(win.peekId))
                    win.peekId = ""
                if (win.hoverId !== "" && !ServiceNotes.find(win.hoverId))
                    win.hoverId = ""
                if (win.fullShownId !== "" && !ServiceNotes.find(win.fullShownId)) {
                    full.opacity = 0
                    win.fullShownId = ""
                }
                if (win.peekShownId !== "" && !ServiceNotes.find(win.peekShownId)) {
                    peekCard.opacity = 0
                    win.peekShownId = ""
                }
                const fullWant = win.openNote ? win.openNote.id : ""
                if (win.fullShownId !== fullWant) {
                    if (win.fullShownId !== "" && fullWant !== "") {
                        win.switchFull(fullWant)
                        return
                    }
                    if (win.fullShownId !== "") {
                        win.bulgeClose(true)
                        return
                    }
                    if (win.peekShownId !== "") {
                        win.morphToFull(fullWant)
                        return
                    }
                    win.fullShownId = fullWant
                    win.bulgeOpen(fullWant, true)
                    return
                }
                const peekWant = win.fullShownId === "" && !!ServiceNotes.find(win.peekId) ? win.peekId : ""
                if (win.peekShownId === peekWant)
                    return
                if (win.peekShownId !== "" && peekWant !== "") {
                    win.switchPeek(peekWant)
                    return
                }
                if (win.peekShownId !== "") {
                    win.bulgeClose(false)
                    return
                }
                win.peekShownId = peekWant
                win.bulgeOpen(peekWant, false)
            }

            property bool glide: false

            function switchPeek(id) {
                win.busy = true
                peekSwap.next = id
                peekSwap.restart()
            }

            function switchFull(id) {
                win.busy = true
                fullSwap.next = id
                fullSwap.restart()
            }

            SequentialAnimation {
                id: peekSwap
                property string next: ""
                NumberAnimation { target: peekCol; property: "opacity"; to: 0; duration: 80 }
                ScriptAction {
                    script: {
                        win.glide = true
                        win.peekShownId = peekSwap.next
                    }
                }
                PauseAnimation { duration: 140 }
                NumberAnimation { target: peekCol; property: "opacity"; to: 1; duration: 150 }
                PauseAnimation { duration: 60 }
                ScriptAction {
                    script: {
                        win.glide = false
                        win.done()
                    }
                }
            }

            SequentialAnimation {
                id: fullSwap
                property string next: ""
                NumberAnimation { target: full; property: "contentOpacity"; to: 0; duration: 90 }
                ScriptAction {
                    script: {
                        win.glide = true
                        win.fullShownId = fullSwap.next
                    }
                }
                PauseAnimation { duration: 170 }
                NumberAnimation { target: full; property: "contentOpacity"; to: 1; duration: 160 }
                PauseAnimation { duration: 60 }
                ScriptAction {
                    script: {
                        win.glide = false
                        win.done()
                    }
                }
            }

            function bulgeOpen(id, isFull) {
                win.busy = true
                const card = isFull ? full : peekCard
                card.opacity = 0
                goo.noteId = id
                goo.target = card
                goo.gp = 0
                goo.opacity = 1
                goo.visible = true
                gooOpen.card = card
                gooOpen.dur = isFull ? 520 : 420
                gooOpen.restart()
            }

            function bulgeClose(isFull) {
                win.busy = true
                const card = isFull ? full : peekCard
                goo.noteId = isFull ? win.fullShownId : win.peekShownId
                goo.target = card
                gooClose.card = card
                gooClose.isFull = isFull
                gooClose.dur = isFull ? 400 : 320
                gooClose.restart()
            }

            function morphToFull(id) {
                win.busy = true
                shell.fromX = peekCard.x
                shell.fromY = peekCard.y
                shell.fromW = peekCard.width
                shell.fromH = peekCard.height
                shell.paper = peekCard.paper
                const target = ServiceNotes.find(id)
                shell.toPaper = target ? (ServiceNotes.colors[target.c] ?? ServiceNotes.colors.butter) : peekCard.paper
                shell.mp = 0
                shell.visible = true
                full.opacity = 0
                win.fullShownId = id
                morph.restart()
            }

            function done() {
                busyGuard.stop()
                win.busy = false
                Qt.callLater(win.sync)
            }

            onBusyChanged: if (win.busy) busyGuard.restart()

            Timer {
                id: busyGuard
                interval: 1600
                onTriggered: {
                    gooOpen.stop()
                    gooClose.stop()
                    morph.stop()
                    goo.visible = false
                    shell.visible = false
                    peekSwap.stop()
                    fullSwap.stop()
                    win.glide = false
                    peekCol.opacity = 1
                    full.contentOpacity = 1
                    peekCard.opacity = win.peekShownId !== "" ? 1 : 0
                    full.opacity = win.fullShownId !== "" ? 1 : 0
                    win.busy = false
                    Qt.callLater(win.sync)
                }
            }

            SequentialAnimation {
                id: gooOpen
                property Item card: null
                property int dur: 420
                NumberAnimation {
                    target: goo
                    property: "gp"
                    from: 0
                    to: 1
                    duration: gooOpen.dur
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.25, 0.9, 0.3, 1, 1, 1]
                }
                NumberAnimation { target: gooOpen.card; property: "opacity"; to: 1; duration: 130 }
                ScriptAction {
                    script: {
                        goo.visible = false
                        win.done()
                    }
                }
            }

            SequentialAnimation {
                id: gooClose
                property Item card: null
                property bool isFull: false
                property int dur: 320
                ScriptAction {
                    script: {
                        goo.gp = 1
                        goo.opacity = 1
                        goo.visible = true
                    }
                }
                NumberAnimation { target: gooClose.card; property: "opacity"; to: 0; duration: 120 }
                NumberAnimation {
                    target: goo
                    property: "gp"
                    from: 1
                    to: 0
                    duration: gooClose.dur
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.6, 0, 0.85, 0.4, 1, 1]
                }
                ScriptAction {
                    script: {
                        goo.visible = false
                        if (gooClose.isFull)
                            win.fullShownId = ""
                        else
                            win.peekShownId = ""
                        win.done()
                    }
                }
            }

            SequentialAnimation {
                id: morph
                ParallelAnimation {
                    NumberAnimation { target: peekCard; property: "opacity"; to: 0; duration: 120 }
                    NumberAnimation {
                        target: shell
                        property: "mp"
                        from: 0
                        to: 1
                        duration: 420
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
                    }
                }
                NumberAnimation { target: full; property: "opacity"; to: 1; duration: 150 }
                ScriptAction {
                    script: {
                        shell.visible = false
                        win.peekShownId = ""
                        win.done()
                    }
                }
            }

            ShaderEffect {
                id: goo
                property string noteId: ""
                property Item target: null
                property real gp: 0
                readonly property var gnote: ServiceNotes.find(goo.noteId)
                readonly property real chipY: goo.gnote ? win.centerY(goo.gnote) - win.chipH / 2 : 0
                readonly property real tx: goo.target ? goo.target.x : 0
                readonly property real ty: goo.target ? goo.target.y : 0
                readonly property real tw: goo.target ? goo.target.width : 0
                readonly property real th: goo.target ? goo.target.height : 0
                readonly property real s1: Math.min(1, goo.gp / 0.45)
                readonly property real s2: Math.max(0, (goo.gp - 0.45) / 0.55)
                readonly property real sx: win.onRight ? win.width - 22 : -4
                readonly property real mw: goo.tw * 0.8
                readonly property real mh: goo.th * 0.76
                readonly property real mx: win.onRight ? goo.tx + 18 : goo.tx + goo.tw - 18 - goo.mw
                readonly property real my: goo.ty + goo.th * 0.12
                readonly property bool early: goo.gp < 0.45
                readonly property real bx: goo.early ? goo.sx + (goo.mx - goo.sx) * goo.s1 : goo.mx + (goo.tx - goo.mx) * goo.s2
                readonly property real by: goo.early ? goo.chipY + 4 + (goo.my - goo.chipY - 4) * goo.s1 : goo.my + (goo.ty - goo.my) * goo.s2
                readonly property real bw: goo.early ? 26 + (goo.mw - 26) * goo.s1 : goo.mw + (goo.tw - goo.mw) * goo.s2
                readonly property real bh: goo.early ? win.chipH - 8 + (goo.mh - win.chipH + 8) * goo.s1 : goo.mh + (goo.th - goo.mh) * goo.s2
                readonly property real nubW: goo.gp < 0.3 ? 16 + 30 * goo.gp / 0.3 : 46 - 30 * (goo.gp - 0.3) / 0.7

                readonly property vector2d itemSize: Qt.vector2d(width, height)
                readonly property vector4d nub: win.onRight ? Qt.vector4d(win.width - goo.nubW, goo.chipY, goo.nubW + 20, win.chipH)
                                                            : Qt.vector4d(-20, goo.chipY, goo.nubW + 20, win.chipH)
                readonly property vector4d blob: Qt.vector4d(goo.bx, goo.by, goo.bw, goo.bh)
                readonly property color color: goo.gnote ? (ServiceNotes.colors[goo.gnote.c] ?? ServiceNotes.colors.butter) : "transparent"
                readonly property real nubR: 8
                readonly property real blobR: goo.early ? 14 + 26 * goo.s1 : 40 - 20 * goo.s2
                readonly property real k: 14

                anchors.fill: parent
                z: 3
                visible: false
                fragmentShader: Qt.resolvedUrl("../../../shaders/qsb/notegoo.frag.qsb")
            }

            Item {
                id: shell
                property real mp: 0
                property real fromX: 0
                property real fromY: 0
                property real fromW: 0
                property real fromH: 0
                property color paper: "transparent"
                property color toPaper: "transparent"
                z: 3
                visible: false
                x: shell.fromX + (full.x - shell.fromX) * shell.mp
                y: shell.fromY + (full.y - shell.fromY) * shell.mp
                width: shell.fromW + (full.width - shell.fromW) * shell.mp
                height: shell.fromH + (full.height - shell.fromH) * shell.mp

                NotePaper {
                    anchors.fill: parent
                    paper: Qt.rgba(shell.paper.r + (shell.toPaper.r - shell.paper.r) * shell.mp,
                                   shell.paper.g + (shell.toPaper.g - shell.paper.g) * shell.mp,
                                   shell.paper.b + (shell.toPaper.b - shell.paper.b) * shell.mp, 1)
                    radius: 16 + 4 * shell.mp
                    fold: 16 + 10 * shell.mp
                }
            }

            Item {
                id: peekCard
                readonly property var note: ServiceNotes.find(win.peekShownId)
                readonly property int done: peekCard.note ? peekCard.note.todo.filter(t => t[1]).length : 0
                readonly property color paper: peekCard.note ? (ServiceNotes.colors[peekCard.note.c] ?? ServiceNotes.colors.butter) : "transparent"
                visible: !!peekCard.note
                opacity: 0
                z: 4
                width: 250
                Behavior on y { enabled: win.glide; SpatialAnim { speed: "fast" } }
                Behavior on height { enabled: win.glide; SpatialAnim { speed: "fast" } }
                height: peekCol.implicitHeight + 30
                x: win.inwardX(width)
                y: peekCard.note ? win.clampY(win.centerY(peekCard.note) - 28, height) : 0

                NotePaper {
                    anchors.fill: parent
                    paper: peekCard.paper
                    fold: 16
                    Behavior on paper { enabled: win.glide; ColorAnimation { duration: 240 } }
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
                note: ServiceNotes.find(win.fullShownId)
                visible: win.fullShownId !== ""
                opacity: 0
                z: 4
                Behavior on y { enabled: win.glide; SpatialAnim { speed: "fast" } }
                Behavior on height { enabled: win.glide; SpatialAnim { speed: "fast" } }
                width: scope.cardWidth
                x: win.inwardX(width)
                y: full.note ? win.clampY(win.centerY(full.note) - 44, height) : 0
                maxHeight: win.height - 80
            }
        }
    }
}
