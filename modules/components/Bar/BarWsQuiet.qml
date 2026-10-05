import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Item {
    id: quiet

    property Item owner: null
    property string style: "ring"

    readonly property var ids: quiet.owner ? quiet.owner.wsIds : []
    readonly property int count: quiet.ids.length
    readonly property int activeId: quiet.owner ? quiet.owner.activeWsId : -1
    readonly property int activeIndex: quiet.ids.indexOf(quiet.activeId)
    readonly property real k: quiet.owner ? quiet.owner.k : 1
    readonly property bool needsApps: quiet.style === "ring"

    implicitWidth: face.item ? face.item.implicitWidth : 0
    implicitHeight: 30 * quiet.k

    function go(id, ws) {
        if (quiet.owner)
            quiet.owner.focusWs(id, ws)
    }

    function step(delta) {
        if (quiet.count === 0)
            return
        const from = Math.max(0, quiet.activeIndex)
        const next = quiet.ids[(from + delta + quiet.count) % quiet.count]
        quiet.go(next, ServiceWorkspaces.getWorkspace(next))
    }

    function mainApp(ws) {
        const tops = ws && ws.toplevels ? ws.toplevels.values : []
        const tally = {}
        let best = ""
        for (let i = 0; i < tops.length; i++) {
            const id = tops[i]?.wayland?.appId ?? ""
            if (!id)
                continue
            tally[id] = (tally[id] ?? 0) + 1
            if (!best || tally[id] > tally[best])
                best = id
        }
        return best
    }

    function appName(appId) {
        if (!appId)
            return ""
        const entry = DesktopEntries.heuristicLookup(appId)
        return entry?.name ?? appId
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

    Slot {
        id: current
        wsId: quiet.activeId
        owner: quiet.owner
    }

    readonly property string currentApp: quiet.needsApps ? quiet.mainApp(current.occupied ? current.ws : null) : ""

    Timer {
        id: refresh
        interval: 200
        onTriggered: Hyprland.refreshToplevels()
    }

    Component.onCompleted: if (quiet.needsApps) refresh.restart()

    Connections {
        target: Hyprland
        enabled: quiet.needsApps
        function onRawEvent(event) {
            if (["openwindow", "closewindow", "movewindowv2", "activewindowv2", "workspacev2"].indexOf(event.name) >= 0)
                refresh.restart()
        }
    }

    Loader {
        id: face
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: {
            return quiet.style === "viewfinder" ? viewfinderComp : ringComp
        }
    }

    Component {
        id: ringComp

        Item {
            id: ringFace
            readonly property real side: 28 * quiet.k
            readonly property real gap: quiet.count > 6 ? 11 : 14
            implicitWidth: ringFace.side + 8 * quiet.k + caption.implicitWidth + 4 * quiet.k
            implicitHeight: 30 * quiet.k

            Item {
                id: dial
                width: ringFace.side
                height: ringFace.side
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: quiet.ids
                    delegate: Shape {
                        id: arc
                        required property int modelData
                        required property int index
                        Slot { id: st; wsId: arc.modelData; owner: quiet.owner }
                        readonly property real span: 360 / Math.max(1, quiet.count)
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: "transparent"
                            capStyle: ShapePath.FlatCap
                            strokeWidth: st.active ? 4.5 * quiet.k : 3 * quiet.k
                            strokeColor: st.active ? Colors.primary
                                       : st.occupied ? Colors.secondary
                                       : Colors.surfaceContainerHighest
                            Behavior on strokeWidth { SpatialAnim { speed: "fast" } }
                            Behavior on strokeColor { EffectsColorAnim {} }

                            PathAngleArc {
                                centerX: ringFace.side / 2
                                centerY: ringFace.side / 2
                                radiusX: ringFace.side / 2 - 3 * quiet.k
                                radiusY: ringFace.side / 2 - 3 * quiet.k
                                startAngle: -90 + arc.index * arc.span + ringFace.gap / 2
                                sweepAngle: arc.span - ringFace.gap
                            }
                        }
                    }
                }

                CustomText {
                    anchors.centerIn: parent
                    content: quiet.activeIndex >= 0 ? quiet.activeId.toString() : ""
                    size: Math.round(10 * quiet.k)
                    weight: 800
                    customColor: Colors.surfaceText
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const dx = mouse.x - width / 2
                        const dy = mouse.y - height / 2
                        const deg = (Math.atan2(dy, dx) * 180 / Math.PI + 90 + 360) % 360
                        const i = Math.min(quiet.count - 1, Math.floor(deg / (360 / Math.max(1, quiet.count))))
                        if (i >= 0)
                            quiet.go(quiet.ids[i], ServiceWorkspaces.getWorkspace(quiet.ids[i]))
                    }
                    onWheel: wheel => {
                        const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                        if (d !== 0)
                            quiet.step(d > 0 ? -1 : 1)
                    }
                }
            }

            CustomText {
                id: caption
                x: ringFace.side + 8 * quiet.k
                anchors.verticalCenter: parent.verticalCenter
                content: quiet.currentApp ? quiet.appName(quiet.currentApp) : "Empty"
                size: Math.round(11 * quiet.k)
                weight: 500
                customColor: quiet.currentApp ? Colors.surfaceVariantText : Colors.outline
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 110 * quiet.k)
            }
        }
    }

    Component {
        id: viewfinderComp

        Item {
            id: vf
            readonly property real cell: 20 * quiet.k
            implicitWidth: quiet.count * vf.cell
            implicitHeight: 30 * quiet.k

            Row {
                Repeater {
                    model: quiet.ids
                    delegate: Item {
                        id: vfCell
                        required property int modelData
                        Slot { id: st; wsId: vfCell.modelData; owner: quiet.owner }
                        width: vf.cell
                        height: 30 * quiet.k

                        CustomText {
                            anchors.centerIn: parent
                            content: vfCell.modelData.toString()
                            size: Math.round(12 * quiet.k)
                            weight: st.active ? 700 : 500
                            customColor: st.active ? Colors.primary
                                       : st.occupied ? Colors.surfaceVariantText : Colors.outline
                            opacity: st.active || st.occupied ? 1 : 0.5
                            Behavior on customColor { EffectsColorAnim {} }
                            Behavior on opacity { EffectsAnim {} }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: quiet.go(vfCell.modelData, st.ws)
                        }
                    }
                }
            }

            Item {
                id: frame
                visible: quiet.activeIndex >= 0
                x: Math.max(0, quiet.activeIndex) * vf.cell
                y: 3 * quiet.k
                width: vf.cell
                height: 24 * quiet.k
                Behavior on x { SpatialAnim { speed: "fast" } }

                Repeater {
                    model: 4
                    delegate: Item {
                        id: corner
                        required property int index
                        readonly property bool atRight: corner.index % 2 === 1
                        readonly property bool atBottom: corner.index > 1
                        x: corner.atRight ? frame.width - width : 0
                        y: corner.atBottom ? frame.height - height : 0
                        width: 6 * quiet.k
                        height: 6 * quiet.k

                        Rectangle {
                            y: corner.atBottom ? parent.height - 2 * quiet.k : 0
                            width: parent.width
                            height: 2 * quiet.k
                            radius: 1 * quiet.k
                            color: Colors.primary
                        }

                        Rectangle {
                            x: corner.atRight ? parent.width - 2 * quiet.k : 0
                            width: 2 * quiet.k
                            height: parent.height
                            radius: 1 * quiet.k
                            color: Colors.primary
                        }
                    }
                }
            }
        }
    }
}
