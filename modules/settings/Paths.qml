pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || root.home + "/.config") + "/nebula"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || root.home + "/.local/state") + "/nebula"
    readonly property string cli: Quickshell.shellDir + "/bin/nebula"
}
