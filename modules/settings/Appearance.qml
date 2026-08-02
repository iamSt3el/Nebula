import Quickshell
import QtQuick

pragma Singleton
pragma ComponentBehavior: Bound

Singleton{
    id: root

    property QtObject size
    property QtObject rounding
    property QtObject duration
    property QtObject radius
    property QtObject margin
    property QtObject spacing

    size : QtObject{
        property int barHeight: 40
        property int arcHeight: 10
        property int arcWidth: 20
        property int lineWidth: 4
        property int notificationPanelWidth: 340
        property int notificationPanelHeight: 1080
        property int weatherPanelWidth: 340
        property int weatherPanelHeight: 1080
        property int dashboardPanelWidth: 320
        property int dashboardPanelHeight: 1080
        property int batteryPanelWidth: 240
        property int batteryPanelHeight: 260
        property int widgetHeight: 25
        property int iconSizeNormal: 20
        property int batteryWidgetHeight: 40
        property int osdWidth: 200
        property int osdHeight: 60
        property int calanderWidth: 400
        property int calanderHeight: 400
        property int clockHeight: 40
        property int wallpaperPanelWidth: 1200
        property int wallpaperPanelHeight: 520
        property int typingGameWidth: 900
        property int typingGameHeight: 380
        property int todoPanelWidth: 380
        property int todoPanelHeight: 620
        property int vpnPanelWidth: 340
        property int vpnPanelHeight: 160
    }

    rounding : QtObject{
        property int arcY: 20
        property int arcX: 20
    }

    duration : QtObject{
        property int small: 100
        property int normal: 300
        property int large: 400
    }

    radius : QtObject{
        property int small:  5
        property int medium: 10
        property int large: 15
        property int extraLarge: 20
    }

    margin : QtObject{
        property int small:  5
        property int medium: 10
        property int large: 15
    }

    spacing : QtObject{
        property int small:  5
        property int medium: 10
        property int large: 15
    }






}
