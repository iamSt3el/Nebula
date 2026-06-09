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
    signal close

    opacity:0
    scale: 0.8

    NumberAnimation on opacity{
        from: 0
        to: 1
        duration: 400
        running: true
    }

    NumberAnimation on scale{
        from: 0.8
        to: 1
        duration: 400
        running: true
    }

    ColumnLayout{
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        Rectangle{
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 15
            color: Colors.surfaceContainer
            RowLayout{
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                CustomText{
                    content: "Battery"
                    size: 14
                }
                // Rectangle{
                //     Layout.alignment: Qt.AlignTop
                //     Layout.preferredWidth: child.implicitWidth + 10
                //     Layout.preferredHeight: child.implicitHeight + 4
                //     color: "green"
                //     radius: height / 2
                //     CustomText{
                //         id: child
                //         anchors.centerIn: parent
                //         content: "Charging"
                //         size: 8
                //     }
                // }

                Item{
                    Layout.fillWidth: true
                }

                MaterialIconSymbol{
                    content: "close"
                    iconSize: 18

                    CustomMouseArea{
                        radius: parent.radius
                        cursorShape: Qt.PointingHandCursor
                        onClicked:root.close()
                    }
                }
            }
        }

        Rectangle{
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 15
            color: Colors.surfaceContainer
            ColumnLayout{
                anchors.fill: parent
                anchors.margins: 5
                RowLayout{
                    Layout.fillWidth: true
                    ColumnLayout{
                        Layout.fillWidth: true
                        // CustomCircularProgressBar{
                        //     Layout.preferredWidth: 100
                        //     Layout.preferredHeight: 100
                        //     progress: ServiceUPower.powerLevel
                        //     thickness: 10
                        // } 
                        CustomMatrialCircularProgress{
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 100
                            progress: 0.4
                            thickness: 8
                            gap: 0.4
                        }

                        CustomText{
                            Layout.alignment: Qt.AlignCenter
                            content: "Charge"
                            size: 14
                            color: Colors.primary
                        }
                    }
                    Item{
                        Layout.fillWidth: true
                    }
                    ColumnLayout{
                        Layout.fillWidth: true
                      

                        CustomMatrialCircularProgress{
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 100
                            lineColor: Colors.error
                            progress: ServiceUPower.health
                            thickness: 8
                            gap: 0.4
                        }
                        CustomText{
                            Layout.alignment: Qt.AlignCenter
                            content: "Health"
                            size: 14
                            color: Colors.error
                        }
                    }
                }

                RowLayout{
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 30
                    ColumnLayout{
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        CustomText{
                            Layout.alignment: Qt.AlignCenter
                            content: "Time Left"
                            size: 12
                            color: Colors.outline
                        }
                        CustomText{
                            Layout.alignment: Qt.AlignCenter
                            content: ServiceUPower.timeToFull
                            size: 14
                        }
                    }
                    Item{
                        Layout.fillWidth: true
                    }
                    ColumnLayout{
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        CustomText{
                            Layout.alignment: Qt.AlignCenter
                            content: "Power"
                            size: 12
                            color: Colors.outline
                        }
                        CustomText{
                            Layout.alignment: Qt.AlignCenter
                            content: `${ServiceUPower.changeRate.toFixed(2)}W`
                            size: 14
                        }
                    }
                }
            }
        }
        
    }
}
