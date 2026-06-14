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
import qs.modules.customComponents
import qs.modules.settings
import qs.modules
import qs.rubiksCube

ShellRoot{
    DockPanel{}

    Variants{
        model: Quickshell.screens
        delegate: Item{
            required property var modelData
            Layout{
                screen: modelData
            }
        }
    }

    AppLauncher{}
    SettingsPanel{}
    ToolsWidget{}
    Shutdown{}
    Loader{
        active: SettingsConfig.general.musicVisOn
        sourceComponent:Vis{
            anchors {
                left: true
                right: true
                bottom: true
            }
        }
    }
    
    //InputTest{}


    WidgetScreen{}
    

    //CubeTest{}




    // Fullscreen area selector (replaces slurp for screenshot/recording area mode)
    AreaSelectorOverlay {}

    // Lock screen - responds to `loginctl lock-session`
    LockScreen {}
}
