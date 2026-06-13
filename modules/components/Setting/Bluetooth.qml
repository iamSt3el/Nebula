import Quickshell
import Quickshell.Widgets
import Quickshell.Bluetooth
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
    property var bluetooth: null

    Loader{
        anchors.fill: parent
        active: root.infoCard
        visible: active
        z: 10

        sourceComponent: BluetoothInfoCard{
            bluetooth: root.bluetooth
            onClose: root.infoCard = false
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
                    content: "bluetooth"
                    iconSize: 20
                }

                CustomText{
                    content: "Bluetooth"
                    size: 20
                    color: Colors.primary
                }
            }

            CustomText{
                Layout.topMargin: 30
                content: "Bluetooth"
                size: 18
                color: Colors.primary
            }
            CustomText{
                content: "Pair and manage Bluetooth devices"
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
                        content: "Bluetooth"
                        size: 16
                    }

                    CustomText{
                        content: "Enable or disable the Bluetooth adapter"
                        size: 13
                        color: Colors.outline
                    }
                }

                Item{
                    Layout.fillWidth: true
                }



                CustomToogle{
                    isToggleOn: Bluetooth.defaultAdapter?.enabled ?? false

                    onToggled: function(state){
                        const adapter = Bluetooth.defaultAdapter;
                        if (adapter)
                        adapter.discovering = state;                
                    }
                }
            }


            Item{
                Layout.topMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: connectedList.implicitHeight
                Layout.minimumHeight: 60
                Layout.maximumHeight: 300
                clip: true

                ListView {
                    id: connectedList
                    anchors.fill: parent
                    implicitHeight: contentHeight
                    model: ServiceBluetooth.connectedDevicesList
                    spacing: 10
                    delegate: BluetoothPill {
                        width: ListView.view.width
                        bluetooth: modelData

                        onClick: function (bluetooth){
                            root.infoCard = true
                            root.bluetooth = bluetooth
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
                    content: "Paired Devices"
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
                Layout.preferredHeight: wifiList.implicitHeight
                Layout.minimumHeight: 60
                Layout.maximumHeight: 300
                clip: true



                // Loader {
                //     active: !ServiceBluetooth.pairedDevices || ServiceBluetooth.pairedDevices.length === 0
                //     anchors.centerIn: parent
                //
                //     sourceComponent: CustomText {
                //         anchors.centerIn: parent
                //         content: "No Paired Devices"
                //         size: 14
                //     }
                // }

                // Loader {
                //     active: ServiceBluetooth.pairedDevices && ServiceBluetooth.pairedDevices > 0
                //     anchors.fill: parent
                //     sourceComponent: ListView {
                //         id: wifiList
                //         anchors.fill: parent
                //         implicitHeight: contentHeight
                //         model: ServiceBluetooth.pairedDevices
                //         spacing: 10
                //         delegate: BluetoothPill {
                //             width: ListView.view.width
                //             bluetooth: modelData
                //         }
                //     }
                // }

                ListView {
                    id: wifiList
                    anchors.fill: parent
                    implicitHeight: contentHeight
                    model: ServiceBluetooth.pairedDevices
                    spacing: 10
                    delegate: BluetoothPill {
                        width: ListView.view.width
                        bluetooth: modelData

                        onClick: function (bluetooth){
                            root.infoCard = true
                            root.bluetooth = bluetooth
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
                    content: "Unpaired Devices"
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
                            Bluetooth.defaultAdapter.discovering = true
                        }
                    }
                }
            }

            Item{
                Layout.topMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 300
                clip: true
                ListView{
                    anchors.fill: parent
                    orientation: Qt.Vertical
                    model: ServiceBluetooth.unpairedDevices
                    spacing: 10
                    delegate: BluetoothPill{
                        width: ListView.view.width
                        bluetooth: modelData


                        onClick: function (bluetooth){
                            root.infoCard = true
                            root.bluetooth = bluetooth
                        }
                    }
                }
            }
        }
    }
}
