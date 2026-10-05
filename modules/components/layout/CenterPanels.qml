import Quickshell
import QtQuick
import qs.modules.settings
import qs.modules.services
import qs.modules.components.Clipboard
import qs.modules.components.WallpaperSelector
import qs.modules.components.FileDrop

Scope {
    CenterPanel {
        name: "wallpaperCenter"
        open: GlobalStates.wallpaperOpen && (SettingsConfig.general.wallpaperPanelMode ?? "dock") === "center"
        panelWidth: ServiceWallpaper.panelWidth
        panelHeight: ServiceWallpaper.panelHeight
        content: Component { WallpaperContent {} }
        onDismissed: GlobalStates.wallpaperOpen = false
    }

    CenterPanel {
        name: "clipboardCenter"
        open: GlobalStates.clipboardOpen && (SettingsConfig.general.clipboardPanelMode ?? "dock") === "center"
        panelWidth: Appearance.size.wallpaperPanelWidth
        panelHeight: Appearance.size.wallpaperPanelHeight
        content: (SettingsConfig.general.clipboardStyle ?? "list") === "fan" ? fanComp
            : (SettingsConfig.general.clipboardStyle ?? "list") === "board" ? boardComp : listComp
        onDismissed: GlobalStates.clipboardOpen = false
    }

    CenterPanel {
        name: "phone"
        open: GlobalStates.phoneOpen
        panelWidth: 440
        panelHeight: 720
        content: Component { PhonePanel { onClosed: GlobalStates.phoneOpen = false } }
        onDismissed: GlobalStates.phoneOpen = false
    }

    CenterPanel {
        name: "phoneFiles"
        open: GlobalStates.phoneBrowserOpen
        panelWidth: 1040
        panelHeight: 660
        content: Component {
            PhoneBrowser {
                onClosed: GlobalStates.phoneBrowserOpen = false
                onBack: {
                    GlobalStates.phoneBrowserOpen = false
                    GlobalStates.phoneOpen = true
                }
            }
        }
        onDismissed: GlobalStates.phoneBrowserOpen = false
    }

    Component {
        id: listComp
        ClipboardContent { onClosed: GlobalStates.clipboardOpen = false }
    }

    Component {
        id: boardComp
        ClipboardBoard { onClosed: GlobalStates.clipboardOpen = false }
    }

    Component {
        id: fanComp
        ClipboardFan { onClosed: GlobalStates.clipboardOpen = false }
    }
}
