import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Clipboard
import qs.modules.components.WallpaperSelector
import qs.modules.components.Osd
import qs.modules.components.AppLauncher
import qs.modules.components.CustomContextMenu

Item {
    id: panels

    required property Item block

    visible: false

    readonly property Component tuckPopup: tuckPopupComp
    readonly property Component tuckOsd: tuckOsdComp

    function forKind(kind) {
        if (!Features.barItemOn(kind))
            return null
        switch (kind) {
        case "calendar":  return calendarComp
        case "musicPoster": return musicPosterComp
        case "musicDial": return musicDialComp
        case "musicSources": return musicSourcesComp
        case "musicBeads": return musicBeadsComp
        case "musicDevelop": return musicDevelopComp
        case "musicShape": return musicShapeComp
        case "tray":      return trayComp
        case "trayMenu":  return trayMenuComp
        case "sound":     return soundComp
        case "soundscape": return soundscapeComp
        case "scenes":    return scenesComp
        case "network":   return networkComp
        case "bluetooth": return bluetoothComp
        case "brightness": return brightnessComp
        case "powerMode": return powerModeComp
        case "power":     return powerComp
        case "windowInfo": return windowInfoComp
        case "notifPopup": return notifPopupComp
        case "more":      return moreComp
        case "notifications": return notificationsComp
        case "battery":   return batteryComp
        case "claudeCode": return claudeCodeComp
        case "cpu":       return cpuComp
        case "memory":    return memoryComp
        case "wiz":       return wizComp
        case "kindle":    return kindleComp
        case "dashboard": return dashboardComp
        case "phoneStatus": return phoneStatusComp
        case "phoneNotifs": return phoneNotifsComp
        case "phoneCall": return phoneCallComp
        case "dockPreview": return dockPreviewComp
        case "dockMenu":  return dockMenuComp
        case "weather":   return weatherComp
        case "clipboard": return (SettingsConfig.general.clipboardStyle ?? "list") === "fan" ? clipFanComp
            : (SettingsConfig.general.clipboardStyle ?? "list") === "board" ? clipBoardComp : clipComp
        case "wallpaper": return wallComp
        case "osd":       return osdComp
        case "launcher":  return launcherComp
        }
        return null
    }

    Component {
        id: calendarComp
        Item {
            id: calHost
            anchors.fill: parent
            readonly property string calStyle: BarLayout.opt("clock", "panel") ?? "rail"
            Loader {
                anchors.fill: parent
                sourceComponent: calHost.calStyle === "rail" ? calRailComp : calAltComp
            }
            Component { id: calRailComp; Calander {} }
            Component { id: calAltComp; CalendarPanelAlt { style: calHost.calStyle } }
        }
    }
    Component {
        id: musicPosterComp
        BarMusicPanelPoster {
            topLeftRadius: panels.block.contentCorner("tl", 28)
            topRightRadius: panels.block.contentCorner("tr", 28)
            bottomLeftRadius: panels.block.contentCorner("bl", 28)
            bottomRightRadius: panels.block.contentCorner("br", 28)
        }
    }
    Component { id: musicDialComp; BarMusicPanelDial {} }
    Component { id: musicSourcesComp; BarMusicPanelSources {} }
    Component { id: musicBeadsComp; BarMusicPanelBeads {} }
    Component { id: musicDevelopComp; BarMusicPanelDevelop {} }
    Component { id: musicShapeComp; BarMusicPanelShape {} }
    Component {
        id: trayComp
        Item {
            SystemTray {
                anchors.centerIn: parent
                columns: 6
                spacing: 6
                iconPx: 20
                plate: 36
                offset: panels.block.trayOffset
                onMenuRequested: (it, src) => panels.block.openTrayMenu(it, null)
                onActivated: panels.block.closePanel()
            }
        }
    }
    Component {
        id: dockPreviewComp
        DockPreview {
            appEntry: panels.block.dockAppEntry
            maxWidth: panels.block.dockPreviewCap
            onActivated: panels.block.closePanel()
        }
    }
    Component {
        id: dockMenuComp
        CustomContextMenu {
            appEntry: panels.block.dockAppEntry
            onClose: panels.block.closePanel()
        }
    }
    Component { id: cpuComp; BarCpuPanel {} }
    Component { id: memoryComp; BarMemoryPanel {} }
    Component {
        id: wizComp
        BarWizPanel {
            maxHeight: Math.max(320, panels.block.openHeight - panels.block.barH - 40)
        }
    }
    Component {
        id: networkComp
        BarNetworkPanel {
            onBackClicked: panels.block.closePanel()
        }
    }
    Component {
        id: bluetoothComp
        Bluetooth {
            showBack: false
            onBackClicked: panels.block.closePanel()
        }
    }
    Component { id: brightnessComp; BarBrightnessPanel {} }
    Component { id: powerModeComp; ModesPanel { onBackClicked: panels.block.closePanel() } }
    Component { id: powerComp;     BarPowerPanel { onCloseRequested: panels.block.closePanel() } }
    Component { id: windowInfoComp; BarWindowPanel { onClosed: panels.block.closePanel() } }
    Component {
        id: notifPopupComp
        BarNotifPopup {
            showOsd: panels.block.osdWant
            onMoreClicked: {
                const bell = panels.block.itemIds.find(id => BarLayout.baseId(id) === "notifications")
                if (bell)
                    panels.block.openPanel("notifications", panels.block.itemFor(bell))
                else
                    ServiceNotification.dismissPopups()
            }
        }
    }
    Component {
        id: moreComp
        BarOverflowContent {
            hostBlock: panels.block
            blockIds: panels.block.frame && panels.block.frame.foldIds ? panels.block.frame.foldIds : []
        }
    }
    Component {
        id: notificationsComp
        BarNotificationsPanel {
            maxHeight: Math.max(320, panels.block.openHeight - panels.block.barH - 40)
        }
    }
    Component { id: batteryComp;   BarBatteryPanel {} }
    Component { id: claudeCodeComp; BarClaudePanel {} }
    Component { id: kindleComp; BarKindlePanel {} }
    Component {
        id: dashboardComp
        DashboardPanel {
            closer: () => panels.block.closePanel()
            room: panels.block.heightRoom
            fixedH: BarLayout.panelH("dashboard")
        }
    }
    Component { id: phoneStatusComp; BarPhoneStatusPanel { onClosed: panels.block.closePanel() } }
    Component {
        id: phoneNotifsComp
        BarPhoneNotifsPanel {
            maxHeight: Math.max(320, panels.block.openHeight - panels.block.barH - 40)
        }
    }
    Component {
        id: phoneCallComp
        BarPhoneCallPanel {
            maxHeight: Math.max(320, panels.block.openHeight - panels.block.barH - 40)
        }
    }
    Component {
        id: soundComp
        BarSoundPanel {
            maxHeight: Math.max(240, panels.block.openHeight - panels.block.barH - 40)
        }
    }
    Component {
        id: scenesComp
        BarScenesPanel {
            maxHeight: Math.max(240, panels.block.openHeight - panels.block.barH - 40)
        }
    }
    Component {
        id: soundscapeComp
        BarSoundscapePanel {
            maxHeight: Math.max(240, panels.block.openHeight - panels.block.barH - 40)
        }
    }
    Component {
        id: trayMenuComp
        TrayMenuContent {
            handle: panels.block.trayMenuAlive ? panels.block.trayMenuItem.menu : null
            title: panels.block.trayMenuAlive ? (panels.block.trayMenuItem.tooltipTitle || panels.block.trayMenuItem.title
                                             || panels.block.trayMenuItem.id || "") : ""
            maxHeight: Math.max(160, panels.block.openHeight - panels.block.barH - 40)
            onDone: panels.block.closePanel()
        }
    }
    Component {
        id: weatherComp
        WeatherPanel {
            topLeftRadius: panels.block.contentCorner("tl", 20)
            topRightRadius: panels.block.contentCorner("tr", 20)
            bottomLeftRadius: panels.block.contentCorner("bl", 20)
            bottomRightRadius: panels.block.contentCorner("br", 20)
            onClosed: panels.block.closePanel()
        }
    }
    Component {
        id: clipComp
        ClipboardContent {
            topLeftRadius: panels.block.contentCorner("tl", 20)
            topRightRadius: panels.block.contentCorner("tr", 20)
            bottomLeftRadius: panels.block.contentCorner("bl", 20)
            bottomRightRadius: panels.block.contentCorner("br", 20)
            onClosed: GlobalStates.clipboardOpen = false
        }
    }
    Component {
        id: clipFanComp
        ClipboardFan {
            topLeftRadius: panels.block.contentCorner("tl", 20)
            topRightRadius: panels.block.contentCorner("tr", 20)
            bottomLeftRadius: panels.block.contentCorner("bl", 20)
            bottomRightRadius: panels.block.contentCorner("br", 20)
            onClosed: GlobalStates.clipboardOpen = false
        }
    }
    Component {
        id: clipBoardComp
        ClipboardBoard {
            topLeftRadius: panels.block.contentCorner("tl", 20)
            topRightRadius: panels.block.contentCorner("tr", 20)
            bottomLeftRadius: panels.block.contentCorner("bl", 20)
            bottomRightRadius: panels.block.contentCorner("br", 20)
            onClosed: GlobalStates.clipboardOpen = false
        }
    }
    Component {
        id: wallComp
        WallpaperContent {
            topLeftRadius: panels.block.contentCorner("tl", Appearance.radius.large)
            topRightRadius: panels.block.contentCorner("tr", Appearance.radius.extraLarge)
            bottomLeftRadius: panels.block.contentCorner("bl", Appearance.radius.large)
            bottomRightRadius: panels.block.contentCorner("br", Appearance.radius.extraLarge)
        }
    }
    Component { id: osdComp; OsdContent { vertical: panels.block.vertical; outerRadius: panels.block.contentFar(20) } }
    Component {
        id: tuckOsdComp
        OsdContent { pad: 0; height: 48 }
    }
    Component {
        id: tuckPopupComp
        BarNotifPopup {
            showOsd: panels.block.tuckOsd
            onMoreClicked: ServiceNotification.dismissPopups()
        }
    }
    Component {
        id: launcherComp
        AppLauncherContent {
            entranceDelay: 0
            outerCorners: ({ tl: panels.block.contentCorner("tl", 20), tr: panels.block.contentCorner("tr", 20),
                             bl: panels.block.contentCorner("bl", 20), br: panels.block.contentCorner("br", 20) })
            preview: GlobalStates.launcherPreview
            enabled: !GlobalStates.launcherPreview
            onClosed: GlobalStates.appLauncherOpen = false
        }
    }
}
