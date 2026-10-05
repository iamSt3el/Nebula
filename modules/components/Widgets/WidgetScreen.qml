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
        function edit(): void { GlobalStates.widgetEditMode = true }
        function close(): void { GlobalStates.widgetEditMode = false }
        function toggle(): void { GlobalStates.widgetEditMode = !GlobalStates.widgetEditMode }
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
    MouseArea {
        id: rippleArea
        anchors.fill: parent
        z: -3
        enabled: (SettingsConfig.general.desktopRipple ?? false) && !GlobalStates.widgetEditMode
        acceptedButtons: Qt.AllButtons
        property point last: Qt.point(0, 0)
        onPressed: mouse => {
            GlobalStates.desktopClicked(widgetScreen.screen?.name ?? "", mouse.x, mouse.y)
            rippleArea.last = Qt.point(mouse.x, mouse.y)
            mouse.accepted = mouse.button === Qt.LeftButton && (SettingsConfig.general.desktopRippleDrag ?? true)
        }
        onPositionChanged: mouse => {
            const dx = mouse.x - rippleArea.last.x
            const dy = mouse.y - rippleArea.last.y
            if (dx * dx + dy * dy < 8100)
                return
            rippleArea.last = Qt.point(mouse.x, mouse.y)
            GlobalStates.desktopDragged(widgetScreen.screen?.name ?? "", mouse.x, mouse.y)
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
            onClicked: {
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

    // Esc leaves arrange mode
    Item {
        anchors.fill: parent
        focus: GlobalStates.widgetEditMode
        Keys.onEscapePressed: {
            if (studio.closePop()) return
            if (GlobalStates.widgetSettingsKey !== "") GlobalStates.widgetSettingsKey = ""
            else GlobalStates.widgetEditMode = false
        }
        Keys.onPressed: event => {
            if (!(event.modifiers & Qt.ControlModifier))
                return
            if (event.key === Qt.Key_Z && (event.modifiers & Qt.ShiftModifier)) studio.redo()
            else if (event.key === Qt.Key_Z) studio.undo()
            else if (event.key === Qt.Key_Y) studio.redo()
            else return
            event.accepted = true
        }
    }

    Item {
        id: stage
        width: GlobalStates.widgetScreenSize.x
        height: GlobalStates.widgetScreenSize.y

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

        Loader {
            active: SettingsConfig.widgets.showDateWidget ?? false
            visible: active
            sourceComponent: {
                var style = SettingsConfig.widgets.dateWidgetStyle ?? "bold"
                if (style === "accent") return dateAccent
                if (style === "shape")  return dateShape
                return dateBold
            }
        }

        Component { id: dateShape;  DateWidgetShape  {} }
        Component { id: dateBold;   DateWidgetBold   {} }
        Component { id: dateAccent; DateWidgetAccent {} }

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
            active: SettingsConfig.widgets.showWeatherForecast ?? false
            visible: active
            sourceComponent: WeatherWidgetForecast {}
        }

        Loader {
            active: SettingsConfig.widgets.showWeatherHourly ?? false
            visible: active
            sourceComponent: WeatherHourlyWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showClaudeCode ?? false
            visible: active
            sourceComponent: ClaudeCodeWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSunArc ?? false
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
            active: SettingsConfig.widgets.showCalendarTorn ?? false
            visible: active
            sourceComponent: CalendarTornWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showCalendarWindows ?? false
            visible: active
            sourceComponent: CalendarWindowsWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showCalendarDaylight ?? false
            visible: active
            sourceComponent: CalendarDaylightWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showCalendarYear ?? false
            visible: active
            sourceComponent: CalendarYearWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showCalendarStamp ?? false
            visible: active
            sourceComponent: CalendarStampWidget {}
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
            sourceComponent: {
                var style = SettingsConfig.widgets.systemMonitorStyle ?? "default"
                if (style === "compact") return sysCompact
                if (style === "pulse")   return sysPulse
                return sysDefault
            }
        }

        Component { id: sysDefault; SystemMonitorWidget  {} }
        Component { id: sysCompact; SystemMonitorCompact {} }
        Component { id: sysPulse;   SystemMonitorPulse   {} }

        Loader {
            active: SettingsConfig.widgets.showBattery ?? false
            visible: active
            sourceComponent: (SettingsConfig.widgets.batteryStyle ?? "ring") === "shape"
                ? battShape : battRing
        }

        Component { id: battShape; BatteryWidgetShape {} }
        Component { id: battRing;  BatteryWidgetRing  {} }

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
            active: SettingsConfig.widgets.showMoonPhase ?? false
            visible: active
            sourceComponent: MoonPhaseWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showStickyNote ?? false
            visible: active
            sourceComponent: StickyNoteWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showHeadlines ?? false
            visible: active
            sourceComponent: HeadlinesWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showTaskList ?? false
            visible: active
            sourceComponent: TaskListWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showCommitGarden ?? false
            visible: active
            sourceComponent: CommitGardenWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showNotebook ?? false
            visible: active
            sourceComponent: NotebookWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showTerminalStats ?? false
            visible: active
            sourceComponent: TerminalStatsWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMostOpened ?? false
            visible: active
            sourceComponent: MostOpenedWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showYearAgo ?? false
            visible: active
            sourceComponent: YearAgoWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showPhone ?? false
            visible: active
            sourceComponent: PhoneWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showHabits ?? false
            visible: active
            sourceComponent: HabitsWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showCountdowns ?? false
            visible: active
            sourceComponent: CountdownsWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMood ?? false
            visible: active
            sourceComponent: MoodWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showNetworkGraph ?? false
            visible: active
            sourceComponent: NetworkGraphWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysCockpit ?? false
            visible: active
            sourceComponent: SysCockpitWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysBlueprint ?? false
            visible: active
            sourceComponent: SysBlueprintWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysVitals ?? false
            visible: active
            sourceComponent: SysVitalsWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysForecast ?? false
            visible: active
            sourceComponent: SysForecastWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysFlask ?? false
            visible: active
            sourceComponent: SysFlaskWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showLavaLamp ?? false
            visible: active
            sourceComponent: LavaLampWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysThermo ?? false
            visible: active
            sourceComponent: SysThermoWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysCreature ?? false
            visible: active
            sourceComponent: SysCreatureWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showDayRibbon ?? false
            visible: active
            sourceComponent: DayRibbonWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysCells ?? false
            visible: active
            sourceComponent: SysCellsWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysShape ?? false
            visible: active
            sourceComponent: SysShapeWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysHourglass ?? false
            visible: active
            sourceComponent: SysHourglassWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showSysFillNumber ?? false
            visible: active
            sourceComponent: SysFillNumberWidget {}
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
            active: SettingsConfig.widgets.showMusicPoster ?? false
            visible: active
            sourceComponent: MusicPosterWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicTuner ?? false
            visible: active
            sourceComponent: MusicTunerWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicWaveform ?? false
            visible: active
            sourceComponent: MusicWaveformWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicSpectrum ?? false
            visible: active
            sourceComponent: MusicSpectrumWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicLyrics ?? false
            visible: active
            sourceComponent: MusicLyricsWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicCapsule ?? false
            visible: active
            sourceComponent: MusicCapsuleWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicGlance ?? false
            visible: active
            sourceComponent: MusicGlanceWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicFlap ?? false
            visible: active
            sourceComponent: MusicFlapWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicBento ?? false
            visible: active
            sourceComponent: MusicBentoWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicRibbon ?? false
            visible: active
            sourceComponent: MusicRibbonWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicNeon ?? false
            visible: active
            sourceComponent: MusicNeonWidget {}
        }

        Loader {
            active: SettingsConfig.widgets.showMusicTerminal ?? false
            visible: active
            sourceComponent: MusicTerminalWidget {}
        }




        Loader {
            active: SettingsConfig.widgets.showWeatherShape ?? false
            visible: active
            sourceComponent: WeatherShapeWidget {}
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
