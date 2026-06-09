import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Item{
    id: appLauncher
    implicitHeight: parent.height
    property var filteredApps:ServiceApps.filteredApps 

    Component.onCompleted:{
        searchInput.forceActiveFocus()
    }
    signal closed

    property bool isGrid: SettingsConfig.general.appGrid
    property var appList: isGrid ? gridLoader.item : listLoader.item


    Behavior on implicitWidth{
        NumberAnimation{
            duration: 300
            easing.type: Easing.OutQuad
        }
    }

    onClosed: {
        col.visible = false
        searchInput.text = ""
        ServiceApps.reset()
        appList.activeIndex = 0
        appList.animationsEnabled = false
    }

    Connections{
        target: loader
        function onAnimationChanged(){
            if(loader.animation){
                timer.start()
            }else{
                col.visible = false
            }
        }
    }


        Timer{
            id: timer
            interval: 300
            onTriggered:{
                col.visible = true
            }
        }


        ColumnLayout{
            id: col
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            visible: false
            
                
            NumberAnimation on opacity{
                from: 0
                to: 1
                duration: 100
                running: col.visible
            }

            NumberAnimation on scale{
                from: 0.8
                to: 1
                duration: 100
                running: col.visible
            }
            
            Rectangle{
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                radius: 20
                color: Colors.surfaceContainer
                ColumnLayout{
                    anchors.fill: parent
                    spacing: 0
                    Rectangle{
                        Layout.alignment: Qt.AlignTop
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 20
                        color: Colors.surfaceContainerHigh

                        RowLayout{
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10
                            MaterialIconSymbol{
                                content: "search"
                                iconSize: 20
                            }

                            TextInput{
                                id: searchInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                focus: true
                                clip: true
                                width: parent.width - parent.height
                                text: ""
                                height: parent.height - 12
                                font.pixelSize: 16
                                font.weight: 800
                                color: Colors.inverseSurface


                                onTextChanged: {
                                    ServiceApps.updateSearch(text) 
                                }

                                onAccepted:{
                                    if(filteredApps[appList.activeIndex]){
                                        filteredApps[appList.activeIndex].execute()
                                        appLauncher.closed()
                                    }
                                }

                                Keys.onPressed: (event) => {
                                    if(event.key === Qt.Key_Down){
                                        if(appList.activeIndex < appList.count - 1 && !isGrid){
                                            appList.activeIndex++
                                            appList.positionViewAtIndex(appList.activeIndex, ListView.Contain)
                                        }else if(appList.activeIndex < appList.count - 5  && isGrid){
                                            appList.activeIndex += 4
                                            appList.positionViewAtIndex(appList.activeIndex, GridView.Contain)
                                        }
                                    }

                                    else if(event.key === Qt.Key_Up){
                                        if(appList.activeIndex > 0 && !isGrid){
                                            appList.activeIndex--
                                            appList.positionViewAtIndex(appList.activeIndex, ListView.Contain)
                                        }else if(appList.activeIndex > 4 && isGrid){
                                            appList.activeIndex -= 4
                                            appList.positionViewAtIndex(appList.activeIndex, GridView.Contain)
                                        }
                                    }else if(event.key === Qt.Key_Right && isGrid){
                                        if(appList.activeIndex < appList.count - 1){
                                            appList.activeIndex++
                                            appList.positionViewAtIndex(appList.activeIndex, ListView.Contain)
                                        }
                                    }else if(event.key === Qt.Key_Left && isGrid){
                                        if(appList.activeIndex > 0 && isGrid){
                                            appList.activeIndex--
                                            appList.positionViewAtIndex(appList.activeIndex, GridView.Contain)
                                        }

                                    }
                                    else if(event.key === Qt.Key_Escape){
                                        appLauncher.closed()
                                    }

                                }

                            }
                        }
                    }
                    RowLayout{
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        MaterialIconSymbol{
                            content: "apps"
                            iconSize: 20
                        }
                        CustomText{
                            content: ServiceApps.totalApps + " Items"
                            size: 15
                            weight: 700
                        }

                        Item{
                            Layout.fillWidth: true
                        }

                        Rectangle{
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 28
                            color: appLauncher.isGrid ? Colors.surfaceContainerHighest : Colors.primary
                            radius: 10
                            MaterialIconSymbol{
                                anchors.centerIn: parent
                                content: "lists"
                                iconSize: 20
                                color: appLauncher.isGrid ? Colors.surfaceText : Colors.primaryText
                            }

                            CustomMouseArea{
                                radius: parent.radius
                                id: listArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if(appLauncher.isGrid){
                                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, {appGrid: false})
                                    }
                                }
                            }

                            CustomToolTip{
                                content: "List"
                                visible: listArea.containsMouse
                            }
                        }
                        Rectangle{
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 28
                            color: appLauncher.isGrid ? Colors.primary : Colors.surfaceContainerHighest
                            radius: 10
                            MaterialIconSymbol{
                                anchors.centerIn: parent
                                content: "grid_view"
                                iconSize: 20
                                color: appLauncher.isGrid ? Colors.primaryText : Colors.surfaceText
                            }

                            CustomMouseArea{
                                radius: parent.radius
                                id: gridArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    if(!appLauncher.isGrid){
                                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, {appGrid: true})
                                    }
                                }
                            }

                            CustomToolTip{
                                content: "Grid"
                                visible: gridArea.containsMouse
                            }

                        }
                    }

                    // Item{
                    //     Layout.fillHeight: true
                    // }
                    
                }
            }

            ClippingWrapperRectangle{
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10
                color: "transparent"
                Item{
                    anchors.fill: parent
                    Loader{
                        id: gridLoader
                        active: appLauncher.isGrid
                        visible: active
                        anchors.fill: parent
                        sourceComponent: GridApps{

                        }
                    }
                    Loader{
                        id: listLoader
                        active: !appLauncher.isGrid
                        visible: active
                        anchors.fill: parent
                        sourceComponent: ListApps{
                        }
                    }
                }
            }
        }
}

