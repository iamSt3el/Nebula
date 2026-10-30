import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.services

// Shared chrome for every desktop widget.
//
// Owns position persistence, grid-snapped dragging, the arrange-mode lift and
// preview mode, so no widget has to repeat any of it. A widget file declares a
// configKey plus its footprint and then contains nothing but its own visuals.
//
//     WidgetHost {
//         configKey: "sunArc"
//         tile: WidgetSizes.wide
//         defaultPos: Qt.point(100, 620)
//         ...content...
//     }
//
// Widgets not yet migrated onto the WidgetSizes ladder can set implicitWidth /
// implicitHeight directly instead of `tile`.
//
// Content is added as ordinary children (no default-property alias — aliasing
// the default property to an inner Item is circular, since the holder is itself
// a child). The drag surface sits above them on z.
Item {
    id: root

    // ── API ───────────────────────────────────────────────────────────
    // Prefix for the persisted position: "<configKey>X" / "<configKey>Y".
    // Variants of one family share a key (all digital clock styles use "clock"),
    // so switching style keeps the position.
    property string configKey: ""

    property size tile: WidgetSizes.small
    property point defaultPos: Qt.point(100, 100)

    // Rendered inside the settings gallery: no position, no drag, no saving.
    // Heavy widgets can also read this to throttle animation.
    property bool preview: false


    property bool resizable: false
    property Component optionsComponent: null
    readonly property size defaultSpan: Qt.size(WidgetSizes.cellsFor(tile.width),
                                                 WidgetSizes.rowsFor(tile.height))
    property size minSpan: defaultSpan
    property size maxSpan: defaultSpan

    property bool turnable: false
    property size turnedMin: Qt.size(Math.max(1, Math.round(minSpan.height)), minSpan.width)
    property size turnedMax: Qt.size(Math.max(1, Math.round(maxSpan.height)), maxSpan.width)
    property bool previewTurned: false
    readonly property bool turned: turnable && (_persists ? (SettingsConfig.widgets[configKey + "Turned"] ?? false) : previewTurned)
    readonly property size spanMin: turned ? turnedMin : minSpan
    readonly property size spanMax: turned ? turnedMax : maxSpan
    readonly property size homeSpan: turned ? Qt.size(Math.round(defaultSpan.height), defaultSpan.width) : defaultSpan

    property bool resizing: false
    property int _dragCols: 0
    property real _dragRows: 0

    readonly property bool _loadsSpan: _persists && (resizable || turnable)
    readonly property int _savedCols: _loadsSpan ? (SettingsConfig.widgets[configKey + "W"] ?? homeSpan.width) : homeSpan.width
    readonly property real _savedRows: _loadsSpan ? (SettingsConfig.widgets[configKey + "H"] ?? homeSpan.height) : homeSpan.height

    readonly property int cols: Math.max(spanMin.width,
                                         Math.min(spanMax.width, resizing ? _dragCols : _savedCols))
    readonly property real rows: Math.max(spanMin.height,
                                          Math.min(spanMax.height, resizing ? _dragRows : _savedRows))

    implicitWidth: WidgetSizes.span(cols)
    implicitHeight: WidgetSizes.span(rows)

    property bool backdrop: true
    property real backdropRadius: WidgetSizes.radius
    property Item backdropMask: null
    property bool outlined: true

    layer.enabled: !root.preview && !root.lifted && KindleMode.outlines && root.outlined
    layer.smooth: true
    layer.effect: inkOutline

    Component {
        id: inkOutline
        ShaderEffect {
            readonly property size itemSize: Qt.size(root.width, root.height)
            readonly property real lineWidth: KindleMode.edge
            readonly property real outsideAlpha: 0
            readonly property real outer: 0
            readonly property color lineColor: Colors.outline
            fragmentShader: Qt.resolvedUrl("../../../shaders/qsb/silhouette.frag.qsb")
        }
    }

    Loader {
        anchors.fill: parent
        z: -3
        active: root.backdrop && !root.preview && WidgetSizes.blurBackground
                && GlobalStates.widgetBackdrop !== null
                && GlobalStates.widgetBackdropSharp !== null
        visible: active

        sourceComponent: root.backdropMask ? maskedBackdrop : clippedBackdrop
    }

    Component {
        id: clippedBackdrop

        ClippingRectangle {
            radius: root.backdropRadius
            color: "transparent"

            ShaderEffectSource {
                anchors.fill: parent
                sourceItem: GlobalStates.widgetBackdrop
                sourceRect: Qt.rect(root.x, root.y, root.width, root.height)
            }
        }
    }

    Component {
        id: maskedBackdrop

        Item {
            Item {
                width: 0
                height: 0
                clip: true

                ShaderEffectSource {
                    id: crop
                    width: root.width
                    height: root.height
                    sourceItem: GlobalStates.widgetBackdrop
                    sourceRect: Qt.rect(root.x, root.y, root.width, root.height)
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: crop
                maskEnabled: true
                maskSource: root.backdropMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }
    }

    // ── Lift affordance ───────────────────────────────────────────────
    readonly property bool lifted: !preview && GlobalStates.widgetEditMode

    // Local slice of the arrange-mode sweep: this widget's chrome traces in as the
    // pass of light reaches its own centre, so it stays in step with the grid under it.
    readonly property real revealT: root.preview ? 0
        : GlobalStates.revealAt(root.x + root.width / 2, GlobalStates.widgetScreenSize.x)
    readonly property bool knobsIn: root.revealT > 0.55

    // Deliberately no scale-up here. Growing the widget while arranging makes
    // its footprint disagree with where it will actually land, which makes
    // placing it against the grid harder. The outline below marks it instead —
    // it's drawn inside the bounds, so the footprint stays honest.

    // ── Position ──────────────────────────────────────────────────────
    readonly property bool _persists: !preview && configKey !== ""
    property bool dragging: false
    readonly property bool locked: _persists && (SettingsConfig.widgets[configKey + "Locked"] ?? false)
    readonly property bool selected: _persists && GlobalStates.widgetSettingsKey === configKey
    readonly property bool hoverLift: root.lifted && root._persists && liftHover.hovered && !root.dragging && !root.resizing
    readonly property string displayName: {
        const n = EditSession.namers.widget
        return root.configKey !== "" && typeof n === "function" ? n(root.configKey) : ""
    }

    HoverHandler {
        id: liftHover
        enabled: root.lifted
    }

    readonly property real homeX: WidgetSizes.snapX(SettingsConfig.widgets[root.configKey + "X"] ?? root.defaultPos.x, root.width)
    readonly property real homeY: WidgetSizes.snapY(SettingsConfig.widgets[root.configKey + "Y"] ?? root.defaultPos.y, root.height)
    readonly property point landing: dragging
        ? WidgetLayout.nearestFree(root, WidgetSizes.snapX(root.x, root.width),
                                   WidgetSizes.snapY(root.y, root.height), root.width, root.height)
        : Qt.point(root.x, root.y)

    QtObject {
        Component.onCompleted: if (root._persists) WidgetLayout.register(root)
        Component.onDestruction: WidgetLayout.unregister(root)
    }

    // Driven by Binding rather than Component.onCompleted: a widget file that
    // declares its own Component.onCompleted would override the host's.
    // RestoreNone so releasing the binding mid-drag keeps the dragged position.
    Binding {
        target: root
        property: "x"
        value: root.homeX
        when: root._persists && !root.dragging
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root
        property: "y"
        value: root.homeY
        when: root._persists && !root.dragging
        restoreMode: Binding.RestoreNone
    }

    Behavior on x {
        enabled: (root.lifted || ServiceLayouts.moving) && !root.dragging
        NumberAnimation {
            duration: root.lifted ? M3Motion.spatialDuration("default") : 650
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.lifted ? M3Motion.spatialCurve("default") : [0.3, 0, 0.1, 1, 1, 1]
        }
    }

    Behavior on y {
        enabled: (root.lifted || ServiceLayouts.moving) && !root.dragging
        NumberAnimation {
            duration: root.lifted ? M3Motion.spatialDuration("default") : 650
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.lifted ? M3Motion.spatialCurve("default") : [0.6, 0, 0.3, 1, 1, 1]
        }
    }

    property real enterT: 1
    opacity: Math.min(1, root.enterT)
    transform: Translate { y: (1 - root.enterT) * 10 }

    SequentialAnimation {
        id: enterAnim
        PauseAnimation { duration: 180 }
        NumberAnimation {
            target: root
            property: "enterT"
            to: 1
            duration: M3Motion.spatialDuration("default")
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
        }
    }

    QtObject {
        Component.onCompleted: if (!root.preview && ServiceLayouts.moving) {
            root.enterT = 0
            enterAnim.start()
        }
    }

    function savePosition() {
        if (!_persists) return
        var patch = {}
        patch[configKey + "X"] = root.landing.x
        patch[configKey + "Y"] = root.landing.y
        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, patch)
    }

    function saveSpan() {
        if (!_persists) return
        var patch = {}
        if (turnable || spanMin.width < spanMax.width) patch[configKey + "W"] = root.cols
        if (turnable || spanMin.height < spanMax.height) patch[configKey + "H"] = root.rows
        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, patch)
    }

    function turn() {
        if (!_persists || !turnable) return
        const next = !root.turned
        const lo = next ? turnedMin : minSpan
        const hi = next ? turnedMax : maxSpan
        const c = Math.max(lo.width, Math.min(hi.width, Math.round(root.rows)))
        const r = Math.max(lo.height, Math.min(hi.height, root.cols))
        const w = WidgetSizes.span(c)
        const h = WidgetSizes.span(r)
        const x = WidgetSizes.snapX(root.homeX, w)
        const y = WidgetSizes.snapY(root.homeY, h)
        const spot = WidgetLayout.nearestFree(root, x, y, w, h)
        const patch = {}
        patch[configKey + "Turned"] = next
        patch[configKey + "W"] = c
        patch[configKey + "H"] = r
        patch[configKey + "X"] = spot.x
        patch[configKey + "Y"] = spot.y
        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, patch)
    }

    // Double-click a widget to enter arrange mode, as it worked before.
    // Sits *beneath* the content so a widget's own controls keep priority —
    // plain Rectangles don't consume events, so ordinary cards still get it.
    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: !root.preview && !root.lifted
        onDoubleClicked: GlobalStates.openEdit("desktop")
    }

    Rectangle {
        z: -4
        visible: root.dragging
        x: root.landing.x - root.x
        y: root.landing.y - root.y
        width: root.width
        height: root.height
        radius: WidgetSizes.radius
        color: Qt.alpha(Colors.primary, 0.14)
        border.width: 2
        border.color: Qt.alpha(Colors.primary, 0.7)
    }

    // Footprint marker — inside the bounds, so it never shifts placement
    Rectangle {
        anchors.fill: parent
        z: 99
        visible: root.revealT > 0.001
        readonly property bool active: root.dragging || root.resizing
        readonly property real settle: Math.max(0, Math.min(1, (root.revealT - 0.45) / 0.55))
        opacity: root.revealT
        color: active ? Qt.alpha(Colors.primary, 0.08) : "transparent"
        radius: WidgetSizes.radius
        border.width: active || root.selected ? 2.5 : root.hoverLift ? 2 : 1.5
        border.color: active || root.selected ? Colors.primary
            : root.hoverLift ? Qt.alpha(Colors.primary, 0.85)
            : Qt.alpha(Colors.surfaceText, 0.34 + 0.4 * (1 - settle))
        Behavior on border.color { EffectsColorAnim { speed: "fast" } }
    }

    Repeater {
        model: !((root.selected || root.hoverLift) && root.lifted && !root.dragging) ? []
            : root.selected && root.resizable && !root.locked ? [Qt.point(0, 0), Qt.point(1, 0), Qt.point(0, 1)]
            : [Qt.point(0, 0), Qt.point(1, 0), Qt.point(0, 1), Qt.point(1, 1)]

        Rectangle {
            required property point modelData
            z: 101
            x: modelData.x * root.width - width / 2
            y: modelData.y * root.height - height / 2
            width: 14
            height: 14
            radius: 7
            color: Colors.primary
            border.width: 3
            border.color: Colors.surface
        }
    }

    Rectangle {
        z: 101
        y: root.height + 8
        opacity: root.hoverLift && !root.selected && root.knobsIn ? 1 : 0
        visible: opacity > 0.01 && root.displayName !== ""
        Behavior on opacity { EffectsAnim { speed: "fast" } }
        width: nameRow.implicitWidth + 20
        height: 26
        radius: 13
        color: Colors.primary

        Row {
            id: nameRow
            anchors.centerIn: parent
            spacing: 6

            MaterialIconSymbol {
                anchors.verticalCenter: parent.verticalCenter
                content: root.locked ? "lock" : "open_with"
                iconSize: 14
                customColor: Colors.primaryText
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: root.displayName + (root.locked ? " · locked" : " · click for options, drag to move")
                size: 11
                weight: 600
                customColor: Colors.primaryText
            }
        }
    }

    Rectangle {
        z: 101
        visible: root.locked && root.revealT > 0.001
        opacity: root.revealT
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 10
        width: 26
        height: 26
        radius: 13
        color: Qt.alpha(Colors.surface, 0.85)

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: "lock"
            iconSize: 14
            customColor: Colors.primary
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 100
        enabled: root.lifted
        visible: root.lifted
        cursorShape: root.locked ? Qt.PointingHandCursor : Qt.SizeAllCursor
        preventStealing: true

        property point grab
        property real grabX: 0
        property real grabY: 0

        onPressed: mouse => {
            if (root.locked) return
            grab = mapToItem(null, mouse.x, mouse.y)
            grabX = root.x
            grabY = root.y
            root.dragging = true
            GlobalStates.widgetSettingsKey = ""
            GlobalStates.widgetQuickAdd = Qt.point(-1, -1)
        }

        // The stage is scaled down in studio mode, so a scene-space delta has to be
        // divided by that scale to become desktop pixels.
        onPositionChanged: mouse => {
            if (!root.dragging) return
            const p = mapToItem(null, mouse.x, mouse.y)
            const s = Math.max(0.01, GlobalStates.widgetStageScale)
            root.x = grabX + (p.x - grab.x) / s
            root.y = grabY + (p.y - grab.y) / s
        }

        onClicked: GlobalStates.widgetSettingsKey = root.configKey

        // Save before clearing `dragging`: the moment dragging goes false the
        // Binding above re-engages, and it must read the new position, not the
        // stale one it would otherwise restore.
        onReleased: {
            if (!root.dragging) return
            root.savePosition()
            root.dragging = false
            GlobalStates.widgetSettingsKey = root.configKey
        }
    }

    Item {
        id: resizeHandle
        z: 101
        // pops in behind the traced outline, and stays visible through the exit sweep;
        // `enabled` tracks the mode itself so a fading knob never takes a click
        visible: root.revealT > 0.001 && root.resizable && root.selected && !root.locked && !root.dragging
        enabled: root.lifted && root.resizable && !root.locked
        opacity: root.knobsIn ? 1 : 0
        Behavior on opacity { EffectsAnim { speed: "fast" } }
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -12
        anchors.bottomMargin: -12
        width: 36
        height: 36

        Rectangle {
            anchors.centerIn: parent
            width: !root.knobsIn ? 10 : resizeArea.pressed ? 30 : resizeArea.containsMouse ? 28 : 26
            height: width
            radius: width / 2
            color: Colors.primary
            Behavior on width { SpatialAnim { speed: "fast" } }

            MaterialIconSymbol {
                anchors.centerIn: parent
                content: "open_in_full"
                iconSize: !root.knobsIn ? 6 : resizeArea.pressed ? 16 : resizeArea.containsMouse ? 15 : 14
                Behavior on iconSize { SpatialAnim { speed: "fast" } }
                rotation: 90
                customColor: Colors.primaryText
            }
        }

        MouseArea {
            id: resizeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            preventStealing: true

            property point start
            property real startW: 0
            property real startH: 0

            onPressed: mouse => {
                start = mapToItem(null, mouse.x, mouse.y)
                startW = root.width
                startH = root.height
                root._dragCols = root.cols
                root._dragRows = root.rows
                root.resizing = true
            }

            onPositionChanged: mouse => {
                if (!root.resizing) return
                const p = mapToItem(null, mouse.x, mouse.y)
                const s = Math.max(0.01, GlobalStates.widgetStageScale)
                const roomC = WidgetSizes.gridCols - WidgetSizes.colAt(root.x)
                const roomR = WidgetSizes.gridRows - WidgetSizes.rowAt(root.y)
                const c = Math.max(root.spanMin.width, Math.min(root.spanMax.width, roomC,
                                   WidgetSizes.cellsFor(startW + (p.x - start.x) / s)))
                const r = Math.max(root.spanMin.height, Math.min(root.spanMax.height, roomR,
                                   WidgetSizes.rowsFor(startH + (p.y - start.y) / s)))
                const fit = WidgetLayout.fitSpan(root, root.x, root.y, c, r,
                                                 root.spanMin.width, root.spanMin.height)
                root._dragCols = fit ? fit.c : c
                root._dragRows = fit ? fit.r : r
            }

            onReleased: {
                if (!root.resizing) return
                root.saveSpan()
                root.resizing = false
            }
        }
    }

    Rectangle {
        z: 102
        visible: root.resizing
        anchors.centerIn: parent
        width: spanLabel.implicitWidth + 26
        height: 32
        radius: 16
        color: Colors.primary

        CustomText {
            id: spanLabel
            anchors.centerIn: parent
            content: root.cols + " × " + root.rows
            size: 13
            weight: 700
            customColor: Colors.primaryText
        }
    }
}
