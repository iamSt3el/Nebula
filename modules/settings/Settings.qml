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
        },
        {
            name: "Awake",
            icon: "bedtime",
            iconActive: "coffee"
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
            name: "Theme",
            icon: "palette",
        },
        {
            name: "Sound",
            icon: "volume_up"
        },
        {
            name: "Notifications",
            icon: "notifications"
        },
        {
            name: "Widgets",
            icon: "widgets"
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
            name: "Weather",
            icon: "partly_cloudy_day"
        },
        {
            name: "Media",
            icon: "perm_media"
        },
        {
            name: "About",
            icon: 'info'
        },
        {
            name: "Appearance",
            icon: "style"
        },
        {
            name: "Sleep",
            icon: "bedtime"
        },
        {
            name: "Storage",
            icon: "hard_drive"
        },
        {
            name: "Lock Screen",
            icon: "lock"
        },
        {
            name: "Sticky Notes",
            icon: "sticky_note_2"
        },
        {
            name: "Layouts",
            icon: "dashboard_customize"
        },
        {
            name: "Displays",
            icon: "monitor"
        },
        {
            name: "Windows",
            icon: "select_window"
        },
        {
            name: "Input",
            icon: "mouse"
        },
        {
            name: "Keybinds",
            icon: "keyboard"
        },
        {
            name: "Profile",
            icon: "account_circle"
        },
        {
            name: "Features",
            icon: "toggle_on"
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

    property var fonts: [
        { name: "Adwaita Sans" },
        { name: "Cantarell" },
        { name: "DejaVu Sans" },
        { name: "Fira Sans" },
        { name: "Liberation Sans" },
        { name: "Noto Sans" },
        { name: "Readex Pro" },
        { name: "Rubik" }
    ]

    property var displayFonts: [
        { name: "Titan One" },
        { name: "Google Sans Flex Clock" },
        { name: "Orbitron" },
        { name: "Michroma" },
        { name: "Just Another Hand" },
        { name: "Fira Sans" }
    ]

    property var transitionTypes: [
        { name: "ink" },
        { name: "ember" },
        { name: "shatter" },
        { name: "hex" },
        { name: "shockwave" },
        { name: "vortex" },
        { name: "light" },
        { name: "melt" },
        { name: "blinds" },
        { name: "glitch" },
        { name: "mosaic" },
        { name: "random" },
        { name: "none" }
    ]

    property var wallpaperFills: [
        { value: "crop", label: "Crop", icon: "crop" },
        { value: "fill", label: "Fill", icon: "open_in_full" },
        { value: "full", label: "Full", icon: "fit_screen" }
    ]

    function wallpaperFillOrDefault(f) {
        return settings.wallpaperFills.some(x => x.value === f) ? f : "crop"
    }

    function transitionOrDefault(t) {
        return settings.transitionTypes.some(x => x.name === t) ? t : "ink"
    }

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
            name: "scheme-vibrant"
        },
        {
            name: "scheme-rainbow"
        },
        {
            name: "scheme-kindle"
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
}
