import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

Item{
    id: root
    property int val
    property int inc: 10
    property int limit: 100
    RowLayout{
        anchors.centerIn: parent
        spacing: 2
        Rectangle{
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            color: Colors.tertiary
            topLeftRadius: 10
            topRightRadius: 2
            bottomLeftRadius: 10
            bottomRightRadius: 2
            MaterialIconSymbol{
                anchors.centerIn: parent
                content: "remove"
                iconSize: 20
                color: Colors.tertiaryText
            }

            CustomMouseArea{
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked:{
                    if(root.val > 0){
                        root.val -= root.inc
                    }
                }
            }
        }
        Rectangle{
            Layout.preferredHeight: 30
            Layout.preferredWidth: text.implicitWidth + 10 
            color: Colors.tertiary
            radius: 2
            CustomText{
                id: text
                anchors.centerIn: parent
                content:root.val 
                color: Colors.tertiaryText
                size: 14
            }
        }
        Rectangle{
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            color: Colors.tertiary
            topLeftRadius: 2
            topRightRadius: 10
            bottomLeftRadius: 2
            bottomRightRadius: 10


            MaterialIconSymbol{
                anchors.centerIn: parent
                content: "add"
                iconSize: 20
                color: Colors.tertiaryText
            }

            CustomMouseArea{
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked:{
                    if(root.val < root.limit){
                        root.val += root.inc
                    }
                }
            }
        }
    }
}
