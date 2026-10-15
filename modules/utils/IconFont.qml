pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property bool dark: Qt.color(Colors.surface).hslLightness < 0.5
    readonly property string family: root.dark && darkFont.status === FontLoader.Ready ? darkFont.name : "Material Symbols Rounded"

    FontLoader {
        id: darkFont
        source: "file://" + Quickshell.shellPath("assets/fonts/NebulaSymbolsDark.ttf")
    }
}
