pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.settings

Singleton {
    id: root

    readonly property var styles: [
        { value: "boost", label: "Bass boost", icon: "speaker" },
        { value: "warm", label: "Warm", icon: "local_fire_department" },
        { value: "clear", label: "Clear vocals", icon: "record_voice_over" },
        { value: "night", label: "Late night", icon: "bedtime" },
        { value: "flat", label: "Flat", icon: "horizontal_rule" }
    ]

    readonly property bool enabled: SettingsConfig.general.soundFxOn === true
    readonly property string style: {
        const s = SettingsConfig.general.soundFxStyle ?? "boost"
        return root.styles.some(x => x.value === s) ? s : "boost"
    }
    readonly property real bass: Math.max(-6, Math.min(12, Number(SettingsConfig.general.soundFxBass ?? 0) || 0))
    readonly property real treble: Math.max(-6, Math.min(9, Number(SettingsConfig.general.soundFxTreble ?? 0) || 0))
    readonly property string target: {
        const t = SettingsConfig.general.soundFxTarget ?? "auto"
        return ["auto", "speakers", "headphones"].indexOf(t) >= 0 ? t : "auto"
    }
    readonly property string styleLabel: (root.styles.find(x => x.value === root.style) ?? root.styles[0]).label

    property string detected: ""
    property string error: ""
    readonly property bool busy: applyProc.running || offProc.running
    readonly property string script: Quickshell.shellDir + "/scripts/soundfx.py"

    function set(patch) {
        SettingsConfig.general = Object.assign({}, SettingsConfig.general, patch)
    }

    function toggle() {
        root.set({ soundFxOn: !root.enabled })
    }

    function sync() {
        if (root.enabled)
            applyDebounce.restart()
        else {
            applyDebounce.stop()
            offProc.running = true
        }
    }

    onEnabledChanged: root.sync()
    onStyleChanged: if (root.enabled) applyDebounce.restart()
    onBassChanged: if (root.enabled) applyDebounce.restart()
    onTrebleChanged: if (root.enabled) applyDebounce.restart()
    onTargetChanged: if (root.enabled) applyDebounce.restart()
    Component.onCompleted: if (root.enabled) applyDebounce.restart()

    Timer {
        id: applyDebounce
        interval: 350
        onTriggered: {
            if (applyProc.running) {
                applyDebounce.restart()
                return
            }
            applyProc.command = ["python3", root.script, "apply", root.style, String(root.bass), String(root.treble), root.target]
            applyProc.running = true
        }
    }

    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text.trim().split("\n").pop() || "{}")
                    if (r.ok) {
                        root.error = ""
                        if (r.target)
                            root.detected = r.target
                    } else {
                        root.error = r.error === "missing" ? "EasyEffects is not installed" : "Could not start EasyEffects"
                    }
                } catch (e) {
                    root.error = "Could not start EasyEffects"
                }
            }
        }
    }

    Process {
        id: offProc
        command: ["python3", root.script, "off"]
    }

    Timer {
        interval: 8000
        repeat: true
        running: root.enabled && root.target === "auto"
        onTriggered: if (!detectProc.running && !applyProc.running) detectProc.running = true
    }

    Process {
        id: detectProc
        command: ["python3", root.script, "detect"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                if ((t === "speakers" || t === "headphones") && t !== root.detected) {
                    const changed = root.detected !== ""
                    root.detected = t
                    if (changed && root.enabled)
                        applyDebounce.restart()
                }
            }
        }
    }
}
