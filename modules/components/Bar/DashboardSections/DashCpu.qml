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
    id: root
    property bool compact: false
    implicitHeight: cpu.implicitHeight + 20
    radius: 20
    color: Colors.surfaceContainer

    ColumnLayout{
        id: cpu
        anchors.fill: parent
        anchors.margins: 10
        spacing: 2
        RowLayout{ 
            Layout.fillHeight: true
            Layout.fillWidth: true

            CustomMatrialCircularProgress{
                Layout.preferredWidth:  root.compact ? 50 : 60
                Layout.preferredHeight: root.compact ? 50 : 60
                progress: ServiceSystemInfo.cpuUsage
                thickness: 4
                gap: 0.6
                icon: "memory"
                iconSize: root.compact ? 22 : 30
                sperm: false
            }

            ColumnLayout{
                Layout.fillWidth: true
                Layout.fillHeight: true
                CustomText{
                    content: "CPU"
                    size: 16
                    color: Colors.primary
                }
                CustomText{
                    Layout.fillWidth: true
                    content: ServiceSystemInfo.cpuName
                    size: 14

                }
            }

            MaterialShapes.ShapeCanvas{
                Layout.preferredWidth: 50
                Layout.preferredHeight: 50

                roundedPolygon: MatrialShapeFn.getCookie4Sided()
                color: Colors.primaryText

                CustomText{
                    anchors.centerIn: parent
                    content: Math.round(ServiceSystemInfo.cpuUsage * 100) + "%"
                    size: 14
                    color: Colors.primary
                }
            }
        }

        // RowLayout{
        //     Layout.leftMargin: 5
        //     spacing: 0
        //     MaterialIconSymbol{
        //         content: "device_thermostat"
        //         iconSize: 20
        //         color: Colors.primary
        //     }
        //
        //     CustomText{
        //         content: ServiceSystemInfo.cpuTemp.toFixed(1) + "°C"
        //         size: 14
        //     }
        // }
        //
        //
        // CustomProgressBar{
        //     value: ServiceSystemInfo.cpuTemp / 100
        //     Layout.leftMargin: 10
        //     Layout.rightMargin: 10
        //     Layout.preferredHeight: 3
        //     Layout.fillWidth: true
        //     valueBarGap: 6
        // }
    }
}

