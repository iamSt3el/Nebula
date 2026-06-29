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

    readonly property int wsCount:    SettingsConfig.general.workspaceCount ?? 5
    readonly property bool wsNumbers: SettingsConfig.general.showWorkspaceNumbers ?? false
    readonly property bool perMonitorMode: SettingsConfig.general.perMonitorWorkspaces ?? false

    readonly property int otherOccupied: {
        if (!perMonitorMode) return 0
        var count = 0
        var vals = Hyprland.workspaces.values
        for (var i = 0; i < vals.length; i++) {
            if (vals[i].monitor?.name !== layout.screen.name) count++
        }
        return count
    }
    readonly property int otherActive: {
        if (!perMonitorMode) return 0
        var count = 0
        var vals = Hyprland.workspaces.values
        for (var i = 0; i < vals.length; i++) {
            if (vals[i].monitor?.name !== layout.screen.name && vals[i].active) count++
        }
        return count
    }
    implicitWidth:  outerRow.implicitWidth + 20
    implicitHeight: 40

    states: State {
        name: "expanded"
        when: root.active
        PropertyChanges {
            target: root
            implicitWidth:  500
            implicitHeight: 1080
        }
    }

    transitions: Transition {
        NumberAnimation {
            properties: "implicitWidth,implicitHeight"
            duration:   300
            easing.type: Easing.OutQuad
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
    }
    RowLayout{
        id: outerRow
        anchors.centerIn: parent
        spacing: 5
        Rectangle{
            Layout.preferredWidth: row.implicitWidth + 6
            Layout.preferredHeight: 30
            radius: 15
            color: Colors.surfaceContainer
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
                        // In per-monitor mode, hide occupied workspaces that live on other monitors
                        readonly property bool isForThisMonitor: !root.perMonitorMode
                            || !currentWorkspace
                            || currentWorkspace.monitor?.name === layout.screen.name

                        visible: isForThisMonitor
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: 25
                        Layout.preferredWidth: isForThisMonitor
                            ? (isOccupied ? Math.max(showNumbers ? 25 : 25, (topLevels.appList?.width ?? 0) + 12) : 25)
                            : 0
                        radius: 15
                        color: isActive   ? Colors.primary
                        : isOccupied ? Colors.surfaceContainerHighest
                        : "transparent"

                        border.width: isOccupied && !isActive ? 1 : 0
                        border.color: Qt.alpha(Colors.outline, 0.15)

                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on Layout.preferredWidth  { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on color                  { ColorAnimation  { duration: 200 } }

                        Rectangle{
                            visible: !isOccupied
                            implicitWidth: 5
                            implicitHeight: 5
                            color: Colors.outline
                            radius: width / 2
                            anchors.centerIn: parent
                        }

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
                                else Hyprland.dispatch(`hl.dsp.focus({ workspace = '${workspaceId}' })`)
                            }
                        }
                    }
                }

                // Other-monitors indicator: shows when per-monitor mode is on and other monitors have workspaces
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 25
                    Layout.preferredWidth: root.perMonitorMode && root.otherOccupied > 0 ? 25 : 0
                    opacity: root.perMonitorMode && root.otherOccupied > 0 ? 1 : 0
                    visible: Layout.preferredWidth > 0
                    radius: 12
                    color: root.otherActive > 0 ? Colors.primary : "transparent"
                    border.width: root.otherActive > 0 ? 0 : 1
                    border.color: Qt.alpha(Colors.outline, 0.35)

                    Behavior on color                 { ColorAnimation  { duration: 200 } }
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity               { NumberAnimation { duration: 180 } }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "tv_displays"
                        iconSize: 12
                        customColor: root.otherActive > 0 ? Colors.primaryText : Colors.outline
                        Behavior on customColor { ColorAnimation { duration: 200 } }
                    }

                    CustomToolTip {
                        content: root.otherOccupied + " workspace" + (root.otherOccupied !== 1 ? "s" : "") + " on other monitor" + (root.otherActive > 0 ? " (active)" : "")
                        visible: otherMonHov.containsMouse
                    }
                    MouseArea { id: otherMonHov; anchors.fill: parent; hoverEnabled: true }
                }
            }
        }
        MaterialIconSymbol{
            Layout.leftMargin: 10
            content: "ad"
            iconSize: 20
        } 
        CustomText{
            Layout.maximumWidth: 200
            content: Hyprland.activeToplevel.title
            size: 14
        }
    }



    GlobalShortcut{
        name: "aiPanel"
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
