import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Qt.labs.platform
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    FileDialog {
        id: soundFilePicker
        title: "Select a shutter sound file"
        nameFilters: ["WAV files (*.wav)"]
        onAccepted: {
            const path = soundFilePicker.file.toString().replace(/^file:\/\//, "")
            SettingsConfig.screenshot = Object.assign({}, SettingsConfig.screenshot, { soundPath: path })
            GlobalStates.fileDialogOpen = false
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }

    FolderDialog {
        id: recFolderPicker
        title: "Select recording output folder"
        onAccepted: {
            const path = folder.toString().replace(/^file:\/\//, "")
            SettingsConfig.recording = Object.assign({}, SettingsConfig.recording, { outputPath: path })
            GlobalStates.fileDialogOpen = false
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }

    FolderDialog {
        id: ssFolderPicker
        title: "Select screenshot output folder"
        onAccepted: {
            const path = folder.toString().replace(/^file:\/\//, "")
            SettingsConfig.screenshot = Object.assign({}, SettingsConfig.screenshot, { outputPath: path })
            GlobalStates.fileDialogOpen = false
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }

    readonly property var videoCodecs: [
        { name: "libx264" },
        { name: "libx265" },
        { name: "libvpx-vp9" },
        { name: "h264_vaapi" },
        { name: "av1_vaapi" }
    ]
    readonly property var muxers: [
        { name: "mp4" },
        { name: "mkv" },
        { name: "webm" }
    ]
    readonly property var framerates: [
        { name: "24" },
        { name: "30" },
        { name: "60" }
    ]
    readonly property var pixelFormats: [
        { name: "yuv420p" },
        { name: "yuv444p" },
        { name: "nv12" }
    ]
    readonly property var audioCodecs: [
        { name: "aac" },
        { name: "opus" },
        { name: "libmp3lame" },
        { name: "flac" }
    ]
    readonly property var audioBitrates: [
        { name: "64k" },
        { name: "96k" },
        { name: "128k" },
        { name: "192k" },
        { name: "256k" }
    ]
    readonly property var audioSampleRates: [
        { name: "44100" },
        { name: "48000" },
        { name: "96000" }
    ]

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight + 20
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

            RowLayout {
                spacing: 10
                MaterialIconSymbol { content: "perm_media"; iconSize: 20 }
                CustomText { content: "Media"; size: 20; color: Colors.primary }
            }

            // ════════════════════════════════════════════════════════════════
            // RECORDING
            // ════════════════════════════════════════════════════════════════
            CustomText {
                Layout.topMargin: 30
                content: "Recording"
                size: 18
                color: Colors.primary
            }
            CustomText {
                content: "Configure screen recording output and encoding"
                size: 14
                color: Colors.outline
            }

            // Output path
            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 0
                    CustomText { content: "Output Folder"; size: 16 }
                    CustomText { content: "Where recordings are saved"; size: 13; color: Colors.outline }
                }
                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 4
                    Rectangle {
                        implicitHeight: 34
                        implicitWidth: 180
                        topLeftRadius: 15; bottomLeftRadius: 15
                        topRightRadius: 5; bottomRightRadius: 5
                        color: Colors.surfaceContainerHighest
                        clip: true
                        CustomText {
                            anchors.left: parent.left; anchors.leftMargin: 10
                            anchors.right: parent.right; anchors.rightMargin: 5
                            anchors.verticalCenter: parent.verticalCenter
                            content: SettingsConfig.recording.outputPath
                            size: 12
                        }
                    }
                    CustomButton {
                        implicitHeight: 34; implicitWidth: 40
                        topLeftRadius: 5; bottomLeftRadius: 5
                        topRightRadius: 15; bottomRightRadius: 15
                        icon: "folder_open"; iconSize: 18
                        onClicked: {
                            GlobalStates.fileDialogOpen = true
                            recFolderPicker.open()
                        }
                    }
                }
            }

            // Video section label
            CustomText { Layout.topMargin: 20; content: "Video"; size: 15; color: Colors.outline }

            // Video card
            Rectangle {
                Layout.topMargin: 8
                Layout.fillWidth: true
                Layout.preferredHeight: videoCol.implicitHeight + 20
                radius: 14
                color: Colors.surfaceContainerHigh

                ColumnLayout {
                    id: videoCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 0
                            CustomText { content: "Codec"; size: 14 }
                            CustomText { content: "Video encoding format"; size: 12; color: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 160
                            currentVal: SettingsConfig.recording.codec
                            list: root.videoCodecs
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.recording.codec)
                                    SettingsConfig.recording = Object.assign({}, SettingsConfig.recording, { codec: currentVal })
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colors.outline; opacity: 0.3 }

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 0
                            CustomText { content: "Container"; size: 14 }
                            CustomText { content: "Output file format"; size: 12; color: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 160
                            currentVal: SettingsConfig.recording.muxer
                            list: root.muxers
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.recording.muxer)
                                    SettingsConfig.recording = Object.assign({}, SettingsConfig.recording, { muxer: currentVal })
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colors.outline; opacity: 0.3 }

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 0
                            CustomText { content: "Framerate"; size: 14 }
                            CustomText { content: "Frames per second"; size: 12; color: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 160
                            currentVal: SettingsConfig.recording.framerate
                            list: root.framerates
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.recording.framerate)
                                    SettingsConfig.recording = Object.assign({}, SettingsConfig.recording, { framerate: currentVal })
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colors.outline; opacity: 0.3 }

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 0
                            CustomText { content: "Pixel Format"; size: 14 }
                            CustomText { content: "Color space encoding"; size: 12; color: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 160
                            currentVal: SettingsConfig.recording.pixelFormat
                            list: root.pixelFormats
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.recording.pixelFormat)
                                    SettingsConfig.recording = Object.assign({}, SettingsConfig.recording, { pixelFormat: currentVal })
                            }
                        }
                    }
                }
            }

            // Audio section label
            CustomText { Layout.topMargin: 20; content: "Audio"; size: 15; color: Colors.outline }

            // Audio card
            Rectangle {
                Layout.topMargin: 8
                Layout.fillWidth: true
                Layout.preferredHeight: audioCol.implicitHeight + 20
                radius: 14
                color: Colors.surfaceContainerHigh

                ColumnLayout {
                    id: audioCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 0
                            CustomText { content: "Capture Audio"; size: 14 }
                            CustomText { content: "Record system or mic audio"; size: 12; color: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.recording.audioEnabled
                            onToggled: function(state) {
                                SettingsConfig.recording = Object.assign({}, SettingsConfig.recording, { audioEnabled: state })
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        visible: SettingsConfig.recording.audioEnabled
                        opacity: SettingsConfig.recording.audioEnabled ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 180 } }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colors.outline; opacity: 0.3 }

                        // Audio source
                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                spacing: 0
                                CustomText { content: "Audio Source"; size: 14 }
                                CustomText { content: "What audio to capture"; size: 12; color: Colors.outline }
                            }
                            Item { Layout.fillWidth: true }

                            ButtonGroup {
                                model: [
                                    { value: "mic",    label: "Mic",    icon: "mic"     },
                                    { value: "system", label: "System", icon: "speaker" },
                                    { value: "both",   label: "Both",   icon: "merge"   }
                                ]
                                activeCheck: function(value) {
                                    return (SettingsConfig.recording.audioSource ?? "mic") === value
                                }
                                onSegmentClicked: function(value) {
                                    SettingsConfig.recording = Object.assign({}, SettingsConfig.recording, { audioSource: value })
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colors.outline; opacity: 0.3 }

                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                spacing: 0
                                CustomText { content: "Audio Codec"; size: 14 }
                                CustomText { content: "Audio encoding format"; size: 12; color: Colors.outline }
                            }
                            Item { Layout.fillWidth: true }
                            CustomListNew {
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: 160
                                currentVal: SettingsConfig.recording.audioCodec
                                list: root.audioCodecs
                                onCurrentValChanged: {
                                    if (currentVal && currentVal !== SettingsConfig.recording.audioCodec)
                                        SettingsConfig.recording = Object.assign({}, SettingsConfig.recording, { audioCodec: currentVal })
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colors.outline; opacity: 0.3 }

                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                spacing: 0
                                CustomText { content: "Bitrate"; size: 14 }
                                CustomText { content: "Audio quality vs file size"; size: 12; color: Colors.outline }
                            }
                            Item { Layout.fillWidth: true }
                            CustomListNew {
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: 160
                                currentVal: SettingsConfig.recording.audioBitrate
                                list: root.audioBitrates
                                onCurrentValChanged: {
                                    if (currentVal && currentVal !== SettingsConfig.recording.audioBitrate)
                                        SettingsConfig.recording = Object.assign({}, SettingsConfig.recording, { audioBitrate: currentVal })
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colors.outline; opacity: 0.3 }

                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                spacing: 0
                                CustomText { content: "Sample Rate"; size: 14 }
                                CustomText { content: "Audio samples per second (Hz)"; size: 12; color: Colors.outline }
                            }
                            Item { Layout.fillWidth: true }
                            CustomListNew {
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: 160
                                currentVal: SettingsConfig.recording.audioSampleRate
                                list: root.audioSampleRates
                                onCurrentValChanged: {
                                    if (currentVal && currentVal !== SettingsConfig.recording.audioSampleRate)
                                        SettingsConfig.recording = Object.assign({}, SettingsConfig.recording, { audioSampleRate: currentVal })
                                }
                            }
                        }
                    }
                }
            }

            // ── Section separator ────────────────────────────────────────────
            Rectangle {
                Layout.topMargin: 24
                Layout.bottomMargin: 16
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.outline
            }

            // ════════════════════════════════════════════════════════════════
            // SCREENSHOT
            // ════════════════════════════════════════════════════════════════
            CustomText { content: "Screenshot"; size: 18; color: Colors.primary }
            CustomText {
                content: "Configure where screenshots are saved"
                size: 14
                color: Colors.outline
            }

            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 0
                    CustomText { content: "Output Folder"; size: 16 }
                    CustomText { content: "Where screenshots are saved"; size: 13; color: Colors.outline }
                }
                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 4
                    Rectangle {
                        implicitHeight: 34
                        implicitWidth: 180
                        topLeftRadius: 15; bottomLeftRadius: 15
                        topRightRadius: 5; bottomRightRadius: 5
                        color: Colors.surfaceContainerHighest
                        clip: true
                        CustomText {
                            anchors.left: parent.left; anchors.leftMargin: 10
                            anchors.right: parent.right; anchors.rightMargin: 5
                            anchors.verticalCenter: parent.verticalCenter
                            content: SettingsConfig.screenshot.outputPath
                            size: 12
                        }
                    }
                    CustomButton {
                        implicitHeight: 34; implicitWidth: 40
                        topLeftRadius: 5; bottomLeftRadius: 5
                        topRightRadius: 15; bottomRightRadius: 15
                        icon: "folder_open"; iconSize: 18
                        onClicked: {
                            GlobalStates.fileDialogOpen = true
                            ssFolderPicker.open()
                        }
                    }
                }
            }

            // Sound section label
            CustomText { Layout.topMargin: 20; content: "Sound"; size: 15; color: Colors.outline }

            // Sound card
            Rectangle {
                Layout.topMargin: 8
                Layout.fillWidth: true
                Layout.preferredHeight: soundCol.implicitHeight + 20
                radius: 14
                color: Colors.surfaceContainerHigh

                ColumnLayout {
                    id: soundCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    // Enable toggle
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 0
                            CustomText { content: "Shutter Sound"; size: 14 }
                            CustomText { content: "Play a sound when a screenshot is taken"; size: 12; color: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.screenshot.soundEnabled
                            onToggled: function(state) {
                                SettingsConfig.screenshot = Object.assign({}, SettingsConfig.screenshot, { soundEnabled: state })
                            }
                        }
                    }

                    // Sound path (only visible when sound is enabled)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        visible: SettingsConfig.screenshot.soundEnabled
                        opacity: SettingsConfig.screenshot.soundEnabled ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 180 } }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colors.outline; opacity: 0.3 }

                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                spacing: 0
                                CustomText { content: "Sound File"; size: 14 }
                                CustomText { content: "WAV file only (uncompressed PCM)"; size: 12; color: Colors.outline }
                            }
                            Item { Layout.fillWidth: true }

                            RowLayout {
                                spacing: 4
                                Rectangle {
                                    implicitHeight: 34
                                    implicitWidth: 180
                                    topLeftRadius: 15; bottomLeftRadius: 15
                                    topRightRadius: 5; bottomRightRadius: 5
                                    color: Colors.surfaceContainerHighest
                                    clip: true
                                    CustomText {
                                        anchors.left: parent.left; anchors.leftMargin: 10
                                        anchors.right: parent.right; anchors.rightMargin: 5
                                        anchors.verticalCenter: parent.verticalCenter
                                        content: SettingsConfig.screenshot.soundPath === ""
                                                 ? "No file selected"
                                                 : SettingsConfig.screenshot.soundPath.split("/").pop()
                                        size: 12
                                        color: SettingsConfig.screenshot.soundPath === "" ? Colors.outline : Colors.surfaceText
                                    }
                                }
                                CustomButton {
                                    implicitHeight: 34; implicitWidth: 40
                                    topLeftRadius: 5; bottomLeftRadius: 5
                                    topRightRadius: 15; bottomRightRadius: 15
                                    icon: "audio_file"; iconSize: 18
                                    onClicked: {
                                        GlobalStates.fileDialogOpen = true
                                        soundFilePicker.open()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.topMargin: 14
                Layout.fillWidth: true
                Layout.preferredHeight: ssInfoCol.implicitHeight + 16
                radius: 10
                color: Colors.surfaceContainer

                ColumnLayout {
                    id: ssInfoCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    RowLayout {
                        spacing: 6
                        MaterialIconSymbol { content: "info"; iconSize: 15; color: Colors.outline }
                        CustomText { content: "Screenshot tools"; size: 12; color: Colors.outline }
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: "Full screen and window shots use grimblast.\nArea selection uses the built-in selection panel.\nAll screenshots are copied to clipboard automatically."
                        size: 12
                        color: Colors.outline
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Item { Layout.preferredHeight: 10 }
        }
    }
}
