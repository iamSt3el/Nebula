import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Item {
    id: motion

    property Item owner: null
    property string style: "goo"

    readonly property var ids: motion.owner ? motion.owner.wsIds : []
    readonly property int count: motion.ids.length
    readonly property int activeId: motion.owner ? motion.owner.activeWsId : -1
    readonly property int activeIndex: motion.ids.indexOf(motion.activeId)
    readonly property real k: motion.owner ? motion.owner.k : 1
    property int lastIndex: 0
    onActiveIndexChanged: if (motion.activeIndex >= 0) motion.lastIndex = motion.activeIndex
    Component.onCompleted: if (motion.activeIndex >= 0) motion.lastIndex = motion.activeIndex

    implicitWidth: face.item ? face.item.implicitWidth : 0
    implicitHeight: 30 * motion.k

    function go(id, ws) {
        if (motion.owner)
            motion.owner.focusWs(id, ws)
    }

    component Slot: QtObject {
        required property int wsId
        property Item owner: null
        readonly property var ws: ServiceWorkspaces.getWorkspace(wsId)
        readonly property bool onOther: !!owner && owner.perMonitorMode && !!ws && !!ws.monitor
            && ws.monitor.name !== owner.screenName
        readonly property bool occupied: !!ws && !onOther
    }

    Loader {
        id: face
        anchors.centerIn: parent
        sourceComponent: motion.style === "bounce" ? bounceComp : gooComp
    }

    Component {
        id: gooComp
        Item {
            id: goo
            readonly property real pitch: 22 * motion.k
            readonly property real pad: 4 * motion.k
            readonly property real target: goo.pad + motion.lastIndex * goo.pitch + goo.pitch / 2

            implicitWidth: motion.count * goo.pitch + goo.pad * 2
            implicitHeight: 30 * motion.k

            property real headX: goo.target
            property real tailX: goo.target
            property real dropX: goo.target
            Behavior on headX { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
            Behavior on tailX { NumberAnimation { duration: 550; easing.type: Easing.InOutCubic } }
            Behavior on dropX { NumberAnimation { duration: 780; easing.type: Easing.InOutQuart } }

            Repeater {
                model: motion.ids
                delegate: Item {
                    id: cell
                    required property int modelData
                    required property int index
                    Slot { id: st; wsId: cell.modelData; owner: motion.owner }
                    x: goo.pad + cell.index * goo.pitch
                    width: goo.pitch
                    height: goo.height

                    Rectangle {
                        anchors.centerIn: parent
                        width: 7 * motion.k
                        height: 7 * motion.k
                        radius: 3.5 * motion.k
                        color: st.occupied ? Colors.outline : Colors.outlineVariant
                        Behavior on color { EffectsColorAnim {} }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: motion.go(cell.modelData, st.ws)
                    }
                }
            }

            ShaderEffect {
                anchors.fill: parent
                visible: motion.activeIndex >= 0
                readonly property vector2d itemSize: Qt.vector2d(width, height)
                readonly property vector4d b0: Qt.vector4d(goo.headX, height / 2, 9 * motion.k, 0)
                readonly property vector4d b1: Qt.vector4d(goo.tailX, height / 2, 7.5 * motion.k, 0)
                readonly property vector4d b2: Qt.vector4d(goo.dropX, height / 2, 5 * motion.k, 0)
                readonly property color color: Colors.primary
                readonly property real k: 7 * motion.k
                readonly property real neck: Math.max(0, (5.8 - Math.abs(goo.headX - goo.tailX) / motion.k * 0.055) * motion.k)
                fragmentShader: Qt.resolvedUrl("../../../shaders/qsb/goo.frag.qsb")
            }
        }
    }

    Component {
        id: bounceComp
        Item {
            id: bounce
            readonly property real pitch: 22 * motion.k
            readonly property real ball: 20 * motion.k

            implicitWidth: motion.count * bounce.pitch
            implicitHeight: 30 * motion.k

            property int lastIndex: -1
            Component.onCompleted: bounce.lastIndex = motion.activeIndex
            property bool landed: true
            property real hop: 6 * motion.k

            Connections {
                target: motion
                function onActiveIndexChanged() {
                    const from = bounce.lastIndex
                    const to = motion.activeIndex
                    bounce.lastIndex = to
                    if (from < 0 || to < 0 || from === to) {
                        bounce.landed = true
                        return
                    }
                    bounce.hop = Math.min(9, 3 + Math.abs(to - from) * 2) * motion.k
                    bounce.landed = false
                    jump.restart()
                }
            }

            Item {
                id: marker
                visible: motion.activeIndex >= 0
                width: bounce.ball
                height: bounce.ball
                x: motion.lastIndex * bounce.pitch + (bounce.pitch - bounce.ball) / 2
                y: (bounce.height - bounce.ball) / 2
                Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.45, 0.05, 0.3, 1, 1, 1] } }

                Rectangle {
                    id: ballShape
                    width: bounce.ball
                    height: bounce.ball
                    radius: bounce.ball / 2
                    color: Colors.primary
                    property real lift: 0
                    property real sx: 1
                    property real sy: 1
                    transform: [
                        Scale { origin.x: bounce.ball / 2; origin.y: bounce.ball; xScale: ballShape.sx; yScale: ballShape.sy },
                        Translate { y: -ballShape.lift }
                    ]
                }
            }

            ParallelAnimation {
                id: jump
                onFinished: bounce.landed = true
                SequentialAnimation {
                    PauseAnimation { duration: 50 }
                    NumberAnimation { target: ballShape; property: "lift"; to: bounce.hop; duration: 160; easing.type: Easing.OutQuad }
                    NumberAnimation { target: ballShape; property: "lift"; to: 0; duration: 150; easing.type: Easing.InQuad }
                }
                SequentialAnimation {
                    ParallelAnimation {
                        NumberAnimation { target: ballShape; property: "sx"; to: 1.18; duration: 50 }
                        NumberAnimation { target: ballShape; property: "sy"; to: 0.82; duration: 50 }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: ballShape; property: "sx"; to: 0.9; duration: 160 }
                        NumberAnimation { target: ballShape; property: "sy"; to: 1.12; duration: 160 }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: ballShape; property: "sx"; to: 1; duration: 150 }
                        NumberAnimation { target: ballShape; property: "sy"; to: 1; duration: 150 }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: ballShape; property: "sx"; to: 1.22; duration: 40 }
                        NumberAnimation { target: ballShape; property: "sy"; to: 0.78; duration: 40 }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: ballShape; property: "sx"; to: 1; duration: 90; easing.type: Easing.OutBack }
                        NumberAnimation { target: ballShape; property: "sy"; to: 1; duration: 90; easing.type: Easing.OutBack }
                    }
                }
            }

            Repeater {
                model: motion.ids
                delegate: Item {
                    id: num
                    required property int modelData
                    required property int index
                    Slot { id: st; wsId: num.modelData; owner: motion.owner }
                    readonly property bool on: num.index === motion.activeIndex && bounce.landed
                    x: num.index * bounce.pitch
                    width: bounce.pitch
                    height: bounce.height

                    CustomText {
                        anchors.centerIn: parent
                        content: num.modelData.toString()
                        size: Math.round(12 * motion.k)
                        weight: 700
                        customColor: num.on ? Colors.primaryText
                                   : st.occupied ? Colors.surfaceText : Colors.outlineVariant
                        font.features: { "tnum": 1 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: motion.go(num.modelData, st.ws)
                    }
                }
            }
        }
    }
}
