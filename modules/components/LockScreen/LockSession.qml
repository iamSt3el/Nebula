pragma Singleton

import QtQuick
import Quickshell
import qs.modules.settings
import qs.modules.services
import qs.modules.utils

QtObject {
    id: root

    readonly property bool greeter: SettingsConfig.greeterMode
    property string identity: ""

    readonly property color _surface: Colors.surface
    readonly property bool light: root._surface.hslLightness > 0.5
    readonly property color shade: root.light ? Colors.surface : Qt.rgba(0.06, 0.04, 0.05, 1)

    readonly property string user: root.identity !== ""
        ? root.identity
        : (SettingsConfig.profileName || Quickshell.env("USER") || "user")

    readonly property string host: Quickshell.env("HOSTNAME")
        || Quickshell.env("HOST")
        || "nebula"

    readonly property var lockCfg: Object.assign({}, SettingsConfig.lockscreen ?? ({}), {
        stateLine: "session locked",
        stateSlug: "LOCKED",
        stateMark: "施錠",
        stateKana: "ロック中"
    })

    readonly property var greeterCfg: Object.assign({}, root.lockCfg, {
        showAvatar: (SettingsConfig.lockscreen ?? ({})).greeterAvatar ?? true,
        showStatus: false,
        showMusic: false,
        stateLine: "sign in",
        stateSlug: "SIGN IN",
        stateMark: "解錠",
        stateKana: "ログイン"
    })

    readonly property var cfg: root.greeter ? root.greeterCfg : root.lockCfg

    readonly property int hour24: parseInt(ServiceClock.hour)
    readonly property string hour: String(root.hour24 % 12 === 0 ? 12 : root.hour24 % 12)
    readonly property string hourPad: root.hour.length < 2 ? "0" + root.hour : root.hour
    readonly property string minute: ServiceClock.minute
    readonly property string ampm: root.hour24 < 12 ? "AM" : "PM"
    readonly property string weekday: ServiceClock.day
    readonly property string month: ServiceClock.month
    readonly property int dayNum: parseInt(ServiceClock.date)
    readonly property string timeGreeting: root.hour24 < 5 ? "Still up"
        : root.hour24 < 12 ? "Good morning"
        : root.hour24 < 17 ? "Good afternoon"
        : root.hour24 < 22 ? "Good evening" : "Good night"
    readonly property string greetingStyle: SettingsConfig.general?.greetingStyle ?? "time"
    readonly property string greeting: root.greetingStyle === "hello" ? "Hello"
        : root.greetingStyle === "custom" ? ((SettingsConfig.general?.greetingText ?? "").trim() || "Hello")
        : root.timeGreeting
}
