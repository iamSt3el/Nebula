pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Nebula
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Widgets

Item {
    id: root

    property var context: null
    property bool preview: false
    property bool exiting: false
    property bool greeter: false
    property var cfg: LockSession.cfg
    property bool handoff: false
    property real handoffReveal: 1
    property bool handoffDate: false

    readonly property Item authField: auth
    readonly property bool fieldGate: !root.preview
    property bool fieldOpen: root.preview
    property real gateT: root.preview ? 1 : 0
    property var gatePts: []
    property rect gateFrom: Qt.rect(0, 0, 1, 1)
    property rect gateTo: Qt.rect(0, 0, 1, 1)
    readonly property bool _gateMoving: gateOpenAnim.running || gateCloseAnim.running
    readonly property real fieldReveal: root.fieldGate ? root.ramp(0.86, 1.0, root.gateT) : 1

    function ramp(a, b, v) {
        const t = Math.max(0, Math.min(1, (v - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    function wakeField() {
        gateIdle.restart()
        if (root.fieldOpen)
            return
        root.fieldOpen = true
        gateCloseAnim.stop()
        gateOpenAnim.start()
        Qt.callLater(() => { if (auth.input) auth.input.forceActiveFocus() })
    }

    function foldField() {
        if (!root.fieldGate || !root.fieldOpen || root._busy || (root.context?.currentText ?? "") !== "")
            return
        root.fieldOpen = false
        gateOpenAnim.stop()
        gateCloseAnim.start()
    }

    function gateMeasure() {
        if (lockBtn.width > 0)
            root.gateFrom = lockBtn.mapToItem(root, 0, 0, lockBtn.width, lockBtn.height)
        const f = auth.fieldBox
        if (f && f.width > 0)
            root.gateTo = f.mapToItem(root, 0, 0, f.width, f.height)
        root.gatePts = root.gateShape()
    }

    function bezAt(x1, y1, x2, y2, x) {
        if (x <= 0)
            return 0
        if (x >= 1)
            return 1
        let lo = 0, hi = 1, t = x
        for (let i = 0; i < 18; i++) {
            const bx = 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t
            if (bx < x)
                lo = t
            else
                hi = t
            t = (lo + hi) / 2
        }
        return 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t
    }

    readonly property real gateTravel: root.bezAt(0.38, 1.21, 0.22, 1.0, Math.min(1, root.gateT / 0.6))
    readonly property real gateUnfurl: root.bezAt(0.05, 0.7, 0.1, 1.0, Math.max(0, (root.gateT - 0.3) / 0.7))
    readonly property real _gk: root.gateTo.height / 64
    readonly property real _btnW: Math.round(76 * root._gk)
    readonly property real _gap: Math.max(2, Math.round(3 * root._gk))
    readonly property rect gateBtn: Qt.rect(root.gateTo.x + root.gateTo.width - root._btnW, root.gateTo.y, root._btnW, root.gateTo.height)
    readonly property bool _hasText: (root.context?.currentText ?? "") !== ""
    readonly property color gateBtnColor: root._hasText || root._busy ? Colors.primary : Colors.secondaryContainer
    readonly property color gateIconColor: root._hasText || root._busy ? Colors.primaryText : Colors.secondaryContainerText

    function gateShape() {
        const t = root.gateTravel
        const m = root.ramp(0, 1, Math.min(1, Math.max(0, t)))
        const B = root.gateFrom, F = root.gateBtn
        const cx0 = B.x + B.width / 2, cy0 = B.y + B.height / 2
        const cx1 = F.x + F.width / 2, cy1 = F.y + F.height / 2
        const ccx = cx0 + (cx1 - cx0) * t, ccy = cy0 + (cy1 - cy0) * t
        const w = B.width + (F.width - B.width) * t, h = B.height + (F.height - B.height) * t
        const rl = Math.min(h / 2, w / 2) + (Math.min(Math.round(8 * root._gk), h / 2) - Math.min(h / 2, w / 2)) * m
        const rr = Math.min(h / 2, w / 2)
        const amp = 0.09 * (1 - m)
        const rot = -m * 0.9
        const R = B.width / 2 + (Math.min(w, h) / 2 - B.width / 2) * m
        const n = 120
        const out = []
        for (let i = 0; i < n; i++) {
            const th = i / n * Math.PI * 2
            const dx = Math.cos(th), dy = Math.sin(th)
            const cr = R * (1 + amp * Math.cos(9 * (th + rot)))
            const ax = ccx + dx * cr, ay = ccy + dy * cr
            const r = dx < 0 ? rl : rr
            let lo = 0, hi = Math.hypot(w, h)
            for (let k = 0; k < 18; k++) {
                const md = (lo + hi) / 2
                const qx = Math.abs(dx * md) - (w / 2 - r), qy = Math.abs(dy * md) - (h / 2 - r)
                const d = Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r
                if (d < 0)
                    lo = md
                else
                    hi = md
            }
            const bx = ccx + dx * lo, by = ccy + dy * lo
            out.push(Qt.point(ax + (bx - ax) * m, ay + (by - ay) * m))
        }
        out.push(out[0])
        return out
    }

    NumberAnimation { id: gateOpenAnim; target: root; property: "gateT"; to: 1; duration: 680; onStopped: root.gateMeasure() }
    NumberAnimation { id: gateCloseAnim; target: root; property: "gateT"; to: 0; duration: 420; onStopped: root.gateMeasure() }
    FrameAnimation {
        running: root.fieldGate && root.gateT < 0.999 && (root._gateMoving || whoEnter.p < 0.999 || root.exiting)
        onTriggered: root.gateMeasure()
    }
    onWidthChanged: if (root.fieldGate) Qt.callLater(root.gateMeasure)
    onHeightChanged: if (root.fieldGate) Qt.callLater(root.gateMeasure)
    Timer {
        id: gateIdle
        interval: 20000
        onTriggered: root.foldField()
    }
    Connections {
        target: root.context
        ignoreUnknownSignals: true
        function onCurrentTextChanged() {
            if ((root.context?.currentText ?? "") !== "")
                root.wakeField()
            else
                gateIdle.restart()
        }
    }
    Shortcut {
        sequence: "Escape"
        enabled: root.fieldGate && root.fieldOpen
        onActivated: root.foldField()
    }
    readonly property var handoffTargets: ({ restyle: false, clock: cutClock, date: root.handoffDate && root.cfg.showDate !== false ? dateText : null })
    readonly property int _lead: root.handoff ? 300 : 0
    readonly property bool _animated: !root.preview
    readonly property real u: Math.min(root.width / 1920, root.height / 1080)
    readonly property string _family: SettingsConfig.general.defaultFont ?? "Rubik"
    readonly property bool _music: root.cfg.showMusic !== false && !root.greeter && ServiceMusic.activePlayer !== null
    readonly property bool _busy: root.context?.unlockInProgress ?? false
    readonly property bool _failed: root.context?.showFailure ?? false

    readonly property real cookieSize: 860 * root.u
    readonly property real cookieX: root.width - 112 * root.u - root.cookieSize
    readonly property real cookieY: (root.height - root.cookieSize) / 2 + 24 * root.u

    readonly property var _decel: [0.05, 0.7, 0.1, 1.0, 1, 1]
    readonly property var _standard: [0.2, 0.0, 0.0, 1.0, 1, 1]
    readonly property var _spring: [0.42, 1.67, 0.21, 0.90, 1, 1]

    readonly property var _frame: ServiceGaps.frame ?? ({ on: 0 })
    readonly property bool _framed: (root._frame.on ?? 0) === 1
    readonly property real _fl: root._framed ? root._frame.left : 0
    readonly property real _ft: root._framed ? root._frame.top : 0
    readonly property real _fr: root._framed ? root._frame.right : 0
    readonly property real _fb: root._framed ? root._frame.bottom : 0

    property real close: root._animated ? 0 : 1
    property real turn: root._animated ? 0 : 1
    property bool shapeOn: !root._animated
    property real spin: 0
    property bool _settled: !root._animated
    readonly property bool _moving: enterAnim.running || exitAnim.running || morphAnim.running
    readonly property real wallIn: Math.max(0, Math.min(1, (root.close - 0.25) / 0.5))
    readonly property string restShape: root._busy ? "sunny" : root._failed ? "clover4" : "cookie12"

    function lerp(a, b, t) {
        return a + (b - a) * t
    }

    function cornerAt(key) {
        return root.lerp(root._framed ? (root._frame[key] ?? 0) : 0, root.cookieSize / 2, root.close)
    }

    function morph(name) {
        if (shape.toShape === name)
            return
        morphAnim.stop()
        shape.fromShape = shape.toShape
        shape.toShape = name
        shape.progress = 0
        morphAnim.start()
    }

    onRestShapeChanged: if (root._settled && !root.exiting) root.morph(root.restShape)

    onExitingChanged: {
        if (!root._animated)
            return
        if (root.exiting) {
            enterAnim.stop()
            exitAnim.restart()
        } else {
            exitAnim.stop()
            enterAnim.restart()
        }
    }

    Component.onCompleted: {
        if (root._animated)
            enterAnim.start()
        if (root.fieldGate)
            Qt.callLater(root.gateMeasure)
    }

    ClockParts { id: clock }
    LockStatusModel { id: status }

    NumberAnimation {
        id: morphAnim
        target: shape
        property: "progress"
        to: 1
        duration: 460
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root._spring
    }

    NumberAnimation {
        target: root
        property: "spin"
        from: 0
        to: 360
        duration: 2400
        loops: Animation.Infinite
        running: root._busy && root._settled
        onRunningChanged: if (!running && !root.exiting && root.spin !== 0) {
            settleSpin.to = Math.ceil(root.spin / 90) * 90
            settleSpin.start()
        }
    }

    NumberAnimation {
        id: settleSpin
        target: root
        property: "spin"
        duration: 520
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root._decel
        onFinished: root.spin = 0
    }

    function symmetryOf(name) {
        return name === "sunny" ? 45 : name === "cookie12" ? 30 : 90
    }

    SequentialAnimation {
        id: enterAnim

        ScriptAction {
            script: {
                morphAnim.stop()
                settleSpin.stop()
                root._settled = false
                root.spin = 0
                root.turn = 0
                root.close = 0
                root.shapeOn = false
                shape.fromShape = "circle"
                shape.toShape = "cookie12"
                shape.progress = 0
            }
        }
        NumberAnimation {
            target: root; property: "close"; to: 1
            duration: 700
            easing.type: Easing.BezierSpline; easing.bezierCurve: root._standard
        }
        ScriptAction { script: root.shapeOn = true }
        ParallelAnimation {
            NumberAnimation {
                target: shape; property: "progress"; to: 1
                duration: 460
                easing.type: Easing.BezierSpline; easing.bezierCurve: root._spring
            }
            NumberAnimation {
                target: root; property: "turn"; to: 1
                duration: 460
                easing.type: Easing.BezierSpline; easing.bezierCurve: root._decel
            }
        }
        ScriptAction {
            script: {
                root._settled = true
                if (root.restShape !== shape.toShape)
                    root.morph(root.restShape)
            }
        }
    }

    SequentialAnimation {
        id: exitAnim

        ScriptAction {
            script: {
                morphAnim.stop()
                settleSpin.stop()
                root._settled = false
                root.spin = root.spin % root.symmetryOf(shape.toShape)
                shape.fromShape = shape.toShape
                shape.toShape = "circle"
                shape.progress = 0
                root.shapeOn = false
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: shape; property: "progress"; to: 1
                duration: 200
                easing.type: Easing.BezierSpline; easing.bezierCurve: root._standard
            }
            NumberAnimation {
                target: root; property: "turn"; to: 0
                duration: 200
                easing.type: Easing.BezierSpline; easing.bezierCurve: root._standard
            }
            NumberAnimation {
                target: root; property: "close"; to: 0
                duration: 680
                easing.type: Easing.BezierSpline; easing.bezierCurve: [0.45, 0.0, 0.2, 1.0, 1, 1]
            }
        }
    }

    Item {
        id: stage
        anchors.fill: parent

        Item {
            id: wall
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true

            Image {
                anchors.fill: parent
                source: WallpaperTheme.wallpaperScreen
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: root.preview ? 960 : 1920
                sourceSize.height: root.preview ? 540 : 1080
                asynchronous: false
                cache: true
                smooth: true
            }
        }

        Rectangle {
            id: fill
            anchors.fill: parent
            visible: false
            layer.enabled: true
            color: Colors.surface
        }

        property bool _maskFresh: false

        Connections {
            target: stage.Window.window
            enabled: !stage._maskFresh
            function onFrameSwapped() {
                stage._maskFresh = true
                shape.update()
            }
        }

        Item {
            id: mask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true

            Rectangle {
                readonly property real core: root.cookieSize * 0.3
                x: root.shapeOn ? root.cookieX + (root.cookieSize - core) / 2 : root.lerp(root._fl, root.cookieX, root.close)
                y: root.shapeOn ? root.cookieY + (root.cookieSize - core) / 2 : root.lerp(root._ft, root.cookieY, root.close)
                width: root.shapeOn ? core : root.lerp(root.width - root._fl - root._fr, root.cookieSize, root.close)
                height: root.shapeOn ? core : root.lerp(root.height - root._ft - root._fb, root.cookieSize, root.close)
                topLeftRadius: root.shapeOn ? core / 2 : root.cornerAt("tl")
                topRightRadius: root.shapeOn ? core / 2 : root.cornerAt("tr")
                bottomLeftRadius: root.shapeOn ? core / 2 : root.cornerAt("bl")
                bottomRightRadius: root.shapeOn ? core / 2 : root.cornerAt("br")
                antialiasing: true
                color: "white"
            }

            ShapePainter {
                id: shape
                x: root.cookieX
                y: root.cookieY
                width: root.cookieSize
                height: root.cookieSize
                textureSize: root._moving ? Qt.size(448, 448) : Qt.size(Math.ceil(width), Math.ceil(height))
                stretchToFill: true
                fromShape: "cookie12"
                toShape: "cookie12"
                progress: 1
                color: "white"
                transform: Rotation {
                    origin.x: root.cookieSize / 2
                    origin.y: root.cookieSize / 2
                    angle: 30 * root.turn + root.spin
                }
            }
        }

        Loader {
            anchors.fill: parent
            active: root.Window.window !== null

            sourceComponent: Item {
                MultiEffect {
                    anchors.fill: parent
                    source: wall
                    opacity: root.wallIn
                    visible: root.wallIn > 0
                    maskEnabled: true
                    maskSource: mask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

                MultiEffect {
                    anchors.fill: parent
                    source: fill
                    maskEnabled: true
                    maskInverted: true
                    maskSource: mask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
            }
        }
    }

    MotionEnter {
        visible: root.cfg.showStatus !== false && !root.greeter
        x: 128 * root.u
        y: 64 * root.u + (64 * root.u - height) / 2
        delay: 440 + root._lead
        dy: -24 * root.u
        speed: "default"
        animated: root._animated
        exiting: root.exiting

        Row {
            spacing: 30 * root.u

            Repeater {
                model: status.entries

                delegate: Row {
                    required property var modelData
                    spacing: 10 * root.u

                    MaterialIconSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        content: parent.modelData.icon
                        iconSize: Math.round(26 * root.u)
                        fill: 1
                        customColor: Colors.primary
                    }
                    CustomText {
                        anchors.verticalCenter: parent.verticalCenter
                        content: parent.modelData.value
                        size: Math.round(22 * root.u)
                        weight: 500
                        customColor: Colors.surfaceVariantText
                    }
                }
            }
        }
    }

    Column {
        x: 112 * root.u
        y: 168 * root.u
        spacing: 18 * root.u

        MotionEnter {
            delay: 300
            dy: 90 * root.u
            fromScale: 0.92
            speed: "default"
            animated: root._animated && !root.handoff
            exiting: root.exiting && !root.handoff

            LockCutClock {
                id: cutClock
                opacity: root.handoff ? root.handoffReveal : 1
                animated: root._animated
                handoff: root.handoff
                reveal: root.handoffReveal
                exiting: root.exiting
                enterDelay: 300
                hours: clock.hourPad
                minutes: clock.minute
                px: Math.round(330 * root.u)
                ink: Colors.surfaceText
                accent: Colors.primary
            }
        }

        MotionEnter {
            visible: root.cfg.showDate !== false
            x: 18 * root.u
            delay: 380
            dy: 28 * root.u
            speed: "default"
            animated: root._animated && !root.handoffDate
            exiting: root.exiting && !root.handoffDate

            CustomText {
                id: dateText
                opacity: root.handoffDate ? root.handoffReveal : 1
                content: (clock.weekday + "  " + clock.day + " " + clock.month).toUpperCase()
                size: Math.round(28 * root.u)
                renderType: root.preview ? Text.CurveRendering : Text.NativeRendering
                weight: 600
                font.letterSpacing: 5 * root.u
                customColor: Colors.surfaceVariantText
            }
        }
    }

    ColumnLayout {
        x: 128 * root.u
        y: root.height - implicitHeight - 96 * root.u
        spacing: 24 * root.u

        MotionEnter {
            id: whoEnter
            delay: 440 + root._lead
            dx: -40 * root.u
            dy: 0
            speed: "default"
            animated: root._animated
            exiting: root.exiting

            RowLayout {
                spacing: 18 * root.u

                LockShapeImage {
                    Layout.preferredWidth: 72 * root.u
                    Layout.preferredHeight: 72 * root.u
                    visible: root.cfg.showAvatar !== false
                    source: SettingsConfig.general.profile ?? ""
                    shapeName: root._busy ? "softBurst" : root._failed ? "clover4" : (SettingsConfig.general.avatarShape ?? "circle")
                    fallbackColor: Colors.tertiaryContainer
                    fallbackIconColor: Colors.tertiaryContainerText
                }

                ColumnLayout {
                    spacing: 0
                    CustomText {
                        content: LockSession.user
                        size: Math.round(30 * root.u)
                        renderType: root.preview ? Text.CurveRendering : Text.NativeRendering
                        weight: 600
                    }
                    CustomText {
                        content: root.greeter ? "Sign in to continue" : LockSession.greeting
                        size: Math.round(19 * root.u)
                        weight: 400
                        customColor: Colors.surfaceVariantText
                    }
                }

                Item {
                    id: lockBtn
                    visible: root.fieldGate
                    Layout.leftMargin: 18 * root.u
                    Layout.preferredWidth: 64 * root.u
                    Layout.preferredHeight: 64 * root.u

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.fieldOpen
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.wakeField()
                    }
                }
            }
        }

        RowLayout {
            spacing: 16 * root.u

            MotionEnter {
                Layout.alignment: Qt.AlignTop
                delay: 480 + root._lead
                dx: -40 * root.u
                dy: 0
                speed: "default"
                animated: root._animated
                exiting: root.exiting

                LockAuthField {
                    id: auth
                    opacity: root.fieldReveal
                    enabled: !root.fieldGate || root.fieldOpen
                    context: root.context
                    variant: "filled"
                    fieldWidth: 560 * root.u
                    fieldHeight: 80 * root.u
                    fieldRadius: 26 * root.u
                    fieldColor: Colors.surfaceContainerHigh
                    placeholder: "Password"
                    placeholderColor: Colors.surfaceVariantText
                    placeholderSize: Math.round(24 * root.u)
                    submitAlways: true
                }
            }
        }
    }

    MotionEnter {
        id: powerBox
        visible: root.cfg.showPower !== false
        x: root.width - width - 112 * root.u
        y: 64 * root.u
        delay: 480 + root._lead
        dy: -24 * root.u
        speed: "default"
        animated: root._animated
        exiting: root.exiting

        LockPowerActions {
            variant: "icons"
            box: 64 * root.u
            iconPx: Math.round(26 * root.u)
            spacing: 10 * root.u
            plate: Colors.surfaceContainerHigh
            plateHover: Colors.surfaceContainerHighest
        }
    }

    MotionEnter {
        visible: root._music
        x: powerBox.x - width - 16 * root.u
        y: 64 * root.u
        delay: 520 + root._lead
        dy: -24 * root.u
        speed: "default"
        animated: root._animated
        exiting: root.exiting

        Rectangle {
            width: musicRow.implicitWidth + 28 * root.u
            height: 64 * root.u
            radius: height / 2
            color: Colors.surfaceContainerHigh

            RowLayout {
                id: musicRow
                anchors.left: parent.left
                anchors.leftMargin: 8 * root.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14 * root.u

                LockShapeImage {
                    Layout.preferredWidth: 48 * root.u
                    Layout.preferredHeight: 48 * root.u
                    source: ServiceMusic.activeTrack?.artUrl ?? ""
                    trackKey: (ServiceMusic.activeTrack?.title ?? "") + "|" + (ServiceMusic.activeTrack?.artist ?? "")
                    sourceSize: 256
                    shapeName: "circle"
                    fallbackIcon: "music_note"
                }

                ColumnLayout {
                    spacing: 0
                    CustomText {
                        Layout.maximumWidth: 280 * root.u
                        content: ServiceMusic.activeTrack?.title ?? ""
                        size: Math.round(19 * root.u)
                        weight: 600
                    }
                    CustomText {
                        Layout.maximumWidth: 280 * root.u
                        content: ServiceMusic.activeTrack?.artist ?? ""
                        size: Math.round(15 * root.u)
                        weight: 400
                        customColor: Colors.surfaceVariantText
                    }
                }

                M3IconButton {
                    implicitWidth: 44 * root.u
                    implicitHeight: 44 * root.u
                    square: true
                    squareRadius: 14 * root.u
                    icon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                    iconSize: Math.round(24 * root.u)
                    iconFill: 1
                    iconColor: Colors.primaryText
                    color: Colors.primary
                    onClicked: ServiceMusic.togglePlaying()
                }
            }
        }
    }

    Item {
        id: gateLayer
        anchors.fill: parent
        visible: root.fieldGate && root.gateT < 0.999 && root.gatePts.length > 2
        opacity: whoEnter.opacity

        Rectangle {
            readonly property real fullW: Math.max(0, root.gateTo.width - root._btnW - root._gap)
            readonly property real w: fullW * root.gateUnfurl
            visible: w > 1
            x: root.gateBtn.x - root._gap - w
            y: root.gateTo.y
            width: w
            height: root.gateTo.height
            topLeftRadius: Math.min(height / 2, w / 2)
            bottomLeftRadius: Math.min(height / 2, w / 2)
            topRightRadius: Math.round(8 * root._gk)
            bottomRightRadius: Math.round(8 * root._gk)
            color: Colors.surfaceContainerHigh
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: Qt.tint(Colors.primary, Qt.alpha(root.gateBtnColor, root.ramp(0.1, 0.7, root.gateT)))
                PathPolyline { path: root.gatePts }
            }
        }

        MaterialIconSymbol {
            readonly property real cx: root.gateFrom.x + root.gateFrom.width / 2 + (root.gateBtn.x + root.gateBtn.width / 2 - root.gateFrom.x - root.gateFrom.width / 2) * root.gateTravel
            readonly property real cy: root.gateFrom.y + root.gateFrom.height / 2 + (root.gateBtn.y + root.gateBtn.height / 2 - root.gateFrom.y - root.gateFrom.height / 2) * root.gateTravel
            x: cx - width / 2
            y: cy - height / 2
            content: "lock"
            iconSize: Math.round(24 * root._gk)
            fill: 1
            opacity: 1 - root.ramp(0.25, 0.55, root.gateT)
            customColor: Colors.primaryText
        }

        MaterialIconSymbol {
            readonly property real cx: root.gateFrom.x + root.gateFrom.width / 2 + (root.gateBtn.x + root.gateBtn.width / 2 - root.gateFrom.x - root.gateFrom.width / 2) * root.gateTravel
            readonly property real cy: root.gateFrom.y + root.gateFrom.height / 2 + (root.gateBtn.y + root.gateBtn.height / 2 - root.gateFrom.y - root.gateFrom.height / 2) * root.gateTravel
            x: cx - width / 2
            y: cy - height / 2
            content: "arrow_forward"
            iconSize: Math.round(24 * root._gk)
            opacity: root.ramp(0.3, 0.6, root.gateT)
            customColor: root.gateIconColor
        }
    }
}
