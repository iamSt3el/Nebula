import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton{
    id: root
    property bool appLauncherOpen: false
    property bool clipboardOpen: false
    property bool settingsOpen: false
    property int  settingsPage: 9
    property bool osdOpen: false
    property bool wallpaperOpen: false
    property bool typingGameOpen: false
    property bool toolsWidgetOpen: false
    property bool shutdownWindow: false
    property bool fileDialogOpen: false
    property bool areaSelectOpen: false
    property string areaSelectMode: ""   // "screenshot" or "recording"
}
