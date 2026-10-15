// IconUtils.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.settings

Item {
    property var greyIndex: ({})

    FileView {
        path: KindleMode.recolorIcons && KindleMode.iconAssets !== "" ? KindleMode.iconAssets + "/icon-index.json" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                greyIndex = JSON.parse(text())
            } catch (e) {
                greyIndex = ({})
            }
        }
    }

    property var colourIndex: ({})

    PersistentProperties {
        id: iconStart
        reloadableId: "iconUtilStartTheme"
        property string theme: ""
        property bool known: false
        property bool reading: false
        onLoaded: if (!iconStart.known) iconStart.reading = true
    }

    FileView {
        path: iconStart.reading ? Quickshell.env("HOME") + "/.config/qt6ct/qt6ct.conf" : ""
        onLoaded: {
            const m = text().match(/^icon_theme=(.*)$/m)
            iconStart.theme = m ? m[1].trim() : ""
            iconStart.known = true
            iconStart.reading = false
        }
    }

    FileView {
        path: iconStart.theme.startsWith("gowall-") && iconStart.theme.endsWith("-kindle")
            ? Quickshell.env("HOME") + "/.cache/quickshell/gowall/assets-kindle/source-index.json" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                colourIndex = JSON.parse(text())
            } catch (e) {
                colourIndex = ({})
            }
        }
    }

    function themeIcon(name, fallback) {
        const file = KindleMode.recolorIcons ? greyIndex[name ?? ""] : colourIndex[name ?? ""]
        if (file)
            return "file://" + file
        return fallback === undefined ? Quickshell.iconPath(name) : Quickshell.iconPath(name, fallback)
    }

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

    function imageSource(src) {
        const s = src ?? ""
        return s.startsWith("image://icon//") ? "file://" + s.slice(13) : s
    }

    function getIconPath(windowClass, fallback = "application-x-executable") {
        return themeIcon(getIconName(windowClass), fallback)
    }

    function getDesktopIconPath(iconName, fallback = "application-x-executable") {
        const icon = iconName ?? ""
        if (icon.startsWith("file://") || icon.startsWith("/"))
            return icon
        return themeIcon(icon, fallback)
    }

    function getSystemIcon(iconName) {
        if (KindleMode.recolorIcons && KindleMode.iconAssets !== "")
            return "file://" + KindleMode.iconAssets + "/" + iconName + ".svg"
        return Qt.resolvedUrl("../../assets/" + iconName + ".svg")
    }

    function getSystemIconPng(iconName){
        return Qt.resolvedUrl("../../assets/" + iconName + ".png")
    }

    function getImage(name){
        return Qt.resolvedUrl("../../assets/" + name)
    }
}

