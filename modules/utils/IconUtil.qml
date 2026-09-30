// IconUtils.qml
pragma Singleton
import QtQuick
import Quickshell

Item {
    function getIconName(windowClass) {
        const iconMap = {
            "firefox": "firefox",
            "google-chrome": "google-chrome",
            "chromium": "chromium",
            "code": "visual-studio-code",
            "discord": "discord",
            "spotify": "spotify",
            "kitty": "kitty",
            "alacritty": "Alacritty",
            "thunar": "thunar",
            "vlc": "vlc",
            "steam": "steam",
            "obsidian": "obsidian",
            "telegram": "telegram",
            "brave-browser": "brave-browser",
            "zen": "zen-browser",
            "emblem-mail": "telegram",
            "quickshell": "Quickshell"

        }
        if (!windowClass) return ""
        var lowerClass = windowClass.toLowerCase()
        return iconMap[lowerClass] || lowerClass || ""
    }

    function getIconPath(windowClass, fallback = "application-x-executable") {
        return Quickshell.iconPath(getIconName(windowClass), fallback)
    }

    // DesktopEntry.icon is already an icon name (or occasionally a file URL).
    // Do not send it through getIconName(): that helper is for window classes
    // and may rewrite or lowercase a perfectly valid desktop icon identifier.
    function getDesktopIconPath(iconName, fallback = "application-x-executable") {
        const icon = iconName ?? ""
        if (icon.startsWith("file://") || icon.startsWith("/"))
            return icon
        return Quickshell.iconPath(icon, fallback)
    }

    function getSystemIcon(iconName) {
        return Qt.resolvedUrl("../../assets/" + iconName + ".svg")
    }

    function getSystemIconPng(iconName){
        return Qt.resolvedUrl("../../assets/" + iconName + ".png")
    }

    function getImage(name){
        return Qt.resolvedUrl("../../assets/" + name)
    }
}
