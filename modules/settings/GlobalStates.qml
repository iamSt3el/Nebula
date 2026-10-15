import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton{
    id: root
    property bool appLauncherOpen: false
    property bool launcherHosted: false
    property bool launcherPreview: false
    property string panelPreview: ""
    property real previewInsetLeft: 0
    property real previewInsetRight: 0
    property bool clipboardOpen: false
    property var dockIconItems: ({})
    property int dockIconsVersion: 0
    property string notifLiftApp: ""
    property bool dockPeek: false
    property var notifBadges: ({})

    function registerDockIcon(appId, item) {
        const k = (appId ?? "").toLowerCase()
        if (k === "") return
        const list = root.dockIconItems[k] ?? []
        if (list.indexOf(item) < 0) list.push(item)
        root.dockIconItems[k] = list
        root.dockIconsVersion++
    }

    function unregisterDockIcon(appId, item) {
        const k = (appId ?? "").toLowerCase()
        const list = (root.dockIconItems[k] ?? []).filter(i => i !== item)
        if (list.length > 0) root.dockIconItems[k] = list
        else delete root.dockIconItems[k]
        root.dockIconsVersion++
    }

    function dockIconIn(key, near) {
        const list = root.dockIconItems[key] ?? []
        const win = near ? near.Window.window : null
        return list.find(i => i && i.visible && (!win || i.Window.window === win)) ?? null
    }
    property bool settingsOpen: false
    property int  settingsPage: 9
    property bool editMode: false
    property string editLayer: "edges"
    readonly property bool widgetEditMode: root.editMode && root.editLayer === "desktop"
    property bool editKeysOpen: false
    property string editOpenAdd: ""
    property string editAddQuery: ""
    property var editEdgeRects: []
    property string editEdgeScreen: ""
    property real editTopInset: 0

    function openEdit(layer) {
        if (layer)
            root.editLayer = layer
        root.editMode = true
    }

    function closeEdit() {
        root.editMode = false
    }

    function toggleEdit(layer) {
        if (root.editMode && (!layer || root.editLayer === layer))
            root.closeEdit()
        else
            root.openEdit(layer)
    }

    onEditModeChanged: {
        if (root.editMode)
            return
        root.editKeysOpen = false
        root.editOpenAdd = ""
        root.editAddQuery = ""
    }
    // Blueprint sweep for widget arrange mode: 0 = off, 1 = fully revealed. Every
    // consumer (grid canvas, scrim, hint bar, each widget's chrome) derives its own
    // local progress from this one number and its own x, so they cannot drift apart.
    property real widgetEditReveal: root.widgetEditMode && !EditSession.peek ? 1 : 0
    Behavior on widgetEditReveal {
        NumberAnimation {
            duration: root.widgetEditMode && !EditSession.peek ? (EditSession.peeked ? M3Motion.reveal.outDuration : M3Motion.reveal.duration) : M3Motion.reveal.outDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: M3Motion.reveal.curve
        }
    }

    function revealAt(centreX, screenW) {
        const r = root.widgetEditReveal
        if (screenW <= 0)
            return r
        const band = M3Motion.reveal.band
        const nx = centreX / screenW
        return Math.max(0, Math.min(1, (r * (1 + band) - nx) / band))
    }
    readonly property bool barEditMode: root.editMode && root.editLayer !== "desktop"
    // Same blueprint sweep as widget arrange mode, so both edit modes read as one idea.
    property real barEditReveal: root.barEditMode && !EditSession.peek ? 1 : 0
    Behavior on barEditReveal {
        NumberAnimation {
            duration: root.barEditMode && !EditSession.peek ? (EditSession.peeked ? M3Motion.reveal.outDuration : M3Motion.reveal.duration) : M3Motion.reveal.outDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: M3Motion.reveal.curve
        }
    }

    function barRevealAt(centreX, screenW) {
        const r = root.barEditReveal
        if (screenW <= 0)
            return r
        const band = M3Motion.reveal.band
        const nx = centreX / screenW
        return Math.max(0, Math.min(1, (r * (1 + band) - nx) / band))
    }
    property bool dockPresent: true
    property string widgetSettingsKey: ""
    property int widgetSection: 0
    property string widgetStudioTab: "layout"
    property real widgetStageScale: 1
    property point widgetStageOrigin: Qt.point(0, 0)
    property point widgetQuickAdd: Qt.point(-1, -1)
    property bool widgetOpenAdd: false

    onWidgetEditModeChanged: {
        if (root.widgetEditMode)
            return
        root.widgetQuickAdd = Qt.point(-1, -1)
        root.widgetOpenAdd = false
        root.widgetSettingsKey = ""
        root.widgetStudioTab = "layout"
    }
    // True only while a desktop widget's text field holds focus. Drives the
    // widget layer's keyboard mode so it never holds the keyboard at rest.
    property bool widgetTextFocus: false
    property bool osdOpen: false
    property bool barEditTest: false
    property string osdKind: "volume"
    property var osdKinds: []
    property bool liveIsland: false
    property bool wallpaperOpen: false
    property bool lockSelectorOpen: false
    property bool toolsWidgetOpen: false
    property bool shutdownWindow: false
    property bool fileDialogOpen: false
    property bool panelHold: false
    property bool areaSelectOpen: false
    property bool liveTextOpen: false
    readonly property bool capturing: root.toolsWidgetOpen || root.areaSelectOpen || root.liveTextOpen
    property bool sessionLocked: false
    property bool cheatSheetOpen: false
    property bool overviewOpen: false
    property bool phoneOpen: false
    property bool phoneBrowserOpen: false
    property bool powerPanelOpen: false
    property bool phoneNotifsPanelOpen: false
    property bool phoneCallPanelOpen: false
    property bool scenesPanelOpen: false
    property bool dockSearchActive: false
    property string launcherSeed: ""
    property int notificationCenterCount: 0
    property var widgetBackdrop: null
    property var widgetBackdropSharp: null
    property vector2d widgetScreenSize: Qt.vector2d(1920, 1080)
    property real desktopCursorX: 0
    property real desktopCursorY: 0
    property bool desktopCursorActive: false
    readonly property bool notificationCenterOpen: root.notificationCenterCount > 0
    signal panelRequested(string kind)
    signal pieRequested()
    signal desktopClicked(string screenName, real x, real y)
    signal desktopDragged(string screenName, real x, real y)
    function openPanel(kind) {
        root.panelRequested(kind)
    }
    property string areaSelectMode: ""   // "screenshot" or "recording"
}
