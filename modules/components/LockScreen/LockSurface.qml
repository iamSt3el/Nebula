pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.modules.settings
import qs.modules.utils
import qs.modules.services
import "LockFlight.js" as Flight

Item {
    id: root

    property LockContext context: null
    property bool exiting: false
    property bool greeter: LockSession.greeter
    property url desk: ""
    property url bar: ""
    property bool primary: true
    property var shellScreen: null
    focus: true

    readonly property var _cfg: (root.greeter ? SettingsConfig.greeter : SettingsConfig.lockscreen) ?? ({})
    readonly property string variantStyle: LockCatalog.normalize(root._cfg.layout)
    readonly property Item layoutItem: layoutLoader.item
    readonly property bool _desk: deskImage.status === Image.Ready
    readonly property var _entry: LockCatalog.entry(root.variantStyle)
    readonly property bool _clearing: !root.greeter && root._desk && root._entry.clear === true
    readonly property bool _bare: root._clearing && root._entry.bareWall === true
    readonly property bool _deskBlur: root._entry.deskBlur !== false && !root._clearing
    readonly property int _deskFade: root._entry.deskFade ?? 460
    readonly property int _deskBack: root.handing ? (root._entry.handBack ?? 40) : (root._entry.deskBack ?? 200)
    readonly property int _clearBack: root._entry.clearBack ?? 480
    readonly property bool _handoffWanted: !root.greeter && !root.clockOn && root._desk && root._entry.handoff === true
    readonly property string _flightStyle: root._entry.flight ?? "glide"
    property bool handing: false
    property var carry: ({})
    property var _bands: []
    property var _wall: null
    property bool _flying: false
    property bool _faces: false
    property real flyPos: 0
    property bool _leaving: false
    property real clear: 0
    property real barOut: 0
    property real _t0: 0
    property int _flyWait: 0
    readonly property var _targets: root.handing && layoutLoader.item ? (layoutLoader.item.handoffTargets ?? null) : null
    readonly property bool _handReady: root._faces && root._targets !== null && patchWall.status === Image.Ready
    on_HandReadyChanged: if (root._handReady) handStart.restart()
    readonly property var _flight: root.handing && root._faces ? Flight.plan(root._flightStyle, root.flyPos, root._leaving, root._src, root._dst) : ({})
    readonly property real handReveal: root._flight.reveal ?? 0
    readonly property bool _hasDate: root._src.date !== undefined
    readonly property real _lift: 1 - root.ramp(0, root._leaving ? 0.25 : 0.12, root.flyPos)
    readonly property real _zoom: {
        const s = root._src.hours
        const d = root._dst.hours
        return s && d ? Math.max(1, Math.min(4, d.height / Math.max(1, s.height))) : 3.5
    }
    readonly property var _copyRoles: root.handing && root._faces && root._targets && root._targets.restyle === true
        ? ["hours", "colon", "minutes", "date"].filter(r => root._targets[r] && (r !== "date" || root._hasDate)) : []

    readonly property string clockFace: {
        const f = root._cfg.clockScreen ?? "display"
        return !root.greeter && (f === "display" || f === "stencil" || f === "matrix") ? f : "off"
    }
    readonly property bool clockOn: root.clockFace !== "off"
    readonly property bool awake: !root.clockOn || (root.context?.clockAwake ?? true)
    property bool layoutHold: false
    property string pendingText: ""
    property point lastPointer: Qt.point(-1, -1)
    property real pointerTravel: 0

    onAwakeChanged: {
        root.pointerTravel = 0
        root.lastPointer = Qt.point(-1, -1)
        if (!root.awake) {
            root.layoutHold = true
            holdTimer.restart()
            root.forceActiveFocus()
        }
    }

    function isPrintable(t) {
        return t.length === 1 && t.charCodeAt(0) >= 32 && t.charCodeAt(0) !== 127
    }

    function wake(text) {
        if (text !== "")
            root.pendingText += text
        if (!root.awake && root.context)
            root.context.wakeClock()
    }

    function flushPending() {
        if (root.pendingText === "" || !root.context)
            return
        root.context.currentText = root.context.currentText + root.pendingText
        root.pendingText = ""
    }

    function pointerMoved(pos) {
        if (root.lastPointer.x >= 0)
            root.pointerTravel += Math.hypot(pos.x - root.lastPointer.x, pos.y - root.lastPointer.y)
        root.lastPointer = pos
        if (!root.awake && root.pointerTravel > 80)
            root.wake("")
        else if (root.awake && root.context)
            root.context.pokeClock()
    }

    property real defocus: 0
    property real shade: 0

    readonly property var _standard: [0.2, 0.0, 0.0, 1.0, 1, 1]

    function focusInput() {
        const lay = layoutLoader.item
        if (lay && lay.fieldGate === true && !lay.fieldOpen) {
            root.forceActiveFocus()
            return
        }
        const f = layoutLoader.authField
        if (f && f.input)
            f.input.forceActiveFocus()
    }

    Keys.onPressed: event => {
        const printable = root.isPrintable(event.text)
        if (!root.awake) {
            root.wake(printable ? event.text : "")
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Escape && root.clockOn && root.context && root.context.currentText === "") {
            root.context.clockAwake = false
            event.accepted = true
            return
        }
        if (root.context)
            root.context.pokeClock()
        const gate = layoutLoader.item
        if (gate && gate.fieldGate === true) {
            if (event.key === Qt.Key_Escape && gate.fieldOpen) {
                gate.foldField()
                event.accepted = true
                return
            }
            if (!gate.fieldOpen)
                gate.wakeField()
        }
        if (printable && root.context) {
            if (layoutLoader.authField)
                root.context.currentText = root.context.currentText + event.text
            else
                root.pendingText += event.text
        }
        root.focusInput()
    }

    HoverHandler {
        onPointChanged: root.pointerMoved(point.position)
    }

    Timer {
        id: holdTimer
        interval: 520
        onTriggered: {
            root.layoutHold = false
            if (!root.awake)
                root.forceActiveFocus()
        }
    }

    function fly() {
        if (root._flying || root.exiting || !root.handing)
            return
        root._flying = true
        handGuard.stop()
        root._flyWait = Math.max(0, (root._entry.flyDelay ?? 0) - (Date.now() - root._t0))
        handEnter.start()
    }

    readonly property int _reachIn: 20

    function reach(band) {
        const r = band.rect
        const m = root._reachIn
        switch (band.side) {
        case "top": return Qt.rect(r.x, r.y, r.width, r.height + m)
        case "bottom": return Qt.rect(r.x, r.y - m, r.width, r.height + m)
        case "left": return Qt.rect(r.x, r.y, r.width + m, r.height)
        default: return Qt.rect(r.x - m, r.y, r.width + m, r.height)
        }
    }

    function ramp(a, b, v) {
        const t = Math.max(0, Math.min(1, (v - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    function sharpen(item, k) {
        if (!item)
            return
        if (item.textureSize !== undefined && item.width > 0 && item.height > 0)
            item.textureSize = Qt.size(Math.ceil(item.width * k), Math.ceil(item.height * k))
        if (item.renderType !== undefined && item.text !== undefined)
            item.renderType = Text.CurveRendering
        for (const c of item.children)
            root.sharpen(c, k)
    }

    function placeOf(rect, local, left) {
        const s = rect.height / Math.max(1, local.height)
        return {
            s: s,
            x: left ? rect.x - local.x * s : rect.x + rect.width / 2 - (local.x + local.width / 2) * s,
            y: rect.y - local.y * s
        }
    }

    readonly property var _src: {
        const out = {}
        for (const p of (handoff.source ? handoff.source.parts : []))
            out[p.role] = p.screen
        return out
    }

    readonly property var _dst: {
        const t = root._targets
        if (!t)
            return {}
        const out = {}
        const offset = (item, q) => {
            const r = root.sceneRect(item)
            return Qt.rect(r.x + q.x, r.y + q.y, q.width, q.height)
        }
        if (t.clock) {
            out.hours = offset(t.clock, t.clock.rowRect(0))
            out.minutes = offset(t.clock, t.clock.rowRect(2))
        }
        for (const role of ["hours", "minutes"])
            if (t[role] && t.ink)
                out[role] = offset(t[role], t.ink.inkOf(t[role]))
        if (t.colon)
            out.colon = root.sceneRect(t.colon)
        if (t.date && root._hasDate)
            out.date = root.sceneRect(t.date)
        return out
    }

    function sceneRect(item) {
        let x = 0
        let y = 0
        for (let it = item; it && it !== root; it = it.parent) {
            x += it.x
            y += it.y
        }
        return Qt.rect(x, y, item.width, item.height)
    }

    LockHandoff {
        id: handoff
        shellScreen: root.shellScreen
    }

    Timer {
        id: handStart
        interval: 60
        onTriggered: root.fly()
    }

    Timer {
        id: handGuard
        interval: 700
        onTriggered: root.fly()
    }

    onExitingChanged: if (root.exiting) {
        enterAnim.stop()
        handEnter.stop()
        handGuard.stop()
        root._leaving = true
        exitAnim.start()
        if (root.handing)
            handExit.start()
    }

    readonly property var _emphasized: [0.05, 0.0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1.0, 1, 1]
    readonly property var _spatial: [0.38, 1.21, 0.22, 1.0, 1, 1]

    SequentialAnimation {
        id: handEnter
        PauseAnimation { duration: root._flyWait }
        NumberAnimation { target: root; property: "flyPos"; to: 1; duration: root._entry.flyIn ?? 940 }
    }
    NumberAnimation { id: handExit; target: root; property: "flyPos"; to: 0; duration: root._entry.flyOut ?? 640 }

    ParallelAnimation {
        id: enterAnim

        NumberAnimation {
            target: root; property: "defocus"; to: root._deskBlur ? 1 : 0
            duration: root._deskFade
            easing.type: Easing.BezierSpline; easing.bezierCurve: root._standard
        }
        SequentialAnimation {
            PauseAnimation { duration: root.handing ? (root._entry.shadeDelay ?? 0) : 0 }
            NumberAnimation {
                target: root; property: "shade"; to: 1
                duration: root._desk ? root._deskFade : 420
                easing.type: Easing.BezierSpline; easing.bezierCurve: root._standard
            }
        }
        NumberAnimation {
            target: root; property: "clear"; to: root._clearing ? 1 : 0
            duration: 380
            easing.type: Easing.BezierSpline; easing.bezierCurve: root._standard
        }
        NumberAnimation {
            target: root; property: "barOut"; to: root._bands.length > 0 ? 1 : 0
            duration: 400
            easing.type: Easing.BezierSpline; easing.bezierCurve: root._emphasized
        }
    }

    ParallelAnimation {
        id: exitAnim

        SequentialAnimation {
            PauseAnimation { duration: root._deskBack }
            ParallelAnimation {
                NumberAnimation {
                    target: root; property: "shade"; to: 0
                    duration: 420
                    easing.type: Easing.BezierSpline; easing.bezierCurve: root._standard
                }
                NumberAnimation {
                    target: root; property: "defocus"; to: 0
                    duration: 420
                    easing.type: Easing.BezierSpline; easing.bezierCurve: root._standard
                }
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: root._clearBack }
            NumberAnimation {
                target: root; property: "clear"; to: 0
                duration: 380
                easing.type: Easing.BezierSpline; easing.bezierCurve: root._standard
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 420 }
            NumberAnimation {
                target: root; property: "barOut"; to: 0
                duration: 500
                easing.type: Easing.BezierSpline; easing.bezierCurve: root._spatial
            }
        }
    }

    component WallCut: Item {
        id: cut
        property rect area
        x: cut.area.x
        y: cut.area.y
        width: cut.area.width
        height: cut.area.height
        clip: true

        Image {
            x: (root._wall ? root._wall.x : 0) - cut.x
            y: -cut.y
            width: root._wall ? root._wall.width : root.width
            height: root.height
            source: handoff.wallUrl
            fillMode: root._wall ? root._wall.fillMode : Image.PreserveAspectCrop
            asynchronous: false
            cache: true
        }
    }

    component DeskCut: Item {
        id: piece
        property rect area
        x: piece.area.x
        y: piece.area.y
        width: piece.area.width
        height: piece.area.height
        clip: true

        Image {
            x: -piece.area.x
            y: -piece.area.y
            width: root.width
            height: root.height
            source: root.desk
            asynchronous: false
            cache: true
            smooth: true
        }
    }

    Item {
        anchors.fill: parent
        visible: root._desk && (root.shade < 1 || root._bare)

        Image {
            id: deskImage
            anchors.fill: parent
            source: root.desk
            asynchronous: false
            cache: false
            smooth: true
            scale: 1 + 0.05 * root.defocus

            layer.enabled: parent.visible && root.defocus > 0.002
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                blur: root.defocus
                blurMax: 64
                brightness: -0.3 * root.defocus
                saturation: -0.3 * root.defocus
            }
        }

        WallCut {
            area: Qt.rect(0, 0, root.width, root.height)
            visible: root._clearing && root.clear > 0
            opacity: root.clear
        }

        WallCut {
            id: wipeWall
            area: Qt.rect(0, 0, root.width, root.height)
            visible: false
            layer.enabled: root._bands.length > 0
        }

        Image {
            id: barImage
            anchors.fill: parent
            source: root._bands.length > 0 ? root.bar : ""
            visible: false
            asynchronous: false
            cache: true
        }

        ShaderEffect {
            anchors.fill: parent
            visible: root._bands.length > 0
            property var source: wipeWall
            property var mask: barImage
            fragmentShader: Qt.resolvedUrl("../../../shaders/qsb/barwipe.frag.qsb")
        }

        Shape {
            id: border
            readonly property var f: ServiceGaps.frame ?? ({ on: 0 })
            anchors.fill: parent
            visible: root._bands.length > 0 && border.f.on === 1
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Colors.surface
                strokeColor: "transparent"
                strokeWidth: 0
                fillRule: ShapePath.OddEvenFill

                PathRectangle { x: 0; y: 0; width: root.width; height: root.height }
                PathRectangle {
                    x: border.f.left ?? 0
                    y: border.f.top ?? 0
                    width: root.width - (border.f.left ?? 0) - (border.f.right ?? 0)
                    height: root.height - (border.f.top ?? 0) - (border.f.bottom ?? 0)
                    topLeftRadius: border.f.tl ?? 0
                    topRightRadius: border.f.tr ?? 0
                    bottomLeftRadius: border.f.bl ?? 0
                    bottomRightRadius: border.f.br ?? 0
                }
            }
        }

        DeskCut {
            area: handoff.source ? handoff.source.box : Qt.rect(0, 0, 0, 0)
            visible: root.handing && root._clearing && !root._flying
        }

        Item {
            readonly property rect box: handoff.source ? handoff.source.box : Qt.rect(0, 0, 0, 0)
            x: box.x
            y: box.y
            width: box.width
            height: box.height
            clip: true
            visible: root._flying && patchWall.status === Image.Ready

            Image {
                id: patchWall
                x: (handoff.source ? handoff.source.wall.x : 0) - parent.x
                y: -parent.y
                width: handoff.source ? handoff.source.wall.width : root.width
                height: root.height
                source: root.handing ? handoff.wallUrl : ""
                fillMode: handoff.source ? handoff.source.wall.fillMode : Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }
        }
    }

    Item {
        anchors.fill: parent

        Item {
            anchors.fill: parent
            opacity: root.shade
            visible: root.shade > 0

            LockBackdrop {
                anchors.fill: parent
                style: LockCatalog.backdropFor(root.variantStyle)
                bare: root._bare
            }
        }

        LockClockStage {
            anchors.fill: parent
            visible: root.clockOn && opacity > 0
            opacity: root.shade
            face: root.clockOn ? root.clockFace : "display"
            awake: root.awake
            onWakeRequested: root.wake("")
        }

        LockLayoutLoader {
            id: layoutLoader
            anchors.fill: parent
            active: root.awake || root.layoutHold
            variant: root.variantStyle
            context: root.context
            exiting: root.exiting || !root.awake
            greeter: root.greeter
            handoff: root.handing
            handoffReveal: root.handing ? root.handReveal : 1
            handoffDate: root.handing && root._hasDate
            sources: root.carry
            desk: root.desk
            onLoaded: Qt.callLater(() => {
                root.focusInput()
                root.flushPending()
            })
        }
    }

    Connections {
        target: layoutLoader.item
        ignoreUnknownSignals: true
        function onFieldOpenChanged() {
            const lay = layoutLoader.item
            if (lay && lay.fieldGate === true && !lay.fieldOpen)
                root.forceActiveFocus()
        }
    }

    Binding {
        target: layoutLoader.authField
        property: "opacity"
        value: 0
        when: !root.primary && layoutLoader.authField !== null
    }

    Item {
        id: flyer
        anchors.fill: parent
        visible: root.handing || root.barOut < 1

        Repeater {
            model: root._bands

            delegate: Item {
                id: strip
                required property var modelData
                readonly property real off: root.barOut * (strip.modelData.depth + root._reachIn + 6)
                readonly property string side: strip.modelData.side
                readonly property rect area: root.reach(strip.modelData)
                x: strip.area.x
                y: strip.area.y
                width: strip.area.width
                height: strip.area.height
                clip: true
                visible: root.barOut < 1
                transform: Translate {
                    x: strip.side === "left" ? -strip.off : strip.side === "right" ? strip.off : 0
                    y: strip.side === "top" ? -strip.off : strip.side === "bottom" ? strip.off : 0
                }

                Image {
                    x: -strip.area.x
                    y: -strip.area.y
                    width: root.width
                    height: root.height
                    source: root.bar
                    asynchronous: false
                    cache: true
                    smooth: true
                }
            }
        }

        Repeater {
            model: root._faces ? handoff.source.parts : []

            delegate: Loader {
                id: face
                required property var modelData
                readonly property string role: face.modelData.role
                readonly property var st: root._flight[face.role] ?? null
                readonly property var at: face.st ? root.placeOf(face.st.rect, face.modelData.local, face.role === "date") : null
                sourceComponent: face.modelData.face
                visible: root._flying && face.at !== null && opacity > 0.001
                opacity: face.st ? face.st.face : 0
                x: face.at ? face.at.x : 0
                y: face.at ? face.at.y : 0
                transform: Scale { xScale: face.at ? face.at.s : 1; yScale: face.at ? face.at.s : 1 }
                onLoaded: {
                    const it = face.item
                    root.sharpen(it, root._zoom)
                    if (it.strength !== undefined) {
                        it.strength = Qt.binding(() => root._lift)
                        it.layer.enabled = Qt.binding(() => it.strength > 0.002)
                    }
                }
            }
        }

        Repeater {
            model: root._copyRoles

            delegate: Text {
                id: copy
                required property string modelData
                readonly property Item target: root._targets ? (root._targets[copy.modelData] ?? null) : null
                readonly property var st: root._flight[copy.modelData] ?? null
                readonly property rect local: !copy.target ? Qt.rect(0, 0, 1, 1)
                    : (copy.modelData === "hours" || copy.modelData === "minutes") && root._targets.ink
                    ? root._targets.ink.inkOf(copy.target) : Qt.rect(0, 0, copy.target.width, copy.target.height)
                readonly property var at: copy.st ? root.placeOf(copy.st.rect, copy.local, copy.modelData === "date") : null
                text: copy.target ? copy.target.text : ""
                color: copy.target ? copy.target.color : "transparent"
                font: copy.target ? copy.target.font : Qt.font({})
                lineHeight: copy.target ? copy.target.lineHeight : 1
                renderType: Text.CurveRendering
                opacity: copy.st ? copy.st.copy * (1 - root.handReveal) : 0
                visible: root._flying && copy.at !== null && opacity > 0.001
                x: copy.at ? copy.at.x : 0
                y: copy.at ? copy.at.y : 0
                transform: Scale { xScale: copy.at ? copy.at.s : 1; yScale: copy.at ? copy.at.s : 1 }
            }
        }
    }

    Component.onCompleted: {
        root._t0 = Date.now()
        if (!root.greeter && root._desk && root._entry.carry === true)
            root.carry = handoff.anchors()
        if (root._clearing) {
            root._wall = handoff.wall()
            root._bands = root.primary && root.bar.toString() !== "" ? handoff.bands(root.width, root.height) : []
        }
        if (root._handoffWanted) {
            handoff.capture()
            root.handing = handoff.ready
        }
        if (root.handing) {
            handGuard.start()
            Qt.callLater(() => root._faces = root.handing)
        }
        enterAnim.start()
        Qt.callLater(root.forceActiveFocus)
    }

    Timer {
        interval: 700; running: true
        onTriggered: root.awake ? root.focusInput() : root.forceActiveFocus()
    }
}
