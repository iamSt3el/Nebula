import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item{
    id: root
    anchors.fill: parent
    anchors.margins: 5
    property bool infoCard: false
    property bool qrCode: false
    property bool passwordPrompt: false
    property var network: null

    // onPasswordPromptChanged:{
    //     if(passwordPrompt){
    //         grab.active = false
    //     }else{
    //         grab.active = true
    //     }
    // }

    Loader{
        anchors.fill: parent
        active: root.infoCard
        visible: active
        z: 10
        sourceComponent: NetworkInfoCard{
            network: root.network
            onClose: root.infoCard = false
        }
    }

    Loader{
        anchors.fill: parent
        active: root.qrCode
        visible: active
        z: 10
        sourceComponent: QrCode{
            network: root.network
            onClose: root.qrCode = false
        }
    }

    Loader{
        anchors.fill: parent
        active: root.passwordPrompt
        visible: active
        z: 11
        sourceComponent: PasswordInput{
            onClose: root.passwordPrompt = false
            onSubmit: function(password){
                root.network.connectWithPsk(password)
                root.passwordPrompt = false
            }
        }
    }

    Flickable{
        anchors.fill: parent
        contentHeight: column.implicitHeight
        contentWidth: width
        clip: true

        ColumnLayout{
            id: column
            width: parent.width
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            anchors.topMargin: 5
            spacing: 0

            RowLayout{
                spacing: 10
                MaterialIconSymbol{
                    content: "android_wifi_4_bar"
                    iconSize: 20
                }

                CustomText{
                    content: "Networking"
                    size: 20
                    color: Colors.primary
                }
            }

            CustomText{
                Layout.topMargin: 30
                content: "Networking"
                size: 18
                color: Colors.primary
            }
            CustomText{
                content: "Edit the networking details"
                size: 14
                color: Colors.outline
            }
            RowLayout{
                Layout.fillWidth: true
                Layout.topMargin: 10
                spacing: 10
                ColumnLayout{
                    spacing: 0
                    CustomText{
                        content: "Available Nodes"
                        size: 16
                    }

                    CustomText{
                        content: "Select your network"
                        size: 13
                        color: Colors.outline
                    }
                }

                Item{
                    Layout.fillWidth: true
                }



                CustomListNew{
                    Layout.preferredHeight: 30 
                    Layout.preferredWidth: 200
                    objectVal: ServiceNetwork.currentNetwork
                    list: ServiceNetwork.availableNetworks

                    onIsListClickedChanged:{
                        if(isListClicked)
                        grab.active = false
                        else 
                        grab.active = true
                    }
                } 
            }

            NetworkPill{
                Layout.topMargin: 20
                network: ServiceNetwork.connectedNetwork
                onClick:function(network){
                    root.infoCard = true
                    root.network = network
                }
                onNeedsPassword: function(net) {
                    root.network = net
                    root.passwordPrompt = true
                }

                onQrCode: function(network){
                    root.network = network
                    root.qrCode = true
                }
            }

            Rectangle{
                Layout.topMargin: 10
                Layout.bottomMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.outline
            }


            RowLayout{
                Layout.fillWidth: true
                spacing: 10


                CustomText{
                    content: "Saved Networks"
                    size: 16
                    color: Colors.primary
                }

                Item{
                    Layout.fillWidth: true
                }
            }


            Item{
                Layout.topMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: savedList.item.implicitHeight
                Layout.minimumHeight: 60
                Layout.maximumHeight: 200
                clip: true



                Loader {
                    active: !ServiceNetwork.savedNetworks || ServiceNetwork.savedNetworks.length === 0
                    anchors.centerIn: parent

                    sourceComponent: CustomText {
                        anchors.centerIn: parent
                        content: "No Saved Networks"
                        size: 14
                    }
                }

                Loader {
                    id: savedList
                    active: ServiceNetwork.savedNetworks && ServiceNetwork.savedNetworks.length > 0
                    anchors.fill: parent
                    sourceComponent: ListView {
                        id: wifiList
                        anchors.fill: parent
                        implicitHeight: contentHeight
                        model: ServiceNetwork.savedNetworks
                        spacing: 10
                        delegate: NetworkPill {
                            width: ListView.view.width
                            network: modelData
                            onNeedsPassword: function(net) {
                                root.network = net
                                root.passwordPrompt = true
                            }
                            onClick:function(network){
                                root.infoCard = true
                                root.network = network
                            }
                        }
                    }
                }

            }


            Rectangle{
                Layout.topMargin: 10
                Layout.bottomMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.outline
            }

            RowLayout{
                Layout.fillWidth: true
                spacing: 10
                CustomText{
                    content: "Available Netoworks"
                    size: 16
                    color: Colors.primary
                }
                Item{
                    Layout.fillWidth: true
                }

                MaterialIconSymbol{
                    content: "refresh"
                    iconSize: 20

                    MouseArea{
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ServiceNetwork.currentNetwork.scannerEnabled = true
                        }
                    }
                }
            }

            Item{
                Layout.topMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 300
                clip: true

                Loader {
                    active: !ServiceNetwork.available || ServiceNetwork.available.length === 0
                    anchors.centerIn: parent

                    sourceComponent: CustomText {
                        anchors.centerIn: parent
                        content: "No Available Networks"
                        size: 14
                    }
                }

                Loader {
                    active: ServiceNetwork.available && ServiceNetwork.available.length > 0
                    anchors.fill: parent
                    sourceComponent:                 ListView{
                        anchors.fill: parent
                        orientation: Qt.Vertical
                        model: ServiceNetwork.available
                        spacing: 10
                        delegate: NetworkPill{
                            width: ListView.view.width
                            network: modelData
                            onNeedsPassword: function(net) {
                                root.network = net
                                root.passwordPrompt = true
                            }
                            onClick:function(network){
                                root.infoCard = true
                                root.network = network
                            }
                        }
                    }
                }

            }
        }
    }
}
