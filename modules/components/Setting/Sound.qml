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

            // ── Page header ──────────────────────────────────────────────
            RowLayout {
                spacing: 10
                MaterialIconSymbol { content: "volume_up"; iconSize: 20 }
                CustomText { content: "Sound"; size: 20; customColor: Colors.primary }
            }

            // ── Output ───────────────────────────────────────────────────
            CustomText { Layout.topMargin: 24; content: "Output"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                // Output device
                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Output Device"; size: 14 }
                            CustomText { content: "Active output sink"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 30
                            color: Colors.surfaceContainerHighest
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
                }

                // Volume
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        M3ButtonGroup {
                            model: [
                                { value: false, icon: "volume_up"  },
                                { value: true,  icon: "volume_off" }
                            ]
                            activeCheck: function(v) { return ServicePipewire.muted === v }
                            onSegmentClicked: function(v) {
                                if (ServicePipewire.muted !== v) ServicePipewire.toggleMute()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 10
                            color: Colors.surfaceContainerHighest

                            M3Slider {
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

                        Rectangle {
                            implicitWidth: 50
                            implicitHeight: 36
                            radius: 10
                            color: Colors.surfaceContainerHighest
                            CustomText {
                                anchors.centerIn: parent
                                content: Math.round(ServicePipewire.volume * 100) + "%"
                                size: 13
                                weight: 600
                            }
                        }
                    }
                }
            }

            // ── Input ────────────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Input"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                // Input device
                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Input Device"; size: 14 }
                            CustomText { content: "Active input source"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 30
                            color: Colors.surfaceContainerHighest
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
                }

                // Mic level
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        M3ButtonGroup {
                            model: [
                                { value: false, icon: "mic"     },
                                { value: true,  icon: "mic_off" }
                            ]
                            activeCheck: function(v) { return ServicePipewire.micMuted === v }
                            onSegmentClicked: function(v) {
                                if (ServicePipewire.micMuted !== v) ServicePipewire.toggleMicMute()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 10
                            color: Colors.surfaceContainerHighest

                            Rectangle {
                                anchors.left: parent.left; anchors.leftMargin: 10
                                anchors.right: parent.right; anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                height: 6
                                radius: 10
                                color: Colors.surfaceContainer

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

                        Rectangle {
                            implicitWidth: 50
                            implicitHeight: 36
                            radius: 10
                            color: Colors.surfaceContainerHighest
                            CustomText {
                                anchors.centerIn: parent
                                content: Math.round(inputPeak.peak * 100) + "%"
                                size: 13
                                weight: 600
                            }
                        }
                    }
                }
            }

            // ── Playbacks ─────────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Playbacks"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                Repeater {
                    model: ServicePipewire.playbacks

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: streamRow.implicitHeight + 24
                        color: Colors.surfaceContainerHigh
                        topLeftRadius:     index === 0 ? 20 : 5
                        topRightRadius:    index === 0 ? 20 : 5
                        bottomLeftRadius:  index === ServicePipewire.playbacks.length - 1 ? 20 : 5
                        bottomRightRadius: index === ServicePipewire.playbacks.length - 1 ? 20 : 5

                        RowLayout {
                            id: streamRow
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Image {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                Layout.alignment: Qt.AlignVCenter
                                source: IconUtil.getIconPath(modelData.name)
                                sourceSize: Qt.size(width, height)
                                fillMode: Image.PreserveAspectFit
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true

                                    CustomText {
                                        Layout.fillWidth: true
                                        content: modelData.properties?.["application.name"] || modelData.name
                                        size: 14
                                        customColor: Colors.primary
                                    }

                                    CustomText {
                                        content: Math.round((modelData.audio?.volume ?? 0) * 100) + "%"
                                        size: 12
                                        customColor: Colors.outline
                                    }
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    content: modelData.properties?.["media.name"] ?? ""
                                    size: 12
                                    customColor: Colors.outline
                                    visible: (modelData.properties?.["media.name"] ?? "").length > 0
                                }

                                M3Slider {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 18
                                    handleHeight: 12
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
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
