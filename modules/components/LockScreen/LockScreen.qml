pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.modules.settings
import qs.modules.services

Scope {
    id: root

    property bool screenLocked: false
    property bool startAnimation: false
    property bool capturing: false
    property var deskShots: ({})
    property var barShot: null
    property bool barPending: false
    onScreenLockedChanged: GlobalStates.sessionLocked = root.screenLocked

    function requestLock() {
        if (root.screenLocked || root.capturing)
            return
        root.deskShots = ({})
        root.barShot = null
        Hyprland.refreshToplevels()
        root.capturing = true
        root.grabBar()
        deskGuard.restart()
    }

    function grabBar() {
        const bar = ServiceGaps.barItem
        root.barPending = !!bar && bar.visible && bar.width > 0 && bar.grabToImage(result => {
            root.barShot = result
            root.barPending = false
            root.tryEngage()
        })
    }

    function tryEngage() {
        if (!root.barPending && Object.keys(root.deskShots).length >= Quickshell.screens.length)
            root.engage()
    }

    function deskTaken(name, result) {
        if (!root.capturing)
            return
        const shots = Object.assign({}, root.deskShots)
        shots[name] = result
        root.deskShots = shots
        root.tryEngage()
    }

    function engage() {
        if (!root.capturing)
            return
        deskGuard.stop()
        root.barPending = false
        root.startAnimation = false
        root.screenLocked = true
        root.capturing = false
    }

    function isPrimary(screen) {
        const pm = SettingsConfig.general.primaryMonitor ?? ""
        if (pm !== "" && Quickshell.screens.some(s => s.name === pm))
            return !!screen && screen.name === pm
        return screen === Quickshell.screens[0]
    }

    function deskUrl(name) {
        const shot = root.deskShots[name]
        return shot ? shot.url : ""
    }

    Timer {
        id: deskGuard
        interval: 250
        onTriggered: root.engage()
    }

    Variants {
        model: root.capturing ? Quickshell.screens : []

        PanelWindow {
            id: grabWin
            required property var modelData
            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:lockWindowPusher"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            ScreencopyView {
                id: grabView
                anchors.fill: parent
                captureSource: grabWin.modelData
                live: false
                paintCursor: false
                onHasContentChanged: if (hasContent) grabTimer.start()
            }

            Timer {
                id: grabTimer
                interval: 16
                onTriggered: {
                    const size = grabView.sourceSize.width > 0 ? grabView.sourceSize : Qt.size(grabView.width, grabView.height)
                    const name = grabWin.modelData.name
                    grabView.grabToImage(result => root.deskTaken(name, result), size)
                }
            }
        }
    }

    LockContext {
        id: lockContext
        active: root.screenLocked

        onUnlocked: {
            timer.start()
            root.startAnimation = true
        }
    }

    Timer {
        id: timer
        interval: 1000
        onTriggered: {
            root.screenLocked = false
            root.startAnimation = false
            root.deskShots = ({})
            root.barShot = null
        }
    }

    WlSessionLock {
        id: lock
        locked: root.screenLocked

        WlSessionLockSurface {
            id: lockSurface
            color: "black"

            Image {
                anchors.fill: parent
                source: root.deskUrl(lockSurface.screen.name)
                asynchronous: false
                cache: false
                visible: status === Image.Ready
            }

            Loader {
                id: contentLoader
                active: root.screenLocked
                asynchronous: true
                anchors.fill: parent

                sourceComponent: Item {
                    anchors.fill: parent

                    LockSurface {
                        width: parent.width
                        height: parent.height
                        context: lockContext
                        exiting: root.startAnimation
                        desk: root.deskUrl(lockSurface.screen.name)
                        bar: root.barShot && root.isPrimary(lockSurface.screen) ? root.barShot.url : ""
                        primary: root.isPrimary(lockSurface.screen)
                        shellScreen: lockSurface.screen
                    }
                }
            }
        }
    }

    Connections {
        target: GlobalStates
        function onLockRequested() { root.requestLock() }
    }

    GlobalShortcut {
        name: "lock"
        description: "Lock the screen"

        onPressed: root.requestLock()
    }
}
