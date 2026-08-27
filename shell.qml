//@ pragma UseQApplication
import Quickshell
import QtQuick
import Quickshell.Wayland
import qs.modules.components.layout
import qs.modules.components.LockScreen
import qs.modules.components.AppLauncher
import qs.modules.components.Clipboard
import qs.modules.components.Setting
import qs.modules.components.Osd
import qs.modules.components.WallpaperSelector
import qs.modules.components.MusicVis
import qs.modules.components.Dock
import qs.modules.components.Widgets
import qs.modules.components.ToolsWidget
import qs.modules.components.ShutdownWindow
import qs.modules.components.Screenshot
import qs.modules.components.GameMode
import qs.modules.components.CheatSheet
import qs.modules.components.Overview
import qs.modules.components.Ai
import qs.modules.components.Welcome
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings

ShellRoot{
    DockPanel{}

    Variants{
        model: Quickshell.screens
        delegate: Item{
            required property var modelData
            Layout{
                screen: modelData
                visible: !ServiceGameMode.hideBar
                isPrimary: {
                    const pm = SettingsConfig.general.primaryMonitor ?? ""
                    if (pm === "") return true
                    // Failover: if the configured primary is disconnected, first screen takes over
                    const primaryExists = Quickshell.screens.some(s => s.name === pm)
                    if (!primaryExists) return modelData === Quickshell.screens[0]
                    return modelData.name === pm
                }
            }
        }
    }

    AppLauncher{}
    SettingsPanel{}
    ToolsWidget{}
    Shutdown{}
    Loader{
        active: SettingsConfig.general.musicVisOn && !ServiceGameMode.hideWidgets
        sourceComponent:Vis{
            anchors {
                left: true
                right: true
                bottom: true
            }
        }
    }
    


    WidgetScreen{
        visible: !ServiceGameMode.hideWidgets
    }

    // Game mode confirmation pill — must outlive everything else it hides
    GameModeToast{}





    // Fullscreen area selector (replaces slurp for screenshot/recording area mode)
    AreaSelectorOverlay {}

    // Live Text — hyprctl dispatch global quickshell:ocr
    LiveTextOverlay {}

    // Post-capture thumbnail with Copy / Edit / Open / Delete
    ScreenshotPreview {}

    // Delayed-capture countdown
    CaptureCountdown {}

    // Keybinding cheat sheet — hyprctl dispatch global quickshell:cheatsheet
    CheatSheet {}

    // Workspace manager with live previews — hyprctl dispatch global quickshell:overview
    Overview {}

    // Type or dictate a prompt into claude.ai — hyprctl dispatch global quickshell:ai
    AiPanel {}

    WelcomePanel {}

    // Lock screen - responds to `loginctl lock-session`
    LockScreen {}

}
