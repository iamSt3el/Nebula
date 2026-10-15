import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

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
    // Variants of one family share a key (all date styles use "dateWidget"),
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

    property bool resizing: false
    property int _dragCols: 0
    property real _dragRows: 0

    readonly property bool _loadsSpan: _persists && resizable
    readonly property int _savedCols: _loadsSpan ? (SettingsConfig.widgets[configKey + "W"] ?? defaultSpan.width) : defaultSpan.width
    readonly property real _savedRows: _loadsSpan ? (SettingsConfig.widgets[configKey + "H"] ?? defaultSpan.height) : defaultSpan.height

    readonly property int cols: Math.max(minSpan.width,
                                         Math.min(maxSpan.width, resizing ? _dragCols : _savedCols))
    readonly property real rows: Math.max(minSpan.height,
                                          Math.min(maxSpan.height, resizing ? _dragRows : _savedRows))

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
        enabled: root.lifted && !root.dragging
        SpatialAnim {}
    }

    Behavior on y {
        enabled: root.lifted && !root.dragging
        SpatialAnim {}
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
        if (minSpan.width < maxSpan.width) patch[configKey + "W"] = root.cols
        if (minSpan.height < maxSpan.height) patch[configKey + "H"] = root.rows
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
        border.width: active || root.selected ? 2.5 : 1
        border.color: active || root.selected ? Colors.primary
            : Qt.alpha(Colors.surfaceText, 0.16 + 0.5 * (1 - settle))
    }

    Repeater {
        model: !(root.selected && root.lifted && !root.dragging) ? []
            : root.resizable && !root.locked ? [Qt.point(0, 0), Qt.point(1, 0), Qt.point(0, 1)]
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
                const c = Math.max(root.minSpan.width, Math.min(root.maxSpan.width, roomC,
                                   WidgetSizes.cellsFor(startW + (p.x - start.x) / s)))
                const r = Math.max(root.minSpan.height, Math.min(root.maxSpan.height, roomR,
                                   WidgetSizes.rowsFor(startH + (p.y - start.y) / s)))
                const fit = WidgetLayout.fitSpan(root, root.x, root.y, c, r,
                                                 root.minSpan.width, root.minSpan.height)
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
