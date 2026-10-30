import QtQuick
import qs.modules.services
import qs.modules.settings
import qs.modules.utils

QtObject {
    id: root

    readonly property bool use24: SettingsConfig.widgets.clockUse24 ?? false
    readonly property bool showDate: SettingsConfig.widgets.clockShowDate ?? true
    readonly property int hour24: parseInt(ServiceClock.hour)
    readonly property string hour: root.use24 ? ServiceClock.hour
        : String(root.hour24 % 12 === 0 ? 12 : root.hour24 % 12)
    readonly property string hourPad: root.hour.length < 2 ? "0" + root.hour : root.hour
    readonly property string minute: ServiceClock.minute
    readonly property int second: parseInt(ServiceClock.seconds)
    readonly property string ampm: root.use24 ? "" : (root.hour24 < 12 ? "AM" : "PM")
    readonly property string weekday: ServiceClock.day
    readonly property string month: ServiceClock.month
    readonly property int day: parseInt(ServiceClock.date)
    readonly property string time: root.hour + ":" + root.minute

    readonly property bool lightScheme: Qt.color(Colors.surface).hslLightness > 0.5
    readonly property color ink: root.lightScheme ? Colors.inverseSurfaceText : Colors.surfaceText
    readonly property color inkVariant: root.lightScheme ? Qt.alpha(Colors.inverseSurfaceText, 0.78) : Colors.surfaceVariantText
    readonly property color accent: root.lightScheme ? Colors.inversePrimary : Colors.primary
    readonly property color accentTertiary: {
        const c = Qt.color(Colors.tertiary)
        return root.lightScheme ? Qt.hsla(c.hslHue, c.hslSaturation, 0.8, 1) : c
    }
}
