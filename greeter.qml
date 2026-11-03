import QtQuick
import Quickshell
import Quickshell.Services.Greetd
import Quickshell.Wayland
import qs.modules.components.LockScreen
import qs.modules.customComponents
import qs.modules.utils
import "modules/customComponents/LogoMotion.js" as Motion

ShellRoot {
    id: shell

    property real close: 0
    readonly property bool closing: closeAnim.running || shell.close > 0

    GreeterContext {
        id: greeterContext

        onReadyToLaunch: closeAnim.start()
        onFailed: {
            closeAnim.stop()
            shell.close = 0
        }
    }

    NumberAnimation {
        id: closeAnim
        target: shell
        property: "close"
        from: 0
        to: 1
        duration: 1600
        onFinished: greeterContext.launchSession()
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win

            required property var modelData
            screen: modelData
            color: "black"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore

            readonly property real u: shell.close
            readonly property real small: win.height * 0.36
            readonly property real e: Motion.emph(Motion.seg(win.u, 0.02, 0.68))
            readonly property real logoSize: Motion.glerp(Motion.coverSize(win.width, win.height), win.small, win.e)
            readonly property real spin: 40 * (1 - win.e)
            readonly property real fill: Motion.soft(Motion.seg(win.u, 0.55, 0.8)) * (1 - Motion.soft(Motion.seg(win.u, 0.82, 1)))

            GreeterSurface {
                anchors.fill: parent
                context: greeterContext
                uiOpacity: 1 - Motion.std(Motion.seg(win.u, 0, 0.25))
            }

            LogoCurtain {
                anchors.fill: parent
                visible: shell.closing
                logoSize: win.logoSize
                minSize: win.small
                spin: win.spin
            }

            NebulaLogo {
                anchors.centerIn: parent
                width: win.logoSize
                height: win.logoSize
                rotation: win.spin
                visible: opacity > 0.001
                opacity: win.fill
                outerColor: Colors.primaryContainer
                middleColor: Colors.primary
                innerColor: Colors.secondary
                coreColor: Colors.tertiary
            }
        }
    }
}
