import Quickshell
import QtQuick
import QtQuick.Layouts

SetupScroll {
    id: scroll

    readonly property bool multiMonitor: Quickshell.screens.length > 1
    readonly property int keyFrom: 0
    readonly property int keyTo: 0

    function pick(n) {
        return false
    }

    GridLayout {
        width: scroll.contentWidthAvail
        columns: 2
        columnSpacing: 12
        rowSpacing: 12

        TileProfile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 12

            TileWeather {}

            TileDisplays {
                visible: scroll.multiMonitor
            }
        }
    }
}
