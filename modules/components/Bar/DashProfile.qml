import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.LockScreen

RowLayout {
    id: root

    property real avatarSize: 58
    property bool big: true
    property string detail: "Up " + ServiceProfile.uptimeText
    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"

    spacing: 14

    LockShapeImage {
        Layout.preferredWidth: root.avatarSize
        Layout.preferredHeight: root.avatarSize
        source: SettingsConfig.general.profile ?? ""
        shapeName: "circle"
        sourceSize: 128
        fallbackColor: Colors.tertiary
        fallbackIconColor: Colors.tertiaryText
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        DashCaps {
            visible: root.big
            content: ServiceProfile.greeting.replace(",", "")
        }

        CustomText {
            Layout.fillWidth: true
            content: ServiceProfile.name
            family: root.big ? root.displayFamily : (SettingsConfig.general.defaultFont ?? "Rubik")
            renderType: root.big ? Text.QtRendering : Text.NativeRendering
            size: root.big ? 30 : 17
            weight: root.big ? 400 : 800
        }

        CustomText {
            Layout.fillWidth: true
            content: root.detail
            size: 12
            weight: 500
            customColor: Colors.surfaceVariantText
        }
    }
}
