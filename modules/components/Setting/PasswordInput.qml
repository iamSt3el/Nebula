import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls.Fusion
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents


PopupWindow{
    id: root
    implicitWidth: 400
    implicitHeight: 200
    signal close
    signal submit(string password)
    color: "transparent"
    property string password: ""
    visible: true 
    anchor.window: panelWindow
    anchor{
        rect.x: panelWindow.width / 2 - root.implicitWidth / 2
        rect.y: panelWindow.height / 2 - root.implicitHeight / 2
    }
   

    MorphCard{
        id: morph
        width: 400
        height: 140

        fadeCard: true
        srcWidth:  400 * 0.85
        srcHeight: 140 * 0.85
        srcRadius: 20
        srcY: 140 * 0.075

        contentHeight: 140
        cardRadius: 20
        cardColor: Colors.surface

        onCloseFinished: root.close()
        Component.onCompleted: Qt.callLater(morph.open)

        MaterialIconSymbol{
            content: "close"
            iconSize: 20
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 10
            anchors.topMargin: 10

            MouseArea{
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: morph.close()
            }
        }
        
        ColumnLayout{
            anchors.fill: parent
            anchors.margins: 10

            CustomText{
                Layout.alignment: Qt.AlignCenter
                content: "Enter your Password"
                size: 18
            }

            Item{
                Layout.fillHeight: true
            }
            Rectangle{
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: Colors.surfaceContainerHigh
                radius: 10
                TextField{
                    id: input
                    anchors.fill: parent
                    anchors.margins: 10
                    placeholderText: "Enter password"
                    inputMethodHints: Qt.ImhSensitiveData
                    background: null
                    clip: true
                    text: ""
                    font.pixelSize: 20
                    font.weight: 600
                    color: Colors.surfaceText
                    echoMode: TextInput.Password
                    verticalAlignment: TextInput.AlignVCenter


                    onTextChanged: {
                        root.password = this.text;
                    }
                    onAccepted: root.submit(root.password);

                }
            }
        }
    }
}
