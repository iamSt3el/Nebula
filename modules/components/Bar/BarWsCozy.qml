import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Item {
    id: cozy

    property Item owner: null
    property string style: "lanterns"

    readonly property var ids: cozy.owner ? cozy.owner.wsIds : []
    readonly property int count: cozy.ids.length
    readonly property int activeId: cozy.owner ? cozy.owner.activeWsId : -1
    readonly property real k: cozy.owner ? cozy.owner.k : 1

    implicitWidth: face.item ? face.item.implicitWidth : 0
    implicitHeight: 32 * cozy.k

    function go(id, ws) {
        if (cozy.owner)
            cozy.owner.focusWs(id, ws)
    }

    function isActive(id) {
        if (!cozy.owner)
            return false
        if (cozy.owner.perMonitorMode)
            return id === cozy.activeId
        const w = ServiceWorkspaces.getWorkspace(id)
        return !!w && w.active
    }

    component Slot: QtObject {
        required property int wsId
        property Item owner: null
        readonly property var ws: ServiceWorkspaces.getWorkspace(wsId)
        readonly property bool onOther: !!owner && owner.perMonitorMode && !!ws && !!ws.monitor
            && ws.monitor.name !== owner.screenName
        readonly property bool occupied: !!ws && !onOther
        readonly property bool active: !!owner && !onOther && (owner.perMonitorMode ? wsId === owner.activeWsId
                                                                                     : (!!ws && ws.active))
        readonly property int windows: occupied && ws.toplevels ? ws.toplevels.values.length : 0
    }

    Loader {
        id: face
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: {
            switch (cozy.style) {
            case "house":   return houseComp
            case "stars":   return starsComp
            case "map":     return mapComp
            case "dial":    return dialComp
            }
            return lanternsComp
        }
    }

    Component {
        id: lanternsComp

        Item {
            id: lf
            readonly property real slot: 20 * cozy.k
            implicitWidth: cozy.count * lf.slot + 12 * cozy.k
            implicitHeight: 32 * cozy.k

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.alpha(Colors.outline, 0.6)
                    strokeWidth: 1 * cozy.k
                    fillColor: "transparent"
                    startX: 3 * cozy.k
                    startY: 5 * cozy.k
                    PathQuad { x: lf.width - 3 * cozy.k; y: 5 * cozy.k; controlX: lf.width / 2; controlY: 15 * cozy.k }
                }
            }

            Repeater {
                model: cozy.ids
                delegate: Item {
                    id: lan
                    required property int modelData
                    required property int index
                    Slot { id: st; wsId: lan.modelData; owner: cozy.owner }

                    readonly property real cx: 6 * cozy.k + (lan.index + 0.5) * lf.slot
                    readonly property real t: (lan.cx - 3 * cozy.k) / Math.max(1, lf.width - 6 * cozy.k)
                    readonly property real sy: (5 + 20 * lan.t * (1 - lan.t)) * cozy.k

                    x: lan.cx - 10 * cozy.k
                    width: 20 * cozy.k
                    height: 32 * cozy.k

                    Rectangle {
                        x: -2 * cozy.k
                        y: lan.sy + 1 * cozy.k
                        width: 24 * cozy.k
                        height: 24 * cozy.k
                        radius: 12 * cozy.k
                        color: Colors.primaryContainer
                        opacity: st.active ? 0.3 : 0
                        Behavior on opacity { EffectsAnim {} }
                    }

                    Item {
                        id: swing
                        y: lan.sy
                        width: 20 * cozy.k
                        height: 20 * cozy.k
                        transformOrigin: Item.Top

                        SequentialAnimation on rotation {
                            running: st.active
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { to: 5; duration: 1300; easing.type: Easing.InOutSine }
                            NumberAnimation { to: -5; duration: 2600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0; duration: 1300; easing.type: Easing.InOutSine }
                        }

                        Rectangle {
                            x: 9.5 * cozy.k
                            width: 1 * cozy.k
                            height: 4 * cozy.k
                            color: Qt.alpha(Colors.outline, 0.6)
                        }

                        Rectangle {
                            width: st.active ? 12 * cozy.k : st.occupied ? 10 * cozy.k : 9 * cozy.k
                            height: st.active ? 15 * cozy.k : st.occupied ? 13 * cozy.k : 12 * cozy.k
                            x: 10 * cozy.k - width / 2
                            y: 4 * cozy.k
                            radius: st.active ? 5 * cozy.k : 4.5 * cozy.k
                            color: st.active ? Colors.primaryContainer
                                 : st.occupied ? Qt.darker(Colors.primaryContainer, 1.9) : "transparent"
                            border.width: st.active || st.occupied ? 0 : 1.2 * cozy.k
                            border.color: Colors.outlineVariant
                            Behavior on width { SpatialAnim { speed: "fast" } }
                            Behavior on height { SpatialAnim { speed: "fast" } }
                            Behavior on color { EffectsColorAnim {} }

                            Rectangle {
                                anchors.centerIn: parent
                                visible: st.occupied && !st.active
                                width: 4 * cozy.k
                                height: 7 * cozy.k
                                radius: 2 * cozy.k
                                color: Colors.primary
                                opacity: 0.55
                            }

                            CustomText {
                                anchors.centerIn: parent
                                visible: st.active
                                content: lan.modelData
                                size: Math.round(8 * cozy.k)
                                weight: 700
                                customColor: Colors.primaryContainerText
                            }
                        }

                        Rectangle {
                            x: 7 * cozy.k
                            y: 2.5 * cozy.k
                            width: 6 * cozy.k
                            height: 2 * cozy.k
                            radius: 1 * cozy.k
                            color: Colors.outline
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cozy.go(lan.modelData, st.ws)
                    }
                }
            }
        }
    }

    Component {
        id: houseComp

        Item {
            id: hf
            readonly property real win: 12 * cozy.k
            readonly property real gap: 5 * cozy.k
            readonly property bool anyOpen: (Hyprland.toplevels?.values?.length ?? 0) > 0
            implicitWidth: 14 * cozy.k + cozy.count * hf.win + (cozy.count - 1) * hf.gap
            implicitHeight: 32 * cozy.k

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.alpha(Colors.surfaceVariantText, 0.55)
                    strokeWidth: 1.4 * cozy.k
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap
                    startX: 3 * cozy.k
                    startY: 13 * cozy.k
                    PathLine { x: hf.width / 2; y: 3 * cozy.k }
                    PathLine { x: hf.width - 3 * cozy.k; y: 13 * cozy.k }
                }
                ShapePath {
                    strokeColor: Qt.alpha(Colors.outline, 0.6)
                    strokeWidth: 1.2 * cozy.k
                    fillColor: "transparent"
                    startX: 2 * cozy.k
                    startY: 29.5 * cozy.k
                    PathLine { x: hf.width - 2 * cozy.k; y: 29.5 * cozy.k }
                }
            }

            Rectangle {
                id: chimney
                x: hf.width - 27 * cozy.k
                y: 4 * cozy.k
                width: 6 * cozy.k
                height: 6 * cozy.k
                color: Colors.surfaceVariantText
                opacity: 0.45
            }

            Repeater {
                model: 3
                delegate: Rectangle {
                    id: puff
                    required property int index
                    x: chimney.x + 1 * cozy.k
                    width: 4 * cozy.k
                    height: 4 * cozy.k
                    radius: 2 * cozy.k
                    color: Colors.surfaceVariantText
                    opacity: 0
                    visible: hf.anyOpen

                    SequentialAnimation {
                        running: hf.anyOpen
                        loops: Animation.Infinite
                        PauseAnimation { duration: puff.index * 900 }
                        ParallelAnimation {
                            NumberAnimation { target: puff; property: "y"; from: 3 * cozy.k; to: -4 * cozy.k; duration: 2700; easing.type: Easing.OutSine }
                            NumberAnimation { target: puff; property: "x"; from: chimney.x + 1 * cozy.k; to: chimney.x + 4 * cozy.k; duration: 2700 }
                            NumberAnimation { target: puff; property: "scale"; from: 0.6; to: 1.4; duration: 2700 }
                            SequentialAnimation {
                                NumberAnimation { target: puff; property: "opacity"; from: 0; to: 0.35; duration: 700 }
                                NumberAnimation { target: puff; property: "opacity"; to: 0; duration: 2000 }
                            }
                        }
                        PauseAnimation { duration: (2 - puff.index) * 900 }
                    }
                }
            }

            Row {
                x: 7 * cozy.k
                y: 15 * cozy.k
                spacing: hf.gap

                Repeater {
                    model: cozy.ids
                    delegate: Item {
                        id: pane
                        required property int modelData
                        Slot { id: st; wsId: pane.modelData; owner: cozy.owner }
                        width: hf.win
                        height: hf.win

                        Rectangle {
                            anchors.centerIn: parent
                            width: hf.win + 6 * cozy.k
                            height: hf.win + 6 * cozy.k
                            radius: 4 * cozy.k
                            color: Colors.primaryContainer
                            opacity: st.active ? 0.25 : 0
                            Behavior on opacity { EffectsAnim {} }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 2 * cozy.k
                            color: st.active ? Colors.primary
                                 : st.occupied ? Qt.alpha(Colors.primaryContainer, 0.55) : Colors.surfaceContainerHighest
                            border.width: 1 * cozy.k
                            border.color: Colors.outlineVariant
                            Behavior on color { EffectsColorAnim {} }
                        }

                        Rectangle {
                            x: hf.win / 2 - 0.5 * cozy.k
                            width: 1 * cozy.k
                            height: hf.win
                            color: Colors.surface
                            opacity: 0.55
                        }

                        Rectangle {
                            y: hf.win / 2 - 0.5 * cozy.k
                            width: hf.win
                            height: 1 * cozy.k
                            color: Colors.surface
                            opacity: 0.55
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -2 * cozy.k
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cozy.go(pane.modelData, st.ws)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: starsComp

        Item {
            id: cf
            readonly property var ys: [18, 9, 20, 12, 22, 10, 17]
            implicitWidth: (cozy.count * 19 + 6) * cozy.k
            implicitHeight: 32 * cozy.k

            function px(i) { return (3 + (i + 0.5) * 19) * cozy.k }
            function py(i) { return cf.ys[i % cf.ys.length] * cozy.k }

            readonly property var lit: {
                const out = []
                for (let i = 0; i < cozy.ids.length; i++) {
                    const w = ServiceWorkspaces.getWorkspace(cozy.ids[i])
                    if (w || cozy.isActive(cozy.ids[i]))
                        out.push(i)
                }
                return out
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.alpha(Colors.surfaceVariantText, 0.35)
                    strokeWidth: 1 * cozy.k
                    fillColor: "transparent"
                    PathPolyline { path: cf.lit.map(i => Qt.point(cf.px(i), cf.py(i))) }
                }
            }

            Repeater {
                model: cozy.ids
                delegate: Item {
                    id: star
                    required property int modelData
                    required property int index
                    Slot { id: st; wsId: star.modelData; owner: cozy.owner }

                    readonly property real rad: (st.active ? 8 : st.occupied ? 3 + Math.min(st.windows, 4) : 0) * cozy.k

                    x: cf.px(star.index) - 9 * cozy.k
                    y: cf.py(star.index) - 9 * cozy.k
                    width: 18 * cozy.k
                    height: 18 * cozy.k

                    Rectangle {
                        anchors.centerIn: parent
                        width: 18 * cozy.k
                        height: 18 * cozy.k
                        radius: 9 * cozy.k
                        color: Colors.primary
                        opacity: st.active ? 0.22 : 0
                        Behavior on opacity { EffectsAnim {} }
                    }

                    Shape {
                        id: sparkle
                        anchors.centerIn: parent
                        width: 18 * cozy.k
                        height: 18 * cozy.k
                        visible: star.rad > 0
                        preferredRendererType: Shape.CurveRenderer

                        SequentialAnimation on scale {
                            running: st.active
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { to: 0.8; duration: 1100; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutSine }
                        }

                        ShapePath {
                            strokeWidth: 0
                            strokeColor: "transparent"
                            fillColor: st.active ? Colors.primary : Colors.secondary
                            PathSvg {
                                path: {
                                    const r = star.rad
                                    const k = r * 0.28
                                    const c = 9 * cozy.k
                                    return `M${c},${c - r} Q${c + k},${c - k} ${c + r},${c} Q${c + k},${c + k} ${c},${c + r} `
                                         + `Q${c - k},${c + k} ${c - r},${c} Q${c - k},${c - k} ${c},${c - r} Z`
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        visible: star.rad === 0
                        width: 2.6 * cozy.k
                        height: 2.6 * cozy.k
                        radius: 1.3 * cozy.k
                        color: Colors.outline
                        opacity: 0.6
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cozy.go(star.modelData, st.ws)
                    }
                }
            }
        }
    }

    Component {
        id: mapComp

        Item {
            implicitWidth: mapRow.implicitWidth + 4 * cozy.k
            implicitHeight: 32 * cozy.k

            Timer {
                id: refresh
                interval: 200
                onTriggered: Hyprland.refreshToplevels()
            }

            Component.onCompleted: refresh.restart()

            Connections {
                target: Hyprland
                function onRawEvent(event) {
                    if (["openwindow", "closewindow", "movewindowv2", "changefloatingmode", "fullscreen",
                         "activewindowv2", "workspacev2"].indexOf(event.name) >= 0)
                        refresh.restart()
                }
            }

            Row {
                id: mapRow
                x: 2 * cozy.k
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * cozy.k

                Repeater {
                    model: cozy.ids
                    delegate: Item {
                        id: fr
                        required property int modelData
                        Slot { id: st; wsId: fr.modelData; owner: cozy.owner }
                        readonly property bool shownFull: st.occupied || st.active

                        anchors.verticalCenter: parent.verticalCenter
                        width: st.active ? 30 * cozy.k : st.occupied ? 24 * cozy.k : 5 * cozy.k
                        height: st.active ? 20 * cozy.k : st.occupied ? 16 * cozy.k : 12 * cozy.k
                        Behavior on width { SpatialAnim { speed: "fast" } }
                        Behavior on height { SpatialAnim { speed: "fast" } }

                        Rectangle {
                            anchors.fill: parent
                            radius: fr.shownFull ? 4.5 * cozy.k : 2.5 * cozy.k
                            color: st.active ? Qt.alpha(Colors.primary, 0.16)
                                 : st.occupied ? Colors.surfaceContainer : Colors.surfaceContainerHighest
                            border.width: fr.shownFull ? (st.active ? 1.4 * cozy.k : 1 * cozy.k) : 0
                            border.color: st.active ? Colors.primary : Colors.outlineVariant
                        }

                        Item {
                            id: stage
                            anchors.fill: parent
                            anchors.margins: 2.5 * cozy.k
                            visible: st.occupied
                            clip: true

                            readonly property var mon: st.ws ? st.ws.monitor : null
                            readonly property real mx: stage.mon ? stage.mon.x : 0
                            readonly property real my: stage.mon ? stage.mon.y : 0
                            readonly property real mw: cozy.owner ? cozy.owner.screenW : 1920
                            readonly property real mh: cozy.owner ? cozy.owner.screenH : 1080

                            Repeater {
                                model: st.ws ? st.ws.toplevels : null
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property var geo: modelData?.lastIpcObject ?? null
                                    readonly property bool placed: !!geo && !!geo.size && geo.size[0] > 0 && geo.size[1] > 0
                                    visible: placed
                                    x: placed ? (geo.at[0] - stage.mx) / stage.mw * stage.width : 0
                                    y: placed ? (geo.at[1] - stage.my) / stage.mh * stage.height : 0
                                    width: placed ? Math.max(2 * cozy.k, geo.size[0] / stage.mw * stage.width - 1 * cozy.k) : 0
                                    height: placed ? Math.max(2 * cozy.k, geo.size[1] / stage.mh * stage.height - 1 * cozy.k) : 0
                                    radius: 1.2 * cozy.k
                                    color: st.active ? Colors.primary : Qt.alpha(Colors.surfaceVariantText, 0.5)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cozy.go(fr.modelData, st.ws)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: dialComp

        Item {
            id: df
            readonly property real a0: 135
            readonly property real a1: 405
            readonly property int activeIndex: Math.max(0, cozy.ids.indexOf(cozy.activeId))
            implicitWidth: 44 * cozy.k + label.implicitWidth + 6 * cozy.k
            implicitHeight: 32 * cozy.k

            function ang(i) { return df.a0 + (df.a1 - df.a0) * i / Math.max(1, cozy.count - 1) }

            function step(d) {
                const n = cozy.count
                if (n === 0)
                    return
                const next = cozy.ids[(df.activeIndex + d + n) % n]
                cozy.go(next, ServiceWorkspaces.getWorkspace(next))
            }

            Rectangle {
                x: 3 * cozy.k
                y: 3 * cozy.k
                width: 26 * cozy.k
                height: 26 * cozy.k
                radius: 13 * cozy.k
                color: Colors.surfaceContainerHigh
            }

            Repeater {
                model: cozy.ids
                delegate: Item {
                    id: tick
                    required property int modelData
                    required property int index
                    Slot { id: st; wsId: tick.modelData; owner: cozy.owner }
                    x: 16 * cozy.k
                    y: 16 * cozy.k
                    rotation: df.ang(tick.index)

                    Rectangle {
                        x: 15 * cozy.k
                        y: -1 * cozy.k
                        width: 3.5 * cozy.k
                        height: 2 * cozy.k
                        radius: 1 * cozy.k
                        color: st.active ? Colors.primary : st.occupied ? Colors.secondary : Colors.outlineVariant
                        opacity: st.active || !st.occupied ? 1 : 0.8
                    }
                }
            }

            Item {
                x: 16 * cozy.k
                y: 16 * cozy.k
                rotation: df.ang(df.activeIndex)
                Behavior on rotation { SpatialAnim {} }

                Rectangle {
                    x: -1.5 * cozy.k
                    y: -1.5 * cozy.k
                    width: 12 * cozy.k
                    height: 3 * cozy.k
                    radius: 1.5 * cozy.k
                    color: Colors.primary
                }
            }

            Rectangle {
                x: 12.8 * cozy.k
                y: 12.8 * cozy.k
                width: 6.4 * cozy.k
                height: 6.4 * cozy.k
                radius: 3.2 * cozy.k
                color: Colors.primary
            }

            Row {
                id: label
                x: 38 * cozy.k
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * cozy.k

                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: cozy.activeId > 0 ? cozy.activeId : "–"
                    size: Math.round(16 * cozy.k)
                    weight: 800
                    font.features: { "tnum": 1 }
                }
                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "/ " + cozy.count
                    size: Math.round(10 * cozy.k)
                    weight: 500
                    customColor: Colors.outline
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => df.step(mouse.button === Qt.RightButton ? -1 : 1)
                onWheel: wheel => {
                    const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                    if (d !== 0)
                        df.step(d > 0 ? -1 : 1)
                }
            }
        }
    }
}
