import Quickshell
import QtQuick
import qs.modules.utils


Item{
    id: root
    property bool isToggleOn: false
    signal toggled(bool state)

    implicitHeight: 22
    implicitWidth: 42

    Rectangle{
        id: track
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: parent.width
        implicitHeight: parent.height
        radius: 12
        color: root.isToggleOn ? Colors.primary : Colors.surfaceVariant

        Behavior on color{
            ColorAnimation{
                duration: 400
                easing.type: Easing.OutQuad
            }
        }

        MouseArea{
            id: toggleArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked:{
                root.isToggleOn = !root.isToggleOn
                root.toggled(root.isToggleOn)
            }
        }

        Rectangle{
            id: handle
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.isToggleOn ? 16 : 12
            implicitHeight: width
            radius: 12
            x: root.isToggleOn ? track.width - (width + 4) : 4
            color: Colors.primaryText

            Behavior on implicitWidth{
                NumberAnimation{
                    duration: 300
                    easing.type: Easing.OutQuad
                }
            }

            Behavior on x{
                NumberAnimation{
                    duration: 300
                    easing.type: Easing.OutElastic
                }
            }
        }
    }
}

