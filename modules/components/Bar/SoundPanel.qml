import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.modules.customComponents
import qs.modules.utils
import qs.modules.settings
import qs.modules.services

PopupWindow {
    id: root
    implicitWidth: 300
    implicitHeight: child.implicitHeight
    visible: true
    color: "transparent"
    signal close

    anchor {
        window: layout
        rect.x: utility.x
        rect.y: utility.y + utility.height + 4
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: true
        windows: [QsWindow.window]
        onCleared: root.close()
    }


    Rectangle {
        id: child
        implicitWidth: parent.width
        implicitHeight: col.implicitHeight + 24
        color: Colors.surface
        radius: 20

        scale:   0.88
        opacity: 0
        NumberAnimation on opacity { from: 0; to: 1; duration: 180; running: true }
        NumberAnimation on scale   { from: 0.88; to: 1; duration: 260; running: true; easing.type: Easing.OutBack; easing.overshoot: 0.35 }

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; topMargin: 12 }
            spacing: 10

            // ── Output section ─────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                // Header row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 30; height: 30; radius: 15
                        color: Colors.primaryContainer
                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "volume_up"; iconSize: 16
                            customColor: Colors.primaryContainerText
                        }
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: "Output"
                        size: 13; weight: 600
                        customColor: Colors.surfaceText
                    }

                    CustomText {
                        content: ServicePipewire.muted ? "Muted"
                               : Math.round(ServicePipewire.volume * 100) + "%"
                        size: 12; weight: 700
                        customColor: ServicePipewire.muted ? Colors.error : Colors.primary
                    }

                    Rectangle {
                        width: 30; height: 30; radius: 15
                        color: ServicePipewire.muted
                               ? Qt.alpha(Colors.error, 0.15)
                               : muteHov.containsMouse ? Colors.primaryContainer : Colors.surfaceContainerHigh
                        Behavior on color { ColorAnimation { duration: 130 } }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: ServicePipewire.muted ? "volume_off" : "volume_up"
                            iconSize: 16
                            customColor: ServicePipewire.muted ? Colors.error
                                       : muteHov.containsMouse ? Colors.primaryContainerText : Colors.outline
                            Behavior on customColor { ColorAnimation { duration: 130 } }
                        }

                        MouseArea {
                            id: muteHov
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ServicePipewire.toggleMute()
                        }
                    }
                }

                // Volume slider
                VolSlider {
                    Layout.fillWidth: true
                    value: ServicePipewire.volume
                    onMoved: v => ServicePipewire.setVolume(v)
                }

                // Output device list
                CustomList {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    color: Colors.surfaceContainerHigh
                    currentVal: ServicePipewire.sink?.description ?? ""
                    list: ServicePipewire.sinks
                    onIsListClickedChanged: focusGrab.active = !isListClicked
                    onListChildClicked: child => ServicePipewire.setAudioSink(child)
                }
            }

            // ── Divider ────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.alpha(Colors.outline, 0.12)
            }

            // ── Input section ──────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                // Header row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 30; height: 30; radius: 15
                        color: Colors.surfaceContainerHigh
                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "mic"; iconSize: 16
                            customColor: Colors.outline
                        }
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: "Input"
                        size: 13; weight: 600
                        customColor: Colors.surfaceText
                    }

                    CustomText {
                        content: ServicePipewire.micMuted ? "Muted"
                               : Math.round((ServicePipewire.source?.audio?.volume ?? 0) * 100) + "%"
                        size: 12; weight: 700
                        customColor: ServicePipewire.micMuted ? Colors.error : Colors.outline
                    }

                    Rectangle {
                        width: 30; height: 30; radius: 15
                        color: ServicePipewire.micMuted
                               ? Qt.alpha(Colors.error, 0.15)
                               : micMuteHov.containsMouse ? Colors.primaryContainer : Colors.surfaceContainerHigh
                        Behavior on color { ColorAnimation { duration: 130 } }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: ServicePipewire.micMuted ? "mic_off" : "mic"
                            iconSize: 16
                            customColor: ServicePipewire.micMuted ? Colors.error
                                       : micMuteHov.containsMouse ? Colors.primaryContainerText : Colors.outline
                            Behavior on customColor { ColorAnimation { duration: 130 } }
                        }

                        MouseArea {
                            id: micMuteHov
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ServicePipewire.toggleMicMute()
                        }
                    }
                }

                // Mic volume slider
                VolSlider {
                    Layout.fillWidth: true
                    value: ServicePipewire.source?.audio?.volume ?? 0
                    onMoved: v => {
                        if (ServicePipewire.source?.audio) {
                            ServicePipewire.source.audio.muted  = false
                            ServicePipewire.source.audio.volume = v
                        }
                    }
                }

                // Input device list
                CustomList {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    color: Colors.surfaceContainerHigh
                    currentVal: ServicePipewire.source?.description ?? ""
                    list: ServicePipewire.sources
                    onIsListClickedChanged: focusGrab.active = !isListClicked
                    onListChildClicked: child => ServicePipewire.setAudioSource(child)
                }
            }
        }
    }

    // ── Continuous volume slider ───────────────────────────────────────────
    component VolSlider: Item {
        id: vs
        implicitHeight: 28

        property real value: 0
        signal moved(real val)

        property bool _drag: false
        property real _dragVal: 0
        readonly property real _shown: _drag ? _dragVal : value

        readonly property real _tw: width - 28
        readonly property real _tx: 14 + _tw * _shown

        Rectangle {
            anchors.left:           parent.left;  anchors.leftMargin:  14
            anchors.verticalCenter: parent.verticalCenter
            width:  Math.max(0, vs._tw * vs._shown)
            height: 4; radius: 2
            color:  Colors.primary
        }

        Rectangle {
            anchors.right:          parent.right; anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width:  Math.max(0, vs._tw * (1 - vs._shown))
            height: 4; radius: 2
            color:  Qt.alpha(Colors.primary, 0.18)
        }

        Rectangle {
            x: vs._tx - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 7
            color: Colors.primary
            scale: sliderArea.pressed ? 1.25 : sliderArea.containsMouse ? 1.1 : 1.0
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }

            Rectangle {
                anchors.centerIn: parent
                width: 5; height: 5; radius: 3
                color: Colors.primaryText
                opacity: 0.5
            }
        }

        MouseArea {
            id: sliderArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            preventStealing: true

            function snap(mx) {
                var v = Math.max(0, Math.min(1, (mx - 14) / vs._tw))
                vs._dragVal = v
                vs.moved(v)
            }

            onPressed:         event => { vs._drag = true;  snap(event.x) }
            onPositionChanged: event => { if (pressed) snap(event.x) }
            onReleased:        vs._drag = false
        }
    }
}
