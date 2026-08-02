import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings
import "../../../MatrialShapes/" as MaterialShapes
import "../../../MatrialShapes/material-shapes.js" as MatrialShapeFn

Rectangle{
    property bool compact: false
    // Dashboard owns the wifi/bluetooth overlay, so this section reports upward
    // instead of driving it. Coordinates have to be mapped into the dashboard's
    // space rather than this section's, or the panel opens offset.
    property Item coordSpace: null
    property string panelMode: ""
    signal openPanel(string mode, var parentPos, var pos)
    id: controleRectangle
    implicitHeight: colu.implicitHeight
    color: "transparent"//Colors.surfaceContainer
    radius: 20

    Behavior on implicitHeight{
        NumberAnimation{
            duration: 200
            easing.type: Easing.OutQuad
        }
    }

    ColumnLayout{
        id: colu
        anchors.fill: parent
        anchors.margins: 0
        spacing: controleRectangle.compact ? 7 : 10

        RowLayout{
            Layout.fillWidth: true
            spacing: controleRectangle.compact ? 7 : 10

            ColumnLayout{
                Layout.fillHeight: true
                spacing: controleRectangle.compact ? 7 : 10
                Rectangle{
                    id: wifi
                    Layout.preferredHeight: controleRectangle.compact ? 50 : 60
                    Layout.fillWidth: true
                    radius: 20
                    color: Colors.surfaceContainerHigh
                    opacity: controleRectangle.panelMode === "wifi" ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation { duration: 300 }
                    }

                    RowLayout{
                        anchors.fill: parent
                        anchors.margins: 5

                        MaterialShapes.ShapeCanvas{
                            Layout.preferredHeight: controleRectangle.compact ? 42 : 50
                            Layout.preferredWidth:  controleRectangle.compact ? 42 : 50
                            roundedPolygon: MatrialShapeFn.getCookie6Sided()
                            color: Colors.primary


                            MaterialIconSymbol{
                                anchors.centerIn: parent
                                iconSize: controleRectangle.compact ? 22 : 28
                                content: ServiceNetwork.icon
                                color: ServiceNetwork.wifiEnabled ? Colors.primaryText : Colors.surfaceText
                            }
                        }

                        ColumnLayout{
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            spacing: 5
                            CustomText{
                                Layout.fillWidth: true
                                content: ServiceNetwork.connectionType
                                size: 14
                                weight: 700
                            }

                            CustomText{
                                Layout.fillWidth: true
                                content: ServiceNetwork.currentSSID || "no device"
                                size: 12
                                color: Colors.outline
                            }
                        }

                        MaterialIconSymbol{
                            content: "chevron_right"
                            size: 14
                            color: Colors.outline
                        }
                    }

                    MouseArea{
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked:{
                            const space = controleRectangle.coordSpace ?? controleRectangle
                            controleRectangle.openPanel("wifi",
                                controleRectangle.mapToItem(space, 0, 0),
                                wifi.mapToItem(space, 0, 0))
                        }
                    }
                }
                Rectangle{
                    id: bluetooth
                    Layout.preferredHeight: controleRectangle.compact ? 50 : 60
                    Layout.fillWidth: true
                    radius: 20
                    color: Colors.surfaceContainerHigh

                    RowLayout{
                        anchors.fill: parent
                        anchors.margins: 5



                        MaterialShapes.ShapeCanvas{
                            Layout.preferredHeight: controleRectangle.compact ? 42 : 50
                            Layout.preferredWidth:  controleRectangle.compact ? 42 : 50
                            roundedPolygon: MatrialShapeFn.getCookie6Sided()
                            color: Colors.primary


                            MaterialIconSymbol{
                                anchors.centerIn: parent
                                iconSize: controleRectangle.compact ? 22 : 28
                                content: ServiceBluetooth.connectedDevices > 0 ? "bluetooth" : "bluetooth_disabled"
                                color: Colors.primaryText
                            }
                        }

                        ColumnLayout{
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            spacing: 5
                            CustomText{
                                Layout.fillWidth: true
                                content: "Bluetooth"
                                size: 14
                            }

                            CustomText{
                                Layout.fillWidth: true
                                content: ServiceBluetooth.connectedDevices + " connected"
                                size: 12
                                color: Colors.outline
                            }
                        }
                        MaterialIconSymbol{
                            content: "chevron_right"
                            size: 14
                            color: Colors.outline
                        }
                    }
                    MouseArea{
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked:{
                            const space = controleRectangle.coordSpace ?? controleRectangle
                            controleRectangle.openPanel("bluetooth",
                                controleRectangle.mapToItem(space, 0, 0),
                                bluetooth.mapToItem(space, 0, 0))
                        }
                    }
                }

                Rectangle{
                    Layout.preferredHeight: controleRectangle.compact ? 32 : 40
                    Layout.fillWidth: true
                    radius: 20
                    color: Colors.surfaceContainerHigh

                    RowLayout{
                        anchors.fill: parent
                        anchors.margins: 5

                        Repeater{
                            model: ServiceUPower.powerProfiles

                            Rectangle{
                                property bool active: ServiceUPower.powerProfile === index
                                Layout.fillHeight: true
                                Layout.fillWidth: true
                                radius: 20
                                color: active ? Colors.primary : profileArea.containsMouse ? Qt.alpha(Colors.primary, 0.5) :"transparent"

                                MaterialIconSymbol{
                                    anchors.centerIn: parent
                                    iconSize: 20
                                    content: modelData.icon
                                    color: parent.active ? Colors.primaryText : Colors.surfaceText
                                    fill: 1
                                }

                                Behavior on color{
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }

                                MouseArea{
                                    id: profileArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked:{
                                        ServiceUPower.setPowerProfile(index)
                                    }
                                }
                            }
                        }

                    }
                }
            }

            // CustomSlider{
            //     Layout.fillHeight: true
            //     icon: "volume_up"
            //     progress: ServicePipewire.volume
            //     onProgressChanged:{
            //         ServicePipewire.setVolume(progress)
            //     }
            //
            // }
            CustomSliderOld{
                Layout.fillHeight: true
                Layout.preferredWidth: 50
                icon: "volume_up"
                progress: ServicePipewire.volume
                onProgressChanged:{
                    ServicePipewire.setVolume(progress)
                }
            }

            CustomSliderOld{
                property var brightnessMonitor: ServiceBrightness.getMonitorForScreen(screen)
                Layout.fillHeight: true
                Layout.preferredWidth: 50
                icon: "brightness_7"

                progress: ServiceBrightness.getMonitorForScreen(screen).brightness
                onChange:{
                    brightnessMonitor.setBrightness(progress)
                }

            }
            // CustomSlider{
            //     property var brightnessMonitor: ServiceBrightness.getMonitorForScreen(screen)
            //     Layout.fillHeight: true
            //     icon: "brightness_7"
            //     progress: brightnessMonitor.brightness
            //     onChange:{
            //         brightnessMonitor.setBrightness(progress)
            //     }
            //
            // }
        }
    }
}

