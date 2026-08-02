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
    implicitHeight: gpu.implicitHeight + 20
    radius: 20
    color: Colors.surfaceContainer

    ColumnLayout{
        id: gpu
        anchors.fill: parent
        anchors.margins: 10


        RowLayout{ 
            Layout.fillHeight: true
            Layout.fillWidth: true

            CustomMatrialCircularProgress{
                Layout.preferredWidth:  root.compact ? 50 : 60
                Layout.preferredHeight: root.compact ? 50 : 60
                progress: ServiceSystemInfo.gpuUsage
                thickness: 4
                gap: 0.6
                icon: "desktop_windows"
                iconSize: root.compact ? 20 : 24
                sperm: false
            }

            ColumnLayout{
                Layout.fillWidth: true
                Layout.fillHeight: true
                CustomText{
                    content: "GPU"
                    size: 16
                    color: Colors.primary
                }
                CustomText{
                    Layout.fillWidth: true
                    content: ServiceSystemInfo.gpuName
                    size: 14

                }
            }

            MaterialShapes.ShapeCanvas{
                Layout.preferredWidth: 50
                Layout.preferredHeight: 50

                roundedPolygon: MatrialShapeFn.getPill()
                color: Colors.primaryText

                CustomText{
                    anchors.centerIn: parent
                    content: Math.round(ServiceSystemInfo.gpuUsage * 100) + "%"
                    size: 14
                    color: Colors.primary
                }
            }
        }

        // RowLayout{
        //     Layout.leftMargin: 5
        //     MaterialIconSymbol{
        //         content: "device_thermostat"
        //         iconSize: 24
        //         color: Colors.primary
        //     }
        //
        //     CustomText{
        //         content: ServiceSystemInfo.gpuTemp.toFixed(1) + "°C"
        //         size: 16
        //     }
        // }
        //
        // Item{
        //     Layout.fillHeight: true
        //     Layout.fillWidth: true
        //     Layout.leftMargin: 10
        //     Layout.rightMargin: 10
        //     CustomProgressBar{
        //         value: ServiceSystemInfo.gpuTemp / 100
        //         implicitHeight: 4
        //         implicitWidth: parent.width
        //         valueBarGap: 6
        //     }
        // }
    }
}

