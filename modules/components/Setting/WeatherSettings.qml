import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import Qt.labs.platform

Item {
    id: root
    anchors.fill: parent

    readonly property var weather: SettingsConfig.weather ?? ({})
    readonly property bool metric: root.weather.useMetric ?? true
    readonly property int refresh: Math.max(5, root.weather.refreshInterval ?? 15)

    function patch(p) {
        SettingsConfig.weather = Object.assign({}, SettingsConfig.weather, p)
    }

    readonly property var rec: SettingsConfig.recording ?? ({})
    readonly property var shot: SettingsConfig.screenshot ?? ({})
    readonly property bool audioOn: root.rec.audioEnabled ?? false
    readonly property string shutterName: (root.shot.soundPath ?? "") === "" ? "" : root.shot.soundPath.split("/").pop()

    function patchRec(p) {
        SettingsConfig.recording = Object.assign({}, SettingsConfig.recording, p)
    }

    function patchShot(p) {
        SettingsConfig.screenshot = Object.assign({}, SettingsConfig.screenshot, p)
    }

    function pick(dialog) {
        GlobalStates.fileDialogOpen = true
        dialog.open()
    }

    FileDialog {
        id: soundFilePicker
        title: "Select a shutter sound file"
        nameFilters: ["WAV files (*.wav)"]
        onAccepted: {
            root.patchShot({ soundPath: soundFilePicker.file.toString().replace(/^file:\/\//, "") })
            GlobalStates.fileDialogOpen = false
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }

    FolderDialog {
        id: recFolderPicker
        title: "Select recording output folder"
        onAccepted: {
            root.patchRec({ outputPath: recFolderPicker.folder.toString().replace(/^file:\/\//, "") })
            GlobalStates.fileDialogOpen = false
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }

    FolderDialog {
        id: shotFolderPicker
        title: "Select screenshot output folder"
        onAccepted: {
            root.patchShot({ outputPath: shotFolderPicker.folder.toString().replace(/^file:\/\//, "") })
            GlobalStates.fileDialogOpen = false
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }

    readonly property var hourly: Features.weather ? (ServiceWeather.todayHourly ?? []).slice(1, 6) : []
    readonly property var captures: ServiceCaptures.items ?? []
    readonly property var shots: root.captures.filter(c => c.kind !== "video")
    readonly property var clips: root.captures.filter(c => c.kind === "video")
    readonly property var shotTiles: root.shots.length > 4 ? root.shots.slice(0, 3) : root.shots.slice(0, 4)

    StageView {
        StagePage {
            stageId: "front"

            CustomCard {
                autoRadius: false; topRadius: 28; bottomRadius: 28
                color: Colors.surfaceContainer

                Component.onCompleted: if (root.captures.length === 0) ServiceCaptures.refresh()

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    spacing: 8

                    CustomText {
                        Layout.fillWidth: true
                        content: "LATELY"
                        size: 11
                        weight: 500
                        customColor: Colors.outline
                    }

                    M3IconButton {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        icon: "refresh"
                        iconSize: 18
                        visible: Features.weather
                        tip: Features.weather && ServiceWeather.isLoading ? "Refreshing" : "Refresh the weather"
                        enabled: Features.weather && !ServiceWeather.isLoading
                        onClicked: ServiceWeather.refresh()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        visible: Features.weather
                        Layout.fillWidth: true
                        Layout.preferredWidth: 3
                        implicitHeight: 132
                        radius: 20
                        color: Colors.tertiaryContainer

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                CustomText {
                                    visible: Features.weather && !ServiceWeather.hasError
                                    content: Features.weather ? ServiceWeather.temperature : ""
                                    family: SettingsConfig.general.displayFont ?? "Rubik"
                                    renderType: Text.QtRendering
                                    size: 30
                                    customColor: Colors.tertiaryContainerText
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    content: !Features.weather ? "" : ServiceWeather.hasError ? "Couldn't load the weather" : ServiceWeather.description + " in " + ServiceWeather.cityName
                                    size: 12
                                    weight: 500
                                    elide: Text.ElideRight
                                    customColor: Colors.tertiaryContainerText
                                }
                            }

                            Item { Layout.fillHeight: true }

                            Row {
                                id: hourRow
                                Layout.fillWidth: true
                                visible: root.hourly.length > 0

                                Repeater {
                                    model: root.hourly

                                    ColumnLayout {
                                        required property var modelData
                                        width: hourRow.width / Math.max(1, root.hourly.length)
                                        spacing: 3

                                        CustomText {
                                            Layout.alignment: Qt.AlignHCenter
                                            content: String(modelData.time).replace(" ", "")
                                            size: 11
                                            weight: 500
                                            customColor: Colors.tertiaryContainerText
                                        }

                                        MaterialIconSymbol {
                                            Layout.alignment: Qt.AlignHCenter
                                            content: ServiceWeather.getWeatherIcon(modelData.weatherCode).icon
                                            iconSize: 18
                                            fill: 1
                                            customColor: Colors.tertiaryContainerText
                                        }

                                        CustomText {
                                            Layout.alignment: Qt.AlignHCenter
                                            content: root.metric ? modelData.tempC : modelData.tempF
                                            size: 11
                                            weight: 600
                                            customColor: Colors.tertiaryContainerText
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 2
                        implicitHeight: 132
                        radius: 20
                        color: Colors.primaryContainer

                        GridLayout {
                            visible: root.shots.length > 0
                            anchors.fill: parent
                            anchors.margins: 10
                            columns: 2
                            rowSpacing: 6
                            columnSpacing: 6

                            Repeater {
                                model: root.shotTiles

                                ClippingRectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 10
                                    color: Qt.alpha(Colors.surface, 0.3)

                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + (modelData.thumb !== "" ? modelData.thumb : modelData.path)
                                        sourceSize: Qt.size(240, 140)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["xdg-open", modelData.path])
                                    }
                                }
                            }

                            Rectangle {
                                visible: root.shots.length > 4
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 10
                                color: Qt.alpha(Colors.surface, 0.3)

                                CustomText {
                                    anchors.centerIn: parent
                                    content: "+" + (root.shots.length - 3)
                                    size: 13
                                    weight: 600
                                    customColor: Colors.primaryContainerText
                                }
                            }
                        }

                        ColumnLayout {
                            visible: root.shots.length === 0
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIconSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                content: "screenshot_region"
                                iconSize: 26
                                fill: 1
                                customColor: Colors.primaryContainerText
                            }

                            CustomText {
                                Layout.alignment: Qt.AlignHCenter
                                content: ServiceCaptures.scanning ? "Looking…" : "No screenshots yet"
                                size: 12
                                customColor: Colors.primaryContainerText
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 132
                        radius: 20
                        color: Colors.secondaryContainer

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - 16
                            spacing: 6

                            MaterialIconSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                content: root.clips.length > 0 ? "play_circle" : "screen_record"
                                iconSize: 28
                                fill: 1
                                customColor: Colors.secondaryContainerText
                            }

                            CustomText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                content: root.clips.length === 0 ? "No clips yet"
                                    : (root.clips.length === 1 ? "1 clip" : root.clips.length + " clips") + "\n" + ServiceCaptures.clock(root.clips[0].duration)
                                size: 11
                                weight: 600
                                wrapMode: Text.WordWrap
                                customColor: Colors.secondaryContainerText
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.clips.length > 0
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: Quickshell.execDetached(["xdg-open", root.clips[0].path])
                        }
                    }
                }
            }

            StageHeading { text: "Where"; aside: "Places the apps read from and save to" }

            StageNavRow {
                visible: Features.weather
                tag: "Weather"; tagIcon: "sunny"; tagColor: Colors.tertiaryContainer; tagInk: Colors.tertiaryContainerText; tagWidth: 118
                title: "Location"
                subtitle: (root.weather.useGeoFile || root.weather.location === "auto")
                    ? "External coordinates file"
                    : "City name or coordinates"
                value: (root.weather.useGeoFile ?? false)
                    ? "Auto" + ((root.weather.geoFile ?? "") !== "" ? " · " + root.weather.geoFile : "")
                    : (root.weather.location ?? "")
                target: "location"
            }

            StageNavRow {
                tag: "Screenshots"; tagIcon: "screenshot_region"; tagColor: Colors.primaryContainer; tagInk: Colors.primaryContainerText; tagWidth: 118
                title: "Save to"
                subtitle: "Area, window and full screen"
                value: root.shot.outputPath ?? ""
                onClicked: root.pick(shotFolderPicker)
            }

            StageNavRow {
                tag: "Recording"; tagIcon: "screen_record"; tagColor: Colors.secondaryContainer; tagInk: Colors.secondaryContainerText; tagWidth: 118
                title: "Save to"
                subtitle: "Screen recordings"
                value: root.rec.outputPath ?? ""
                onClicked: root.pick(recFolderPicker)
            }

            StageHeading { text: "How"; aside: "Formats and units" }

            StageDropdownRow {
                visible: Features.weather
                tag: "Weather"; tagIcon: "sunny"; tagColor: Colors.tertiaryContainer; tagInk: Colors.tertiaryContainerText; tagWidth: 118
                title: "Units"
                subtitle: "Temperature, wind and distance"
                options: ["Metric (°C)", "Imperial (°F)"]
                current: root.metric ? "Metric (°C)" : "Imperial (°F)"
                dropdownWidth: 160
                onPicked: name => root.patch({ useMetric: name === "Metric (°C)" })
            }

            StageNavRow {
                tag: "Recording"; tagIcon: "screen_record"; tagColor: Colors.secondaryContainer; tagInk: Colors.secondaryContainerText; tagWidth: 118
                title: "Video"
                subtitle: [root.rec.codec, (root.rec.muxer ?? "").toUpperCase(), (root.rec.framerate ?? "") + " fps", root.rec.pixelFormat].join(" · ")
                target: "video"
            }

            StageRow {
                tag: "Recording"; tagIcon: "screen_record"; tagColor: Colors.secondaryContainer; tagInk: Colors.secondaryContainerText; tagWidth: 118
                title: "Record audio"
                subtitle: root.audioOn ? [root.rec.audioSource, root.rec.audioCodec, root.rec.audioBitrate].join(" · ") : "Video only"
                target: "audio"

                CustomToogle {
                    isToggleOn: root.audioOn
                    onToggled: state => root.patchRec({ audioEnabled: state })
                }
            }

            StageHeading { text: "When"; aside: "Timing and feedback" }

            StageDropdownRow {
                visible: Features.weather
                tag: "Weather"; tagIcon: "sunny"; tagColor: Colors.tertiaryContainer; tagInk: Colors.tertiaryContainerText; tagWidth: 118
                title: "Update every"
                subtitle: Features.weather && ServiceWeather.lastUpdated ? "Last updated " + Qt.formatTime(ServiceWeather.lastUpdated, "h:mm AP") : "At least 5 minutes"
                options: [5, 15, 30, 60].map(m => m + " min")
                current: root.refresh + " min"
                dropdownWidth: 160
                onPicked: name => root.patch({ refreshInterval: parseInt(name) })
            }

            StageSwitchRow {
                tag: "Screenshots"; tagIcon: "screenshot_region"; tagColor: Colors.primaryContainer; tagInk: Colors.primaryContainerText; tagWidth: 118
                title: "Freeze the screen while selecting"
                subtitle: "Area, window and text work on a still frame"
                checked: root.shot.freeze === true
                onToggled: on => root.patchShot({ freeze: on })
            }

            StageRow {
                tag: "Screenshots"; tagIcon: "screenshot_region"; tagColor: Colors.primaryContainer; tagInk: Colors.primaryContainerText; tagWidth: 118
                title: "Shutter sound"
                subtitle: root.shutterName !== "" ? root.shutterName : "No sound file set"
                target: "screenshots"

                CustomToogle {
                    isToggleOn: root.shot.soundEnabled ?? false
                    onToggled: state => root.patchShot({ soundEnabled: state })
                }
            }
        }

        StageLazy {
            stageId: "location"

            StagePage {
                stageId: "location"
                title: "Location"

                StageSwitchRow {
                    icon: "my_location"
                    title: "External geolocation"
                    subtitle: "Read coordinates from an external file (e.g. Wi-Fi positioning or geoclue)"
                    checked: root.weather.useGeoFile ?? false
                    onToggled: on => root.patch({ useGeoFile: on })
                }

                StageFieldRow {
                    visible: root.weather.useGeoFile ?? false
                    icon: "folder"
                    title: "Coordinates file"
                    subtitle: "Path to a file containing \"lat lon\""
                    fieldIcon: "description"
                    text: root.weather.geoFile ?? "~/.cache/quickshell/geo"
                    placeholder: "~/.cache/quickshell/geo"
                    allowEmpty: true
                    onSubmitted: t => root.patch({ geoFile: t.trim() })
                }

                StageFieldRow {
                    visible: !(root.weather.useGeoFile ?? false)
                    icon: "search"
                    title: "City"
                    subtitle: "Name, coordinates, or \"auto\" (leave blank for timezone city)"
                    fieldIcon: "location_on"
                    text: root.weather.location ?? ""
                    placeholder: "City"
                    allowEmpty: true
                    onSubmitted: t => root.patch({ location: t })
                }

                StageNote { content: "A new location shows on the next refresh." }
            }
        }

        StageLazy {
            stageId: "screenshots"

            StagePage {
                stageId: "screenshots"
                title: "Screenshots"

                StageNavRow {
                    icon: "folder"
                    title: "Save to"
                    value: root.shot.outputPath ?? ""
                    onClicked: root.pick(shotFolderPicker)
                }

                StageSwitchRow {
                    title: "Freeze the screen while selecting"
                    subtitle: "Area, window and text selection work on a still frame"
                    checked: root.shot.freeze === true
                    onToggled: on => root.patchShot({ freeze: on })
                }

                StageHeading { text: "Shutter sound" }

                StageSwitchRow {
                    title: "Play a sound"
                    subtitle: "When a screenshot is taken"
                    checked: root.shot.soundEnabled ?? false
                    onToggled: on => root.patchShot({ soundEnabled: on })
                }

                StageNavRow {
                    enabled: root.shot.soundEnabled ?? false
                    icon: "audio_file"
                    title: "Sound file"
                    subtitle: "WAV only (uncompressed PCM)"
                    value: root.shutterName !== "" ? root.shutterName : "Not set"
                    onClicked: root.pick(soundFilePicker)
                }
            }
        }

        StageLazy {
            stageId: "video"

            StagePage {
                stageId: "video"
                title: "Video"

                StageDropdownRow {
                    title: "Codec"
                    subtitle: "Video encoding format"
                    options: ["libx264", "libx265", "libvpx-vp9", "h264_vaapi", "av1_vaapi"]
                    current: root.rec.codec ?? ""
                    onPicked: name => root.patchRec({ codec: name })
                }

                StageChoiceRow {
                    title: "Container"
                    subtitle: "Output file format"
                    options: ["mp4", "mkv", "webm"].map(v => ({ value: v, label: v.toUpperCase() }))
                    current: root.rec.muxer ?? ""
                    onPicked: v => root.patchRec({ muxer: v })
                }

                StageSpinRow {
                    title: "Frame rate"
                    subtitle: "Frames per second"
                    from: 10
                    to: 120
                    step: 5
                    suffix: " fps"
                    current: parseInt(root.rec.framerate ?? "30") || 30
                    onStepped: v => root.patchRec({ framerate: String(v) })
                }

                StageChoiceRow {
                    title: "Pixel format"
                    subtitle: "yuv420p plays everywhere"
                    options: ["yuv420p", "yuv444p", "nv12"].map(v => ({ value: v, label: v }))
                    current: root.rec.pixelFormat ?? ""
                    onPicked: v => root.patchRec({ pixelFormat: v })
                }
            }
        }

        StageLazy {
            stageId: "audio"

            StagePage {
                stageId: "audio"
                title: "Audio"

                StageSwitchRow {
                    title: "Record audio"
                    subtitle: "Capture sound alongside the video"
                    checked: root.audioOn
                    onToggled: on => root.patchRec({ audioEnabled: on })
                }

                StageChoiceRow {
                    enabled: root.audioOn
                    title: "Source"
                    subtitle: "What audio to capture"
                    options: [{ value: "mic", label: "Mic", icon: "mic" }, { value: "system", label: "System", icon: "speaker" }, { value: "both", label: "Both", icon: "merge" }]
                    current: root.rec.audioSource ?? "mic"
                    onPicked: v => root.patchRec({ audioSource: v })
                }

                StageGap {}

                StageDropdownRow {
                    enabled: root.audioOn
                    title: "Codec"
                    subtitle: "Audio encoding format"
                    options: ["aac", "opus", "libmp3lame", "flac"]
                    current: root.rec.audioCodec ?? ""
                    onPicked: name => root.patchRec({ audioCodec: name })
                }

                StageDropdownRow {
                    enabled: root.audioOn
                    title: "Bitrate"
                    subtitle: "Quality against file size"
                    options: ["64k", "96k", "128k", "192k", "256k"]
                    current: root.rec.audioBitrate ?? ""
                    onPicked: name => root.patchRec({ audioBitrate: name })
                }

                StageChoiceRow {
                    enabled: root.audioOn
                    title: "Sample rate"
                    subtitle: "Audio samples per second"
                    options: ["44100", "48000", "96000"].map(v => ({ value: v, label: (Number(v) / 1000) + " kHz" }))
                    current: root.rec.audioSampleRate ?? ""
                    onPicked: v => root.patchRec({ audioSampleRate: v })
                }
            }
        }
    }
}
