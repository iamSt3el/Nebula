pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property bool dark: Qt.color(Colors.surface).hslLightness < 0.5
    readonly property string family: root.dark && darkFont.status === FontLoader.Ready ? darkFont.name : "Material Symbols Rounded"
    readonly property string filledFamily: filledFont.status === FontLoader.Ready ? filledFont.name : root.family

    FontLoader {
        id: darkFont
        source: "file://" + Quickshell.shellPath("assets/fonts/NebulaSymbolsDark.ttf")
    }

    FontLoader {
        id: filledFont
        source: "file://" + Quickshell.shellPath("assets/fonts/NebulaSymbolsFilled.ttf")
    }
}
