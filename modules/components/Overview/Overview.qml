import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

// Full-screen workspace manager with live window previews and drag-to-move.
//
//     hl.bind(mainMod .. " + grave", hl.dsp.global("quickshell:overview"))
//
// One window on the focused monitor rather than an overlay per screen: QML drag
// and drop is scene-local, so cards in different windows could never accept each
// other's windows.
Scope {
    id: scope

    GlobalShortcut {
        name: "overview"
        description: "Toggle the workspace manager"
        onPressed: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
    }

    LazyLoader {
        id: loader
        activeAsync: true

        component: PanelWindow {
            id: win

            readonly property bool shouldOpen: GlobalStates.overviewOpen
            property real openProgress: win.shouldOpen ? 1 : 0
            Behavior on openProgress { SpatialAnim { speed: "fast" } }

            visible: win.shouldOpen || win.openProgress > 0.01
            color: "transparent"
            anchors { top: true; left: true; right: true; bottom: true }

            WlrLayershell.namespace: "quickshell:overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // Follows the keyboard, not the pointer — the overview is opened by
            // a keybind, so it should appear where you're already working.
            screen: {
                const name = Hyprland.focusedMonitor?.name ?? ""
                return Quickshell.screens.find(s => s.name === name) ?? null
            }

            // Deliberately not SettingsConfig.general.workspaceCount — that is
            // how many pills the bar draws, and the bar wants to stay narrow.
            // The manager's job is the opposite: show every workspace you can
            // reach, empty ones included, because an empty workspace is a drop
            // target. Ten matches Hyprland's conventional 1–10 and the Super+1..0
            // binds.
            readonly property int slotCount: 10

            readonly property int totalWindows: Hyprland.toplevels?.values?.length ?? 0

            // The ten slots, plus anything live beyond them — a window parked on
            // 14, or a workspace owned by another monitor, still has to be
            // visible and droppable. Negative ids are Hyprland's special
            // workspaces (scratchpads), which aren't drop targets.
            //
            // Bound straight to the Repeater rather than cached behind a
            // change-detector. The cache was there to stop unrelated workspace
            // churn from restarting every live capture, but a stale list is a
            // correctness bug and a restarted capture is only a flicker.
            readonly property var wsIds: {
                var ids = []
                for (var i = 1; i <= win.slotCount; i++) ids.push(i)

                const vals = Hyprland.workspaces?.values ?? []
                for (var j = 0; j < vals.length; j++) {
                    const id = vals[j].id
                    if (id > 0 && ids.indexOf(id) === -1) ids.push(id)
                }

                ids.sort((a, b) => a - b)
                return ids
            }

            // Quickshell's Hyprland models are populated lazily, so an overview
            // opened before anything else touched them would render against a
            // stale or empty workspace list.
            Component.onCompleted: {
                Hyprland.refreshMonitors()
                Hyprland.refreshWorkspaces()
                Hyprland.refreshToplevels()
            }

            // Rows first, aiming at a roughly 2:1 grid. Picking columns from
            // sqrt(n) instead leaves 10 slots as 4×3 with a ragged last row;
            // solving for rows gives 5×2, which fills exactly and keeps each
            // cell landscape — the shape a window preview actually wants.
            readonly property int rows:
                Math.max(1, Math.round(Math.sqrt(Math.max(1, win.wsIds.length) / 1.8)))
            readonly property int cols:
                Math.max(1, Math.ceil(Math.max(1, win.wsIds.length) / win.rows))

            function dismiss() { GlobalStates.overviewOpen = false }

            function activateWorkspace(id) {
                ServiceWorkspaces.activateWorkspaceId(id)
                win.dismiss()
            }

            function activateWindow(toplevel) {
                toplevel?.wayland?.activate()
                win.dismiss()
            }

            // Hyprland only reports a toplevel's new workspace after the move
            // lands, so the grid is refreshed a beat later rather than on the
            // drop itself — otherwise the tile snaps back before it moves.
            Timer {
                id: settleTimer
                interval: 90
                onTriggered: ServiceWorkspaces.refreshToplevels()
            }

            // ── Scrim ─────────────────────────────────────────────────
            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Colors.surface, 0.78)
                opacity: win.openProgress

                MouseArea {
                    anchors.fill: parent
                    onClicked: win.dismiss()
                }
            }

            // ── Card ──────────────────────────────────────────────────
            Rectangle {
                id: card
                anchors.centerIn: parent
                opacity: win.openProgress
                scale: 0.92 + 0.08 * win.openProgress
                layer.enabled: win.openProgress > 0 && win.openProgress < 1
                // Wide but short: ten cards in two rows need the width, and
                // keeping the height down is what stops it feeling like the
                // full-screen panel it replaced.
                width:  Math.min(parent.width  - 140, 1360)
                height: Math.min(parent.height - 220, 580)
                radius: 24
                color: Colors.surface

                // Swallow clicks so they don't reach the dismiss scrim
                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 0

                    // ── Header ────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 11

                        Rectangle {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: 11
                            color: Colors.primaryContainer

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: "grid_view"
                                iconSize: 18
                                customColor: Colors.primaryContainerText
                            }
                        }

                        ColumnLayout {
                            spacing: -2
                            CustomText { content: "Workspaces"; size: 16; weight: 700 }
                            CustomText {
                                content: win.totalWindows
                                    + (win.totalWindows === 1 ? " window" : " windows")
                                    + " · drag to move"
                                size: 11
                                customColor: Colors.outline
                            }
                        }

                        Item { Layout.fillWidth: true }

                        KeyCap { text: "1–9" }
                        KeyCap { text: "ESC" }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 14
                        implicitHeight: 1
                        color: Colors.outlineVariant
                        opacity: 0.35
                    }

                    // ── Workspace grid ────────────────────────────────
                    GridLayout {
                        id: wsGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: 14
                        columns: win.cols
                        columnSpacing: 10
                        rowSpacing: 10

                        // Which card sits under a window-space point. Used
                        // instead of DropArea: the dragged item is a stand-in
                        // for the tile, and hit-testing it directly is both
                        // shorter and free of Drag/DropArea's rules about who
                        // sends the drop and when.
                        function wsIdAt(wx, wy) {
                            const p = wsGrid.mapFromItem(null, wx, wy)
                            if (p.x < 0 || p.y < 0 || p.x > wsGrid.width || p.y > wsGrid.height)
                                return -1
                            const it = wsGrid.childAt(p.x, p.y)
                            return (it && it.wsId !== undefined) ? it.wsId : -1
                        }

                        Repeater {
                            model: win.wsIds

                            delegate: OverviewWorkspaceCard {
                                required property var modelData
                                wsId: modelData
                                draggingToplevel: ghost.toplevel
                                dropTarget: ghost.toplevel !== null
                                            && ghost.targetWsId === modelData

                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                onActivateRequested: win.activateWorkspace(wsId)
                                onWindowActivateRequested: tl => win.activateWindow(tl)

                                onWindowDragStarted: (tl, wx, wy) => ghost.begin(tl, wx, wy)
                                onWindowDragMoved:   (wx, wy)     => ghost.moveTo(wx, wy)
                                onWindowDragEnded:   ghost.finish()
                            }
                        }
                    }
                }
            }

            // ── Drag ghost ────────────────────────────────────────────
            // What follows the cursor. Tiles report window coordinates and this
            // tracks them, because reparenting a live ScreencopyView mid-drag
            // tears down its capture.
            Item {
                id: ghost

                property var toplevel: null
                // Card under the cursor right now; -1 for none
                property int targetWsId: -1

                readonly property string appId: ghost.toplevel?.wayland?.appId ?? ""
                readonly property string title: ghost.toplevel?.title ?? ""
                readonly property int sourceWsId: ghost.toplevel?.workspace?.id ?? -1

                width: Math.min(240, ghostRow.implicitWidth + 24)
                height: 36
                z: 1000
                visible: ghost.toplevel !== null

                function begin(tl, wx, wy) {
                    ghost.toplevel = tl
                    ghost.moveTo(wx, wy)
                }

                function moveTo(wx, wy) {
                    ghost.x = wx - ghost.width / 2
                    ghost.y = wy - ghost.height / 2
                    ghost.targetWsId = wsGrid.wsIdAt(wx, wy)
                }

                function finish() {
                    // Read everything off the ghost before clearing it —
                    // sourceWsId is derived from toplevel and goes to -1 the
                    // moment that's nulled.
                    const tl = ghost.toplevel
                    const target = ghost.targetWsId
                    const source = ghost.sourceWsId

                    ghost.toplevel = null
                    ghost.targetWsId = -1

                    if (!tl || target < 1 || target === source) return

                    ServiceWorkspaces.moveWindowToWorkspace(tl.address, target)
                    settleTimer.restart()
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: Colors.primaryContainer
                    opacity: 0.96

                    RowLayout {
                        id: ghostRow
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Image {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            source: Quickshell.iconPath(
                                DesktopEntries.heuristicLookup(ghost.appId)?.icon, "image-missing")
                            sourceSize: Qt.size(18, 18)
                            fillMode: Image.PreserveAspectFit
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: ghost.title !== "" ? ghost.title : ghost.appId
                            size: 11
                            weight: 700
                            elide: Text.ElideRight
                            customColor: Colors.primaryContainerText
                        }
                    }
                }
            }

            // The overlay holds the keyboard: escape closes, digits jump.
            Item {
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        win.dismiss()
                        event.accepted = true
                        return
                    }

                    // 1–9 select that workspace, 0 selects the tenth
                    if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                        const n = event.key === Qt.Key_0 ? 10 : event.key - Qt.Key_0
                        if (n >= 1 && n <= win.slotCount) {
                            win.activateWorkspace(n)
                            event.accepted = true
                        }
                    }
                }
            }
        }
    }

    // ── Key cap ───────────────────────────────────────────────────────────
    component KeyCap: Rectangle {
        id: cap
        property string text: ""

        implicitWidth: Math.max(26, capText.implicitWidth + 14)
        implicitHeight: 24
        radius: 7
        color: Colors.surfaceContainerHigh
        border.width: 1
        border.color: Qt.alpha(Colors.outlineVariant, 0.55)

        CustomText {
            id: capText
            anchors.centerIn: parent
            content: cap.text
            size: 11
            weight: 600
            customColor: Colors.surfaceText
        }
    }
}
