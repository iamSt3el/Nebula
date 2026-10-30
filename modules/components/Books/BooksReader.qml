import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: reader

    signal leave

    readonly property var book: ServiceBooks.book
    readonly property var cfg: ServiceBooks.cfg
    readonly property int count: reader.book ? reader.book.chapters.length : 0

    readonly property var pageColors: ({
        warm: {
            light: { paper: "#f4ead8", ink: "#2e2620", muted: "#8a7b6c", ground: "#171310" },
            dark:  { paper: "#1f1a16", ink: "#d9cdbd", muted: "#8f8273", ground: "#0b0908" }
        },
        sepia: {
            light: { paper: "#e7d3b0", ink: "#3b2a1a", muted: "#7d6748", ground: "#16110b" },
            dark:  { paper: "#211a12", ink: "#dcc7a4", muted: "#8c7859", ground: "#0c0906" }
        },
        eink: {
            light: { paper: "#e4e4df", ink: "#222222", muted: "#6c6c67", ground: "#141414" },
            dark:  { paper: "#1b1b1b", ink: "#d4d4d0", muted: "#7c7c78", ground: "#090909" }
        }
    })
    readonly property string paperTone: reader.cfg.page === "night" || !reader.pageColors[reader.cfg.page] ? "warm" : reader.cfg.page
    readonly property string darkPref: reader.cfg.page === "night" ? "on" : (reader.cfg.dark ?? "off")
    readonly property bool darkPages: reader.darkPref === "on"
        || (reader.darkPref === "auto" && (SettingsConfig.theme?.matugenTheme ?? "dark") === "dark")
    readonly property var pc: reader.pageColors[reader.paperTone][reader.darkPages ? "dark" : "light"]
    readonly property string fontFamily: reader.cfg.font ?? "Literata"
    readonly property int fontSize: reader.cfg.size ?? 17
    readonly property real lineFactor: reader.cfg.spacing === "tight" ? 1.0 : reader.cfg.spacing === "loose" ? 1.28 : 1.12
    readonly property bool justify: reader.cfg.justify ?? true

    property bool settingsOpen: false
    property bool contentsOpen: false
    property bool stirred: false
    readonly property bool chromeWanted: reader.stirred || reader.settingsOpen || reader.contentsOpen
        || topHover.hovered || scrubHover.hovered || prevHover.hovered || nextHover.hovered
    property real chromeT: reader.chromeWanted ? 1 : 0
    Behavior on chromeT { EffectsAnim { speed: reader.chromeWanted ? "fast" : "default" } }

    function stir() {
        reader.stirred = true
        idle.restart()
    }

    function calm() {
        idle.stop()
        reader.stirred = false
    }

    Timer {
        id: idle
        interval: 2500
        onTriggered: reader.stirred = false
    }

    property point lastPointer: Qt.point(-1, -1)

    HoverHandler {
        id: pointer
        onPointChanged: {
            const p = pointer.point.scenePosition
            const moved = Math.abs(p.x - reader.lastPointer.x) + Math.abs(p.y - reader.lastPointer.y) > 3
            reader.lastPointer = p
            if (moved)
                reader.stir()
        }
    }

    readonly property real drawerW: 372
    readonly property real stageW: reader.width - (reader.settingsOpen ? reader.drawerW : 0)
    readonly property real availW: reader.stageW - 200
    readonly property real availH: reader.height - 72 - 104
    readonly property bool spread: (reader.cfg.layout ?? "spread") !== "single" && reader.availW / 2 >= 300
    readonly property int step: reader.spread ? 2 : 1
    readonly property real pageH: Math.round(Math.max(360, Math.min(reader.availH, (reader.spread ? reader.availW / 2 : reader.availW) / 0.68)))
    readonly property real pageW: Math.round(Math.min(reader.pageH * 0.68, reader.spread ? reader.availW / 2 : reader.availW))
    readonly property real padX: Math.round(reader.pageW * 0.105)
    readonly property real padTop: 56
    readonly property real padBottom: 50
    readonly property real textW: reader.pageW - reader.padX * 2
    readonly property real textH: reader.pageH - reader.padTop - reader.padBottom
    readonly property real titleBand: Math.round(reader.fontSize * 4.6)
    readonly property real gapX: 64
    readonly property real bookX: Math.round((reader.stageW - reader.pageW * reader.step) / 2)
    readonly property real bookY: Math.round(72 + (reader.availH - reader.pageH) / 2)

    property int ci: 0
    property int pi: 0
    property real posFrac: 0
    property real angle: 0
    property int flipDir: 0
    property var flipTo: null

    readonly property var cum: {
        const out = [0]
        if (reader.book)
            for (const c of reader.book.chapters)
                out.push(out[out.length - 1] + (c.words ?? 0))
        return out
    }
    readonly property real totalWords: Math.max(1, reader.cum[reader.cum.length - 1] ?? 1)

    function clampChapter(c) {
        return Math.max(0, Math.min(reader.count - 1, c))
    }

    function align(p) {
        return reader.spread ? p - (p % 2) : p
    }

    function start() {
        if (!reader.book)
            return
        const e = ServiceBooks.entry(reader.book.key)
        reader.flipDir = 0
        reader.flipTo = null
        reader.angle = 0
        reader.contentsOpen = false
        reader.posFrac = e ? (e.frac ?? 0) : 0
        reader.pi = 0
        reader.ci = reader.clampChapter(e ? (e.chapter ?? 0) : (reader.book.start ?? 0))
        reader.forceActiveFocus()
        reader.stir()
    }

    Connections {
        target: ServiceBooks
        function onBookReady() { reader.start() }
    }

    function esc(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    function markup(c) {
        if (!reader.book || c < 0 || c >= reader.count)
            return ""
        const out = []
        let first = true
        for (const p of reader.book.chapters[c].paras) {
            if (p.h) {
                out.push((out.length ? "<br>" : "") + "<b>" + p.t + "</b>")
                first = true
                continue
            }
            out.push(first ? p.t : "&nbsp;&nbsp;&nbsp;&nbsp;" + p.t)
            first = false
        }
        return out.join("<br>")
    }

    function slotChapter(k) {
        for (let c = reader.ci - 1; c <= reader.ci + 1; c++)
            if (c >= 0 && c < reader.count && ((c % 3) + 3) % 3 === k)
                return c
        return -1
    }

    property int flowEpoch: 0

    function flowFor(c) {
        reader.flowEpoch
        flowRep.count
        if (c < 0)
            return null
        const f = flowRep.itemAt(((c % 3) + 3) % 3)
        return f && f.chapter === c ? f : null
    }

    function pagesOf(c) {
        const f = reader.flowFor(c)
        return f ? f.pages : 0
    }

    function relaid(c) {
        if (c !== reader.ci || reader.flipDir !== 0)
            return
        const n = reader.pagesOf(c)
        if (n <= 0)
            return
        reader.pi = reader.align(Math.max(0, Math.min(n - 1, Math.floor(reader.posFrac * n + 1e-6))))
    }

    onSpreadChanged: Qt.callLater(() => reader.relaid(reader.ci))

    function target(dir) {
        const n = reader.pagesOf(reader.ci)
        if (n <= 0)
            return null
        if (dir > 0) {
            if (reader.pi + reader.step < n)
                return { c: reader.ci, p: reader.pi + reader.step }
            if (reader.ci + 1 < reader.count && reader.pagesOf(reader.ci + 1) > 0)
                return { c: reader.ci + 1, p: 0 }
            return null
        }
        if (reader.pi - reader.step >= 0)
            return { c: reader.ci, p: reader.pi - reader.step }
        if (reader.ci > 0) {
            const m = reader.pagesOf(reader.ci - 1)
            if (m > 0)
                return { c: reader.ci - 1, p: reader.align(m - 1) }
        }
        return null
    }

    function turn(dir) {
        if (reader.flipDir !== 0) {
            flipAnim.stop()
            reader.commit()
        }
        const t = reader.target(dir)
        if (!t)
            return
        reader.flipTo = t
        reader.flipDir = dir
        flipAnim.from = dir > 0 ? 0 : 180
        flipAnim.to = dir > 0 ? 180 : 0
        reader.angle = flipAnim.from
        flipAnim.restart()
    }

    function commit() {
        if (reader.flipDir === 0 || !reader.flipTo)
            return
        const t = reader.flipTo
        reader.flipDir = 0
        reader.flipTo = null
        reader.angle = 0
        reader.ci = t.c
        reader.pi = t.p
        reader.noteProgress()
    }

    function jump(c, frac) {
        flipAnim.stop()
        reader.flipDir = 0
        reader.flipTo = null
        reader.angle = 0
        reader.posFrac = frac ?? 0
        reader.pi = 0
        reader.ci = reader.clampChapter(c)
        Qt.callLater(() => reader.relaid(reader.ci))
        reader.noteProgress()
    }

    function noteProgress() {
        const n = reader.pagesOf(reader.ci)
        reader.posFrac = n > 0 ? reader.pi / n : reader.posFrac
        const seen = n > 0 ? Math.min(1, (reader.pi + reader.step) / n) : 0
        const w = reader.book ? (reader.book.chapters[reader.ci]?.words ?? 0) : 0
        const done = (reader.cum[reader.ci] + seen * w) / reader.totalWords
        ServiceBooks.saveProgress(reader.ci, reader.posFrac, reader.ci === reader.count - 1 && seen >= 1 ? 1 : done)
    }

    readonly property real wordsPerPage: {
        const n = reader.pagesOf(reader.ci)
        const w = reader.book ? (reader.book.chapters[reader.ci]?.words ?? 0) : 0
        return n > 0 && w > 0 ? w / n : 280
    }
    readonly property int pageNo: Math.round(reader.cum[reader.ci] / reader.wordsPerPage) + reader.pi + 1
    readonly property int pageTotal: Math.max(reader.pageNo, Math.round(reader.totalWords / reader.wordsPerPage))
    readonly property int minutesLeft: {
        const n = reader.pagesOf(reader.ci)
        const w = reader.book ? (reader.book.chapters[reader.ci]?.words ?? 0) : 0
        const left = n > 0 ? w * Math.max(0, 1 - (reader.pi + reader.step) / n) : w
        return Math.max(0, Math.round(left / 240))
    }

    NumberAnimation {
        id: flipAnim
        target: reader
        property: "angle"
        duration: 900
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.35, 0.08, 0.2, 1.0, 1, 1]
        onFinished: reader.commit()
    }

    function leafMatrix(a, h) {
        const s = Math.sin(a)
        const c = Math.cos(a)
        const d = 5600
        return Qt.matrix4x4(c, 0, 0, 0,
                            -(h / 2) * s / d, 1, 0, 0,
                            0, 0, 1, 0,
                            -s / d, 0, 0, 1)
    }

    focus: true
    Keys.onPressed: event => {
        const k = event.key
        if (k === Qt.Key_Right || k === Qt.Key_PageDown || k === Qt.Key_Space || k === Qt.Key_Down) {
            reader.calm()
            reader.turn(1)
        } else if (k === Qt.Key_Left || k === Qt.Key_PageUp || k === Qt.Key_Backspace || k === Qt.Key_Up) {
            reader.calm()
            reader.turn(-1)
        } else if (k === Qt.Key_T) {
            reader.contentsOpen = !reader.contentsOpen
        } else if (k === Qt.Key_Escape) {
            if (reader.contentsOpen)
                reader.contentsOpen = false
            else if (reader.settingsOpen)
                reader.settingsOpen = false
            else
                reader.leave()
        } else {
            return
        }
        event.accepted = true
    }

    Rectangle {
        anchors.fill: parent
        color: reader.pc.ground
        Behavior on color { EffectsColorAnim {} }
    }

    Item {
        id: flowHost
        x: -100000
        y: 0

        Repeater {
            id: flowRep
            model: 3

            delegate: Text {
                id: flow
                required property int index
                readonly property int chapter: reader.slotChapter(flow.index)
                property int pages: 0
                property real carry: 0
                property int maxPage: 0

                onChapterChanged: {
                    flow.pages = 0
                    reader.flowEpoch++
                }
                onPagesChanged: {
                    reader.flowEpoch++
                    reader.relaid(flow.chapter)
                }

                width: reader.textW
                text: reader.markup(flow.chapter)
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                font.family: reader.fontFamily
                font.pixelSize: reader.fontSize
                lineHeightMode: Text.ProportionalHeight
                lineHeight: reader.lineFactor
                horizontalAlignment: reader.justify ? Text.AlignJustify : Text.AlignLeft
                color: reader.pc.ink
                renderType: Text.QtRendering

                onLineLaidOut: line => {
                    if (line.number === 0) {
                        flow.carry = reader.titleBand
                        flow.maxPage = 0
                    }
                    const h = reader.textH
                    let y = line.y + flow.carry
                    let p = Math.floor(y / h)
                    if (y + line.height > (p + 1) * h + 0.5) {
                        const top = (p + 1) * h
                        flow.carry += top - y
                        y = top
                        p += 1
                    }
                    line.x = p * (reader.textW + reader.gapX)
                    line.y = y - p * h
                    if (p > flow.maxPage)
                        flow.maxPage = p
                    if (line.isLast) {
                        const n = flow.maxPage + 1
                        Qt.callLater(() => flow.pages = flow.chapter < 0 ? 0 : n)
                    }
                }
            }
        }
    }

    readonly property bool fwd: reader.flipDir === 1
    readonly property bool back: reader.flipDir === -1
    readonly property int tc: reader.flipTo ? reader.flipTo.c : reader.ci
    readonly property int tp: reader.flipTo ? reader.flipTo.p : reader.pi
    readonly property real sinA: Math.sin(reader.angle * Math.PI / 180)

    Item {
        id: book
        x: reader.bookX
        y: reader.bookY
        width: reader.pageW * reader.step
        height: reader.pageH

        Rectangle {
            x: 6
            y: reader.pageH
            width: parent.width - 12
            height: 9
            radius: 4
            color: reader.darkPages ? Qt.lighter(reader.pc.paper, 1.45) : Qt.darker(reader.pc.paper, 1.14)
            Rectangle {
                width: parent.width
                height: 2
                y: 3
                color: reader.darkPages ? Qt.lighter(reader.pc.paper, 1.9) : Qt.darker(reader.pc.paper, 1.28)
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: 8
            color: "transparent"
            border.width: 0
            layer.enabled: false
        }

        BookPage {
            id: leftPage
            visible: reader.spread
            host: reader
            side: "left"
            chapter: reader.back ? reader.tc : reader.ci
            page: reader.back ? reader.tp : reader.pi
            shade: reader.fwd && reader.angle > 90 ? reader.sinA * 0.28 : reader.back && reader.angle > 90 ? reader.sinA * 0.28 : 0
        }

        BookPage {
            id: rightPage
            x: reader.spread ? reader.pageW : 0
            host: reader
            side: reader.spread ? "right" : "single"
            chapter: reader.spread ? (reader.fwd ? reader.tc : reader.ci) : (reader.fwd ? reader.tc : reader.ci)
            page: reader.spread ? (reader.fwd ? reader.tp + 1 : reader.pi + 1) : (reader.fwd ? reader.tp : reader.pi)
            shade: reader.flipDir !== 0 && reader.angle <= 90 ? reader.sinA * 0.3 : 0
        }

        Item {
            id: leaf
            visible: reader.flipDir !== 0
            x: reader.spread ? reader.pageW : 0
            width: reader.pageW
            height: reader.pageH
            opacity: reader.spread ? 1 : Math.max(0, Math.min(1, (180 - reader.angle) / 50))
            transform: Matrix4x4 { matrix: reader.leafMatrix(reader.angle * Math.PI / 180, leaf.height) }

            BookPage {
                visible: reader.angle <= 90
                host: reader
                side: reader.spread ? "right" : "single"
                chapter: reader.fwd ? reader.ci : reader.tc
                page: reader.spread ? (reader.fwd ? reader.pi + 1 : reader.tp + 1) : (reader.fwd ? reader.pi : reader.tp)
                shade: reader.sinA * 0.22
                bend: true
            }

            BookPage {
                visible: reader.angle > 90
                host: reader
                side: "left"
                blank: !reader.spread
                chapter: reader.fwd ? reader.tc : reader.ci
                page: reader.fwd ? reader.tp : reader.pi
                shade: reader.sinA * 0.22
                bend: true
                transform: Scale { origin.x: reader.pageW / 2; xScale: -1 }
            }
        }
    }

    MouseArea {
        x: book.x
        y: book.y
        width: book.width
        height: book.height
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => reader.turn(mouse.x < width / 2 ? -1 : 1)
        onWheel: wheel => {
            if (Math.abs(wheel.angleDelta.y) < 30)
                return
            reader.turn(wheel.angleDelta.y < 0 ? 1 : -1)
        }
    }

    M3IconButton {
        x: book.x - width - 28
        y: book.y + book.height / 2 - height / 2
        opacity: reader.chromeT
        visible: opacity > 0.01
        icon: "chevron_left"
        tip: "Previous page · ←"
        onClicked: reader.turn(-1)
        HoverHandler { id: prevHover }
    }

    M3IconButton {
        x: book.x + book.width + 28
        y: book.y + book.height / 2 - height / 2
        opacity: reader.chromeT
        visible: opacity > 0.01
        icon: "chevron_right"
        tip: "Next page · →"
        onClicked: reader.turn(1)
        HoverHandler { id: nextHover }
    }

    RowLayout {
        x: 20
        y: -10 * (1 - reader.chromeT)
        width: reader.stageW - 40
        height: 72
        spacing: 6
        opacity: reader.chromeT
        visible: opacity > 0.01

        HoverHandler { id: topHover }

        M3IconButton {
            icon: "arrow_back"
            tip: "Back to the library · Esc"
            onClicked: reader.leave()
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 100
            Layout.minimumWidth: 0
            Layout.leftMargin: 4
            spacing: 2

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: reader.book ? reader.book.title : ""
                elide: Text.ElideRight
                font.family: "Literata"
                font.weight: Font.DemiBold
                font.pixelSize: 17
                color: Colors.surfaceText
            }
            CustomText {
                Layout.fillWidth: true
                content: !reader.book ? "" : (reader.book.chapters[reader.ci]?.title ?? "")
                    + (reader.minutesLeft > 0 ? " · " + reader.minutesLeft + " min left in chapter" : " · last page of the chapter")
                elide: Text.ElideRight
                size: 12
                customColor: Colors.surfaceVariantText
            }
        }

        M3IconButton {
            icon: "toc"
            tip: "Contents · T"
            onClicked: reader.contentsOpen = !reader.contentsOpen
        }
        M3IconButton {
            icon: "text_fields"
            tip: "Reading settings"
            onClicked: reader.settingsOpen = !reader.settingsOpen
        }
    }

    Item {
        id: scrub
        x: book.x
        y: book.y + book.height + 38 + 8 * (1 - reader.chromeT)
        width: book.width
        height: 36
        opacity: reader.chromeT
        visible: opacity > 0.01

        HoverHandler { id: scrubHover }

        Rectangle {
            id: track
            y: 8
            width: parent.width
            height: 6
            radius: 3
            color: Colors.surfaceContainerHighest

            Rectangle {
                width: Math.max(6, parent.width * Math.min(1, (reader.pageNo + reader.step - 1) / Math.max(1, reader.pageTotal)))
                height: parent.height
                radius: 3
                color: Colors.primary
                Behavior on width { SpatialAnim { speed: "move" } }
            }

            Repeater {
                model: reader.count > 1 && reader.count <= 90 ? reader.count - 1 : 0
                Rectangle {
                    required property int index
                    x: Math.round(track.width * reader.cum[index + 1] / reader.totalWords)
                    y: -2
                    width: 2
                    height: 10
                    radius: 1
                    color: Qt.alpha(Colors.outline, 0.7)
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                const w = Math.max(0, Math.min(1, mouse.x / width)) * reader.totalWords
                let c = 0
                while (c + 1 < reader.count && reader.cum[c + 1] <= w)
                    c++
                const cw = Math.max(1, reader.cum[c + 1] - reader.cum[c])
                reader.jump(c, Math.max(0, Math.min(0.999, (w - reader.cum[c]) / cw)))
            }
        }

        CustomText {
            y: 22
            content: reader.spread ? "Pages " + reader.pageNo + "–" + (reader.pageNo + 1) + " of about " + reader.pageTotal
                : "Page " + reader.pageNo + " of about " + reader.pageTotal
            size: 12
            customColor: Colors.surfaceVariantText
        }
        CustomText {
            y: 22
            anchors.right: parent.right
            content: Math.round(100 * (reader.cum[reader.ci] + reader.posFrac * ((reader.cum[reader.ci + 1] ?? 0) - reader.cum[reader.ci])) / reader.totalWords) + "% read"
            size: 12
            customColor: Colors.surfaceVariantText
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: reader.contentsOpen
        color: Qt.alpha(Colors.scrim, 0.35)
        MouseArea {
            anchors.fill: parent
            onClicked: reader.contentsOpen = false
        }
    }

    Rectangle {
        id: contents
        width: 340
        height: parent.height
        x: reader.contentsOpen ? 0 : -width - 20
        Behavior on x { SpatialAnim { speed: "move" } }
        visible: x > -width - 10
        color: Colors.surfaceContainer
        topRightRadius: 28
        bottomRightRadius: 28

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                BookCover {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 78
                    source: ServiceBooks.entry(reader.book ? reader.book.key : "")?.cover ?? ""
                    title: reader.book ? reader.book.title : ""
                    author: reader.book ? reader.book.author : ""
                    radius: 6
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: reader.book ? reader.book.title : ""
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.family: "Literata"
                        font.weight: Font.DemiBold
                        font.pixelSize: 17
                        color: Colors.surfaceText
                    }
                    CustomText {
                        Layout.fillWidth: true
                        content: (reader.book ? reader.book.author : "") + " · " + reader.count + " chapters"
                        elide: Text.ElideRight
                        size: 12
                        customColor: Colors.surfaceVariantText
                    }
                }
            }

            ListView {
                id: tocList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: reader.count
                currentIndex: reader.ci
                onVisibleChanged: if (visible) tocList.positionViewAtIndex(reader.ci, ListView.Center)

                delegate: Rectangle {
                    id: tocRow
                    required property int index
                    readonly property bool here: tocRow.index === reader.ci
                    width: tocList.width
                    height: 42
                    radius: 14
                    color: tocRow.here ? Colors.primaryContainer
                        : tocArea.containsMouse ? Colors.surfaceContainerHighest : "transparent"
                    Behavior on color { EffectsColorAnim { speed: "fast" } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        MaterialIconSymbol {
                            content: tocRow.here ? "play_arrow" : tocRow.index < reader.ci ? "check" : ""
                            iconSize: 16
                            Layout.preferredWidth: 16
                            customColor: tocRow.here ? Colors.primaryContainerText : Colors.outline
                        }
                        CustomText {
                            Layout.fillWidth: true
                            content: reader.book ? reader.book.chapters[tocRow.index].title : ""
                            elide: Text.ElideRight
                            size: 13
                            weight: tocRow.here ? 600 : 400
                            customColor: tocRow.here ? Colors.primaryContainerText
                                : tocRow.index < reader.ci ? Colors.surfaceVariantText : Colors.surfaceText
                        }
                        CustomText {
                            content: reader.book ? Math.max(1, Math.round((reader.book.chapters[tocRow.index].words ?? 0) / 240)) + " min" : ""
                            size: 11
                            customColor: tocRow.here ? Colors.primaryContainerText : Colors.outline
                        }
                    }

                    MouseArea {
                        id: tocArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            reader.jump(tocRow.index, 0)
                            reader.contentsOpen = false
                        }
                    }
                }
            }
        }
    }

    BooksReaderSettings {
        id: settingsPanel
        host: reader
        width: reader.drawerW
        height: parent.height
        x: reader.settingsOpen ? reader.width - width : reader.width + 20
        Behavior on x { SpatialAnim { speed: "move" } }
        visible: x < reader.width
        onCloseRequested: reader.settingsOpen = false
    }
}
