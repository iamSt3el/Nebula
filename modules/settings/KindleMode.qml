pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property bool active: (SettingsConfig.theme.matugenScheme ?? "") === "scheme-kindle"
    readonly property bool outlines: active && (SettingsConfig.theme.kindleOutlines ?? true)
    readonly property string wallpaper: active ? (SettingsConfig.theme.kindleWallpaper ?? "blank") : "keep"
    readonly property bool greyIcons: active && (SettingsConfig.theme.kindleGreyIcons ?? true)
    readonly property bool greyAnsi: active && (SettingsConfig.theme.kindleGreyAnsi ?? false)
    readonly property int edge: 2
    readonly property string iconTheme: greyIcons ? "kindle" : ""
    readonly property bool recolorIcons: iconTheme !== ""
    property string iconAssets: ""
}
