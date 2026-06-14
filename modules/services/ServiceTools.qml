pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtMultimedia
import qs.modules.settings
import WfRecorder


Singleton{
    id: root

    // Recording state — sourced directly from the C++ plugin
    readonly property bool   isRecording:   WfRecorder.recording
    readonly property string recordingMode: WfRecorder.mode
    readonly property int    recordingSeconds: WfRecorder.elapsed
    readonly property string lastFilename:  WfRecorder.filename

    // Send stop notification when recording finishes
    Connections {
        target: WfRecorder
        function onRecordingStopped(duration) {
            ServiceNotification.sendNotification(
                "Recording Stopped",
                "Duration: " + Math.floor(duration / 60) + ":" + String(duration % 60).padStart(2, "0"),
                "Recording",
                "camera-video"
            )
        }
        function onRecordingError(message) {
            ServiceNotification.sendNotification(
                "Recording Error",
                message,
                "Recording",
                "dialog-error"
            )
        }
    }

    // ── Screenshot sound ──────────────────────────────────────────────────────
    SoundEffect {
        id: shutterSound
        source: {
            var p = SettingsConfig.screenshot.soundPath || ""
            if (p === "") return ""
            return "file://" + p.replace("~", Quickshell.env("HOME"))
        }
    }

    function playShutterSound() {
        if (SettingsConfig.screenshot.soundEnabled && shutterSound.source.toString() !== "")
            shutterSound.play()
    }

    // Fires after sleep 0.5 + grimblast completes (~900 ms total)
    Timer {
        id: screenShotFeedbackTimer
        interval: 900
        repeat: false
        onTriggered: {
            root.playShutterSound()
            ServiceNotification.sendNotification("Screenshot", "Screen captured", "Screenshot", "camera-photo")
        }
    }

    // Process-based area screenshot so onExited gives us a reliable callback
    Process {
        id: areaScreenshotProc
        onExited: {
            root.playShutterSound()
            ServiceNotification.sendNotification("Screenshot", "Area screenshot saved", "Screenshot", "camera-photo")
        }
    }

    property var tools: [
        {
            name: "Record",
            icon: "videocam",
            options:[
                {
                    name: "Screen",
                    icon: "screenshot_frame_2",
                    audio: false
                },

                {
                    name: "Window",
                    icon: "window",
                    audio: false
                },
                {
                    name: "Area",
                    icon: "select",
                    audio: false
                },
 
            ]
        },
        {
            name: "Screenshot",
            icon: "photo_camera",
            options:[
                {
                    name: "Screen",
                    icon: "screenshot_frame_2",
                    command: ["sh", "-c", "sleep 0.5 && grimblast copysave output"]

                },
                {
                    name: "Window",
                    icon: "window",
                    command: ["sh", "-c", "sleep 0.5 && grimblast copysave active"]

                },
                {
                    name: "Area",
                    icon: "select",
                    command: ["sh", "-c", "sleep 0.5 && grimblast copysave area"]

                }
            ]
        },
        {
            name: "Setting",
            icon: "settings"
        },
        {
            name: "Power",
            icon: "power_settings_new",
            options:[
                {
                    name: "Shutdown",
                    icon: "power_settings_new",
                    command: ["systemctl", "poweroff"]


                },
                {
                    name: "Restart",
                    icon: "refresh",
                    command: ["systemctl", "reboot"]

                },
                {
                    name: "Logout",
                    icon: "logout",
                    command: ["loginctl", "lock-session"]

                }
            ]
        }
    ]

    // Delay timer for Area mode: fires after the widget fully closes so
    // HyprlandFocusGrab is released before slurp requests Wayland input.
    Timer {
        id: delayTimer
        interval: 700
        repeat: false
        property string pendingMode: ""
        property string pendingGeometry: ""
        onTriggered: root.toggleRecording(pendingMode, pendingGeometry)
    }

    // Call this from ToolsWidgetContent for Area/Window so the timer
    // survives the Loader teardown.
    function startDelayed(mode, geometry) {
        delayTimer.pendingMode = mode
        delayTimer.pendingGeometry = geometry
        delayTimer.restart()
    }

    // Generate filename using SettingsConfig output path + muxer extension
    function generateFilename() {
        var now = new Date()
        var timestamp = now.getFullYear() + "-" +
            String(now.getMonth() + 1).padStart(2, "0") + "-" +
            String(now.getDate()).padStart(2, "0") + "_" +
            String(now.getHours()).padStart(2, "0") + "." +
            String(now.getMinutes()).padStart(2, "0") + "." +
            String(now.getSeconds()).padStart(2, "0")
        var dir = SettingsConfig.recording.outputPath.replace("~", Quickshell.env("HOME"))
        var ext = SettingsConfig.recording.muxer
        return dir + "/recording_" + timestamp + "." + ext
    }

    function toggleRecording(mode, geometry) {
        if (WfRecorder.recording) {
            WfRecorder.stop()
            return
        }

        var rec = SettingsConfig.recording
        var dir = rec.outputPath.replace("~", Quickshell.env("HOME"))
        var filename = generateFilename()
        var base = `wf-recorder --codec ${rec.codec} --pixel-format ${rec.pixelFormat} -r ${rec.framerate}`
        var cmd = ""

        if (mode === "Screen") {
            cmd = `mkdir -p '${dir}' && ${base} -o ${Hyprland.focusedMonitor.name} -f '${filename}'`
        } else if (mode === "Area") {
            // slurp must run after the tools widget fully closes and releases its focus grab
            cmd = `mkdir -p '${dir}' && ${base} -g "$(slurp)" -f '${filename}'`
        }

        if (rec.audioEnabled) {
            var audioCodecFlags = ` --audio-codec ${rec.audioCodec} --audio-bitrate ${rec.audioBitrate} --sample-rate ${rec.audioSampleRate}`
            if (rec.audioSource === "system") {
                cmd += ` --audio=$(pactl get-default-sink).monitor` + audioCodecFlags
            } else if (rec.audioSource === "both") {
                // Create a temporary virtual combined sink, loopback both sources into it,
                // run wf-recorder, then unload modules on exit (; runs even if wf-recorder fails)
                cmd = `NULL_MOD=$(pactl load-module module-null-sink sink_name=qsrec_combined sink_properties=device.description=QuickshellCombined) && ` +
                      `SYS_MOD=$(pactl load-module module-loopback source=$(pactl get-default-sink).monitor sink=qsrec_combined latency_msec=1) && ` +
                      `MIC_MOD=$(pactl load-module module-loopback source=$(pactl get-default-source) sink=qsrec_combined latency_msec=1) && ` +
                      cmd + ` --audio=qsrec_combined.monitor` + audioCodecFlags +
                      ` ; pactl unload-module $MIC_MOD ; pactl unload-module $SYS_MOD ; pactl unload-module $NULL_MOD`
            } else {
                cmd += ` --audio` + audioCodecFlags
            }
        }

        WfRecorder.start(cmd, mode, filename)
        ServiceNotification.sendNotification("Recording Started", "Recording " + mode, "Recording", "camera-video")
    }

    function stopRecording() {
        WfRecorder.stop()
    }

    function takeScreenshot(mode) {
        if (mode === "Screen") {
            Quickshell.execDetached(["sh", "-c", "sleep 0.5 && grimblast copysave output"])
            screenShotFeedbackTimer.restart()
        }
    }

    // Called after the in-shell area selector provides a geometry string "x,y WxH"
    function takeAreaScreenshot(geo) {
        var now = new Date()
        var ts  = now.getFullYear() + "-" +
                  String(now.getMonth() + 1).padStart(2, "0") + "-" +
                  String(now.getDate()).padStart(2, "0") + "_" +
                  String(now.getHours()).padStart(2, "0") + "." +
                  String(now.getMinutes()).padStart(2, "0") + "." +
                  String(now.getSeconds()).padStart(2, "0")
        var dir  = SettingsConfig.screenshot.outputPath.replace("~", Quickshell.env("HOME"))
        var path = dir + "/screenshot_" + ts + ".png"
        areaScreenshotProc.command = ["sh", "-c",
            "mkdir -p '" + dir + "' && grim -g '" + geo + "' '" + path + "' && wl-copy < '" + path + "'"]
        areaScreenshotProc.running = true
    }

    // Start recording with a geometry string provided by the in-shell area selector
    function startWithGeometry(mode, geometry) {
        var rec      = SettingsConfig.recording
        var dir      = rec.outputPath.replace("~", Quickshell.env("HOME"))
        var filename = generateFilename()
        var base     = `wf-recorder --codec ${rec.codec} --pixel-format ${rec.pixelFormat} -r ${rec.framerate}`
        var cmd      = `mkdir -p '${dir}' && ${base} -g "${geometry}" -f '${filename}'`
        if (rec.audioEnabled) {
            var audioCodecFlags = ` --audio-codec ${rec.audioCodec} --audio-bitrate ${rec.audioBitrate} --sample-rate ${rec.audioSampleRate}`
            if (rec.audioSource === "system") {
                cmd += ` --audio=$(pactl get-default-sink).monitor` + audioCodecFlags
            } else if (rec.audioSource === "both") {
                // Create a temporary virtual combined sink, loopback both sources into it,
                // run wf-recorder, then unload modules on exit (; runs even if wf-recorder fails)
                cmd = `NULL_MOD=$(pactl load-module module-null-sink sink_name=qsrec_combined sink_properties=device.description=QuickshellCombined) && ` +
                      `SYS_MOD=$(pactl load-module module-loopback source=$(pactl get-default-sink).monitor sink=qsrec_combined latency_msec=1) && ` +
                      `MIC_MOD=$(pactl load-module module-loopback source=$(pactl get-default-source) sink=qsrec_combined latency_msec=1) && ` +
                      cmd + ` --audio=qsrec_combined.monitor` + audioCodecFlags +
                      ` ; pactl unload-module $MIC_MOD ; pactl unload-module $SYS_MOD ; pactl unload-module $NULL_MOD`
            } else {
                cmd += ` --audio` + audioCodecFlags
            }
        }
        WfRecorder.start(cmd, mode, filename)
        ServiceNotification.sendNotification("Recording Started", "Recording " + mode, "Recording", "camera-video")
    }

    function getFormattedRecordingTime() {
        return WfRecorder.formattedTime()
    }
}
