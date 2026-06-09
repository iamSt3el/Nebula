import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item{
    id: root
    anchors.fill: parent
    anchors.margins: 5


    Flickable{
        id: flickable
        anchors.fill: parent
        contentHeight: column.implicitHeight
        contentWidth: width
        clip: true

        

        ColumnLayout{
            id: column
            width: parent.width
            spacing: 0

            RowLayout{
                Layout.margins: 5
                spacing: 10
                MaterialIconSymbol {
                    iconSize: 20
                    Layout.alignment: Qt.AlignVCenter
                    content:"volume_up"
                }

                CustomText{
                    content: "Sound"
                    size: 20
                    color: Colors.primary
                }

            }

            CustomText{
                Layout.topMargin: 30
                content: "System Volume"
                size: 18
                color: Colors.primary
            }
            CustomText{
                content: "Change volume system-wide"
                size: 14
                color: Colors.outline
            }

            RowLayout{
                Layout.fillWidth: true
                Layout.topMargin: 10
                spacing: 5
                Rectangle{
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    topLeftRadius: 20
                    bottomLeftRadius: 20
                    topRightRadius: 5
                    bottomRightRadius: 5
                    color: Colors.surfaceContainerHigh

                    PwNodePeakMonitor{
                        id: peak
                        node: ServicePipewire.sink
                    }

                    CustomSliderNew{
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        progress: ServicePipewire.volume
                        peakLevel: peak.peak
                        showPeak: true
                    }
                }
                Rectangle{
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 30
                    topLeftRadius: 5
                    bottomLeftRadius: 5
                    topRightRadius: 20
                    bottomRightRadius: 20
                    color: Colors.surfaceContainerHigh
                    MaterialIconSymbol{
                        anchors.centerIn: parent
                        content: "volume_up"
                        size: 24
                    }

                    RippleEffect{
                        anchors.fill: parent
                        topLeftRadius: 5
                        bottomLeftRadius: 5
                        topRightRadius: 20
                        bottomRightRadius: 20
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

            CustomText{
                Layout.bottomMargin: 10
                content: "Playbacks"
                size: 18
                color: Colors.primary
            }

            Repeater{

                model: ServicePipewire.playbacks
                delegate: Rectangle{
                    Layout.bottomMargin: 5
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: Colors.surfaceContainerHigh
                    topRightRadius: index === 0 ? 20 : 5
                    topLeftRadius: index === 0 ? 20 : 5
                    bottomRightRadius: index === ServicePipewire.playbacks.length - 1 ? 20 : 5
                    bottomLeftRadius: index === ServicePipewire.playbacks.length - 1 ? 20 : 5

                    Rectangle{
                        implicitHeight: 30
                        implicitWidth: 30
                        radius: 10
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 10
                        anchors.topMargin: 10
                        color: Colors.surfaceContainerHighest
                        MaterialIconSymbol{
                            anchors.centerIn: parent
                            content: "volume_up"
                            size: 24
                        }

                        RippleEffect{
                            anchors.fill: parent
                            radius: 10
                        }
                    }


                    RowLayout{
                        anchors.fill: parent
                        anchors.margins: 10


                        Image{
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 30
                            source: IconUtil.getIconPath(modelData.name)
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectFit
                        }

                        ColumnLayout{
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            CustomText{
                                Layout.alignment: Qt.AlignLeft
                                content: modelData.properties?.["application.name"] || modelData.name
                                size: 14
                                color: Colors.primary
                            }
                            CustomText{
                                Layout.alignment: Qt.AlignLeft
                                Layout.fillWidth: true
                                content: modelData.properties?.["media.name"]
                                size: 12
                                color: Colors.outline
                            }
                            CustomSliderNew{
                                Layout.fillWidth: true
                                Layout.preferredHeight: 10
                                handleSize: 10
                                trackHeight: 4
                                progress: modelData.audio?.volume
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

            CustomText{
                content: "Output"
                size: 18
                color: Colors.primary
            }

            CustomText{
                content: "Configure Output device"
                size: 14
                color: Colors.outline
            }

            Rectangle{
                Layout.topMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                radius: 20
                color: Colors.surfaceContainerHigh

                ColumnLayout{
                    anchors.fill: parent
                    anchors.margins: 10

                    RowLayout{
                        spacing: 20
                        Layout.fillWidth: true
                        CustomText{
                            content: "Output Devices"
                            size: 14
                        }

                        CustomList{
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            list: ServicePipewire.sinks
                            currentVal: ServicePipewire.sink ? ServicePipewire.sink.description : ""

                            // onIsListClickedChanged:{
                            //     if(isListClicked)
                            //     focusGrab.active = false
                            //     else 
                            //     focusGrab.active = true
                            // }

                            onListChildClicked: (child) => ServicePipewire.setAudioSink(child)
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

            CustomText{
                content: "Input"
                size: 18
                color: Colors.primary
            }

            CustomText{
                content: "Configure Input device"
                size: 14
                color: Colors.outline
            }

            Rectangle{
                Layout.topMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                radius: 20
                color: Colors.surfaceContainerHigh

                ColumnLayout{
                    anchors.fill: parent
                    anchors.margins: 10

                    RowLayout{
                        spacing: 20
                        Layout.fillWidth: true
                        CustomText{
                            content: "Input Devices"
                            size: 14
                        }

                        CustomList{
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            list: ServicePipewire.sources
                            currentVal: ServicePipewire.source ? ServicePipewire.source.description : ""
                            // onIsListClickedChanged:{
                            //     if(isListClicked)
                            //     focusGrab.active = false
                            //     else 
                            //     focusGrab.active = true
                            // }

                            onListChildClicked: (child) => ServicePipewire.setAudioSource(child)
                        }


                    }

                    RowLayout{
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10
                        Rectangle{
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 30
                            radius: 10
                            color: Colors.surfaceContainerHighest
                            MaterialIconSymbol{
                                anchors.centerIn: parent
                                content: "mic"
                                size: 24
                            }

                            RippleEffect{
                                anchors.fill: parent
                                radius: 10
                            }
                        }


                        Rectangle{
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 10
                            color: Colors.surface
                            PwNodePeakMonitor{
                                id: inputPeak
                                node: ServicePipewire.source
                            }

                            Rectangle {
                                id: peakBar
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 10
                                height: parent.height
                                width: parent.width * inputPeak.peak
                                color: Colors.primary
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 80
                                        easing.type: Easing.OutQuad
                                    }
                                }
                            }
                        }
                    }
                }
            }





        }

    }
}


