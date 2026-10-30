import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    PwNodePeakMonitor { id: inputPeak; node: ServicePipewire.source }

    function fmtRate(node) {
        const p = node?.properties ?? ({})
        let r = parseInt(p["audio.rate"] ?? "")
        if (isNaN(r)) {
            const nr = String(p["node.rate"] ?? "")
            const slash = nr.indexOf("/")
            if (slash >= 0)
                r = parseInt(nr.slice(slash + 1))
        }
        if (isNaN(r) || r <= 0)
            return ""
        const k = r / 1000
        return (r % 1000 === 0 ? k : k.toFixed(1)) + " kHz"
    }

    function fmtChannels(node) {
        const n = node?.audio?.channels?.length ?? 0
        if (n <= 0)
            return ""
        return ({ 1: "Mono", 2: "Stereo", 6: "5.1", 8: "7.1" })[n] ?? n + " channels"
    }

    function fmtLatency(node) {
        const parts = String(node?.properties?.["node.latency"] ?? "").split("/")
        if (parts.length !== 2)
            return ""
        const q = parseInt(parts[0])
        const r = parseInt(parts[1])
        if (isNaN(q) || isNaN(r) || r <= 0)
            return ""
        return Math.round(q / r * 1000) + " ms"
    }

    function fmtBus(node) {
        const p = node?.properties ?? ({})
        const bus = String(p["device.bus"] ?? "")
        const api = String(p["device.api"] ?? "")
        return (bus !== "" ? bus : api).toUpperCase()
    }

    function details(node) {
        return [root.fmtRate(node), root.fmtChannels(node), root.fmtLatency(node), root.fmtBus(node)].filter(x => x !== "").join(" · ")
    }

    function appName(stream) {
        return stream?.properties?.["application.name"] || stream?.name || "Unknown"
    }

    readonly property string playingSummary: {
        const list = ServicePipewire.playbacks
        if (list.length === 0)
            return "Nothing is playing"
        return list.map(s => root.appName(s)).join(", ")
    }

    StageView {
        StagePage {
            stageId: "front"

            StageSliderRow {
                icon: "volume_up"
                title: "Volume"
                subtitle: ServicePipewire.sink?.description ?? "No output"
                from: 0
                to: 1
                current: ServicePipewire.volume
                format: v => Math.round(v * 100) + "%"
                onMoved: v => ServicePipewire.setVolume(v)
            }

            StageSliderRow {
                icon: "mic"
                title: "Microphone"
                subtitle: ServicePipewire.source?.description ?? "No input"
                from: 0
                to: 1
                current: ServicePipewire.micVolume
                peak: inputPeak.peak
                showPeak: true
                format: v => Math.round(v * 100) + "%"
                onMoved: v => ServicePipewire.setMicVolume(v)
            }

            StageGap {}

            StageNavRow {
                icon: "speaker"
                title: "Output"
                subtitle: ServicePipewire.sink?.description ?? "No output"
                value: ServicePipewire.sinks.length + (ServicePipewire.sinks.length === 1 ? " device" : " devices")
                target: "output"
            }

            StageNavRow {
                icon: "mic"
                title: "Input"
                subtitle: ServicePipewire.source?.description ?? "No input"
                value: ServicePipewire.sources.length + (ServicePipewire.sources.length === 1 ? " device" : " devices")
                target: "input"
            }

            StageGap {}

            StageNavRow {
                visible: Features.soundFx
                icon: "equalizer"
                tonal: Features.soundFx && ServiceSoundFx.enabled
                title: "Sound effects"
                subtitle: !(Features.soundFx && ServiceSoundFx.enabled) ? "Off" : ServiceSoundFx.styleLabel
                    + (ServiceSoundFx.bass !== 0 ? " · bass " + (ServiceSoundFx.bass > 0 ? "+" : "") + ServiceSoundFx.bass + " dB" : "")
                value: Features.soundFx && ServiceSoundFx.enabled ? "On" : ""
                target: "effects"
            }

            StageNavRow {
                icon: "music_note"
                tonal: ServicePipewire.playbacks.length > 0
                title: "Playing now"
                subtitle: root.playingSummary
                value: ServicePipewire.playbacks.length > 0 ? String(ServicePipewire.playbacks.length) : ""
                target: "apps"
            }
        }

        DevicePage {
            stageId: "output"
            title: "Output"
            devices: ServicePipewire.sinks
            selected: ServicePipewire.sink
            icon: "speaker"
            onChosen: node => ServicePipewire.setAudioSink(node)
        }

        DevicePage {
            stageId: "input"
            title: "Input"
            devices: ServicePipewire.sources
            selected: ServicePipewire.source
            icon: "mic"
            onChosen: node => ServicePipewire.setAudioSource(node)
        }

        StageLazy {
            stageId: "effects"

            StagePage {
                stageId: "effects"
                title: "Sound effects"

                StageSwitchRow {
                    icon: "equalizer"
                    title: "Sound effects"
                    subtitle: ServiceSoundFx.error !== "" ? ServiceSoundFx.error : "Bass, warmth and clarity for everything you play"
                    checked: ServiceSoundFx.enabled
                    onToggled: on => ServiceSoundFx.set({ soundFxOn: on })
                }

                StageGap {}

                StageChoiceRow {
                    enabled: ServiceSoundFx.enabled
                    title: "Style"
                    subtitle: "Bass boost adds weight, Warm softens, Clear vocals lifts voices, Late night evens out loud and quiet parts"
                    options: ServiceSoundFx.styles
                    current: ServiceSoundFx.style
                    onPicked: v => ServiceSoundFx.set({ soundFxStyle: v })
                }

                StageSliderRow {
                    enabled: ServiceSoundFx.enabled
                    icon: "speaker"
                    title: "Bass"
                    subtitle: "Added on top of the style"
                    from: -6
                    to: 12
                    step: 1
                    current: ServiceSoundFx.bass
                    format: v => (v > 0 ? "+" : "") + Math.round(v) + " dB"
                    onCommitted: v => ServiceSoundFx.set({ soundFxBass: Math.round(v) })
                }

                StageSliderRow {
                    enabled: ServiceSoundFx.enabled
                    icon: "graphic_eq"
                    title: "Treble"
                    subtitle: "Added on top of the style"
                    from: -6
                    to: 9
                    step: 1
                    current: ServiceSoundFx.treble
                    format: v => (v > 0 ? "+" : "") + Math.round(v) + " dB"
                    onCommitted: v => ServiceSoundFx.set({ soundFxTreble: Math.round(v) })
                }

                StageGap {}

                StageChoiceRow {
                    enabled: ServiceSoundFx.enabled
                    title: "Listening on"
                    subtitle: ServiceSoundFx.target === "auto" && ServiceSoundFx.detected !== ""
                        ? "Detected: " + ServiceSoundFx.detected + ". Speakers get harmonic bass instead of a deep boost they can't play."
                        : "Speakers get harmonic bass instead of a deep boost they can't play"
                    options: [
                        { value: "auto", label: "Auto", icon: "auto_mode" },
                        { value: "speakers", label: "Speakers", icon: "laptop" },
                        { value: "headphones", label: "Headphones", icon: "headphones" }
                    ]
                    current: ServiceSoundFx.target
                    onPicked: v => ServiceSoundFx.set({ soundFxTarget: v })
                }

                StageNote {
                    content: "Runs through EasyEffects in the background. A limiter at the end keeps boosts from distorting."
                }
            }
        }

        StageLazy {
            stageId: "apps"

            StagePage {
                stageId: "apps"
                title: "Playing now"

                StageNote {
                    visible: ServicePipewire.playbacks.length === 0
                    content: "Nothing is playing. Apps show up here with their own volume while they play sound."
                }

                Repeater {
                    model: ServicePipewire.playbacks

                    StageSliderRow {
                        required property var modelData
                        icon: "graphic_eq"
                        title: root.appName(modelData)
                        subtitle: modelData.properties?.["media.name"] ?? ""
                        from: 0
                        to: 1
                        current: modelData.audio?.volume ?? 0
                        format: v => Math.round(v * 100) + "%"
                        onMoved: v => ServicePipewire.setSinkVolume(modelData, v)
                    }
                }
            }
        }
    }

    component DevicePage: StagePage {
        id: devicePage

        property var devices: []
        property var selected: null
        property string icon: ""
        signal chosen(var node)

        Repeater {
            model: devicePage.devices

            StageRow {
                required property var modelData
                readonly property bool current: modelData === devicePage.selected
                icon: devicePage.icon
                tonal: current
                clickable: !current
                title: modelData.description ?? modelData.name ?? ""
                subtitle: root.details(modelData)
                value: current ? "In use" : ""
                onClicked: devicePage.chosen(modelData)
            }
        }
    }
}
