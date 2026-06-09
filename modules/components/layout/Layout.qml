import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.modules.utils
import qs.modules.components.Bar
import qs.modules.settings
import qs.modules.components.AppLauncher
import qs.modules.components.ToolsWidget
import qs.modules.components.Setting
import qs.modules.components.Clipboard
import qs.modules.components.Notification
import qs.modules.components.Dock
import qs.modules.components.Osd
import qs.modules.components.Widgets
import qs.modules.services
import qs.modules.customComponents


PanelWindow{
    id: layout
    color: "transparent"
    anchors{
        top: true 
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.keyboardFocus: (workspaces.active || utility.isTodoClicked) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None



    mask: Region{
        item: maskRect;
        intersection: Intersection.Xor;
        Region{
            x: workspaces.x;
            y: workspaces.y;
            width: workspaces.width;
            height: workspaces.height;
            intersection: Intersection.Subtract
        } 


        Region{
            x: utility.x
            y: utility.y
            width: utility.container.width
            height: utility.container.height
            intersection: Intersection.Subtract
        }


        Region{
            x: clock.x
            y: clock.y
            width: clock.width
            height: clock.height
            intersection: Intersection.Subtract
        } 

    }
    Rectangle{
        id: maskRect
        implicitHeight: parent.height
        implicitWidth: parent.width
        anchors.bottom: parent.bottom
        color: "transparent"
    }



    Item{
        id: root
        anchors.fill: parent
        property real disX: 18
        property real disY: 18
        property real radX: 18
        property real radY: 18
        property real lineDis: 4
        property real clockHeight: 0
        property real clockWidth: clock.width
        property real workspaceWidth: 100
        property real utilityWidth: 100
        Shape{
            preferredRendererType: Shape.CurveRenderer   
            ShapePath{
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: Colors.surface//"transparent"
                startX: 0
                startY: workspaces.height + root.disY

                PathArc{
                    relativeX: root.disX
                    relativeY: -root.disY
                    radiusX: root.radX
                    radiusY: root.radY
                }

                PathLine{
                    x: workspaces.width + (workspaces.showArc ? root.disX : -root.disX)
                    relativeY: 0
                }

                PathArc{
                    relativeX: workspaces.showArc ? -root.disX : root.disX
                    relativeY: -root.disY 
                    radiusX: root.radX
                    radiusY: root.radY
                    direction: workspaces.showArc ? PathArc.Clockwise : PathArc.Counterclockwise
                }

                PathLine{
                    relativeX: 0
                    relativeY: -(workspaces.height - 2 * root.disY)
                }

                PathArc{
                    relativeX: root.disX
                    relativeY: -(root.disY - root.lineDis)
                    radiusX: root.radX
                    radiusY: root.radY
                } 

                PathLine{
                    x: clock.x - root.disX
                    relativeY: 0
                }

                PathArc{
                    relativeX: root.disX
                    relativeY: (root.disY - root.lineDis)
                    radiusX: root.radX
                    radiusY: root.radY
                }

                PathLine{
                    relativeX: 0
                    relativeY: (clock.height - (2 * root.disY))
                }

                PathArc{
                    relativeX: root.disX
                    relativeY: (root.disY )
                    radiusX: root.radX
                    radiusY: root.radY
                    direction: PathArc.Counterclockwise
                }

                PathLine{
                    relativeX: clock.width - 2 * root.disX
                    relativeY: 0
                }

                PathArc{
                    relativeX: root.disX
                    relativeY: -root.disY
                    radiusX: root.radX
                    radiusY: root.radY
                    direction: PathArc.Counterclockwise
                }

                PathLine{
                    relativeX: 0
                    relativeY: -(clock.height - (2 * root.disY))
                }

                PathArc{
                    relativeX: root.disX
                    relativeY: -(root.disY - root.lineDis)
                    radiusX: root.radX
                    radiusY: root.radY
                }

                PathLine{
                    x: utility.x - root.disX 
                    relativeY: 0
                }

                PathArc{
                    relativeX: root.disX
                    relativeY:(root.disY - root.lineDis)
                    radiusX: root.radX
                    radiusY: root.radY
                }

                PathLine{
                    relativeX: 0
                    relativeY: (utility.height - 2 * root.disY)
                }

                PathArc{
                    relativeX: utility.isDashboard ? -root.disX : root.disX
                    relativeY: root.disY
                    radiusX: root.radX
                    radiusY: root.radY
                    direction: utility.isDashboard ? PathArc.Clockwise : PathArc.Counterclockwise
                }

                PathLine{
                    relativeX: utility.isDashboard ? utility.width + root.disX: utility.width - 2 * root.disX
                    relativeY: 0
                }

                PathArc{
                    relativeX: root.disX
                    relativeY: root.disY
                    radiusX: root.radX
                    radiusY: root.radY
                    //direction: PathArc.Counterclockwise
                }

                PathLine{
                    relativeX: 0
                    relativeY: -(utility.height + root.disY)
                }

                PathLine{
                    x: 0
                    y: 0
                }

                PathLine{
                    relativeX: 0
                    relativeY: workspaces.height + root.disY
                }
            }
        }

        // Shape{
        //     preferredRendererType: Shape.CurveRenderer   
        //     ShapePath{
        //         strokeWidth: 0
        //         strokeColor: "transparent"
        //         fillColor: Colors.surface//"transparent"
        //         startX: 0
        //         startY: 60
        //
        //         PathArc{
        //             relativeX: root.disX
        //             relativeY: -root.disY
        //             radiusX: root.radX
        //             radiusY: root.radY
        //         }
        //
        //         PathLine{
        //             relativeX: root.width - 2 * root.disX
        //             relativeY: 0
        //         }
        //
        //         PathArc{
        //             relativeX: root.disX
        //             relativeY: root.disY
        //             radiusX: root.radX
        //             radiusY: root.radY
        //         }
        //
        //         PathLine{
        //             relativeX: 0
        //             relativeY: -60
        //         }
        //
        //         PathLine{
        //             relativeX: -root.width
        //             relativeY: 0
        //         }
        //
        //         PathLine{
        //             relativeX: 0
        //             relativeY: 60
        //         }
        //     }
        //
        // }

        Workspaces{
            id: workspaces
        }

        Clock{
            id: clock
        }

        Utility{
            id: utility
        }
    }

    property bool isToolsWidgetClicked: false
    property bool isSettingClicked: false
    property bool showOsd: false

    GlobalShortcut{
        name: "toolsWidget"
        onPressed:{
            if(Hyprland.focusedMonitor.name === layout.screen.name){
                layout.isToolsWidgetClicked = !layout.isToolsWidgetClicked 
            }
        }
    }


    NotificationPanel{
   
    }
}
