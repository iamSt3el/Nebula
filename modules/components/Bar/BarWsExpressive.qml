import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

Item {
    id: ex

    property Item owner: null
    property string style: "connected"

    readonly property var ids: ex.owner ? ex.owner.wsIds : []
    readonly property int count: ex.ids.length
    readonly property int activeId: ex.owner ? ex.owner.activeWsId : -1
    readonly property int activeIndex: ex.ids.indexOf(ex.activeId)
    readonly property bool present: ex.activeIndex >= 0
    readonly property real k: ex.owner ? ex.owner.k : 1
    readonly property bool turned: !!ex.owner && ex.owner.vertical
    readonly property real cross: 30 * ex.k
    readonly property var shapes: ["cookie4", "sunny", "cookie6", "clover4", "softBurst",
                                   "cookie9", "flower", "pentagon", "cookie7", "gem"]

    property int lastIndex: 0
    property real fromPos: 0
    property bool ready: false
    onActiveIndexChanged: {
        if (ex.activeIndex < 0)
            return
        ex.fromPos = ex.pos
        ex.lastIndex = Math.min(ex.activeIndex, Math.max(0, ex.count - 1))
    }
    Component.onCompleted: {
        if (ex.activeIndex >= 0)
            ex.lastIndex = ex.activeIndex
        ex.fromPos = ex.lastIndex
        ex.ready = true
    }

    property real pos: ex.lastIndex
    Behavior on pos {
        enabled: ex.ready
        SpatialAnim { speed: "default" }
    }

    readonly property real span: ex.lastIndex - ex.fromPos
    readonly property real progress: Math.abs(ex.span) < 0.001 ? 1
        : Math.max(0, Math.min(1, (ex.pos - ex.fromPos) / ex.span))
    readonly property real travel: Math.sin(Math.PI * ex.progress) * Math.min(1, Math.abs(ex.span))

    readonly property real length: face.item ? face.item.length : 0
    implicitWidth: ex.turned ? ex.cross : ex.length
    implicitHeight: ex.turned ? ex.length : ex.cross

    function go(id, ws) {
        if (ex.owner)
            ex.owner.focusWs(id, ws)
    }

    function clamp01(v) {
        return Math.max(0, Math.min(1, v))
    }

    function mix(from, to, t) {
        const a = Qt.lighter(from, 1)
        const b = Qt.lighter(to, 1)
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
    }

    readonly property string nearLabel: {
        const i = Math.max(0, Math.min(ex.count - 1, Math.round(ex.pos)))
        return (ex.ids[i] ?? "").toString()
    }

    component Slot: QtObject {
        required property int wsId
        property Item owner: null
        readonly property var ws: ServiceWorkspaces.getWorkspace(wsId)
        readonly property bool onOther: !!owner && owner.perMonitorMode && !!ws && !!ws.monitor
            && ws.monitor.name !== owner.screenName
        readonly property bool occupied: !!ws && !onOther
    }

    component Seg: Rectangle {
        property real along: 0
        property real across: 0
        property real alongLen: 0
        property real acrossLen: 0
        property real startR: 0
        property real endR: 0
        x: ex.turned ? across : along
        y: ex.turned ? along : across
        width: ex.turned ? acrossLen : alongLen
        height: ex.turned ? alongLen : acrossLen
        topLeftRadius: startR
        topRightRadius: ex.turned ? startR : endR
        bottomLeftRadius: ex.turned ? endR : startR
        bottomRightRadius: endR
    }

    component Cell: Item {
        property real along: 0
        property real pitch: 0
        x: ex.turned ? 0 : along
        y: ex.turned ? along : 0
        width: ex.turned ? ex.cross : pitch
        height: ex.turned ? pitch : ex.cross
    }

    Loader {
        id: face
        anchors.fill: parent
        sourceComponent: {
            switch (ex.style) {
            case "slider": return sliderComp
            case "wavy":   return wavyComp
            case "morph":  return morphComp
            }
            return connectedComp
        }
    }

    Component {
        id: connectedComp
        Item {
            id: con
            readonly property real s: ex.cross - 6 * ex.k
            readonly property real gap: 3 * ex.k
            readonly property real grow: con.s * 0.9
            readonly property real length: ex.count * con.s + Math.max(0, ex.count - 1) * con.gap + con.grow

            function act(i) {
                return Math.max(0, 1 - Math.abs(ex.pos - i))
            }
            function startOf(i) {
                var a = i * (con.s + con.gap)
                for (var j = 0; j < i; j++)
                    a += con.grow * con.act(j)
                return a
            }

            Repeater {
                model: ex.ids
                delegate: Seg {
                    id: seg
                    required property int modelData
                    required property int index
                    Slot { id: st; wsId: seg.modelData; owner: ex.owner }
                    readonly property real act: con.act(seg.index)
                    readonly property real lit: ex.present ? Math.min(1, seg.act * 1.25) : 0
                    readonly property real inner: 6 * ex.k + (con.s / 2 - 6 * ex.k) * seg.act
                    along: con.startOf(seg.index)
                    across: 3 * ex.k
                    alongLen: con.s + con.grow * seg.act
                    acrossLen: con.s
                    startR: seg.index === 0 ? con.s / 2 : seg.inner
                    endR: seg.index === ex.count - 1 ? con.s / 2 : seg.inner
                    color: ex.mix(st.occupied ? Colors.secondaryContainer : Colors.surfaceContainerHighest,
                                  Colors.primary, seg.lit)

                    Text {
                        anchors.centerIn: parent
                        text: seg.modelData.toString()
                        font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                        font.pixelSize: Math.round(12 * ex.k)
                        font.weight: 700
                        font.features: { "tnum": 1 }
                        color: seg.lit > 0.5 ? Colors.primaryText
                             : st.occupied ? Colors.secondaryContainerText : Colors.outline
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ex.go(seg.modelData, st.ws)
                    }
                }
            }
        }
    }

    Component {
        id: sliderComp
        Item {
            id: sl
            readonly property real pitch: 26 * ex.k
            readonly property real pad: 4 * ex.k
            readonly property real th: 18 * ex.k
            readonly property real gap: 4 * ex.k
            readonly property real hw: (4 - 2 * ex.travel) * ex.k
            readonly property real head: sl.pad + sl.pitch * (ex.pos + 0.5)
            readonly property real trackEnd: sl.pad + sl.pitch * ex.count
            readonly property real length: ex.count * sl.pitch + sl.pad * 2

            Seg {
                readonly property real len: Math.max(0, sl.head - sl.gap - sl.hw / 2 - sl.pad)
                visible: len > 0.5
                along: sl.pad
                across: (ex.cross - sl.th) / 2
                alongLen: len
                acrossLen: sl.th
                startR: sl.th / 2
                endR: Math.min(3 * ex.k, len / 2)
                color: Colors.primary
            }

            Seg {
                readonly property real start: sl.head + sl.gap + sl.hw / 2
                readonly property real len: Math.max(0, sl.trackEnd - start)
                visible: len > 0.5
                along: start
                across: (ex.cross - sl.th) / 2
                alongLen: len
                acrossLen: sl.th
                startR: Math.min(3 * ex.k, len / 2)
                endR: sl.th / 2
                color: Colors.secondaryContainer
            }

            Repeater {
                model: ex.ids
                delegate: Cell {
                    id: stop
                    required property int modelData
                    required property int index
                    Slot { id: st; wsId: stop.modelData; owner: ex.owner }
                    readonly property real centre: sl.pad + sl.pitch * (stop.index + 0.5)
                    readonly property bool filled: stop.centre < sl.head
                    along: sl.pad + sl.pitch * stop.index
                    pitch: sl.pitch

                    CustomText {
                        anchors.centerIn: parent
                        content: stop.modelData.toString()
                        size: Math.round(10 * ex.k)
                        weight: 700
                        font.features: { "tnum": 1 }
                        opacity: ex.clamp01((Math.abs(stop.centre - sl.head) - sl.pitch * 0.25) / (sl.pitch * 0.25))
                        customColor: stop.filled
                            ? (st.occupied ? Colors.primaryText : Qt.alpha(Colors.primaryText, 0.55))
                            : (st.occupied ? Colors.secondaryContainerText : Colors.outline)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ex.go(stop.modelData, st.ws)
                    }
                }
            }

            Seg {
                readonly property real hh: ex.cross - 4 * ex.k
                visible: ex.present
                along: sl.head - sl.hw / 2
                across: (ex.cross - hh) / 2
                alongLen: sl.hw
                acrossLen: hh
                startR: sl.hw / 2
                endR: sl.hw / 2
                color: Colors.primary
            }
        }
    }

    Component {
        id: wavyComp
        Item {
            id: wv
            readonly property real pitch: 24 * ex.k
            readonly property real pad: 2 * ex.k
            readonly property real r: 10 * ex.k
            readonly property real gap: 4 * ex.k
            readonly property real head: wv.centre(ex.pos)
            readonly property real amp: 4 * ex.k * ex.travel
            readonly property real length: ex.count * wv.pitch + wv.pad * 2

            function centre(i) {
                return wv.pad + wv.pitch * (i + 0.5)
            }

            property real phase: 0
            NumberAnimation on phase {
                from: 0
                to: 2 * Math.PI
                duration: 700
                loops: Animation.Infinite
                running: wv.visible && ex.travel > 0.01
            }

            Canvas {
                id: line
                anchors.fill: parent
                renderStrategy: Canvas.Cooperative
                readonly property var key: [wv.head, wv.phase, wv.amp, ex.count, ex.turned,
                                            Colors.primary, Colors.secondaryContainer, width, height]
                onKeyChanged: line.requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const k = ex.k
                    const c = ex.cross / 2
                    const lam = 14 * k
                    const turned = ex.turned
                    function pt(a, o, first) {
                        const x = turned ? c + o : a
                        const y = turned ? a : c + o
                        if (first)
                            ctx.moveTo(x, y)
                        else
                            ctx.lineTo(x, y)
                    }
                    ctx.lineWidth = 4 * k
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"

                    const s0 = wv.centre(0) - 4 * k
                    const s1 = wv.head - wv.r - wv.gap
                    if (s1 > s0) {
                        ctx.strokeStyle = Colors.primary
                        ctx.beginPath()
                        for (let a = s0; ; a = Math.min(s1, a + 1.5)) {
                            const fade = Math.min(1, (s1 - a) / (lam * 0.75))
                            pt(a, wv.amp * fade * Math.sin(a / lam * 2 * Math.PI - wv.phase), a === s0)
                            if (a >= s1)
                                break
                        }
                        ctx.stroke()
                    }

                    const t0 = wv.head + wv.r + wv.gap
                    const t1 = wv.centre(ex.count - 1) + 4 * k
                    if (t1 > t0) {
                        ctx.strokeStyle = Colors.secondaryContainer
                        ctx.beginPath()
                        pt(t0, 0, true)
                        pt(t1, 0, false)
                        ctx.stroke()
                    }
                }
            }

            Repeater {
                model: ex.ids
                delegate: Cell {
                    id: dotCell
                    required property int modelData
                    required property int index
                    Slot { id: st; wsId: dotCell.modelData; owner: ex.owner }
                    readonly property real centre: wv.centre(dotCell.index)
                    along: wv.pad + wv.pitch * dotCell.index
                    pitch: wv.pitch

                    Rectangle {
                        anchors.centerIn: parent
                        width: (st.occupied ? 6.4 : 3.6) * ex.k
                        height: width
                        radius: width / 2
                        color: st.occupied ? Colors.tertiary : Colors.outline
                        opacity: ex.clamp01((dotCell.centre - wv.head - wv.r - wv.gap) / (3 * ex.k))
                        Behavior on width { SpatialAnim { speed: "fast" } }
                        Behavior on color { EffectsColorAnim {} }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ex.go(dotCell.modelData, st.ws)
                    }
                }
            }

            Rectangle {
                visible: ex.present
                width: wv.r * 2
                height: wv.r * 2
                radius: wv.r
                x: ex.turned ? (ex.cross - width) / 2 : wv.head - wv.r
                y: ex.turned ? wv.head - wv.r : (ex.cross - height) / 2
                color: Colors.primary

                CustomText {
                    anchors.centerIn: parent
                    content: ex.nearLabel
                    size: Math.round(11 * ex.k)
                    weight: 700
                    font.features: { "tnum": 1 }
                    customColor: Colors.primaryText
                }
            }
        }
    }

    Component {
        id: morphComp
        Item {
            id: mo
            readonly property real pitch: 22 * ex.k
            readonly property real pad: 4 * ex.k
            readonly property real d: ex.cross - 6 * ex.k
            readonly property real head: mo.pad + mo.pitch * (ex.pos + 0.5)
            readonly property real length: ex.count * mo.pitch + mo.pad * 2

            Repeater {
                model: ex.ids
                delegate: Cell {
                    id: dotCell
                    required property int modelData
                    required property int index
                    Slot { id: st; wsId: dotCell.modelData; owner: ex.owner }
                    readonly property real centre: mo.pad + mo.pitch * (dotCell.index + 0.5)
                    along: mo.pad + mo.pitch * dotCell.index
                    pitch: mo.pitch

                    Rectangle {
                        anchors.centerIn: parent
                        width: (st.occupied ? 8 : 5.2) * ex.k
                        height: width
                        radius: width / 2
                        color: st.occupied ? Colors.primary : Qt.alpha(Colors.outline, 0)
                        border.width: st.occupied ? 0 : 1.2 * ex.k
                        border.color: Colors.outline
                        opacity: ex.present
                            ? ex.clamp01((Math.abs(dotCell.centre - mo.head) - mo.d * 0.4) / (5 * ex.k)) : 1
                        Behavior on width { SpatialAnim { speed: "fast" } }
                        Behavior on color { EffectsColorAnim {} }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ex.go(dotCell.modelData, st.ws)
                    }
                }
            }

            Item {
                visible: ex.present
                width: mo.d
                height: mo.d
                x: ex.turned ? (ex.cross - width) / 2 : mo.head - mo.d / 2
                y: ex.turned ? mo.head - mo.d / 2 : (ex.cross - height) / 2

                MaterialShapes.ShapeCanvas {
                    anchors.fill: parent
                    rotation: ex.pos * 45
                    roundedPolygon: ShapeLibrary.get(ex.shapes[ex.lastIndex % ex.shapes.length])
                    color: Colors.tertiaryContainer
                    animation: SpatialAnim { speed: "default" }
                }

                CustomText {
                    anchors.centerIn: parent
                    content: ex.nearLabel
                    size: Math.round(12 * ex.k)
                    weight: 700
                    font.features: { "tnum": 1 }
                    customColor: Colors.tertiaryContainerText
                }
            }
        }
    }
}
