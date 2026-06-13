import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.modules.settings
import qs.modules.customComponents

Scope {
    FloatingWindow {
        id: floatWindow
        implicitWidth: 1000
        implicitHeight: 700
        title: "Settings"
        color: "transparent"
        visible: GlobalStates.settingsOpen

SettingsContent {
            onSettingClosed: GlobalStates.settingsOpen = false
        }
    }

    GlobalShortcut {
        name: "settingOpen"
        onPressed: GlobalStates.settingsOpen = !GlobalStates.settingsOpen
    }
}
