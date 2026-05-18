import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Rectangle{
    id: root
    radius: 10
    color: Colors.surfaceContainerHigh
    implicitWidth: row.implicitWidth + 20
    property bool isWeatherPanelClicked: false

    Loader{
        active: root.isWeatherPanelClicked
        visible: active
        sourceComponent: WeatherPanel{
            onClose: root.isWeatherPanelClicked = false
        }
    }

    RowLayout{
        id: row
        anchors.fill: parent 
        spacing: 10
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        // CustomIconImage{
        //     icon: ServiceWeather.weatherIconPath
        //     size: 14
        //     bright: 1
        // }
        MaterialIconSymbol{
            content: ServiceWeather.weatherIconPath
            iconSize: 16
        }

        CustomText{
            content: ServiceWeather.temperature
            size: 12
        }
    }

    CustomMouseArea{
        cursorShape: Qt.PointingHandCursor
        onClicked:{
           root.isWeatherPanelClicked = true 
        }
    }
}
