import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.modules.settings
import qs.modules.customComponents

Scope {
    // Keep FloatingWindow always alive so the Wayland surface doesn't need
    // to be re-negotiated on every open. Only SettingsContent is lazy-loaded.
    FloatingWindow {
        id: floatWindow
        implicitWidth: 1000
        implicitHeight: 700
        title: "Settings"
        color: "transparent"
        visible: GlobalStates.settingsOpen

        Loader {
            anchors.fill: parent
            active: GlobalStates.settingsOpen
            sourceComponent: SettingsContent {
                onSettingClosed: GlobalStates.settingsOpen = false
            }
        }
    }

    GlobalShortcut {
        name: "settingOpen"
        onPressed: GlobalStates.settingsOpen = !GlobalStates.settingsOpen
    }
}
