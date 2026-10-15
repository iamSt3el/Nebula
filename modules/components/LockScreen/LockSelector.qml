pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Scope {
    id: scope

    IpcHandler {
        target: "lockscreen"
        function choose(): void { GlobalStates.lockSelectorOpen = true }
        function close(): void { GlobalStates.lockSelectorOpen = false }
    }

    LazyLoader {
        active: GlobalStates.lockSelectorOpen

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors { left: true; right: true; top: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:lockSelector"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            FocusScope {
                id: root
                anchors.fill: parent
                focus: true

                readonly property real u: Math.min(width / 1920, height / 1080)
                readonly property var styles: LockCatalog.variants
                property bool greeterInstalled: false
                property string target: "lock"
                readonly property bool targetGreeter: root.greeterInstalled && root.target === "greeter"
                readonly property int appliedIndex: LockCatalog.indexOf(
                    (root.targetGreeter ? SettingsConfig.greeter : SettingsConfig.lockscreen)?.layout)
                property int sel: LockCatalog.indexOf(SettingsConfig.lockscreen?.layout)
                property int named: root.sel
                property int dir: 1
                property bool open: false
                property bool leaving: false

                readonly property var geo: root.open
                    ? { x: 392, y: 112, w: 1136, h: 639, strip: 776 }
                    : { x: 160, y: 112, w: 1600, h: 900, strip: 1030 }

                readonly property real thumbW: Math.min(256, (1800 - (root.styles.length - 1) * 20) / root.styles.length)
                readonly property real thumbGap: 20

                readonly property var decel: [0.05, 0.7, 0.1, 1.0, 1, 1]
                readonly property var accel: [0.3, 0.0, 0.8, 0.15, 1, 1]
                readonly property var standard: [0.2, 0.0, 0.0, 1.0, 1, 1]
                readonly property var pop: [0.38, 1.21, 0.22, 1.0, 1, 1]

                function select(i, d) {
                    const n = root.styles.length
                    const next = ((i % n) + n) % n
                    if (next === root.sel || root.leaving)
                        return
                    root.dir = d !== undefined ? d : (next > root.sel ? 1 : -1)
                    root.sel = next
                }

                function apply() {
                    const v = root.styles[root.sel].value
                    if (root.targetGreeter) {
                        SettingsConfig.greeter = Object.assign({}, SettingsConfig.greeter, { layout: v })
                    } else {
                        const base = Object.assign({}, SettingsConfig.lockscreen)
                        delete base.clockStyle
                        delete base.placement
                        SettingsConfig.lockscreen = Object.assign(base, { layout: v })
                    }
                    if (root.leaving)
                        return
                    root.leaving = true
                    swap.finish()
                    inAnim.complete()
                    settleAnim.complete()
                    root.growing = true
                    growAnim.start()
                }

                function dismiss() {
                    if (root.leaving)
                        return
                    root.leaving = true
                    leaveAnim.start()
                }

                function band(a, b) {
                    return Math.max(0, Math.min(1, (root.enter - a) / (b - a)))
                }

                function out3(t) {
                    return 1 - Math.pow(1 - t, 3)
                }

                function back(t) {
                    const c = 1.7
                    return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2)
                }

                function lerp(a, b, t) {
                    return a + (b - a) * t
                }

                onSelChanged: {
                    swap.go(root.sel)
                    nameSwap.restart()
                }
                onTargetChanged: root.select(root.appliedIndex)

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left) root.select(root.sel - 1, -1)
                    else if (event.key === Qt.Key_Right) root.select(root.sel + 1, 1)
                    else if (event.key === Qt.Key_Up) root.open = true
                    else if (event.key === Qt.Key_Down) root.open = false
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.apply()
                    else if (event.key === Qt.Key_Escape) root.dismiss()
                    else return
                    event.accepted = true
                }

                Process {
                    running: true
                    command: ["bash", "-c", "systemctl is-enabled greetd >/dev/null 2>&1 && grep -rqs -e greeter.qml /etc/greetd/ && echo yes || echo no"]
                    stdout: StdioCollector { onStreamFinished: root.greeterInstalled = text.trim() === "yes" }
                }

                property real enter: 0
                property real settle: 0
                property real leave: 0
                property real grow: 0
                property real toast: 0
                property bool growing: false
                property bool thumbsWanted: false
                onOpenChanged: if (root.open) root.thumbsWanted = true

                Timer {
                    interval: 1150
                    running: true
                    onTriggered: root.thumbsWanted = true
                }
                readonly property real full: Math.max(1 - root.settle, root.grow)
                readonly property real chromeIn: 1 - Math.min(1, root.leave * 2.2)
                readonly property real chromeOut: root.chromeIn * (1 - Math.min(1, root.grow * 3))

                NumberAnimation on enter {
                    id: inAnim
                    running: true
                    from: 0
                    to: 1
                    duration: 1000
                }

                SequentialAnimation {
                    id: settleAnim
                    running: true
                    PauseAnimation { duration: 240 }
                    NumberAnimation {
                        target: root
                        property: "settle"
                        to: 1
                        duration: 660
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.decel
                    }
                }

                NumberAnimation {
                    id: leaveAnim
                    target: root
                    property: "leave"
                    to: 1
                    duration: 340
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.accel
                    onFinished: GlobalStates.lockSelectorOpen = false
                }

                SequentialAnimation {
                    id: growAnim
                    ParallelAnimation {
                        NumberAnimation {
                            target: root
                            property: "grow"
                            to: 1
                            duration: 600
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: root.standard
                        }
                        SequentialAnimation {
                            PauseAnimation { duration: 360 }
                            ScriptAction { script: swap.replay() }
                        }
                    }
                    PauseAnimation { duration: 420 }
                    NumberAnimation {
                        target: root
                        property: "toast"
                        to: 1
                        duration: 420
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.pop
                    }
                    PauseAnimation { duration: 1100 }
                    ParallelAnimation {
                        NumberAnimation { target: root; property: "toast"; to: 0; duration: 200; easing.type: Easing.InCubic }
                        NumberAnimation {
                            target: root
                            property: "opacity"
                            to: 0
                            duration: 340
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: root.accel
                        }
                    }
                    ScriptAction { script: GlobalStates.lockSelectorOpen = false }
                }

                Item {
                    anchors.fill: parent
                    opacity: root.out3(root.band(0.1, 0.6)) * (1 - root.leave)

                    Image {
                        anchors.fill: parent
                        source: WallpaperTheme.wallpaperScreen
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 960
                        asynchronous: true
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blur: 1.0
                            blurMax: 64
                            autoPaddingEnabled: false
                            brightness: LockSession.light ? 0.3 : -0.5
                            saturation: 0.2
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.alpha(Colors.surface, LockSession.light ? 0.5 : 0.35)
                    }
                }

                RowLayout {
                    id: topBar
                    readonly property real t: root.out3(root.band(0.45, 0.85))
                    x: 64 * root.u
                    y: 28 * root.u
                    opacity: topBar.t * root.chromeOut
                    transform: Translate { y: (1 - topBar.t) * -36 * root.u }
                    width: parent.width - 128 * root.u
                    height: 60 * root.u
                    spacing: 22 * root.u

                    MaterialIconSymbol { content: "lock"; iconSize: Math.round(30 * root.u); customColor: Colors.primary }
                    CustomText { content: "Lock screen style"; size: Math.round(24 * root.u); weight: 600 }

                    M3ButtonGroup {
                        visible: root.greeterInstalled
                        Layout.preferredHeight: 46 * root.u
                        iconSize: Math.round(20 * root.u)
                        textSize: Math.round(17 * root.u)
                        model: [
                            { value: "lock",    label: "Lock screen",  icon: "lock" },
                            { value: "greeter", label: "Login screen", icon: "login" }
                        ]
                        activeCheck: v => root.target === v
                        onSegmentClicked: v => root.target = v
                    }

                    Item { Layout.fillWidth: true }

                    Item {
                        id: nameBox
                        Layout.preferredWidth: 420 * root.u
                        Layout.preferredHeight: 40 * root.u
                        clip: true

                        property real shift: 0

                        RowLayout {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: (nameBox.height - height) / 2 + nameBox.shift * 26 * root.u
                            opacity: 1 - Math.abs(nameBox.shift)
                            spacing: 10 * root.u
                            CustomText { content: root.styles[root.named].label; size: Math.round(22 * root.u); weight: 600 }
                            CustomText { content: root.styles[root.named].role; size: Math.round(18 * root.u); weight: 400; customColor: Colors.surfaceVariantText }
                        }

                        SequentialAnimation {
                            id: nameSwap
                            NumberAnimation {
                                target: nameBox; property: "shift"; to: -root.dir; duration: 170
                                easing.type: Easing.BezierSpline; easing.bezierCurve: root.accel
                            }
                            ScriptAction { script: { root.named = root.sel; nameBox.shift = root.dir } }
                            NumberAnimation {
                                target: nameBox; property: "shift"; to: 0; duration: 340
                                easing.type: Easing.BezierSpline; easing.bezierCurve: root.decel
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    M3IconButton {
                        implicitWidth: 52 * root.u
                        implicitHeight: 52 * root.u
                        icon: "close"
                        iconSize: Math.round(24 * root.u)
                        color: Qt.alpha(Colors.surfaceContainerHighest, 0.85)
                        onClicked: root.dismiss()
                    }

                    Rectangle {
                        implicitWidth: applyRow.implicitWidth + 56 * root.u
                        implicitHeight: 52 * root.u
                        radius: applyArea.containsMouse ? 16 * root.u : height / 2
                        color: Colors.primary
                        Behavior on radius { SpatialAnim { speed: "fast" } }

                        RowLayout {
                            id: applyRow
                            anchors.centerIn: parent
                            spacing: 10 * root.u
                            MaterialIconSymbol { content: "check"; iconSize: Math.round(24 * root.u); customColor: Colors.primaryText }
                            CustomText { content: "Apply"; size: Math.round(19 * root.u); weight: 600; customColor: Colors.primaryText }
                        }

                        MouseArea {
                            id: applyArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.apply()
                        }
                    }
                }

                ClippingRectangle {
                    id: frame
                    property real gx: root.geo.x * root.u
                    property real gy: root.geo.y * root.u
                    property real gw: root.geo.w * root.u
                    property real gh: root.geo.h * root.u

                    x: root.lerp(frame.gx, 0, root.full)
                    y: root.lerp(frame.gy, 0, root.full)
                    width: root.lerp(frame.gw, root.width, root.full)
                    height: root.lerp(frame.gh, root.height, root.full)
                    radius: 34 * root.u * (1 - root.full)
                    color: "black"
                    opacity: Math.min(1, root.enter / 0.12) * (1 - root.leave)
                    transform: [
                        Scale {
                            origin.x: frame.width / 2
                            origin.y: frame.height / 2
                            xScale: 1 - 0.08 * root.leave
                            yScale: 1 - 0.08 * root.leave
                        },
                        Translate { y: 40 * root.u * root.leave }
                    ]

                    Behavior on gx { NumberAnimation { duration: 540; easing.type: Easing.BezierSpline; easing.bezierCurve: root.open ? root.decel : root.standard } }
                    Behavior on gy { NumberAnimation { duration: 540; easing.type: Easing.BezierSpline; easing.bezierCurve: root.open ? root.decel : root.standard } }
                    Behavior on gw { NumberAnimation { duration: 540; easing.type: Easing.BezierSpline; easing.bezierCurve: root.open ? root.decel : root.standard } }
                    Behavior on gh { NumberAnimation { duration: 540; easing.type: Easing.BezierSpline; easing.bezierCurve: root.open ? root.decel : root.standard } }

                    Item {
                        id: swap
                        anchors.fill: parent

                        property bool frontA: true
                        readonly property Item front: swap.frontA ? layerA : layerB
                        readonly property Item back: swap.frontA ? layerB : layerA

                        function go(i) {
                            if (swapAnim.running)
                                swapAnim.complete()
                            const inn = swap.back
                            const out = swap.front
                            inn.idx = i
                            inn.off = root.dir * 0.22
                            inn.fade = 0
                            out.off = 0
                            out.fade = 1
                            swapAnim.inn = inn
                            swapAnim.out = out
                            swap.frontA = !swap.frontA
                            swapAnim.restart()
                        }

                        function finish() {
                            if (swapAnim.running)
                                swapAnim.complete()
                        }

                        function replay() {
                            swap.front.reload()
                        }

                        SequentialAnimation {
                            id: swapAnim
                            property Item inn: null
                            property Item out: null

                            ParallelAnimation {
                                NumberAnimation {
                                    target: swapAnim.out; property: "off"; to: -root.dir * 0.22; duration: 300
                                    easing.type: Easing.BezierSpline; easing.bezierCurve: root.accel
                                }
                                NumberAnimation {
                                    target: swapAnim.out; property: "fade"; to: 0; duration: 220
                                    easing.type: Easing.BezierSpline; easing.bezierCurve: root.accel
                                }
                                SequentialAnimation {
                                    PauseAnimation { duration: 70 }
                                    ParallelAnimation {
                                        NumberAnimation {
                                            target: swapAnim.inn; property: "off"; to: 0; duration: 520
                                            easing.type: Easing.BezierSpline; easing.bezierCurve: root.decel
                                        }
                                        NumberAnimation {
                                            target: swapAnim.inn; property: "fade"; to: 1; duration: 300
                                            easing.type: Easing.BezierSpline; easing.bezierCurve: root.standard
                                        }
                                    }
                                }
                            }
                            ScriptAction { script: if (swapAnim.out) swapAnim.out.idx = -1 }
                        }

                        SwapLayer { id: layerA; Component.onCompleted: layerA.idx = root.sel }
                        SwapLayer { id: layerB }
                    }

                    Rectangle {
                        x: 24 * root.u
                        y: 22 * root.u
                        width: badgeRow.implicitWidth + 30 * root.u
                        height: 40 * root.u
                        radius: height / 2
                        color: Qt.alpha(Colors.surface, 0.75)
                        visible: !root.growing
                        opacity: (root.appliedIndex === root.sel ? 1 : 0) * Math.max(0, (root.settle - 0.6) / 0.4)
                        Behavior on opacity { EffectsAnim { speed: "fast" } }

                        RowLayout {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 8 * root.u
                            MaterialIconSymbol { content: "check_circle"; iconSize: Math.round(20 * root.u); customColor: Colors.primary }
                            CustomText { content: "In use"; size: Math.round(17 * root.u); weight: 600 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: 10
                        acceptedButtons: Qt.AllButtons
                        onWheel: wheel => wheel.accepted = true
                    }
                }

                component SwapLayer: Item {
                    id: layer
                    property int idx: -1
                    property real off: 0
                    property real fade: 1
                    property bool live: true

                    function reload() {
                        layer.live = false
                        Qt.callLater(() => layer.live = true)
                    }

                    width: frame.width
                    height: frame.height
                    opacity: layer.fade
                    transform: [
                        Scale {
                            origin.x: layer.width / 2
                            origin.y: layer.height / 2
                            xScale: 1 - 0.04 * Math.min(1, Math.abs(layer.off) / 0.22)
                            yScale: 1 - 0.04 * Math.min(1, Math.abs(layer.off) / 0.22)
                        },
                        Translate { x: layer.off * frame.width }
                    ]

                    Loader {
                        anchors.fill: parent
                        active: layer.idx >= 0 && layer.live
                        sourceComponent: LockPreview {
                            live: true
                            layoutStyle: root.styles[Math.max(0, layer.idx)].value
                            greeter: root.targetGreeter
                        }
                    }
                }

                component NavButton: M3IconButton {
                    readonly property real t: root.band(0.55, 0.95)
                    y: frame.y + frame.height / 2 - height / 2
                    opacity: Math.min(1, t * 1.6) * root.chromeOut
                    scale: 0.6 + 0.4 * root.back(t)
                    implicitWidth: 64 * root.u
                    implicitHeight: 64 * root.u
                    iconSize: Math.round(34 * root.u)
                    color: Qt.alpha(Colors.surfaceContainerHighest, 0.8)
                }

                NavButton { x: 52 * root.u; icon: "chevron_left"; onClicked: root.select(root.sel - 1, -1) }
                NavButton { x: parent.width - width - 52 * root.u; icon: "chevron_right"; onClicked: root.select(root.sel + 1, 1) }

                Item {
                    id: strip
                    readonly property real t: root.out3(root.band(0.6, 1))
                    x: 0
                    opacity: Math.min(1, strip.t * 1.4) * root.chromeOut
                    transform: Translate { y: (1 - strip.t) * 110 * root.u }
                    y: strip.gy
                    width: parent.width
                    height: 300 * root.u

                    property real gy: root.geo.strip * root.u
                    Behavior on gy { NumberAnimation { duration: 540; easing.type: Easing.BezierSpline; easing.bezierCurve: root.open ? root.decel : root.standard } }

                    HoverHandler {
                        id: stripHover
                        onHoveredChanged: {
                            if (hovered) {
                                closeTimer.stop()
                                root.open = true
                            } else {
                                closeTimer.restart()
                            }
                        }
                    }

                    Timer {
                        id: closeTimer
                        interval: 500
                        onTriggered: root.open = false
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: handleRow.implicitWidth + 48 * root.u
                        height: 44 * root.u
                        radius: height / 2
                        color: Qt.alpha(Colors.surfaceContainerHighest, 0.8)

                        RowLayout {
                            id: handleRow
                            anchors.centerIn: parent
                            spacing: 12 * root.u
                            MaterialIconSymbol {
                                content: "expand_less"
                                iconSize: Math.round(24 * root.u)
                                rotation: root.open ? 180 : 0
                                Behavior on rotation { SpatialAnim {} }
                            }
                            CustomText { content: root.styles.length + " styles"; size: Math.round(17 * root.u); weight: 600; customColor: Colors.surfaceVariantText }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.open = !root.open
                        }
                    }

                    Item {
                        id: thumbs
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 66 * root.u
                        width: (root.styles.length * root.thumbW + (root.styles.length - 1) * root.thumbGap) * root.u
                        height: 190 * root.u

                        readonly property real picH: root.thumbW * 9 / 16 * root.u

                        Rectangle {
                            id: ring
                            property real l: root.sel * (root.thumbW + root.thumbGap) * root.u
                            property real r: ring.l + root.thumbW * root.u
                            x: ring.l - 5 * root.u
                            y: -5 * root.u
                            width: ring.r - ring.l + 10 * root.u
                            height: thumbs.picH + 10 * root.u
                            radius: 30 * root.u
                            color: "transparent"
                            border.width: 4 * root.u
                            border.color: Colors.primary
                            opacity: thumbRow.lift
                            z: 2

                            Behavior on l {
                                NumberAnimation {
                                    duration: root.dir > 0 ? 460 : 250
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: root.standard
                                }
                            }
                            Behavior on r {
                                NumberAnimation {
                                    duration: root.dir > 0 ? 250 : 460
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: root.standard
                                }
                            }
                        }

                        Row {
                            id: thumbRow
                            spacing: root.thumbGap * root.u
                            property real lift: root.open ? 1 : 0
                            Behavior on lift {
                                SequentialAnimation {
                                    PauseAnimation { duration: root.open ? 80 + root.styles.length * 45 : 0 }
                                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                }
                            }

                            Repeater {
                                model: root.styles

                                delegate: Item {
                                    id: thumb
                                    required property var modelData
                                    required property int index
                                    readonly property bool isSel: thumb.index === root.sel

                                    property real lift: root.open ? 1 : 0
                                    Behavior on lift {
                                        SequentialAnimation {
                                            PauseAnimation { duration: root.open ? 80 + thumb.index * 45 : 0 }
                                            NumberAnimation {
                                                duration: root.open ? 480 : 160
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: root.open ? root.decel : root.accel
                                            }
                                        }
                                    }

                                    width: root.thumbW * root.u
                                    height: 190 * root.u
                                    opacity: thumb.lift
                                    transform: [
                                        Scale {
                                            origin.x: thumb.width / 2
                                            origin.y: thumb.height
                                            xScale: 0.94 + 0.06 * thumb.lift
                                            yScale: 0.94 + 0.06 * thumb.lift
                                        },
                                        Translate { y: (1 - thumb.lift) * 46 * root.u }
                                    ]

                                    ClippingRectangle {
                                        id: pic
                                        width: parent.width
                                        height: thumbs.picH
                                        radius: (thumb.isSel ? 26 : 20) * root.u
                                        color: "black"
                                        Behavior on radius { SpatialAnim { speed: "fast" } }

                                        Loader {
                                            anchors.fill: parent
                                            asynchronous: true
                                            active: root.thumbsWanted
                                            sourceComponent: LockPreview {
                                                layoutStyle: thumb.modelData.value
                                                greeter: root.targetGreeter
                                            }
                                        }
                                    }

                                    RowLayout {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.leftMargin: 6 * root.u
                                        anchors.rightMargin: 6 * root.u
                                        y: pic.height + 12 * root.u

                                        CustomText {
                                            content: thumb.modelData.label
                                            size: Math.round(19 * root.u)
                                            weight: 600
                                            customColor: thumb.isSel ? Colors.primary : Colors.surfaceText
                                        }
                                        Item { Layout.fillWidth: true }
                                        Rectangle {
                                            visible: thumb.index === root.appliedIndex
                                            implicitWidth: inUse.implicitWidth + 20 * root.u
                                            implicitHeight: 26 * root.u
                                            radius: height / 2
                                            color: Colors.secondaryContainer
                                            CustomText {
                                                id: inUse
                                                anchors.centerIn: parent
                                                content: "In use"
                                                size: Math.round(14 * root.u)
                                                weight: 600
                                                customColor: Colors.secondaryContainerText
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.select(thumb.index)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 48 * root.u - (1 - root.toast) * 24 * root.u
                    visible: root.toast > 0
                    opacity: Math.min(1, root.toast)
                    scale: 0.9 + 0.1 * root.toast
                    width: toastRow.implicitWidth + 52 * root.u
                    height: 60 * root.u
                    radius: height / 2
                    color: Colors.inverseSurface

                    RowLayout {
                        id: toastRow
                        anchors.centerIn: parent
                        spacing: 12 * root.u
                        MaterialIconSymbol { content: "check_circle"; iconSize: Math.round(24 * root.u); customColor: Colors.inversePrimary }
                        CustomText {
                            content: root.styles[root.sel].label + (root.targetGreeter ? " is your login screen" : " is your lock screen")
                            size: Math.round(20 * root.u)
                            weight: 600
                            customColor: Colors.inverseSurfaceText
                        }
                    }
                }
            }
        }
    }
}
