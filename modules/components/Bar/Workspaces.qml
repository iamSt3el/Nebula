import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import Quickshell.Hyprland
import Quickshell.Widgets



Item{
    id: root
    property bool isClicked: false 
    property bool active: false
    property bool showArc: height > 1000 ? true : false
    implicitWidth: root.active ? 500 : row.implicitWidth + 20//workspacesRow.width + 20
    implicitHeight: root.active ? 1080 : 40

    Behavior on implicitWidth{
        NumberAnimation{
            duration: 300
            easing: Easing.OutQuad
        }
    }
    Behavior on implicitHeight{
        NumberAnimation{
            duration: 300
            easing: Easing.OutQuad
        }
    }
    onActiveChanged:{
        if(active){
            timer.start();
        }else{
            loader.active = false
        }
    }
    Timer{
        id: timer
        interval: 300
        onTriggered:{
            loader.active = true
        }
    }

    Timer{
        id: rowTimer
        interval: 300
        onTriggered:{
            row.visible = true
        }
    }
    Loader{
        id: loader
        active: false
        visible: active
        anchors.fill: parent
         sourceComponent: AiContent{}
        //sourceComponent: MangaContent{}
    }

    RowLayout{
        id: row
        anchors.centerIn: parent
        spacing: 10
        Repeater{
            model: 5
            delegate: Rectangle{
                property int workspaceId: modelData + 1
                property var currentWorkspace: ServiceWorkspaces.getWorkspace(workspaceId)
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: currentWorkspace ? 25 : 15
                Layout.preferredWidth: currentWorkspace ? Math.max(15, topLevels.appList.width) + 10 : 15
                radius: 10
                color: currentWorkspace ? currentWorkspace.active ? Colors.primary : Colors.surfaceContainerHighest : Colors.surfaceContainer
                // border{
                //     width: 1
                //     color: Qt.alpha(Colors.outline, 0.5)
                // }

                Behavior on implicitWidth{
                    NumberAnimation{
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }

                TopLevels{
                    id: topLevels
                }

                MouseArea{
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.RightButton | Qt.LeftButton
                    onClicked: function(mouse){
                        if(mouse.button === Qt.LeftButton){
                            if(currentWorkspace){
                                currentWorkspace.activate()
                            }else{
                                Hyprland.dispatch(`workspace ${workspaceId}`)
                            }
                        }else if(mouse.button === Qt.RightButton){
                        }
                    }
                }
            }
        }
    }

    GlobalShortcut{
        name: "mangaReader"
        onPressed:{
            if(root.active){
                root.active = false
                rowTimer.start()
            }
            else if(Hyprland.focusedMonitor.name === layout.screen.name){
                root.active = true
                row.visible = false
            }
        }
    }

}
