import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings

Item{
    id: root
    property bool isListClicked: false
    property var currentVal: null
    property var objectVal: null
    property var list: []
    z: isListClicked ? 1000 : 0
    signal listClicked
    signal listChildClicked(var child)
    height: 30

    MouseArea{
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked:{
            root.isListClicked = true
            root.listClicked()
        }
    }


    RowLayout{
        visible: !root.isListClicked && root.height === 30
        anchors.fill: parent
        Rectangle{
            Layout.fillHeight: true
            Layout.fillWidth: true
            topLeftRadius: 15
            bottomLeftRadius: 15
            topRightRadius: 5
            bottomRightRadius: 5
            color: Colors.surfaceContainerHighest
            CustomText{
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                content: root.currentVal ?? root.objectVal?.name ?? ""
                size: 12
                weight: 600
            }
        }
        Rectangle{
            Layout.fillHeight: true
            Layout.preferredWidth: 40
            topLeftRadius: 5
            bottomLeftRadius: 5
            topRightRadius: 15
            bottomRightRadius: 15
            color: Colors.surfaceContainerHighest
            MaterialIconSymbol{
                anchors.centerIn: parent
                content: "keyboard_arrow_down"
                iconSize: 20
            } 
        }

    }

    Loader{
        id: listLoader
        active: root.isListClicked
        sourceComponent: PopupWindow{
            id: popup
            anchor.window: panelWindow
            visible: true
            implicitWidth: root.width
            implicitHeight: child.implicitHeight
            color: "transparent"


            HyprlandFocusGrab {
                active: true
                windows: [QsWindow.window]
                onCleared: root.isListClicked = false
            }



            property var windowPos: panelWindow?.mapFromItem(root, 0, root.height) ?? Qt.point(0, 0)

            anchor{
                rect.x: windowPos.x
                rect.y: windowPos.y - root.height
            }

            Rectangle{
                id: child
                implicitWidth: parent.width
                implicitHeight: Math.min(listView.contentHeight + 10, 250)
                radius: 10
                color: Colors.surfaceContainerHighest

                // border{
                //     width: 1
                //     color: Colors.outline
                // }




                ListView{
                    id: listView
                    anchors{
                        fill: parent
                        margins: 5
                    }
                    orientation: Qt.Vertical
                    model: root.list
                    spacing: 5
                    clip: true

                    delegate: Rectangle{
                        implicitWidth: ListView.view.width
                        implicitHeight: 20
                        radius: 5
                        color: (root.currentVal ? root.currentVal === modelData.name : root.objectVal?.name === modelData.name) ? Colors.primary : area.containsMouse ? Qt.alpha(Colors.primary, 0.5) : "transparent"
                        CustomText{
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 5
                            content: modelData.name
                            width: parent.width
                            size: 12
                            weight: 600
                            color: (root.currentVal ? root.currentVal === modelData.name : root.objectVal?.name === modelData.name) ? Colors.primaryText : Colors.surfaceVariantText
                        }

                        MouseArea{
                            id: area
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked:{
                                root.isListClicked = false
                                root.currentVal = modelData.name
                                root.listChildClicked(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
