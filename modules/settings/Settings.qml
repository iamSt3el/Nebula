pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import qs.modules.utils

Singleton{
    id: settings

    property string layoutColor: Colors.surface
    property string activeTheme: "Wallpaper"
    property int    dashboardHeight: 400
    property string wallpaper: Colors.wallpaper
    property string matugenSetting: "Light"
    property string matugenTheme: matugenSetting.toLowerCase()
    property string currentDisplayMode: "Extended"
    property string currentMatugenStyle: "default"
    property string matugenScheme: "scheme-content"

    // Workspace configur ation per monitor
    property var monitorWorkspaces: ({
        "eDP-1": { // Your HDMI monitor name - adjust this
            workspaces: [1, 2, 3, 4, 5],
            type: "external"
        }
            //,
        // "eDP-1": { // Your laptop display name - adjust this
        //     workspaces: [6, 7, 8, 9, 10],
        //     type: "laptop"
        // }
    })

    property string firstColor:"#833ab4"
    property string secondColor:"#fd1d1d"
    property string thirdColor:"#fcb045"

    property var quickIcons:[
        {
            name: "Airplane",
            icon: "travel",
            iconActive: "airplanemode_inactive"

        },
        {
            name: "Notification",
            icon: "notifications",
            iconActive: "notifications_off"
        },
        {
            name: "Speaker",
            icon: "volume_up",
            iconActive: "volume_off"
        },
        {
            name: "Mic",
            icon: "mic",
            iconActive: "mic_off"
        }

    ]
    property var themeModes:[
        {
            name: "Dark",
            icon: "bedtime"
        },
        {
            name: "Light",
            icon: "sunny"
        }
    ]

    property var pages:[
        {
            name: "General",
            icon: "tune",
        },
        {
            name: "Theme",
            icon: "palette",
        },
        {
            name: "Sound",
            icon: "volume_up"
        },
        {
            name: "Networking",
            icon: "android_wifi_4_bar"
        },
        {
            name: "Bluetooth",
            icon: "bluetooth"
        },
        {
            name: "Ai",
            icon: "neurology"
        },
        {
            name: "Manga",
            icon: "menu_book"
        },
        {
            name: "Weather",
            icon: "partly_cloudy_day"
        },
        {
            name: "About",
            icon: 'info'
        }

    ]

    property var displayModes:[
        {
            name: "Extended",
            icon: "pan_zoom"
        },
        {
            name: "Mirror",
            icon: "tv_displays"
        },
        {
            name: "Single",
            icon: "monitor"
        }
    ]

    property var fonts:[
        { 
            name: "Noto Sans"
        },

        {
           name:"Fira Sans"
        },
        {
            name:"Readex Pro"
        },
        {
            name:"Cantarell"
        },
        {
            name: "Rubik"
        }
    ]

    property var matugen:[
        {
            name: "scheme-tonal-spot"
        },
        {
            name: "scheme-content"
        },
        {
            name: "scheme-expressive"
        },
        {
            name: "scheme-fidelity"
        },
        {
            name: "scheme-fruit-salad"
        },
        {
            name:"scheme-monochrome"
        },
        {
            name:"scheme-neutral"
        },
        {
            name: "scheme-rainbow"
        }    
    ]

    function setActiveTheme(theme): void{
        settings.activeTheme = theme
    }

    function setMatugenTheme(theme): void{
        settings.matugenTheme = theme
    }

    function setMatugenSetting(type): void{
        settings.matugenSetting = type
    }

    // Get workspaces for a specific monitor
    function getWorkspacesForMonitor(monitorName): var {
        if (monitorWorkspaces[monitorName]) {
            return monitorWorkspaces[monitorName].workspaces
        }
        // Fallback: return 1-5 if monitor not found
        return [1, 2, 3, 4, 5]
    }

    // Get all workspaces NOT assigned to this monitor (for other screen indicator)
    function getOtherScreenWorkspaces(monitorName): var {
        var otherWorkspaces = []
        for (var monitor in monitorWorkspaces) {
            if (monitor !== monitorName) {
                otherWorkspaces = otherWorkspaces.concat(monitorWorkspaces[monitor].workspaces)
            }
        }
        return otherWorkspaces
    }
}
