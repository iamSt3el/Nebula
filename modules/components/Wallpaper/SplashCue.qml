import QtQuick
import Quickshell
import qs.modules.settings
import qs.modules.utils

Scope {
    id: root

    readonly property bool wanted: Quickshell.env("NEBULA_SPLASH") === "1"
    readonly property bool shown: GlobalStates.wallpaperShown || WallpaperTheme.wallpaperScreen === ""
    property bool sent: false

    function send() {
        if (root.sent)
            return
        root.sent = true
        Quickshell.execDetached(["qs", "ipc", "-p", Quickshell.shellDir + "/splash.qml", "call", "splash", "reveal"])
    }

    onShownChanged: if (root.wanted && root.shown) settle.restart()
    Component.onCompleted: if (root.wanted && root.shown) settle.restart()

    Timer {
        id: settle
        interval: 300
        onTriggered: root.send()
    }

    Timer {
        interval: 8000
        running: root.wanted
        onTriggered: root.send()
    }
}
