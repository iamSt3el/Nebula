//@ pragma Env QS_NO_RELOAD_POPUP=1
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.customComponents
import qs.modules.utils
import "modules/customComponents/LogoMotion.js" as Motion

ShellRoot {
    id: root

    property bool ignited: false
    property bool asked: false
    property bool revealing: false
    property real spin: 0
    property real spinStart: 0
    property real reveal: 0

    function ask() {
        root.asked = true
        root.tryReveal()
    }

    function tryReveal() {
        if (!root.asked || !root.ignited || root.revealing)
            return
        holdSpin.stop()
        root.spinStart = root.spin
        root.revealing = true
        revealAnim.start()
    }

    IpcHandler {
        target: "splash"

        function reveal(): void {
            root.ask()
        }
    }

    property real ignite: 0

    Timer {
        interval: 150
        running: true
        onTriggered: igniteAnim.start()
    }

    NumberAnimation {
        id: igniteAnim
        target: root
        property: "ignite"
        from: 0
        to: 1
        duration: 1800
        onFinished: {
            root.ignited = true
            holdSpin.start()
            root.tryReveal()
        }
    }

    Timer {
        interval: 12000
        running: true
        onTriggered: root.ask()
    }

    NumberAnimation {
        id: holdSpin
        target: root
        property: "spin"
        from: 0
        to: 360
        duration: 20000
        loops: Animation.Infinite
    }

    NumberAnimation {
        id: revealAnim
        target: root
        property: "reveal"
        from: 0
        to: 1
        duration: 1500
        onFinished: Qt.quit()
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: win

            required property var modelData
            screen: modelData
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:splash"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            readonly property real small: win.height * 0.36
            readonly property real r: root.reveal
            readonly property real logoSize: Motion.glerp(win.small, Motion.coverSize(win.width, win.height), Motion.accel(Motion.seg(win.r, 0.3, 1)))
            readonly property real spin: root.revealing ? root.spinStart + 60 * Motion.std(win.r) : root.spin

            Rectangle {
                anchors.fill: parent
                visible: !root.revealing
                color: "black"
            }

            LogoCurtain {
                anchors.fill: parent
                visible: root.revealing
                logoSize: win.logoSize
                minSize: win.small
                spin: win.spin
            }

            NebulaLogo {
                anchors.centerIn: parent
                width: win.logoSize
                height: win.logoSize
                rotation: win.spin
                progress: root.ignite
                visible: opacity > 0.001
                opacity: 1 - Motion.seg(win.r, 0.2, 0.45)
                outerColor: Colors.primaryContainer
                middleColor: Colors.primary
                innerColor: Colors.secondary
                coreColor: Colors.tertiary
            }
        }
    }
}
