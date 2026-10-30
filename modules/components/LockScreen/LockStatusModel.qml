import QtQuick
import Quickshell.Services.UPower
import qs.modules.utils
import qs.modules.services
import qs.modules.settings

QtObject {
    id: root

    readonly property real _level: LockSession.greeter ? 0 : ServiceUPower.powerLevel
    readonly property bool _lowBattery: !LockSession.greeter
        && !ServiceUPower.isCharging && _level > 0 && _level <= 0.15

    readonly property string _batteryIcon: {
        if (LockSession.greeter)      return "battery_android_0"
        if (ServiceUPower.isCharging) return "battery_android_bolt"
        if (_level === 1)                       return "battery_android_full"
        if (_level < 1    && _level > 0.9)      return "battery_android_6"
        if (_level <= 0.9 && _level > 0.7)      return "battery_android_5"
        if (_level <= 0.7 && _level > 0.5)      return "battery_android_4"
        if (_level <= 0.5 && _level > 0.3)      return "battery_android_3"
        if (_level <= 0.3 && _level > 0.2)      return "battery_android_2"
        if (_level <= 0.2 && _level > 0)        return "battery_android_1"
        return "battery_android_0"
    }

    readonly property var entries: {
        const out = []

        if (LockSession.greeter)
            return out

        try {
            if (Features.weather && ServiceWeather.currentCondition !== null)
                out.push({
                    icon: ServiceWeather.weatherIconPath.icon,
                    name: "Weather",
                    value: ServiceWeather.temperature,
                    sub: ServiceWeather.description,
                    iconColor: Colors.primary,
                    valueColor: Colors.surfaceText
                })

            if (UPower.displayDevice?.isLaptopBattery ?? false)
                out.push({
                    icon: root._batteryIcon,
                    name: "Battery",
                    value: Math.round(root._level * 100) + "%",
                    sub: ServiceUPower.isCharging ? "charging" : "",
                    iconColor: root._lowBattery ? Colors.error
                        : ServiceUPower.isCharging ? Colors.primary : Colors.surfaceText,
                    valueColor: root._lowBattery ? Colors.error : Colors.surfaceText
                })

            const online = ServiceNetwork.connectionType !== "disconnected"
            out.push({
                icon: ServiceNetwork.icon,
                name: "Network",
                value: ServiceNetwork.connectionLabel !== "" ? ServiceNetwork.connectionLabel : "Offline",
                sub: "",
                iconColor: online ? Colors.surfaceText : Qt.alpha(Colors.surfaceText, 0.5),
                valueColor: online ? Colors.surfaceText : Qt.alpha(Colors.surfaceText, 0.5)
            })

            if (ServiceNotification.notificationsNumber > 0)
                out.push({
                    icon: "notifications",
                    name: "Notifications",
                    value: ServiceNotification.notificationsNumber.toString(),
                    sub: "",
                    iconColor: Colors.primary,
                    valueColor: Colors.primary
                })

        } catch (e) {
            console.warn("lock status entry skipped:", e)
        }

        return out
    }
}
