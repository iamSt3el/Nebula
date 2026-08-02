import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings

Rectangle{
    id: root
    property bool compact: false
    // Owns its own history feed now that it is a standalone section
    property var downloadHistory: []

    Connections {
        target: ServiceSystemInfo
        function onNetDownloadBpsChanged() {
            sparkline.addValue(ServiceSystemInfo.netDownloadBps)
        }
    }
    // Was fillHeight, which only worked while the dashboard was a fixed
    // full-height panel — it absorbed all the slack. With the dashboard sized
    // to its content there is no slack to absorb, so this needs a real height.
    implicitHeight: root.compact ? 150 : 190
    radius: 20
    color: Colors.surfaceContainer

    ColumnLayout{
        anchors.fill: parent
        anchors.margins: 15
        RowLayout{
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            MaterialIconSymbol{
                content: "network_check"
                iconSize: 20
                color: Colors.primary
            }

            CustomText{
                content: "Network"
                size: 16
            }
        }

        // Item{
        //     Layout.fillWidth: true
        //     Layout.fillHeight: true
        // }
        CustomSparkline {
            id: sparkline
            Layout.fillWidth: true
            Layout.fillHeight: true
            lineColor: Colors.primary
        }


        RowLayout{
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            MaterialIconSymbol{
                content: "download"
                iconSize: 20
                color: Colors.primary
            }

            CustomText{
                content: "Download"
                size: 16
            }

            Item{
                Layout.fillWidth: true
            }

            CustomText{
                content: ServiceSystemInfo.formatBytes(ServiceSystemInfo.netDownloadBps)
                size: 16
                color: Colors.primary
            }
        }


        RowLayout{
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            MaterialIconSymbol{
                content: "upload"
                iconSize: 20
                color: Colors.primary
            }

            CustomText{
                content: "Upload"
                size: 16
            }

            Item{
                Layout.fillWidth: true
            }

            CustomText{
                content: ServiceSystemInfo.formatBytes(ServiceSystemInfo.netUploadBps)
                size: 16
                color: Colors.primary
            }
        }


        RowLayout{
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            MaterialIconSymbol{
                content: "history"
                iconSize: 20
                color: Colors.outline
            }

            CustomText{
                content: "Total"
                size: 16
                color: Colors.outline
            }

            Item{
                Layout.fillWidth: true
            }

            CustomText{
                content: "↓" +ServiceSystemInfo.formatBytes(ServiceSystemInfo.netTotalRxBytes) + " ↑" + ServiceSystemInfo.formatBytes(ServiceSystemInfo.netTotalTxBytes) 
                size: 16
                color: Colors.outline
            }
        }

    }
}
