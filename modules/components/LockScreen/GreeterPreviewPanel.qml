import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.modules.components.LockScreen

Scope {
    id: root
    property bool active: true

    GlobalShortcut {
        name: "greeterpreview"
        description: "Toggle greeter preview panel"
        onPressed: root.active = !root.active
    }

    Variants {
        model: root.active ? Quickshell.screens : []

        delegate: PanelWindow {
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore

            // Mock context that mimics GreeterContext API for preview
            QtObject {
                id: mockCtx
                property string currentText: ""
                property string currentUser: Quickshell.env("USER") || "steel"
                property bool   unlockInProgress: false
                property bool   showFailure: false

                signal readyToLaunch()
                signal failed()

                function tryUnlock() {
                    unlockInProgress = true
                    fakeTimer.start()
                }
            }

            Timer {
                id: fakeTimer
                interval: 900
                onTriggered: {
                    mockCtx.unlockInProgress = false
                    mockCtx.showFailure = true
                    mockCtx.currentText = ""
                }
            }

            Item {
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: root.active = false

                GreeterSurface {
                    anchors.fill: parent
                    context: mockCtx
                }

                // "Preview" badge + close hint
                Rectangle {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 20
                    implicitWidth: badgeRow.implicitWidth + 24
                    implicitHeight: 32
                    radius: 10
                    color: Qt.rgba(0, 0, 0, 0.55)

                    Row {
                        id: badgeRow
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "GREETER PREVIEW"
                            color: "#ffffff"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: escLabel.implicitWidth + 10
                            height: 18
                            radius: 4
                            color: Qt.rgba(1, 1, 1, 0.15)
                            Text {
                                id: escLabel
                                anchors.centerIn: parent
                                text: "ESC to close"
                                color: "#cccccc"
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }
}
