import Quickshell
import Quickshell.Widgets
import Quickshell.Networking
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: root
    implicitWidth: parent?.width
    implicitHeight: 60
    radius: 15
    color: network?.connected || handler.hovered ? Colors.surfaceContainerHighest : "transparent"
    property var network: null
    visible: network !== null
    signal click(var network)
    signal needsPassword(var network)
    signal qrCode(var network)

    MouseArea{
        id: pillArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked:{
            if(!network?.connected){
                //root.wrongPassword = false
                network.connect()
            }
            else{
                //root.wrongPassword = false
                network.disconnect()
            }
        }
    }
    HoverHandler{
        id: handler
    }
    Connections {
        target: root.network
        ignoreUnknownSignals: true
        function onConnectionFailed(reason) {
            if (reason === ConnectionFailReason.NoSecrets) {
                root.needsPassword(root.network)
            }
        }
    }
    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 10
            //color: Colors.primary
            color: "transparent"
            MaterialIconSymbol {
                anchors.centerIn: parent
                content: "network_wifi_locked"
                iconSize: 30
                // color: Colors.primaryText
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            CustomText {
                content: network?.name ?? ""
                size: 14
            }
            CustomText {
                content: network?.known ? "Known" : "Unknown"
                size: 13
                color: Colors.outline
            }
        }



        Item {
            Layout.fillWidth: true
        }

        Loader{
            active: handler.hovered && network?.connected
            visible: active
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            sourceComponent: Rectangle{
                anchors.fill: parent
                radius: width
                color: qrArea.containsMouse ? Colors.primary: "transparent"

                MaterialIconSymbol{
                    anchors.centerIn: parent
                    content: "qr_code"
                    iconSize: 16
                    color: qrArea.containsMouse ? Colors.primaryText : Colors.surfaceText
                }
                MouseArea {
                    id: qrArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked:root.qrCode(root.network)
                }
            }
        }

        Loader{
            active: handler.hovered
            visible: active
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            sourceComponent: Rectangle {
                anchors.fill: parent
                radius: width
                color: area.containsMouse ? Colors.primary : "transparent"

                MaterialIconSymbol{
                    anchors.centerIn: parent
                    content: "info"
                    iconSize: 16
                    color: area.containsMouse ? Colors.primaryText : Colors.surfaceText
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked:root.click(root.network)
                }
            }
        }
    }
}
