import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    PwNodePeakMonitor { id: outputPeak; node: ServicePipewire.sink }
    PwNodePeakMonitor { id: inputPeak;  node: ServicePipewire.source }

    property var sinkList: {
        const r = []
        for (let i = 0; i < ServicePipewire.sinks.length; i++)
            r.push({ name: ServicePipewire.sinks[i].description })
        return r
    }
    property var sourceList: {
        const r = []
        for (let i = 0; i < ServicePipewire.sources.length; i++)
            r.push({ name: ServicePipewire.sources[i].description })
        return r
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        contentWidth: width
        clip: true

        ColumnLayout {
            id: column
            width: parent.width
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            anchors.topMargin: 5
            spacing: 0

            // ── Header ────────────────────────────────────────────────────────
            RowLayout {
                spacing: 10
                MaterialIconSymbol { content: "volume_up"; iconSize: 20 }
                CustomText { content: "Sound"; size: 20; color: Colors.primary }
            }

            // ── Output ────────────────────────────────────────────────────────
            CustomText { Layout.topMargin: 30; content: "Output"; size: 18; color: Colors.primary }
            CustomText { content: "Adjust volume and choose your playback device"; size: 14; color: Colors.outline }

            // Output device row
            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 0
                    CustomText { content: "Output Device"; size: 16 }
                    CustomText { content: "Active output sink"; size: 13; color: Colors.outline }
                }
                Item { Layout.fillWidth: true }
                CustomListNew {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 30
                    currentVal: ServicePipewire.sink?.description ?? ""
                    list: root.sinkList
                    onCurrentValChanged: {
                        if (!currentVal) return
                        for (let i = 0; i < ServicePipewire.sinks.length; i++) {
                            if (ServicePipewire.sinks[i].description === currentVal) {
                                ServicePipewire.setAudioSink(ServicePipewire.sinks[i])
                                return
                            }
                        }
                    }
                }
            }

            // Volume control row
            RowLayout {
                Layout.topMargin: 10
                Layout.fillWidth: true
                spacing: 6

                // Mute toggle button
                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 10
                    color: ServicePipewire.muted ? Colors.primary : Colors.surfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: ServicePipewire.muted ? "volume_off" : "volume_up"
                        iconSize: 18
                        color: ServicePipewire.muted ? Colors.primaryText : Colors.surfaceVariantText
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ServicePipewire.toggleMute()
                    }
                    RippleEffect { anchors.fill: parent; radius: 10 }
                }

                // Slider track
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 10
                    color: Colors.surfaceContainerHigh

                    CustomSliderNew {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        progress: ServicePipewire.volume
                        peakLevel: outputPeak.peak
                        showPeak: true
                        onProgressChanged: {
                            if (Math.abs(progress - ServicePipewire.volume) > 0.005)
                                ServicePipewire.setVolume(progress)
                        }
                    }
                }

                // Volume percentage badge
                Rectangle {
                    implicitWidth: 50
                    implicitHeight: 36
                    radius: 10
                    color: Colors.surfaceContainerHigh
                    CustomText {
                        anchors.centerIn: parent
                        content: Math.round(ServicePipewire.volume * 100) + "%"
                        size: 13
                        weight: 600
                    }
                }
            }

            // ── Divider ───────────────────────────────────────────────────────
            Rectangle {
                Layout.topMargin: 20; Layout.bottomMargin: 20
                Layout.fillWidth: true; Layout.preferredHeight: 1
                color: Colors.outline
            }

            // ── Input ─────────────────────────────────────────────────────────
            CustomText { content: "Input"; size: 18; color: Colors.primary }
            CustomText { content: "Set mic levels and choose your input device"; size: 14; color: Colors.outline }

            // Input device row
            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 0
                    CustomText { content: "Input Device"; size: 16 }
                    CustomText { content: "Active input source"; size: 13; color: Colors.outline }
                }
                Item { Layout.fillWidth: true }
                CustomListNew {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 30
                    currentVal: ServicePipewire.source?.description ?? ""
                    list: root.sourceList
                    onCurrentValChanged: {
                        if (!currentVal) return
                        for (let i = 0; i < ServicePipewire.sources.length; i++) {
                            if (ServicePipewire.sources[i].description === currentVal) {
                                ServicePipewire.setAudioSource(ServicePipewire.sources[i])
                                return
                            }
                        }
                    }
                }
            }

            // Mic level row
            RowLayout {
                Layout.topMargin: 10
                Layout.fillWidth: true
                spacing: 6

                // Mic mute toggle
                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 10
                    color: ServicePipewire.micMuted ? Colors.primary : Colors.surfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: ServicePipewire.micMuted ? "mic_off" : "mic"
                        iconSize: 18
                        color: ServicePipewire.micMuted ? Colors.primaryText : Colors.surfaceVariantText
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ServicePipewire.toggleMicMute()
                    }
                    RippleEffect { anchors.fill: parent; radius: 10 }
                }

                // Mic peak bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 10
                    color: Colors.surfaceContainerHigh

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: 6
                        radius: 10
                        color: Colors.surfaceContainerHighest

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            radius: parent.radius
                            width: parent.width * inputPeak.peak
                            color: inputPeak.peak > 0.85 ? Colors.error : Colors.primary
                            Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                    }
                }

                // Mic level percentage
                Rectangle {
                    implicitWidth: 50
                    implicitHeight: 36
                    radius: 10
                    color: Colors.surfaceContainerHigh
                    CustomText {
                        anchors.centerIn: parent
                        content: Math.round(inputPeak.peak * 100) + "%"
                        size: 13
                        weight: 600
                    }
                }
            }

            // ── Divider ───────────────────────────────────────────────────────
            Rectangle {
                Layout.topMargin: 20; Layout.bottomMargin: 20
                Layout.fillWidth: true; Layout.preferredHeight: 1
                color: Colors.outline
            }

            // ── Playbacks ─────────────────────────────────────────────────────
            CustomText { content: "Playbacks"; size: 18; color: Colors.primary }
            CustomText { content: "Per-app volume for currently running streams"; size: 14; color: Colors.outline }

            Repeater {
                model: ServicePipewire.playbacks

                delegate: Rectangle {
                    Layout.topMargin: index === 0 ? 14 : 4
                    Layout.fillWidth: true
                    implicitHeight: streamRow.implicitHeight + 24
                    color: Colors.surfaceContainerHigh
                    topLeftRadius:     index === 0 ? 15 : 5
                    topRightRadius:    index === 0 ? 15 : 5
                    bottomLeftRadius:  index === ServicePipewire.playbacks.length - 1 ? 15 : 5
                    bottomRightRadius: index === ServicePipewire.playbacks.length - 1 ? 15 : 5

                    RowLayout {
                        id: streamRow
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        // App icon
                        Image {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            Layout.alignment: Qt.AlignVCenter
                            source: IconUtil.getIconPath(modelData.name)
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectFit
                        }

                        // App name + media name + slider
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                CustomText {
                                    Layout.fillWidth: true
                                    content: modelData.properties?.["application.name"] || modelData.name
                                    size: 14
                                    color: Colors.primary
                                }

                                CustomText {
                                    content: Math.round((modelData.audio?.volume ?? 0) * 100) + "%"
                                    size: 12
                                    color: Colors.outline
                                }
                            }

                            CustomText {
                                Layout.fillWidth: true
                                content: modelData.properties?.["media.name"] ?? ""
                                size: 12
                                color: Colors.outline
                                visible: (modelData.properties?.["media.name"] ?? "").length > 0
                            }

                            CustomSliderNew {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 18
                                handleSize: 12
                                trackHeight: 4
                                progress: modelData.audio?.volume ?? 0
                                onProgressChanged: {
                                    const cur = modelData.audio?.volume ?? 0
                                    if (Math.abs(progress - cur) > 0.005)
                                        ServicePipewire.setSinkVolume(modelData, progress)
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 16 }
        }
    }
}
