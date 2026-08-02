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
    signal toggleDashboard()
    implicitHeight: root.compact ? 42 : 50
    color: Colors.surfaceContainer
    radius: 20
    RowLayout{
        anchors.fill: parent
        anchors.margins: 10
        anchors.rightMargin: 10
        spacing: 5

        ClippingWrapperRectangle{
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: height
            color: "transparent"

            border{
                width: 1
                color: Colors.outline
            }

            Image{
                anchors.fill: parent
                sourceSize: Qt.size(width, height)
                source: SettingsConfig.general.profile
            }
        }

        ColumnLayout{
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: 0
            CustomText{
                Layout.fillWidth: true
                Layout.fillHeight: true
                content: "St3el"
                size: 14
            }
            CustomText{
                Layout.fillWidth: true
                Layout.fillHeight: true
                content: "uptime " + ServiceSystemInfo.getUptime()

                size: 13
                color: Colors.outline
            }
        }

        // MaterialIconSymbol{
        //     content: "settings"
        //     iconSize: 20 
        //     MouseArea{
        //         cursorShape: Qt.PointingHandCursor
        //         anchors.fill: parent
        //         onClicked: {
        //             GlobalStates.settingsOpen = true
        //             root.toggleDashboard()
        //         }
        //     }
        // }
        CustomButton{
            icon: "settings"
            iconSize: 18
            Layout.preferredHeight: 30
            Layout.preferredWidth: 30
            radius: 10
            onClicked: {
                root.toggleDashboard()
                GlobalStates.settingsPage = 9
                GlobalStates.settingsOpen = true
            }
        }

        CustomButton{
            icon: "power_settings_new"
            iconSize: 18
            Layout.preferredHeight: 30
            Layout.preferredWidth: 40
            radius: 10
            onClicked: {
                root.toggleDashboard()
                GlobalStates.shutdownWindow = true
            }
        }
        CustomButton{
            icon: "close"
            iconSize: 18
            Layout.preferredHeight: 30
            Layout.preferredWidth: 30
            radius: 10

            onClicked: {
                root.toggleDashboard()
            }
        }
       
        // MaterialIconSymbol{
        //     content: "close"
        //     iconSize: 20
        //     MouseArea{
        //         cursorShape: Qt.PointingHandCursor
        //         anchors.fill: parent
        //         onClicked: root.toggleDashboard()
        //     }
        // }


    }
}

