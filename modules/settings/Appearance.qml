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
    property QtObject motion

    readonly property string fontFamily: SettingsConfig.general.defaultFont ?? "Rubik"

    readonly property real fontScale: {
        const s = SettingsConfig.general.fontScale ?? "normal"
        if (s === "compact") return 0.85
        if (s === "large")   return 1.15
        if (s === "xlarge")  return 1.3
        return 1.0
    }

    readonly property int fontWeight: {
        const w = SettingsConfig.general.fontWeight ?? "extrabold"
        if (w === "thin")     return 300
        if (w === "regular")  return 400
        if (w === "medium")   return 500
        if (w === "semibold") return 600
        if (w === "bold")     return 700
        return 800
    }

    size : QtObject{
        property int barHeight: Math.max(32, Math.min(56, SettingsConfig.bar?.height ?? 40))
        property int arcHeight: 10
        property int arcWidth: 20
        property int lineWidth: 4
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
        property int clockHeight: barHeight
        property int wallpaperPanelWidth: 1200
        property int wallpaperPanelHeight: 520
        property int wallpaperSelectorWidth: 1560
        property int todoPanelWidth: 380
        property int todoPanelHeight: 620
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

    motion : QtObject{
        readonly property int spatialFast: M3Motion.spatial.fastDuration
        readonly property int spatialDefault: M3Motion.spatial.defaultDuration
        readonly property int spatialSlow: M3Motion.spatial.slowDuration
        property int spatialEasing: Easing.OutBack
        property real spatialOvershoot: 1.1
        property int sizeEasing: Easing.OutCubic

        readonly property int effectsFast: M3Motion.effects.fastDuration
        readonly property int effectsDefault: M3Motion.effects.defaultDuration
        readonly property int effectsSlow: M3Motion.effects.slowDuration
        property int effectsEasing: Easing.OutCubic

        property real swipeSpring: 3.2
        property real swipeDamping: 0.32
        property real swipeMass: 0.7
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
