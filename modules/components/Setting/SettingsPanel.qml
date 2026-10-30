import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.modules.settings
import qs.modules.customComponents

Scope {
    id: scope

    property bool loaded: false

    Connections {
        target: GlobalStates
        function onSettingsOpenChanged() {
            if (GlobalStates.settingsOpen) {
                unloadTimer.stop()
                scope.loaded = true
            } else {
                unloadTimer.restart()
            }
        }
    }

    Timer {
        id: unloadTimer
        interval: 10000
        onTriggered: if (!GlobalStates.settingsOpen) scope.loaded = false
    }

    LazyLoader {
        id: settingsLoader

        activeAsync: scope.loaded

        component: FloatingWindow {
            implicitWidth: 1000
            implicitHeight: 700
            title: "Settings"
            color: "transparent"

            readonly property real animT: settingsContent.t

            SettingsContent {
                id: settingsContent
                onSettingClosed: GlobalStates.settingsOpen = false
            }
        }
    }

    // Driven by a Binding rather than `visible: GlobalStates.settingsOpen`.
    // Closing the window from the compositor writes visible = false directly,
    // which would break a plain binding; a Binding element re-applies on every
    // later change, so the shortcut keeps working afterwards.
    Binding {
        target: settingsLoader.item
        property: "visible"
        value: GlobalStates.settingsOpen || (!!settingsLoader.item && settingsLoader.item.animT > 0.01)
        restoreMode: Binding.RestoreNone
    }

    // Closing it externally has to feed back into the shared state, otherwise
    // settingsOpen stays true and the next keypress only toggles it to false —
    // which is why it took two presses to get the window back.
    Connections {
        target: settingsLoader.item
        function onVisibleChanged() {
            if (settingsLoader.item && !settingsLoader.item.visible)
                GlobalStates.settingsOpen = false
        }
    }

    GlobalShortcut {
        name: "settingOpen"
        onPressed: GlobalStates.settingsOpen = !GlobalStates.settingsOpen
    }
}
