import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Scope {
    id: scope

    property bool everOpened: false

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen)
                scope.everOpened = true
        }
    }

    GlobalShortcut {
        name: "overview"
        description: "Toggle the workspace manager"
        onPressed: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
    }

    LazyLoader {
        id: loader
        activeAsync: scope.everOpened

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

            screen: {
                const name = Hyprland.focusedMonitor?.name ?? ""
                return Quickshell.screens.find(s => s.name === name) ?? null
            }

            readonly property int slotCount: 10

            readonly property int totalWindows: Hyprland.toplevels?.values?.length ?? 0

            property int selectedWsId: 1
            property string search: ""
            property bool moveMode: false

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

            function wsLabel(id) {
                const custom = (SettingsConfig.general.workspaceNames ?? {})[String(id)] ?? ""
                if (custom !== "") return custom

                const ws = ServiceWorkspaces.getWorkspace(id)
                const given = ws?.name ?? ""
                if (given !== "" && given !== String(id)) return given

                return "Workspace " + id
            }

            function setWsLabel(id, name) {
                var names = Object.assign({}, SettingsConfig.general.workspaceNames ?? {})
                if (name === "") delete names[String(id)]
                else             names[String(id)] = name
                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { workspaceNames: names })
            }

            function wsMatches(id) {
                const q = win.search.trim().toLowerCase()
                if (q === "") return true
                if (String(id).indexOf(q) !== -1) return true
                if (win.wsLabel(id).toLowerCase().indexOf(q) !== -1) return true

                const list = ServiceWorkspaces.getWorkspace(id)?.toplevels?.values ?? []
                for (var i = 0; i < list.length; i++) {
                    const title = (list[i]?.title ?? "").toLowerCase()
                    const appId = (list[i]?.wayland?.appId ?? "").toLowerCase()
                    if (title.indexOf(q) !== -1 || appId.indexOf(q) !== -1) return true
                }
                return false
            }

            readonly property var visibleWsIds: win.wsIds.filter(id => win.wsMatches(id))

            function screenRectFor(id) {
                const name = ServiceWorkspaces.getWorkspace(id)?.monitor?.name ?? ""
                const s = Quickshell.screens.find(sc => sc.name === name) ?? win.screen ?? Quickshell.screens[0]
                if (!s) return Qt.rect(0, 0, 1920, 1080)
                return Qt.rect(s.x, s.y, s.width, s.height)
            }

            Component.onCompleted: {
                Hyprland.refreshMonitors()
                Hyprland.refreshWorkspaces()
                Hyprland.refreshToplevels()
            }

            onShouldOpenChanged: {
                if (!win.shouldOpen) return
                Hyprland.refreshWorkspaces()
                Hyprland.refreshToplevels()
                win.search = ""
                win.moveMode = false
                win.selectedWsId = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1
                searchField.forceActiveFocus()
            }

            function dismiss() { GlobalStates.overviewOpen = false }

            function activateWorkspace(id) {
                ServiceWorkspaces.activateWorkspaceId(id)
                win.dismiss()
            }

            function activateWindow(toplevel) {
                toplevel?.wayland?.activate()
                win.dismiss()
            }

            function moveAllTo(targetId) {
                const source = win.selectedWsId
                win.moveMode = false
                if (targetId === source) return

                const restore = Hyprland.focusedMonitor?.activeWorkspace?.id ?? source
                const list = (ServiceWorkspaces.getWorkspace(source)?.toplevels?.values ?? []).slice()
                for (var i = 0; i < list.length; i++)
                    ServiceWorkspaces.moveWindowToWorkspace(list[i].address, targetId)

                if (list.length > 0 && restore !== targetId)
                    ServiceWorkspaces.activateWorkspaceId(restore)

                settleTimer.restart()
            }

            function closeAll(id) {
                const list = (ServiceWorkspaces.getWorkspace(id)?.toplevels?.values ?? []).slice()
                for (var i = 0; i < list.length; i++) list[i]?.wayland?.close()
                settleTimer.restart()
            }

            function stepSelection(delta) {
                const ids = win.visibleWsIds
                if (ids.length === 0) return
                var idx = ids.indexOf(win.selectedWsId)
                if (idx === -1) idx = 0
                else            idx = Math.max(0, Math.min(ids.length - 1, idx + delta))
                win.selectedWsId = ids[idx]
                wsList.positionViewAtIndex(idx, ListView.Contain)
            }

            Timer {
                id: settleTimer
                interval: 90
                onTriggered: ServiceWorkspaces.refreshToplevels()
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Colors.surface, 0.78)
                opacity: win.openProgress

                MouseArea {
                    anchors.fill: parent
                    onClicked: win.dismiss()
                }
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                opacity: win.openProgress
                scale: 0.92 + 0.08 * win.openProgress
                layer.enabled: win.openProgress > 0 && win.openProgress < 1
                width:  Math.min(parent.width  - 140, 1300)
                height: Math.min(parent.height - 160, 680)
                radius: 30
                color: Colors.surface

                MouseArea { anchors.fill: parent }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 18

                    ColumnLayout {
                        Layout.preferredWidth: 300
                        Layout.fillHeight: true
                        spacing: 12

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 22
                            color: Colors.surfaceContainerHigh

                            RowLayout {
                                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                spacing: 10

                                MaterialIconSymbol {
                                    content: "search"
                                    iconSize: 20
                                    customColor: Colors.primary
                                }

                                TextInput {
                                    id: searchField
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.pixelSize: 14
                                    font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                                    color: Colors.surfaceText
                                    selectionColor: Colors.primary
                                    selectedTextColor: Colors.primaryText
                                    clip: true
                                    focus: true

                                    onTextChanged: {
                                        win.search = text
                                        const ids = win.visibleWsIds
                                        if (ids.length > 0 && ids.indexOf(win.selectedWsId) === -1)
                                            win.selectedWsId = ids[0]
                                    }

                                    Keys.onUpPressed:   win.stepSelection(-1)
                                    Keys.onDownPressed: win.stepSelection(1)
                                    Keys.onReturnPressed: win.activateWorkspace(win.selectedWsId)
                                    Keys.onEnterPressed:  win.activateWorkspace(win.selectedWsId)
                                    Keys.onEscapePressed: {
                                        if (win.moveMode)      win.moveMode = false
                                        else if (text !== "")  text = ""
                                        else                   win.dismiss()
                                    }

                                    CustomText {
                                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                        content: "Search windows"
                                        size: 14
                                        weight: 400
                                        customColor: Colors.outline
                                        visible: searchField.text === ""
                                    }
                                }
                            }
                        }

                        ListView {
                            id: wsList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            model: win.visibleWsIds
                            boundsBehavior: Flickable.StopAtBounds

                            function wsIdAt(wx, wy) {
                                const p = wsList.mapFromItem(null, wx, wy)
                                if (p.x < 0 || p.y < 0 || p.x > wsList.width || p.y > wsList.height)
                                    return -1
                                const idx = wsList.indexAt(p.x + wsList.contentX, p.y + wsList.contentY)
                                return idx >= 0 ? win.visibleWsIds[idx] : -1
                            }

                            delegate: OverviewSidebarRow {
                                required property var modelData

                                width: wsList.width
                                wsId: modelData
                                label: win.wsLabel(modelData)
                                selected: win.selectedWsId === modelData && !win.moveMode
                                dropTarget: ghost.toplevel !== null && ghost.targetWsId === modelData
                                moveTarget: win.moveMode && win.selectedWsId !== modelData
                                dimmed: win.moveMode && win.selectedWsId === modelData

                                onClicked: {
                                    if (win.moveMode) win.moveAllTo(modelData)
                                    else              win.selectedWsId = modelData
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 2
                            spacing: 6

                            CustomText {
                                Layout.fillWidth: true
                                content: win.totalWindows
                                         + (win.totalWindows === 1 ? " window open" : " windows open")
                                size: 11
                                customColor: Colors.outline
                            }

                            KeyCap { text: "↑↓" }
                            KeyCap { text: "⏎" }
                            KeyCap { text: "ESC" }
                        }
                    }

                    OverviewDetail {
                        id: detail
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        wsId: win.selectedWsId
                        label: win.wsLabel(win.selectedWsId)
                        searchText: win.search
                        moveMode: win.moveMode
                        draggingToplevel: ghost.toplevel
                        screenRect: win.screenRectFor(win.selectedWsId)

                        onActivateRequested: win.activateWorkspace(win.selectedWsId)
                        onRenamed: name => win.setWsLabel(win.selectedWsId, name)
                        onMoveAllRequested: win.moveMode = true
                        onMoveCancelled: win.moveMode = false
                        onCloseAllRequested: win.closeAll(win.selectedWsId)

                        onWindowActivateRequested: tl => win.activateWindow(tl)
                        onWindowDragStarted: (tl, wx, wy) => ghost.begin(tl, wx, wy)
                        onWindowDragMoved:   (wx, wy)     => ghost.moveTo(wx, wy)
                        onWindowDragEnded:   ghost.finish()
                    }
                }
            }

            Item {
                id: ghost

                property var toplevel: null
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
                    ghost.targetWsId = wsList.wsIdAt(wx, wy)
                }

                function finish() {
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
                            source: IconUtil.themeIcon(
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
        }
    }

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
