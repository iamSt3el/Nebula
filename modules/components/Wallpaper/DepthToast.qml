import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Scope {
    id: scope

    property bool shown: false

    readonly property bool busy: ServiceWallpaper.depthBusy
                                 && (SettingsConfig.parallax?.enabled ?? true)
                                 && !ServiceGameMode.hideWidgets

    onBusyChanged: {
        if (scope.busy) {
            showDelay.restart()
        } else {
            showDelay.stop()
            scope.shown = false
        }
    }

    Timer {
        id: showDelay
        interval: 600
        repeat: false
        onTriggered: scope.shown = scope.busy
    }

    Loader {
        active: scope.shown
        visible: active

        sourceComponent: PanelWindow {
            implicitWidth: 320
            implicitHeight: 56
            visible: true
            color: "transparent"

            anchors.top: true
            margins.top: 90

            WlrLayershell.namespace: "quickshell:depthToast"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            mask: Region {}

            Rectangle {
                anchors.centerIn: parent
                implicitWidth: content.implicitWidth + 34
                implicitHeight: 44
                radius: height / 2
                color: Settings.layoutColor
                opacity: 0
                scale: 0.88

                NumberAnimation on opacity { from: 0; to: 1; duration: 220; running: true; easing.type: Easing.OutCubic }
                NumberAnimation on scale   { from: 0.88; to: 1; duration: 220; running: true; easing.type: Easing.OutCubic }

                RowLayout {
                    id: content
                    anchors.centerIn: parent
                    spacing: 12

                    CustomCircularLoader {
                        size: 20
                        trackWidth: 3
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                    }

                    CustomText {
                        content: "Generating depth map…"
                        size: 14
                    }
                }
            }
        }
    }
}
