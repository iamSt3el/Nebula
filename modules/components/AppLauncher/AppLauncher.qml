import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Scope{
    Loader{
        id: loader
        active: false
        property bool animation: false
        sourceComponent: PanelWindow{
            id: panelWindow
            implicitWidth: 380
            anchors.left: true
            anchors.top: true
            anchors.bottom: true
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Normal
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

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

            HyprlandFocusGrab{
                id: grab
                windows: [panelWindow]
                active: loader.active
                onCleared: () => {
                    if(!active) {
                        GlobalStates.appLauncherOpen = false
                    }
                }
            }

            Shape {
                id: bgShape
                z: 1
                preferredRendererType: Shape.CurveRenderer
                visible: child.width > 0

                readonly property real w: child.width
                readonly property real h: child.height
                readonly property real bodyLeft: container.x
                readonly property real bodyRight: container.x + w
                readonly property real bodyTop: container.y
                readonly property real bodyBottom: container.y + container.height

                readonly property real rounding: Math.min(w / 3, 20)

                readonly property real flareY: h / 18
                readonly property bool flattenFlare: w < flareY * 2
                readonly property real flareX: flattenFlare ? Math.max(0, w / 2) : flareY
                readonly property real flareRadiusX: Math.min(flareY, Math.max(0, w))

                ShapePath {
                    strokeWidth: -1
                    fillColor: Settings.layoutColor

                    startX: bgShape.bodyLeft
                    startY: bgShape.bodyTop - bgShape.flareY

                    PathArc {
                        x: bgShape.bodyLeft + bgShape.flareX
                        y: bgShape.bodyTop
                        radiusX: bgShape.flareRadiusX
                        radiusY: bgShape.flareY
                        direction: PathArc.Counterclockwise
                    }

                    PathLine {
                        x: bgShape.bodyRight - bgShape.rounding
                        y: bgShape.bodyTop
                    }

                    PathArc {
                        x: bgShape.bodyRight
                        y: bgShape.bodyTop + bgShape.rounding
                        radiusX: bgShape.rounding
                        radiusY: bgShape.rounding
                    }

                    PathLine {
                        x: bgShape.bodyRight
                        y: bgShape.bodyBottom - bgShape.rounding
                    }

                    PathArc {
                        x: bgShape.bodyRight - bgShape.rounding
                        y: bgShape.bodyBottom
                        radiusX: bgShape.rounding
                        radiusY: bgShape.rounding
                    }

                    PathLine {
                        x: bgShape.bodyLeft + bgShape.flareX
                        y: bgShape.bodyBottom
                    }

                    PathArc {
                        x: bgShape.bodyLeft
                        y: bgShape.bodyBottom + bgShape.flareY
                        radiusX: bgShape.flareRadiusX
                        radiusY: bgShape.flareY
                        direction: PathArc.Counterclockwise
                    }

                    PathLine {
                        x: bgShape.bodyLeft
                        y: bgShape.bodyTop - bgShape.flareY
                    }
                }
            }

            Item {
                id: container
                z: 10
                implicitWidth: Math.max(20, child.width)
                implicitHeight: Math.max(100, child.implicitHeight)
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                Item {
                    id: child
                    implicitWidth: loader.animation ? 380 : 0
                    implicitHeight: 720
                    clip: true

                    Behavior on implicitWidth {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutQuad
                        }
                    }

                    AppLauncherContent{
                        anchors.fill: parent
                        onClosed:{
                            GlobalStates.appLauncherOpen = false
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: GlobalStates
        function onAppLauncherOpenChanged() {
            if (GlobalStates.appLauncherOpen) {
                loader.active = true
                loader.animation = true
            } else if (loader.active) {
                loader.animation = false
                animationTimer.start()
            }
        }
    }

    Timer{
        id: animationTimer
        interval: 300
        onTriggered:{
            loader.active = false
        }
    }

    GlobalShortcut{
        name: "appLauncher"
        onPressed:{
            GlobalStates.appLauncherOpen = !GlobalStates.appLauncherOpen
        }
    }

}
