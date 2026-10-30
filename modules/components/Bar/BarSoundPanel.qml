import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property real maxHeight: 600
    readonly property bool holdOpen: outList.isListClicked || inList.isListClicked

    readonly property var streams: ServicePipewire.playbacks.filter(n => n && n.audio
        && (n.properties?.["media.class"] ?? "") === "Stream/Output/Audio")

    readonly property var sinkList: ServicePipewire.sinks.map(n => ({ name: n.description }))
    readonly property var sourceList: ServicePipewire.sources.map(n => ({ name: n.description }))

    implicitWidth: 360
    implicitHeight: Math.min(root.maxHeight, column.implicitHeight + 24)

    PwNodePeakMonitor { id: inputPeak; node: ServicePipewire.source }

    function pick(nodes, name, setter) {
        if (!name)
            return
        for (let i = 0; i < nodes.length; i++) {
            if (nodes[i].description === name) {
                setter(nodes[i])
                return
            }
        }
    }

    component ValueChip: Rectangle {
        id: vchip
        property string label: ""
        implicitWidth: 48
        implicitHeight: 30
        radius: 10
        color: Colors.surfaceContainerHighest
        CustomText {
            anchors.centerIn: parent
            content: vchip.label
            size: 12
            weight: 600
        }
    }

    component SectionTitle: CustomText {
        Layout.topMargin: 8
        Layout.leftMargin: 4
        Layout.bottomMargin: 2
        size: 12
        weight: 600
        customColor: Colors.primary
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 12
        contentWidth: width
        contentHeight: column.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: CustomScrollBar {}

        ColumnLayout {
            id: column
            width: parent.width
            spacing: 3

            SectionTitle { Layout.topMargin: 0; content: "Output" }

            CustomCard {
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        CustomListNew {
                            id: outList
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            color: Colors.surfaceContainerHighest
                            currentVal: ServicePipewire.sink?.description ?? ""
                            list: root.sinkList
                            onListChildClicked: child => {
                                const currentVal = child.name
                                root.pick(ServicePipewire.sinks, currentVal, n => ServicePipewire.setAudioSink(n))
                            }
                        }

                        M3IconButton {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            icon: ServicePipewire.muted ? "volume_off" : "volume_up"
                            iconSize: 17
                            square: ServicePipewire.muted
                            iconColor: ServicePipewire.muted ? Colors.error : Colors.surfaceText
                            onClicked: ServicePipewire.toggleMute()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        M3Slider {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            progress: ServicePipewire.volume
                            onMoved: v => ServicePipewire.setVolume(v)
                        }

                        ValueChip {
                            label: ServicePipewire.muted ? "Off" : Math.round(ServicePipewire.volume * 100) + "%"
                        }
                    }
                }
            }

            Loader {
                Layout.fillWidth: true
                active: Features.soundFx
                visible: active
                sourceComponent: ColumnLayout {
                    spacing: 3

                    SectionTitle { content: "Sound effects" }

                    CustomCard {
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                MaterialIconSymbol {
                                    content: "equalizer"
                                    iconSize: 18
                                    customColor: ServiceSoundFx.enabled ? Colors.primary : Colors.outline
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    content: ServiceSoundFx.error !== "" ? ServiceSoundFx.error
                                        : ServiceSoundFx.enabled ? ServiceSoundFx.styleLabel + (ServiceSoundFx.detected !== "" ? " · " + ServiceSoundFx.detected : "")
                                        : "Off"
                                    size: 12
                                    weight: 600
                                    elide: Text.ElideRight
                                    customColor: ServiceSoundFx.error !== "" ? Colors.error : Colors.surfaceText
                                }

                                CustomToogle {
                                    isToggleOn: ServiceSoundFx.enabled
                                    onToggled: state => ServiceSoundFx.set({ soundFxOn: state })
                                }
                            }

                            Flow {
                                Layout.fillWidth: true
                                visible: ServiceSoundFx.enabled
                                spacing: 6

                                Repeater {
                                    model: ServiceSoundFx.styles

                                    Rectangle {
                                        id: fxChip
                                        required property var modelData
                                        readonly property bool on: ServiceSoundFx.style === fxChip.modelData.value
                                        implicitWidth: fxRow.implicitWidth + 20
                                        implicitHeight: 30
                                        radius: fxChip.on ? 15 : 8
                                        color: fxChip.on ? Colors.secondaryContainer : Colors.surfaceContainerHighest
                                        Behavior on radius { SpatialAnim { speed: "fast" } }
                                        Behavior on color { EffectsColorAnim {} }

                                        RowLayout {
                                            id: fxRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            MaterialIconSymbol {
                                                content: fxChip.modelData.icon
                                                iconSize: 15
                                                customColor: fxChip.on ? Colors.secondaryContainerText : Colors.surfaceVariantText
                                            }

                                            CustomText {
                                                content: fxChip.modelData.label
                                                size: 12
                                                weight: 600
                                                customColor: fxChip.on ? Colors.secondaryContainerText : Colors.surfaceText
                                            }
                                        }

                                        CustomMouseArea {
                                            radius: fxChip.radius
                                            onClicked: ServiceSoundFx.set({ soundFxStyle: fxChip.modelData.value })
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            SectionTitle { content: "Input" }

            CustomCard {
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        CustomListNew {
                            id: inList
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            color: Colors.surfaceContainerHighest
                            currentVal: ServicePipewire.source?.description ?? ""
                            list: root.sourceList
                            onListChildClicked: child => {
                                const currentVal = child.name
                                root.pick(ServicePipewire.sources, currentVal, n => ServicePipewire.setAudioSource(n))
                            }
                        }

                        M3IconButton {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            icon: ServicePipewire.micMuted ? "mic_off" : "mic"
                            iconSize: 17
                            square: ServicePipewire.micMuted
                            iconColor: ServicePipewire.micMuted ? Colors.error : Colors.surfaceText
                            onClicked: ServicePipewire.toggleMicMute()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        M3Slider {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            progress: ServicePipewire.micVolume
                            peakLevel: inputPeak.peak
                            showPeak: true
                            onMoved: v => ServicePipewire.setMicVolume(v)
                        }

                        ValueChip {
                            label: ServicePipewire.micMuted ? "Off" : Math.round(ServicePipewire.micVolume * 100) + "%"
                        }
                    }
                }
            }

            SectionTitle { content: "Playbacks" }

            CustomCard {
                visible: root.streams.length === 0
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialIconSymbol { content: "music_off"; iconSize: 18; customColor: Colors.outline }
                    CustomText { content: "Nothing is playing"; size: 12; customColor: Colors.outline }
                }
            }

            Repeater {
                model: root.streams

                delegate: Rectangle {
                    id: stream
                    required property var modelData
                    required property int index

                    readonly property string appName:
                        stream.modelData.properties?.["application.name"] || stream.modelData.name || "Unknown"
                    readonly property string mediaName: {
                        const m = String(stream.modelData.properties?.["media.name"] ?? "")
                        return m === stream.appName || /^(playback|audio ?stream|output|stream|audio)$/i.test(m) ? "" : m
                    }
                    readonly property real vol: stream.modelData.audio?.volume ?? 0
                    readonly property bool muted: !!stream.modelData.audio?.muted

                    Layout.fillWidth: true
                    implicitHeight: streamCol.implicitHeight + 20
                    color: Colors.surfaceContainerHigh
                    topLeftRadius: stream.index === 0 ? 20 : 5
                    topRightRadius: stream.index === 0 ? 20 : 5
                    bottomLeftRadius: stream.index === root.streams.length - 1 ? 20 : 5
                    bottomRightRadius: stream.index === root.streams.length - 1 ? 20 : 5

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 14
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: stream.muted ? 10 : 16
                            color: muteArea.containsMouse ? Colors.primaryContainer : Colors.surfaceContainerHighest
                            Behavior on radius { SpatialAnim { speed: "fast" } }

                            Image {
                                id: streamIcon
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                source: IconUtil.getIconPath(stream.modelData.name)
                                sourceSize.width: 40
                                sourceSize.height: 40
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready && !stream.muted
                            }

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: stream.muted ? "volume_off" : "volume_up"
                                iconSize: 16
                                customColor: stream.muted ? Colors.error : Colors.outline
                                visible: stream.muted || streamIcon.status !== Image.Ready
                            }

                            MouseArea {
                                id: muteArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (stream.modelData.audio) stream.modelData.audio.muted = !stream.modelData.audio.muted
                            }

                            CustomToolTip {
                                content: stream.muted ? "Unmute" : "Mute"
                                visible: muteArea.containsMouse
                            }
                        }

                        ColumnLayout {
                            id: streamCol
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                CustomText {
                                    Layout.maximumWidth: 120
                                    content: stream.appName
                                    size: 12
                                    weight: 600
                                    elide: Text.ElideRight
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    content: stream.mediaName
                                    size: 11
                                    customColor: Colors.outline
                                    elide: Text.ElideRight
                                }

                                CustomText {
                                    content: stream.muted ? "Off" : Math.round(stream.vol * 100) + "%"
                                    size: 11
                                    weight: 600
                                    customColor: Colors.outline
                                }
                            }

                            M3Slider {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 18
                                trackHeight: 6
                                handleHeight: 18
                                handleGap: 4
                                showStopIndicator: false
                                progress: stream.vol
                                onMoved: v => ServicePipewire.setSinkVolume(stream.modelData, v)
                            }
                        }
                    }
                }
            }
        }
    }

    ScrollFade {
        anchors.fill: flick
        flickable: flick
    }
}
