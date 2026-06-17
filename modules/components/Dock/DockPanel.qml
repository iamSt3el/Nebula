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

Scope {
    id: root

    PanelWindow {
        id: panelWindow
        //implicitHeight: 600
        anchors.top: true
        anchors.left: true
        anchors.right: true
        anchors.bottom: true
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.keyboardFocus: (GlobalStates.clipboardOpen || GlobalStates.wallpaperOpen || GlobalStates.typingGameOpen) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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

            readonly property real w: child.width
            readonly property real h: child.height
            readonly property real bodyLeft: container.x
            readonly property real bodyRight: container.x + w
            readonly property real bodyBottom: container.y + container.height
            readonly property real bodyTop: bodyBottom - h

            readonly property real rounding: GlobalStates.shutdownWindow ? 10 : Math.min(h / 3, w / 3)

            readonly property real flareX: w / 18
            readonly property bool flattenFlare: h < flareX * 2
            readonly property real flareY: flattenFlare ? Math.max(0, h / 2) : flareX
            readonly property real flareRadiusY: Math.min(flareX, Math.max(0, h))

            ShapePath {
                strokeWidth: -1
                fillColor: Settings.layoutColor

                startX: bgShape.bodyLeft - bgShape.flareX
                startY: bgShape.bodyBottom

                PathArc {
                    x: bgShape.bodyLeft
                    y: bgShape.bodyBottom - bgShape.flareY
                    radiusX: bgShape.flareX
                    radiusY: bgShape.flareRadiusY
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: bgShape.bodyLeft
                    y: bgShape.bodyTop + bgShape.rounding
                }

                PathArc {
                    x: bgShape.bodyLeft + bgShape.rounding
                    y: bgShape.bodyTop
                    radiusX: bgShape.rounding
                    radiusY: Math.min(bgShape.rounding, bgShape.h)
                }

                PathLine {
                    x: bgShape.bodyRight - bgShape.rounding
                    y: bgShape.bodyTop
                }

                PathArc {
                    x: bgShape.bodyRight
                    y: bgShape.bodyTop + bgShape.rounding
                    radiusX: bgShape.rounding
                    radiusY: Math.min(bgShape.rounding, bgShape.h)
                }

                PathLine {
                    x: bgShape.bodyRight
                    y: bgShape.bodyBottom - bgShape.flareY
                }

                PathArc {
                    x: bgShape.bodyRight + bgShape.flareX
                    y: bgShape.bodyBottom
                    radiusX: bgShape.flareX
                    radiusY: bgShape.flareRadiusY
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: bgShape.bodyLeft - bgShape.flareX
                    y: bgShape.bodyBottom
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
            property bool active: SettingsConfig.general.dockAutoHide ? hover.hovered || GlobalStates.clipboardOpen || GlobalStates.wallpaperOpen || GlobalStates.typingGameOpen || GlobalStates.osdOpen || contextMenuLoader.active || (dockLoder.item && dockLoder.item.showPreview) : true
            property bool collapsed: false

            onActiveChanged: {
                if (active)
                collapsed = false
            }

            HoverHandler {
                id: hover
            }

            Timer {
                id: collapseTimer
                interval: 1000
                running: SettingsConfig.general.dockAutoHide && !container.active
                onTriggered: container.collapsed = true
            }

            Item {
                id: child

                property real dockWidth: dockLoder.item ? dockLoder.item.implicitWidth + 20 : dockWidth

                implicitHeight: SettingsConfig.general.dock ? 60 : 0
                implicitWidth:  dockWidth

                anchors.bottom: parent.bottom
                clip: true

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
                        name: "typingGame"
                        when: GlobalStates.typingGameOpen
                        PropertyChanges {
                            target: child
                            implicitHeight: Appearance.size.typingGameHeight
                            implicitWidth:  Appearance.size.typingGameWidth
                        }
                    },
                    State {
                        name: "osd"
                        when: GlobalStates.osdOpen
                        PropertyChanges { target: child; implicitHeight: 60; implicitWidth: 300 }
                    }
                ]

                transitions: Transition {
                    NumberAnimation {
                        properties: "implicitWidth,implicitHeight"
                        duration:   300
                        easing.type: Easing.OutQuad
                    }
                }

                // Loader {
                //     id: typingGameLoader
                //     active: GlobalStates.typingGameOpen
                //     anchors.fill: parent
                //     sourceComponent: TypingGameContent {
                //         onClosed: GlobalStates.typingGameOpen = false
                //     }
                // }

                Loader{
                    id: osdLoader
                    active: GlobalStates.osdOpen
                    anchors.fill: parent
                    sourceComponent:OsdContent{}
                }



                Loader {
                    id: dockLoder
                    active: SettingsConfig.general.dock && !GlobalStates.clipboardOpen && !GlobalStates.wallpaperOpen && !GlobalStates.typingGameOpen && !container.collapsed && !GlobalStates.osdOpen && !GlobalStates.shutdownWindow
                    anchors.fill: parent
                    sourceComponent: Dock {}
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
                GlobalStates.typingGameOpen = false
            }
        }
    }

    GlobalShortcut {
        name: "typingGame"
        onPressed: {
            if (GlobalStates.typingGameOpen) {
                GlobalStates.typingGameOpen = false
            } else {
                GlobalStates.typingGameOpen = true
                GlobalStates.clipboardOpen = false
                GlobalStates.wallpaperOpen = false
            }
        }
    }
}
