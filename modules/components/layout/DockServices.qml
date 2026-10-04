import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.modules.settings
import qs.modules.services

Scope {
    id: root

    Timer {
        id: osdTimer
        interval: 3000
        onTriggered: GlobalStates.osdOpen = false
    }

    function showOsd(kind) {
        GlobalStates.osdKind = kind
        GlobalStates.osdOpen = true
        osdTimer.restart()
    }

    Connections {
        target: ServicePipewire.sink?.audio ?? null
        function onVolumeChanged() {
            if (!GlobalStates.liveIsland)
                root.showOsd("volume")
        }
        function onMutedChanged() {
            if (!GlobalStates.liveIsland)
                root.showOsd("volume")
        }
    }

    Connections {
        target: ServiceBrightness
        function onBrightnessChanged() {
            root.showOsd("brightness")
        }
    }

    Connections {
        target: GlobalStates
        function onBarEditModeChanged() {
            if (!GlobalStates.barEditMode)
                return
            GlobalStates.clipboardOpen = false
            GlobalStates.wallpaperOpen = false
            GlobalStates.fileDropOpen = false
            GlobalStates.appLauncherOpen = false
        }
        function onAppLauncherOpenChanged() {
            if (!GlobalStates.appLauncherOpen)
                return
            GlobalStates.clipboardOpen = false
            GlobalStates.wallpaperOpen = false
            GlobalStates.fileDropOpen = false
        }
        function onClipboardOpenChanged() {
            if (!GlobalStates.clipboardOpen)
                return
            GlobalStates.wallpaperOpen = false
            GlobalStates.fileDropOpen = false
            GlobalStates.appLauncherOpen = false
        }
        function onWallpaperOpenChanged() {
            if (!GlobalStates.wallpaperOpen)
                return
            GlobalStates.clipboardOpen = false
            GlobalStates.fileDropOpen = false
            GlobalStates.appLauncherOpen = false
        }
        function onFileDropOpenChanged() {
            if (!GlobalStates.fileDropOpen)
                return
            GlobalStates.clipboardOpen = false
            GlobalStates.wallpaperOpen = false
            GlobalStates.appLauncherOpen = false
        }
    }

    GlobalShortcut {
        name: "clipboard"
        onPressed: {
            if (GlobalStates.clipboardOpen) {
                GlobalStates.clipboardOpen = false
            } else {
                GlobalStates.clipboardOpen = true
                GlobalStates.wallpaperOpen = false
                GlobalStates.fileDropOpen = false
            }
        }
    }

    GlobalShortcut {
        name: "wallpaperLauncher"
        onPressed: {
            if (GlobalStates.wallpaperOpen) {
                GlobalStates.wallpaperOpen = false
            } else {
                GlobalStates.wallpaperOpen = true
                GlobalStates.clipboardOpen = false
                GlobalStates.fileDropOpen = false
            }
        }
    }

    GlobalShortcut {
        name: "filedrop"
        onPressed: {
            if (GlobalStates.fileDropOpen) {
                GlobalStates.fileDropOpen = false
            } else {
                GlobalStates.fileDropOpen = true
                GlobalStates.clipboardOpen = false
                GlobalStates.wallpaperOpen = false
                if (!ServiceFileDrop.running)
                    ServiceFileDrop.start()
            }
        }
    }
}
