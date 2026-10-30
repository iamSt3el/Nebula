//@ pragma UseQApplication
//@ pragma Env QSG_ATLAS_WIDTH=512
//@ pragma Env QSG_ATLAS_HEIGHT=512
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.modules.settings
import qs.modules.components.Welcome

ShellRoot {
    id: shellRoot

    property var chosenScreen: null

    function pickScreen() {
        if (shellRoot.chosenScreen)
            return
        const name = Hyprland.focusedMonitor?.name ?? ""
        const match = Quickshell.screens.find(s => s.name === name)
        if (match)
            shellRoot.chosenScreen = match
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() { shellRoot.pickScreen() }
    }

    Component.onCompleted: {
        Features.manageReload = false
        shellRoot.pickScreen()
    }

    PanelWindow {
        id: panel

        screen: shellRoot.chosenScreen ?? Quickshell.screens[0]
        implicitWidth: 1120
        implicitHeight: 720
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "nebula-setup"
        WlrLayershell.layer: GlobalStates.fileDialogOpen ? WlrLayer.Bottom : WlrLayer.Top
        WlrLayershell.keyboardFocus: GlobalStates.fileDialogOpen ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand

        WelcomeContent {
            onClosed: Qt.quit()
        }
    }
}
