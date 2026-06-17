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

    readonly property int wsCount:   SettingsConfig.general.workspaceCount ?? 5
    readonly property bool wsNumbers: SettingsConfig.general.showWorkspaceNumbers ?? false
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

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: ScriptModel {
                values: Array.from({ length: root.wsCount }, (_, i) => i + 1)
            }

            delegate: Rectangle {
                property int workspaceId: modelData
                property var currentWorkspace: ServiceWorkspaces.getWorkspace(workspaceId)
                readonly property bool isActive:   !!currentWorkspace && currentWorkspace.active
                readonly property bool isOccupied: !!currentWorkspace
                readonly property bool showNumbers: root.wsNumbers

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: isOccupied ? 28 : 10
                Layout.preferredWidth:  isOccupied
                    ? Math.max(showNumbers ? 28 : 28, (topLevels.appList?.width ?? 0) + 12)
                    : 10
                radius: 15
                color: isActive   ? Colors.primary
                     : isOccupied ? Colors.surfaceContainerHighest
                     : Qt.alpha(Colors.outline, 0.2)

                border.width: isOccupied && !isActive ? 1 : 0
                border.color: Qt.alpha(Colors.outline, 0.15)

                Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on Layout.preferredWidth  { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on color                  { ColorAnimation  { duration: 200 } }

                Loader {
                    id: topLevels
                    anchors.fill: parent
                    active: isOccupied && !showNumbers
                    visible: active
                    sourceComponent: TopLevels {}
                    property var appList: item ? item.appList : null
                }

                CustomText {
                    anchors.centerIn: parent
                    visible: showNumbers && isOccupied
                    content: workspaceId.toString()
                    size: 10
                    weight: isActive ? 800 : 600
                    customColor: isActive ? Colors.primaryText : Colors.surfaceText
                    Behavior on customColor { ColorAnimation { duration: 200 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (currentWorkspace) currentWorkspace.activate()
                        else Hyprland.dispatch(`workspace ${workspaceId}`)
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
