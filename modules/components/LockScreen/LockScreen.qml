pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.modules.settings

Scope {
    id: root

    property bool screenLocked: false
    property bool startAnimation: false
    property bool capturing: false
    property var deskShots: ({})
    onScreenLockedChanged: GlobalStates.sessionLocked = root.screenLocked

    function requestLock() {
        if (root.screenLocked || root.capturing)
            return
        root.deskShots = ({})
        root.capturing = true
        deskGuard.restart()
    }

    function deskTaken(name, result) {
        if (!root.capturing)
            return
        const shots = Object.assign({}, root.deskShots)
        shots[name] = result
        root.deskShots = shots
        if (Object.keys(shots).length >= Quickshell.screens.length)
            root.engage()
    }

    function engage() {
        if (!root.capturing)
            return
        deskGuard.stop()
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
        interval: 900
        onTriggered: {
            root.screenLocked = false
            root.startAnimation = false
            root.deskShots = ({})
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
                        primary: root.isPrimary(lockSurface.screen)
                    }
                }
            }
        }
    }

    GlobalShortcut {
        name: "lock"
        description: "Lock the screen"

        onPressed: root.requestLock()
    }
}
