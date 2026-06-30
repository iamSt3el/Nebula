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
    implicitWidth: 260
    implicitHeight: child.implicitHeight
    visible: true
    color: "transparent"
    signal close

    anchor {
        window: layout
        rect.x: utility.soundPanelCenterX - root.implicitWidth / 2
        rect.y: sectionsRow.y + utility.y + utility.height + (SettingsConfig.general.barMode === "pill" ? 8 : 4)
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
        implicitHeight: col.implicitHeight + 20
        color: Colors.surface
        radius: 20

        opacity: 0
        NumberAnimation on opacity { from: 0; to: 1; duration: 160; running: true }

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors { margins: 10; topMargin: 10 }
            spacing: 8

            // ── Output card ────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: outCol.implicitHeight + 20
                radius: 16
                color: Colors.surfaceContainerHigh

                ColumnLayout {
                    id: outCol
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    anchors { margins: 12; topMargin: 12 }
                    spacing: 10

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            width: 26; height: 26; radius: 8
                            color: Colors.primaryContainer
                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: "volume_up"; iconSize: 15
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
                            width: 26; height: 26; radius: 8
                            color: ServicePipewire.muted
                                   ? Qt.alpha(Colors.error, 0.15)
                                   : muteHov.containsMouse
                                     ? Colors.primaryContainer
                                     : Colors.surfaceContainerHighest
                            Behavior on color { ColorAnimation { duration: 120 } }

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: ServicePipewire.muted ? "volume_off" : "volume_up"
                                iconSize: 15
                                customColor: ServicePipewire.muted ? Colors.error
                                           : muteHov.containsMouse ? Colors.primaryContainerText
                                           : Colors.outline
                                Behavior on customColor { ColorAnimation { duration: 120 } }
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

                    // Output device
                    CustomList {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        color: Colors.surfaceContainerHighest
                        currentVal: ServicePipewire.sink?.description ?? ""
                        list: ServicePipewire.sinks
                        onIsListClickedChanged: focusGrab.active = !isListClicked
                        onListChildClicked: child => ServicePipewire.setAudioSink(child)
                    }
                }
            }

            // ── Input card ─────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: inCol.implicitHeight + 20
                radius: 16
                color: Colors.surfaceContainerHigh

                ColumnLayout {
                    id: inCol
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    anchors { margins: 12; topMargin: 12 }
                    spacing: 10

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            width: 26; height: 26; radius: 8
                            color: Colors.surfaceContainerHighest
                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: "mic"; iconSize: 15
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
                            width: 26; height: 26; radius: 8
                            color: ServicePipewire.micMuted
                                   ? Qt.alpha(Colors.error, 0.15)
                                   : micMuteHov.containsMouse
                                     ? Colors.primaryContainer
                                     : Colors.surfaceContainerHighest
                            Behavior on color { ColorAnimation { duration: 120 } }

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: ServicePipewire.micMuted ? "mic_off" : "mic"
                                iconSize: 15
                                customColor: ServicePipewire.micMuted ? Colors.error
                                           : micMuteHov.containsMouse ? Colors.primaryContainerText
                                           : Colors.outline
                                Behavior on customColor { ColorAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: micMuteHov
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ServicePipewire.toggleMicMute()
                            }
                        }
                    }

                    // Mic slider
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

                    // Input device
                    CustomList {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        color: Colors.surfaceContainerHighest
                        currentVal: ServicePipewire.source?.description ?? ""
                        list: ServicePipewire.sources
                        onIsListClickedChanged: focusGrab.active = !isListClicked
                        onListChildClicked: child => ServicePipewire.setAudioSource(child)
                    }
                }
            }
        }
    }

    // ── Slider component ──────────────────────────────────────────────────
    component VolSlider: Item {
        id: vs
        implicitHeight: 24

        property real value: 0
        signal moved(real val)

        property bool _drag: false
        property real _dragVal: 0
        readonly property real _shown: _drag ? _dragVal : value

        readonly property real _tw: width - 24
        readonly property real _tx: 12 + _tw * _shown

        // Track fill
        Rectangle {
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width:  Math.max(0, vs._tw * vs._shown)
            height: 3; radius: 2
            color: Colors.primary
        }

        // Track empty
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width:  Math.max(0, vs._tw * (1 - vs._shown))
            height: 3; radius: 2
            color: Qt.alpha(Colors.primary, 0.15)
        }

        // Thumb
        Rectangle {
            x: vs._tx - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 13; height: 13; radius: 7
            color: Colors.primary
            scale: sliderArea.pressed ? 1.3 : sliderArea.containsMouse ? 1.1 : 1.0
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }

            Rectangle {
                anchors.centerIn: parent
                width: 4; height: 4; radius: 2
                color: Colors.primaryText
                opacity: 0.5
            }
        }

        MouseArea {
            id: sliderArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function snap(mx) {
                var v = Math.max(0, Math.min(1, (mx - 12) / vs._tw))
                vs._dragVal = v
                vs.moved(v)
            }

            onPressed:         event => { vs._drag = true;  snap(event.x) }
            onPositionChanged: event => { if (pressed) snap(event.x) }
            onReleased:        vs._drag = false
        }
    }
}
