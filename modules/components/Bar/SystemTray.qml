import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.customComponents
import qs.modules.services
import qs.modules.utils

Rectangle{
    id: root
    implicitHeight: 25
    implicitWidth: row.implicitWidth + 10
    //implicitWidth: 40
    color: Colors.surfaceContainerHigh
    radius: 10

    property bool menuClicked: false
    property QsMenuHandle menuData

    Behavior on implicitWidth{
        NumberAnimation{
            duration: 100
            easing.type: Easing.OutQuad
        }
    }



    Loader{
        active: root.menuClicked 
        sourceComponent:SystemTrayMenu{
            menuData: root.menuData
            onClose: root.menuClicked = false
        }
    }

    RowLayout{
        id: row
        anchors.centerIn: parent
        anchors.margins: 10
        spacing: 10
        Repeater{
            model: ServiceSystemTray.items
            delegate:CustomIconImage{
                isColor: false
                source: modelData.icon
                size: 16

                CustomMouseArea{
                    radius: 0
                    id: iconArea
                    hoverEnabled: true
                    acceptedButtons: Qt.RightButton | Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor

                    onClicked: function(mouse){
                        if(mouse.button === Qt.RightButton && modelData.hasMenu){
                            root.menuClicked = true
                            root.menuData = modelData.menu
                            //modelData.display(layout, utility.x, utility.height)
                        }
                        if(mouse.button === Qt.LeftButton){
                            modelData.activate()
                        }
                    }
                }
            }
        }
    }

}
