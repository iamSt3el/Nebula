import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings

RowLayout{
    id: root
    property bool compact: false
    // Sizes to its two cards rather than stretching; see DashNetwork
    spacing: 10

    Rectangle{
        Layout.fillWidth: true
        Layout.preferredHeight: mem.implicitHeight + 20
        radius: 20
        color: Colors.surfaceContainer

        ColumnLayout{
            id: mem
            anchors.centerIn: parent
            spacing: 0
            CustomGaugeProgress{
                Layout.preferredWidth:  root.compact ? 100 : 120
                Layout.preferredHeight: root.compact ? 100 : 120
                progress: ServiceSystemInfo.memUsage
                thickness: 8
                gap: 0.2
                icon: "memory_alt"
                iconSize: 18
                sperm: false
            }

            CustomText{
                Layout.alignment: Qt.AlignCenter
                content: ServiceSystemInfo.memUsedGb.toFixed(1) + " / " + ServiceSystemInfo.memTotalGb.toFixed(1) + " GB"
                size: 14
            }
        }
    }

    Rectangle{
        Layout.fillWidth: true
        Layout.preferredHeight: disk.implicitHeight + 20
        radius: 20
        color: Colors.surfaceContainer

        ColumnLayout{
            id: disk
            anchors.centerIn: parent
            spacing: 0
            CustomGaugeProgress{
                Layout.preferredWidth:  root.compact ? 100 : 120
                Layout.preferredHeight: root.compact ? 100 : 120
                progress: ServiceSystemInfo.diskUsage
                thickness: 8
                gap: 0.2
                icon: "hard_disk"
                iconSize: 18
                sperm: false
            }

            CustomText{
                Layout.alignment: Qt.AlignCenter
                content: ServiceSystemInfo.diskUsedGb.toFixed(1) + " / " + ServiceSystemInfo.diskTotalGb.toFixed(1) + " GB"
                size: 14
            }
        }
    }
}

