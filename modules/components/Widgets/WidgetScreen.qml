import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

PanelWindow{
    id: widgetScreen
    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true

    // Normally parked behind windows. Arrange mode has to come forward and take
    // the keyboard, otherwise the widgets are unreachable and Esc never arrives.
    WlrLayershell.namespace: "quickshell:backgroundWidgets"
    readonly property bool arranging: GlobalStates.widgetEditMode && !GlobalStates.fileDialogOpen
    WlrLayershell.layer: widgetScreen.arranging ? WlrLayer.Top : WlrLayer.Bottom

    // Three states rather than two. A layer surface with None can be clicked but
    // never receives key events, so text fields were untypable; leaving it on
    // OnDemand permanently meant the surface kept the keyboard and no other
    // window could be typed into. So: ask for the keyboard only while a widget
    // text field actually holds focus, and drop straight back to None after.
    WlrLayershell.keyboardFocus: widgetScreen.arranging       ? WlrKeyboardFocus.Exclusive
                               : GlobalStates.widgetTextFocus ? WlrKeyboardFocus.OnDemand
                                                              : WlrKeyboardFocus.None

    IpcHandler {
        target: "widgets"
        function edit(): void { GlobalStates.openEdit("desktop") }
        function close(): void { GlobalStates.closeEdit() }
        function toggle(): void { GlobalStates.toggleEdit("desktop") }
    }

    HoverHandler {
        onPointChanged: {
            GlobalStates.desktopCursorX = point.position.x
            GlobalStates.desktopCursorY = point.position.y
        }
        onHoveredChanged: GlobalStates.desktopCursorActive = hovered
    }

    // Parking spot for focus. Clicking empty desktop moves QML focus here, which
    // makes the text field report activeFocus false and releases the keyboard.
    Item { id: focusSink }

    // Sits under everything: a click that a widget already consumed never
    // reaches it, so only clicks on bare desktop drop the field's focus.
    MouseArea {
        anchors.fill: parent
        z: -2
        enabled: GlobalStates.widgetTextFocus && !GlobalStates.widgetEditMode
        onPressed: mouse => {
            focusSink.forceActiveFocus()
            mouse.accepted = false
        }
    }
    color: "transparent"

    Item {
        width: 0
        height: 0
        clip: true

        Image {
            id: backdropRaw
            width: widgetScreen.width
            height: widgetScreen.height
            source: WallpaperTheme.wallpaperScreen !== "" ? "file://" + WallpaperTheme.wallpaperScreen : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 1280
            sourceSize.height: 720
            asynchronous: true
            cache: false

            Rectangle {
                anchors.fill: parent
                visible: KindleMode.wallpaper === "blank"
                color: Colors.surfaceContainer
            }
        }

        ShaderEffectSource {
            id: backdropSharp
            width: widgetScreen.width
            height: widgetScreen.height
            textureSize: Qt.size(1280, 720)
            sourceItem: backdropRaw
            hideSource: true
            live: true
        }

        MultiEffect {
            id: backdropBlur
            source: backdropSharp
            width: widgetScreen.width
            height: widgetScreen.height
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: -0.1
        }
    }

    Component.onCompleted: {
        GlobalStates.widgetBackdrop = backdropBlur
        GlobalStates.widgetBackdropSharp = backdropSharp
    }
    Component.onDestruction: {
        GlobalStates.widgetBackdrop = null
        GlobalStates.widgetBackdropSharp = null
    }

    onWidthChanged: GlobalStates.widgetScreenSize = Qt.vector2d(width, height)
    onHeightChanged: GlobalStates.widgetScreenSize = Qt.vector2d(width, height)

    // ── Arrange mode: grid + scrim, behind the widgets ────────────────
    readonly property real reveal: GlobalStates.widgetEditReveal
    readonly property real scrimT: Math.max(0, Math.min(1, widgetScreen.reveal * 2.5))

    Rectangle {
        anchors.fill: parent
        z: -1
        visible: widgetScreen.reveal > 0.001
        color: Qt.alpha(Colors.surface, 0.45 * widgetScreen.scrimT)

        ClippingRectangle {
            id: canvasFace
            x: studio.stageX
            y: studio.stageY
            width: GlobalStates.widgetScreenSize.x * studio.stageScale
            height: GlobalStates.widgetScreenSize.y * studio.stageScale
            visible: studio.studioT > 0.01
            opacity: studio.studioT
            radius: studio.stageScale < 0.999 ? 20 * studio.studioT : 0
            color: Colors.surfaceContainerLowest

            Image {
                anchors.fill: parent
                source: WallpaperTheme.wallpaperScreen !== "" ? "file://" + WallpaperTheme.wallpaperScreen : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 1600
                sourceSize.height: 900
                asynchronous: true
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Colors.scrim, 0.16)
            }

            readonly property bool holes: canvasFace.visible && studio.stageScale > 0.999 && GlobalStates.editEdgeRects.length > 0
                && (GlobalStates.editEdgeScreen === "" || (widgetScreen.screen?.name ?? "") === GlobalStates.editEdgeScreen)
            layer.enabled: canvasFace.holes
            layer.effect: MultiEffect {
                maskEnabled: true
                maskInverted: true
                maskSource: edgeHoles
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }

        Item {
            id: edgeHoles
            x: canvasFace.x
            y: canvasFace.y
            width: canvasFace.width
            height: canvasFace.height
            visible: false
            layer.enabled: canvasFace.holes

            Repeater {
                model: canvasFace.holes ? GlobalStates.editEdgeRects : []

                Rectangle {
                    required property rect modelData
                    x: modelData.x
                    y: modelData.y
                    width: modelData.width
                    height: modelData.height
                    color: "white"
                }
            }
        }

        Rectangle {
            x: canvasFace.x
            y: canvasFace.y
            width: canvasFace.width
            height: canvasFace.height
            visible: canvasFace.visible && studio.stageScale < 0.999
            opacity: studio.studioT
            radius: canvasFace.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Colors.outline, 0.35)
        }

        MouseArea {
            anchors.fill: parent
            enabled: GlobalStates.widgetEditMode
            onClicked: mouse => {
                if (widgetScreen.edgeAt(mouse.x, mouse.y)) {
                    GlobalStates.editLayer = "edges"
                    return
                }
                studio.pop = ""
                GlobalStates.widgetSettingsKey = ""
                GlobalStates.widgetQuickAdd = Qt.point(-1, -1)
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: GlobalStates.widgetEditMode

            transform: [
                Scale {
                    origin.x: 0
                    origin.y: 0
                    xScale: studio.stageScale
                    yScale: studio.stageScale
                },
                Translate {
                    x: studio.stageX
                    y: studio.stageY
                }
            ]

            onClicked: mouse => {
                const sp = mapToItem(widgetScreen.contentItem, mouse.x, mouse.y)
                if (widgetScreen.edgeAt(sp.x, sp.y)) {
                    GlobalStates.editLayer = "edges"
                    return
                }
                GlobalStates.widgetSettingsKey = ""
                if (studio.closePop()) {
                    GlobalStates.widgetQuickAdd = Qt.point(-1, -1)
                    return
                }
                const S = WidgetSizes
                const c = Math.floor((mouse.x - S.originX) / S.pitch)
                const r = Math.floor((mouse.y - S.originY) / S.pitch)
                const inGrid = c >= 0 && r >= 0 && c < S.gridCols && r < S.gridRows
                    && (mouse.x - S.originX) - c * S.pitch <= S.cell
                    && (mouse.y - S.originY) - r * S.pitch <= S.cell
                const free = inGrid && WidgetLayout.isFree(null, S.originX + c * S.pitch,
                                                           S.originY + r * S.pitch, S.cell, S.cell)
                GlobalStates.widgetQuickAdd = free ? Qt.point(c, r * 2) : Qt.point(-1, -1)
            }
        }

        // The pass of light itself: one band travelling left to right, its x driven
        // by the same reveal the cells read, so the lighting always matches the edge.
        Rectangle {
            id: sweepBand
            readonly property real band: M3Motion.reveal.band
            width: parent.width * sweepBand.band
            height: parent.height
            x: -sweepBand.width + widgetScreen.reveal * (parent.width + sweepBand.width)
            visible: widgetScreen.reveal > 0.001 && widgetScreen.reveal < 0.999
            opacity: Math.min(1, Math.min(widgetScreen.reveal, 1 - widgetScreen.reveal) * 8)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;  color: "transparent" }
                GradientStop { position: 0.55; color: Qt.alpha(Colors.primary, 0.20) }
                GradientStop { position: 1.0;  color: "transparent" }
            }
        }

        Canvas {
            id: gridCanvas
            anchors.fill: parent

            transform: [
                Scale {
                    origin.x: 0
                    origin.y: 0
                    xScale: studio.stageScale
                    yScale: studio.stageScale
                },
                Translate {
                    x: studio.stageX
                    y: studio.stageY
                }
            ]

            property color inkColor: Colors.surfaceText
            property color liveColor: Colors.primary
            property real reveal: widgetScreen.reveal
            property var geometry: [WidgetSizes.originX, WidgetSizes.originY,
                                    WidgetSizes.gridCols, WidgetSizes.gridRows]
            onInkColorChanged: requestPaint()
            onRevealChanged: requestPaint()
            onGeometryChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()

                const p = WidgetSizes.pitch
                const g = WidgetSizes.gutter
                const band = M3Motion.reveal.band
                const edge = gridCanvas.reveal * (1 + band)

                for (let i = 0; i <= WidgetSizes.gridCols; i++) {
                    const x = WidgetSizes.originX + i * p - g / 2
                    const nx = x / Math.max(1, gridCanvas.width)
                    const t = Math.max(0, Math.min(1, (edge - nx) / band))
                    if (t <= 0.001)
                        continue

                    const settle = Math.max(0, Math.min(1, (t - 0.45) / 0.55))
                    const lit = Qt.rgba(liveColor.r + (inkColor.r - liveColor.r) * settle,
                                        liveColor.g + (inkColor.g - liveColor.g) * settle,
                                        liveColor.b + (inkColor.b - liveColor.b) * settle,
                                        1)
                    ctx.fillStyle = Qt.alpha(lit, 0.30 + 0.45 * (1 - settle) * t)
                    const r = 1.4 + 0.8 * (1 - settle) * t

                    for (let j = 0; j <= WidgetSizes.gridRows; j++) {
                        const y = WidgetSizes.originY + j * p - g / 2
                        ctx.beginPath()
                        ctx.arc(x, y, r, 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
            }
        }
    }

    function edgeAt(x, y) {
        if (GlobalStates.editEdgeScreen !== "" && (widgetScreen.screen?.name ?? "") !== GlobalStates.editEdgeScreen)
            return false
        for (const r of GlobalStates.editEdgeRects)
            if (x >= r.x && x <= r.x + r.width && y >= r.y && y <= r.y + r.height)
                return true
        return false
    }

    function screenHosts() {
        return WidgetLayout.hosts.filter(h => h && h.visible && h.configKey !== "" && !h.preview
                                         && h.Window.window === editKeys.Window.window)
    }

    function selectedHost() {
        const k = GlobalStates.widgetSettingsKey
        return k === "" ? null : (widgetScreen.screenHosts().find(h => h.configKey === k) ?? null)
    }

    function cycleWidget(dir) {
        const hs = widgetScreen.screenHosts().sort((a, b) => a.homeY - b.homeY || a.homeX - b.homeX)
        if (hs.length === 0)
            return
        const cur = hs.findIndex(h => h.configKey === GlobalStates.widgetSettingsKey)
        const next = cur < 0 ? (dir > 0 ? 0 : hs.length - 1) : (cur + dir + hs.length) % hs.length
        GlobalStates.widgetSettingsKey = hs[next].configKey
    }

    function nearestWidget(dx, dy) {
        const cur = widgetScreen.selectedHost()
        if (!cur) {
            widgetScreen.cycleWidget(1)
            return
        }
        const cx = cur.homeX + cur.width / 2
        const cy = cur.homeY + cur.height / 2
        let best = null
        let bestD = 1e9
        for (const h of widgetScreen.screenHosts()) {
            if (h === cur)
                continue
            const vx = h.homeX + h.width / 2 - cx
            const vy = h.homeY + h.height / 2 - cy
            const along = vx * dx + vy * dy
            if (along <= 1)
                continue
            const across = Math.abs(vx * dy - vy * dx)
            const d = along + across * 2
            if (d < bestD) {
                bestD = d
                best = h
            }
        }
        if (best)
            GlobalStates.widgetSettingsKey = best.configKey
    }

    function nudgeWidget(dx, dy) {
        const h = widgetScreen.selectedHost()
        if (!h || h.locked)
            return
        const p = WidgetSizes.pitch
        const nx = WidgetSizes.snapX(h.homeX + dx * p, h.width)
        const ny = WidgetSizes.snapY(h.homeY + dy * p, h.height)
        if ((nx === h.homeX && ny === h.homeY) || !WidgetLayout.isFree(h, nx, ny, h.width, h.height))
            return
        const patch = {}
        patch[h.configKey + "X"] = nx
        patch[h.configKey + "Y"] = ny
        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, patch)
    }

    function toggleLock() {
        const h = widgetScreen.selectedHost()
        if (!h)
            return
        const patch = {}
        patch[h.configKey + "Locked"] = !h.locked
        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, patch)
    }

    Connections {
        target: studioLoader.item
        ignoreUnknownSignals: true
        function onPopChanged() {
            if (GlobalStates.widgetEditMode && studio.pop === "")
                editKeys.forceActiveFocus()
        }
    }

    Item {
        id: editKeys
        anchors.fill: parent
        focus: GlobalStates.widgetEditMode
        onFocusChanged: if (focus) editKeys.forceActiveFocus()
        Keys.onEscapePressed: {
            if (studio.closePop()) return
            if (GlobalStates.widgetSettingsKey !== "") GlobalStates.widgetSettingsKey = ""
            else GlobalStates.closeEdit()
        }
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Space && !event.isAutoRepeat) {
                EditSession.peek = false
                event.accepted = true
            }
        }
        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier
            const alt = event.modifiers & Qt.AltModifier
            const shift = event.modifiers & Qt.ShiftModifier
            const k = event.key
            if (ctrl) {
                if (k === Qt.Key_Z && shift) EditSession.redo()
                else if (k === Qt.Key_Z) EditSession.undo()
                else if (k === Qt.Key_Y) EditSession.redo()
                else if (k === Qt.Key_S) GlobalStates.closeEdit()
                else return
                event.accepted = true
                return
            }
            if (k === Qt.Key_Space) {
                if (!event.isAutoRepeat) EditSession.peek = true
            } else if (k === Qt.Key_Question || k === Qt.Key_Slash) {
                GlobalStates.editKeysOpen = !GlobalStates.editKeysOpen
            } else if (k === Qt.Key_1) {
                GlobalStates.editLayer = "edges"
            } else if (k === Qt.Key_2) {
                GlobalStates.editLayer = "desktop"
            } else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
                widgetScreen.cycleWidget(k === Qt.Key_Backtab || shift ? -1 : 1)
            } else if (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Up || k === Qt.Key_Down) {
                const dx = k === Qt.Key_Left ? -1 : k === Qt.Key_Right ? 1 : 0
                const dy = k === Qt.Key_Up ? -1 : k === Qt.Key_Down ? 1 : 0
                if (alt) widgetScreen.nudgeWidget(dx, dy)
                else widgetScreen.nearestWidget(dx, dy)
            } else if (k === Qt.Key_Delete) {
                const key = GlobalStates.widgetSettingsKey
                if (key === "") return
                studio.pop = ""
                GlobalStates.widgetSettingsKey = ""
                WidgetCatalog.remove(key)
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                if (GlobalStates.widgetSettingsKey !== "") studio.pop = studio.pop === "options" ? "" : "options"
            } else if (k === Qt.Key_L) {
                widgetScreen.toggleLock()
            } else if (k === Qt.Key_T) {
                const t = studio.target
                if (t && t.turnable && !t.locked) t.turn()
            } else if (k === Qt.Key_A) {
                GlobalStates.widgetSettingsKey = ""
                studio.pop = "add"
            } else {
                return
            }
            event.accepted = true
        }
    }

    Item {
        id: stage
        width: GlobalStates.widgetScreenSize.x
        height: GlobalStates.widgetScreenSize.y
        opacity: GlobalStates.barEditMode && !EditSession.peek ? 0.4 : 1
        Behavior on opacity { EffectsAnim { speed: "default" } }

        layer.enabled: studio.studioT > 0.01 && studio.stageScale < 0.999
        layer.smooth: true

        transform: [
            Scale {
                origin.x: 0
                origin.y: 0
                xScale: studio.stageScale
                yScale: studio.stageScale
            },
            Translate {
                x: studio.stageX
                y: studio.stageY
            }
        ]

        Loader {
            active: SettingsConfig.widgets.showClock ?? false
            visible: active
            sourceComponent: {
                switch (SettingsConfig.widgets.digitalClockStyle ?? "veil") {
                case "bloom":
                case "shapes":    return clockBloom
                case "orbit":     return clockOrbit
                case "script":    return clockScript
                case "stack":
                case "stacked":   return clockStack
                case "condensed": return clockCondensed
                case "display":   return clockDisplay
                default:          return clockVeil
                }
            }
        }

        Component { id: clockVeil;      ClockVeil      {} }
        Component { id: clockBloom;     ClockBloom     {} }
        Component { id: clockOrbit;     ClockOrbit     {} }
        Component { id: clockScript;    ClockScript    {} }
        Component { id: clockStack;     ClockStack     {} }
        Component { id: clockCondensed; ClockCondensed {} }
        Component { id: clockDisplay;   ClockDisplay   {} }

        Loader {
            active: SettingsConfig.widgets.showAnalogClock ?? false
            visible: active
            sourceComponent: {
                var style = SettingsConfig.widgets.analogClockStyle ?? "classic"
                if (style === "minimal") return analogMinimal
                if (style === "shape")   return analogShape
                return analogClassic
            }
        }

        Component { id: analogClassic; AnalogClockClassic {} }
        Component { id: analogMinimal; AnalogClockMinimal {} }
        Component { id: analogShape;   AnalogClockShape   {} }

        Loader {
            active: Features.widgetOn("showWeatherHourly") && (SettingsConfig.widgets.showWeatherHourly ?? false)
            visible: active
            sourceComponent: WeatherHourlyWidget {}
        }

        Loader {
            active: Features.widgetOn("showWeatherPoster") && (SettingsConfig.widgets.showWeatherPoster ?? false)
            visible: active
            sourceComponent: WeatherPosterWidget {}
        }

        Loader {
            active: Features.widgetOn("showWeatherHours") && (SettingsConfig.widgets.showWeatherHours ?? false)
            visible: active
            sourceComponent: WeatherHoursWidget {}
        }

        Loader {
            active: Features.widgetOn("showWeatherDayClock") && (SettingsConfig.widgets.showWeatherDayClock ?? false)
            visible: active
            sourceComponent: WeatherDayClockWidget {}
        }

        Loader {
            active: Features.widgetOn("showWeatherWind") && (SettingsConfig.widgets.showWeatherWind ?? false)
            visible: active
            sourceComponent: WeatherWindWidget {}
        }

        Loader {
            active: Features.widgetOn("showWeatherTileHourly") && (SettingsConfig.widgets.showWeatherTileHourly ?? false)
            visible: active
            sourceComponent: WeatherTileHourly {}
        }

        Loader {
            active: Features.widgetOn("showWeatherTileThermo") && (SettingsConfig.widgets.showWeatherTileThermo ?? false)
            visible: active
            sourceComponent: WeatherTileThermo {}
        }

        Loader {
            active: Features.widgetOn("showWeatherTileDays") && (SettingsConfig.widgets.showWeatherTileDays ?? false)
            visible: active
            sourceComponent: WeatherTileDays {}
        }

        Loader {
            active: Features.widgetOn("showWeatherTileWeek") && (SettingsConfig.widgets.showWeatherTileWeek ?? false)
            visible: active
            sourceComponent: WeatherTileWeek {}
        }

        Loader {
            active: Features.widgetOn("showWeatherTileStats") && (SettingsConfig.widgets.showWeatherTileStats ?? false)
            visible: active
            sourceComponent: WeatherTileStats {}
        }

        Loader {
            active: Features.widgetOn("showWeatherTileMini") && (SettingsConfig.widgets.showWeatherTileMini ?? false)
            visible: active
            sourceComponent: WeatherTileMini {}
        }

        Loader {
            active: Features.widgetOn("showWeatherTileSky") && (SettingsConfig.widgets.showWeatherTileSky ?? false)
            visible: active
            sourceComponent: WeatherTileSky {}
        }

        Loader {
            active: Features.widgetOn("showWeatherTileList") && (SettingsConfig.widgets.showWeatherTileList ?? false)
            visible: active
            sourceComponent: WeatherTileList {}
        }

        Loader {
            active: Features.widgetOn("showClaudeCode") && (SettingsConfig.widgets.showClaudeCode ?? false)
            visible: active
            sourceComponent: ClaudeCodeWidget {}
        }

        Loader {
            active: Features.widgetOn("showSunArc") && (SettingsConfig.widgets.showSunArc ?? false)
            visible: active
            sourceComponent: SunArcWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showCalendarMini ?? false
            visible: active
            sourceComponent: CalendarMiniWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showCalendarYarn ?? false
            visible: active
            sourceComponent: CalendarYarnWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showCalendarAlmanac ?? false
            visible: active
            sourceComponent: CalendarAlmanacWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showCalendarWindows ?? false
            visible: active
            sourceComponent: CalendarWindowsWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showCalendarYear ?? false
            visible: active
            sourceComponent: CalendarYearWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showCalendarMoon ?? false
            visible: active
            sourceComponent: CalendarMoonWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showPomodoro ?? false
            visible: active
            sourceComponent: PomodoroWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSystemMonitor ?? false
            visible: active
            sourceComponent: SystemMonitorPulse {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysCores ?? false
            visible: active
            sourceComponent: SysCoresWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysQuad ?? false
            visible: active
            sourceComponent: SysQuadWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysChrono ?? false
            visible: active
            sourceComponent: SysChronoWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysSilhouette ?? false
            visible: active
            sourceComponent: SysSilhouetteWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysMemory ?? false
            visible: active
            sourceComponent: SysMemoryWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysBattery ?? false
            visible: active
            sourceComponent: SysBatteryWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysThermals ?? false
            visible: active
            sourceComponent: SysThermalsWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysNet ?? false
            visible: active
            sourceComponent: SysNetWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysOrbit ?? false
            visible: active
            sourceComponent: SysOrbitWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showProfileBadge ?? false
            visible: active
            sourceComponent: ProfileBadgeWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showProfileDay ?? false
            visible: active
            sourceComponent: ProfileDayWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showProfileStatus ?? false
            visible: active
            sourceComponent: ProfileStatusWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showProfileMachine ?? false
            visible: active
            sourceComponent: ProfileMachineWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showProfileShape ?? false
            visible: active
            sourceComponent: ProfileShapeWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showProfileRings ?? false
            visible: active
            sourceComponent: ProfileRingsWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showStickyNote ?? false
            visible: active
            sourceComponent: StickyNoteWidget {}
        }

        Loader {
            active: Features.widgetOn("showHeadlines") && (SettingsConfig.widgets.showHeadlines ?? false)
            visible: active
            sourceComponent: HeadlinesWidget {}
        }

        Loader {
            active: Features.widgetOn("showYearAgo") && (SettingsConfig.widgets.showYearAgo ?? false)
            visible: active
            sourceComponent: YearAgoWidget {}
        }

        Loader {
            active: Features.widgetOn("showPhone") && (SettingsConfig.widgets.showPhone ?? false)
            visible: active
            sourceComponent: PhoneWidget {}
        }

        Loader {
            active: Features.widgetOn("showCountdowns") && (SettingsConfig.widgets.showCountdowns ?? false)
            visible: active
            sourceComponent: CountdownsWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicExpressive ?? false
            visible: active
            sourceComponent: MusicExpressiveWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicTicket ?? false
            visible: active
            sourceComponent: MusicTicketWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicDisc ?? false
            visible: active
            sourceComponent: MusicDiscWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicDeck ?? false
            visible: active
            sourceComponent: MusicDeckWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicRail ?? false
            visible: active
            sourceComponent: MusicRailWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicPulse ?? false
            visible: active
            sourceComponent: MusicPulseWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showWorldClock ?? false
            visible: active
            sourceComponent: WorldClockWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showPhotoFrame ?? false
            visible: active
            sourceComponent: PhotoFrameWidget {}
        }
    }

    WidgetFlight {
        anchors.fill: stage
        stageItem: stage
    }

    readonly property var studio: studioLoader.item ?? studioIdle

    QtObject {
        id: studioIdle
        readonly property real stageScale: 1
        readonly property real stageX: 0
        readonly property real stageY: 0
        readonly property real studioT: 0
        property string pop: ""
        function closePop() { return false }
        function undo() {}
        function redo() {}
    }

    Loader {
        id: studioLoader
        anchors.fill: parent
        z: 20
        active: false
        Component.onCompleted: if (GlobalStates.widgetEditMode) studioLoader.active = true
        sourceComponent: WidgetStudio {}
    }

    Timer {
        id: studioUnload
        interval: 10000
        onTriggered: if (!GlobalStates.widgetEditMode) studioLoader.active = false
    }

    WidgetQuickAdd {
        z: 25
    }

    Connections {
        target: GlobalStates
        function onWidgetEditModeChanged() {
            if (!GlobalStates.widgetEditMode) {
                GlobalStates.widgetSettingsKey = ""
                studioUnload.restart()
            } else {
                studioUnload.stop()
                studioLoader.active = true
            }
        }
    }

}
