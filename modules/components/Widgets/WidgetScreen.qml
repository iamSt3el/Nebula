import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents


PanelWindow{
    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true

    WlrLayershell.layer: WlrLayer.Bottom
    color: "transparent"

    Loader {
        active: SettingsConfig.widgets.showCircularMusicPlayer ?? true
        visible: active
        sourceComponent: CircularMusicPlayer {}
    }

    Loader {
        active: SettingsConfig.widgets.showClock ?? false
        visible: active
        sourceComponent: NewClock {}
    }

    Loader {
        active: SettingsConfig.widgets.showDateWidget ?? false
        visible: active
        sourceComponent: {
            var style = SettingsConfig.widgets.dateWidgetStyle ?? "default"
            if (style === "calendar") return dateCalendar
            if (style === "pill")     return datePill
            if (style === "split")    return dateSplit
            if (style === "bold")     return dateBold
            if (style === "ghost")    return dateGhost
            if (style === "accent")   return dateAccent
            if (style === "inline")   return dateInline
            return dateDefault
        }
    }

    Component { id: dateDefault;  DateWidget         {} }
    Component { id: dateCalendar; DateWidgetCalendar {} }
    Component { id: datePill;     DateWidgetPill     {} }
    Component { id: dateSplit;    DateWidgetSplit     {} }
    Component { id: dateBold;     DateWidgetBold     {} }
    Component { id: dateGhost;    DateWidgetGhost    {} }
    Component { id: dateAccent;   DateWidgetAccent   {} }
    Component { id: dateInline;   DateWidgetInline   {} }

    Loader {
        active: SettingsConfig.widgets.showAnalogClock ?? false
        visible: active
        sourceComponent: {
            var style = SettingsConfig.widgets.analogClockStyle ?? "classic"
            if (style === "minimal") return analogMinimal
            if (style === "shape")   return analogShape
            return analogClassic
        }
    }

    Component { id: analogClassic; AnalogClockClassic {} }
    Component { id: analogMinimal; AnalogClockMinimal {} }
    Component { id: analogShape;   AnalogClockShape   {} }

    Loader {
        active: SettingsConfig.widgets.showWeatherSlanted ?? false
        visible: active
        sourceComponent: WeatherWidgetSlanted {}
    }

    Loader {
        active: SettingsConfig.widgets.showWeatherForecast ?? false
        visible: active
        sourceComponent: WeatherWidgetForecast {}
    }

    Loader {
        active: SettingsConfig.widgets.showWeatherDetails ?? false
        visible: active
        sourceComponent: WeatherWidgetDetails {}
    }

    Loader {
        active: SettingsConfig.widgets.showPomodoro ?? false
        visible: active
        sourceComponent: PomodoroWidget {}
    }

    Loader {
        active: SettingsConfig.widgets.showSystemMonitor ?? false
        visible: active
        sourceComponent: (SettingsConfig.widgets.systemMonitorStyle ?? "default") === "compact"
            ? sysCompact : sysDefault
    }

    Component { id: sysDefault; SystemMonitorWidget  {} }
    Component { id: sysCompact; SystemMonitorCompact {} }

    Loader {
        active: SettingsConfig.widgets.showBattery ?? false
        visible: active
        sourceComponent: (SettingsConfig.widgets.batteryStyle ?? "default") === "minimal"
            ? battMinimal : battDefault
    }

    Component { id: battDefault; BatteryWidget        {} }
    Component { id: battMinimal; BatteryWidgetMinimal {} }

}
