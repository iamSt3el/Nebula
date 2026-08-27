import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.Clipboard
import qs.modules.components.WallpaperSelector
import qs.modules.components.CustomContextMenu
import qs.modules.components.Osd
import qs.modules.components.FileDrop

Scope {
    id: root

    PanelWindow {
        id: panelWindow
        //implicitHeight: 600
        visible: !ServiceGameMode.hideWidgets
        anchors.top: true
        anchors.left: true
        anchors.right: true
        anchors.bottom: true
        WlrLayershell.namespace: "quickshell:dock"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.keyboardFocus: (GlobalStates.clipboardOpen || GlobalStates.wallpaperOpen || GlobalStates.fileDropOpen) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        Loader {
            id: contextMenuLoader
            active: false
            sourceComponent: CustomContextMenu {
                onClose: contextMenuLoader.active = false
            }
        }

        Connections {
            target: dockLoder.item
            function onContextMenuRequested(px, py, appEntry) {
                contextMenuLoader.active = true
                const mapped = dockLoder.item.mapToItem(panelWindow.contentItem, px, py)
                contextMenuLoader.item.appEntry = appEntry
                contextMenuLoader.item.anchor.rect = Qt.rect(mapped.x, mapped.y, 1, 1)
                contextMenuLoader.item.visible = true
            }
        }

        mask: Region {
            item: maskRect
            intersection: Intersection.Xor

            Region {
                item: container
                intersection: Intersection.Subtract
            }
        }

        Rectangle {
            id: maskRect
            anchors.fill: parent
            color: "transparent"
        }

        Shape {
            id: bgShape
            z: 1
            preferredRendererType: Shape.CurveRenderer
            visible: child.height > 0

            // Same arc parameters as the top bar (disX/disY/radX/radY = 18)
            readonly property real dX: 18
            readonly property real dY: 18
            readonly property real rX: 18
            readonly property real rY: 18

            // Mirrors buildFlatBarPath in Layout.qml but grows upward from the bottom.
            // effDY clamps the arc offset so arcs never self-intersect when h is very small.
            function buildPath(dX, dY, rX, rY, left, right, bottom, h) {
                const effDY = Math.min(dY, h / 2)
                const top   = bottom - h
                function A(sw, ex, ey) { return `A ${rX} ${rY} 0 0 ${sw} ${ex} ${ey} ` }
                function L(x,  y)      { return `L ${x} ${y} ` }
                const CW = 1, CCW = 0
                let p = `M ${left - dX} ${bottom} `
                p += A(CCW, left,       bottom - effDY) // bottom-left concave flare
                p += L(left,            top    + effDY) // left wall up
                p += A(CW,  left  + dX, top)            // top-left convex corner
                p += L(right - dX,      top)            // top edge
                p += A(CW,  right,      top    + effDY) // top-right convex corner
                p += L(right,           bottom - effDY) // right wall down
                p += A(CCW, right + dX, bottom)         // bottom-right concave flare
                p += L(left - dX,       bottom)         // close
                return p
            }

            ShapePath {
                strokeWidth: -1
                fillColor: Settings.layoutColor
                PathSvg {
                    path: bgShape.buildPath(
                        bgShape.dX, bgShape.dY, bgShape.rX, bgShape.rY,
                        container.x,
                        container.x + child.width,
                        container.y + container.height,
                        child.height
                    )
                }
            }
        }

        Item {
            id: container
            z: 10
            implicitWidth: Math.max(100, child.width)
            implicitHeight: Math.max(20, child.implicitHeight)
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            property bool active: SettingsConfig.general.dockAutoHide ? hover.hovered || GlobalStates.clipboardOpen || GlobalStates.wallpaperOpen || GlobalStates.fileDropOpen || GlobalStates.osdOpen || contextMenuLoader.active || (dockLoder.item && dockLoder.item.showPreview) : true
            property bool collapsed: false

            onActiveChanged: {
                if (active) collapsed = false
            }

            HoverHandler {
                id: hover
            }

            Timer {
                id: collapseTimer
                interval: 1000
                running: SettingsConfig.general.dockAutoHide && !container.active
                onTriggered: child.startCollapse()
            }

            Item {
                id: child

                property real dockWidth: dockLoder.item ? dockLoder.item.implicitWidth + 20 : dockWidth

                implicitHeight: SettingsConfig.general.dock ? 60 : 0
                implicitWidth:  dockWidth

                anchors.bottom: parent.bottom
                clip: true

                // Two-step collapse: content animates out first, then height collapses
                property bool collapsing: false

                function startCollapse() {
                    collapsing = true
                    collapseHeightTimer.restart()
                }

                // Cancel pending collapse when dock becomes active again
                Connections {
                    target: container
                    function onActiveChanged() {
                        if (container.active) {
                            collapseHeightTimer.stop()
                            child.collapsing = false
                        }
                    }
                }

                // Fires after content close animation completes (260ms + small buffer)
                Timer {
                    id: collapseHeightTimer
                    interval: 300
                    onTriggered: container.collapsed = true
                }

                property bool wantDock: SettingsConfig.general.dock
                    && !GlobalStates.clipboardOpen
                    && !GlobalStates.wallpaperOpen
                    && !GlobalStates.fileDropOpen
                    && !container.collapsed
                    && !child.collapsing
                    && !GlobalStates.osdOpen
                    && !GlobalStates.shutdownWindow

                onWantDockChanged: {
                    if (!wantDock) dockCloseTimer.restart()
                    else           dockCloseTimer.stop()
                }

                Timer {
                    id: dockCloseTimer
                    interval: 320
                }

                states: [
                    State {
                        name: "collapsed"
                        when: container.collapsed
                        PropertyChanges { target: child; implicitHeight: 0 }
                    },
                    State {
                        name: "clipboard"
                        when: GlobalStates.clipboardOpen
                        PropertyChanges { target: child; implicitHeight: 600; implicitWidth: 400 }
                    },
                    State {
                        name: "wallpaper"
                        when: GlobalStates.wallpaperOpen
                        PropertyChanges {
                            target: child
                            implicitHeight: Appearance.size.wallpaperPanelHeight
                            implicitWidth:  Appearance.size.wallpaperPanelWidth
                        }
                    },
                    State {
                        name: "filedrop"
                        when: GlobalStates.fileDropOpen
                        PropertyChanges { target: child; implicitHeight: 560; implicitWidth: 460 }
                    },
                    State {
                        name: "osd"
                        when: GlobalStates.osdOpen
                        PropertyChanges { target: child; implicitHeight: 60; implicitWidth: 300 }
                    }
                ]

                transitions: [
                    // Height collapses after content is already hidden — snappy InCubic
                    Transition {
                        to: "collapsed"
                        NumberAnimation {
                            properties: "implicitWidth,implicitHeight"
                            duration: 220
                            easing.type: Easing.InCubic
                        }
                    },
                    // Dock reappears — slight overshoot like the dock intro animation
                    Transition {
                        from: "collapsed"; to: ""
                        NumberAnimation {
                            properties: "implicitWidth,implicitHeight"
                            duration: Appearance.duration.large
                            easing.type: Easing.OutBack
                            easing.overshoot: 0.2
                        }
                    },
                    // All other state changes (clipboard, wallpaper, osd, etc.)
                    Transition {
                        NumberAnimation {
                            properties: "implicitWidth,implicitHeight"
                            duration: Appearance.duration.large
                            easing.type: Easing.OutQuad
                        }
                    }
                ]

                Loader{
                    id: osdLoader
                    active: GlobalStates.osdOpen
                    anchors.fill: parent
                    sourceComponent:OsdContent{}
                }



                Loader {
                    id: dockLoder
                    active: child.wantDock || dockCloseTimer.running
                    anchors.fill: parent
                    sourceComponent: Dock { closing: !child.wantDock }
                }

                Loader {
                    id: clipLoader
                    active: GlobalStates.clipboardOpen
                    anchors.fill: parent
                    sourceComponent: ClipboardContent {
                        onClosed: GlobalStates.clipboardOpen = false
                    }
                }

                Loader {
                    id: fileDropLoader
                    active: GlobalStates.fileDropOpen
                    anchors.fill: parent
                    sourceComponent: FileDropContent {
                        onClosed: GlobalStates.fileDropOpen = false
                    }
                }

                Loader {
                    id: wallpaperLoader
                    active: GlobalStates.wallpaperOpen
                    anchors.fill: parent
                    sourceComponent: WallpaperContent {}
                }
            }
        }

    }

    Timer{
        id: osdTimer
        interval: 3000
        onTriggered:{
            GlobalStates.osdOpen = false
        }
    }

    Connections {
        target: ServicePipewire.sink?.audio ?? null
        function onVolumeChanged() {
            GlobalStates.osdOpen = true
            osdTimer.restart()
        }
        function onMutedChanged(){
            GlobalStates.osdOpen = true
            osdTimer.restart()
        }
    }

    GlobalShortcut {
        name: "clipboard"
        onPressed: {
            if (GlobalStates.clipboardOpen) {
                GlobalStates.clipboardOpen = false
            } else {
                GlobalStates.clipboardOpen = true
                GlobalStates.wallpaperOpen = false
                GlobalStates.fileDropOpen = false
            }
        }
    }



    GlobalShortcut {
        name: "wallpaperLauncher"
        onPressed: {
            if (GlobalStates.wallpaperOpen) {
                GlobalStates.wallpaperOpen = false
            } else {
                GlobalStates.wallpaperOpen = true
                GlobalStates.clipboardOpen = false
                GlobalStates.fileDropOpen = false
            }
        }
    }

    GlobalShortcut {
        name: "filedrop"
        onPressed: {
            if (GlobalStates.fileDropOpen) {
                GlobalStates.fileDropOpen = false
            } else {
                GlobalStates.fileDropOpen = true
                GlobalStates.clipboardOpen = false
                GlobalStates.wallpaperOpen = false
                if (!ServiceFileDrop.running) ServiceFileDrop.start()
            }
        }
    }

}
