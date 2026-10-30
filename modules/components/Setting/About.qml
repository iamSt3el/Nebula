import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import Quickshell.Widgets

Item {
    id: root
    anchors.fill: parent

    property var info: ({})
    property bool copied: false

    readonly property string home: Quickshell.env("HOME") ?? ""
    readonly property string shellDir: Quickshell.shellDir ?? ""
    readonly property string prettyDir: root.home !== "" && root.shellDir.startsWith(root.home)
        ? "~" + root.shellDir.slice(root.home.length) : root.shellDir
    readonly property string revision: root.info.revision ?? ""
    readonly property bool dirty: root.revision.endsWith("*")
    readonly property var links: [
        { icon: "code", title: "GitHub", subtitle: "Source and releases", url: "https://github.com/iamSt3el/Nebula" },
        { icon: "bug_report", title: "Report an issue", subtitle: "Opens a new issue on GitHub", url: "https://github.com/iamSt3el/Nebula/issues/new" },
        { icon: "star", title: "Star the project", subtitle: "", url: "https://github.com/iamSt3el/Nebula" }
    ]

    function shown(v) {
        return (v === undefined || v === null || v === "") ? "—" : String(v)
    }

    Process {
        id: infoProcess
        command: [Quickshell.shellDir + "/bin/nebula", "about", root.shellDir]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.info = JSON.parse(text)
                } catch (e) {
                    root.info = ({})
                }
            }
        }
    }

    Timer {
        id: copiedReset
        interval: 1600
        onTriggered: root.copied = false
    }

    Component.onCompleted: {
        infoProcess.running = true
        ServiceSystemInfo.getUptime()
        ServiceSystemInfo.retain()
    }

    Component.onDestruction: ServiceSystemInfo.release()

    readonly property var drive: ServiceStorage.rootDrive

    property real usedBytes: root.drive?.used ?? 0
    property real availBytes: root.drive?.avail ?? 0
    property real usedPct: root.drive?.pct ?? 0

    Behavior on usedBytes {
        NumberAnimation { duration: 850; easing.type: Easing.OutCubic }
    }
    Behavior on availBytes {
        NumberAnimation { duration: 850; easing.type: Easing.OutCubic }
    }
    Behavior on usedPct {
        NumberAnimation { duration: 850; easing.type: Easing.OutCubic }
    }

    property string hostname: ""
    readonly property real homeBytes: ServiceStorage.childrenPath === root.home
        ? ServiceStorage.entries.reduce((s, e) => s + (e.bytes ?? 0), 0) : 0
    readonly property real driveSize: root.drive?.size ?? 0
    readonly property var segments: {
        const used = root.drive?.used ?? 0
        const free = root.drive?.avail ?? 0
        const home = Math.min(root.homeBytes, used)
        const out = []
        if (home > 0) {
            out.push({ label: "Home", bytes: home, color: Colors.primary })
            out.push({ label: "System and other", bytes: Math.max(0, used - home), color: Colors.secondary })
        } else {
            out.push({ label: "Used", bytes: used, color: Colors.primary })
        }
        out.push({ label: "Free", bytes: free, color: Colors.surfaceContainerHighest })
        return out.filter(s => s.bytes > 0)
    }

    Process {
        running: true
        command: ["cat", "/proc/sys/kernel/hostname"]
        stdout: StdioCollector {
            onStreamFinished: root.hostname = text.trim()
        }
    }

    component SpecTile: Rectangle {
        id: tile
        property string icon: ""
        property string title: ""
        property string target: ""
        default property alias rows: tileRows.data
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        implicitHeight: tileCol.implicitHeight + 32
        radius: 20
        color: Colors.surfaceContainerHigh

        ColumnLayout {
            id: tileCol
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 8

            Item {
                Layout.fillWidth: true
                implicitHeight: 32

                RippleEffect {
                    anchors.fill: parent
                    anchors.margins: -6
                    radius: 14
                    visible: tile.target !== ""
                    onClicked: aboutStages.push(tile.target)
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 10

                    MaterialIconSymbol { content: tile.icon; iconSize: 21; fill: 1; customColor: Colors.primary }

                    CustomText {
                        Layout.fillWidth: true
                        content: tile.title
                        size: 14
                        weight: 500
                        elide: Text.ElideRight
                    }

                    MaterialIconSymbol {
                        visible: tile.target !== ""
                        content: "chevron_right"
                        iconSize: 20
                        customColor: Colors.outline
                    }
                }
            }

            ColumnLayout {
                id: tileRows
                Layout.fillWidth: true
                spacing: 0
            }
        }
    }

    component SpecRow: Item {
        id: spec
        property string label: ""
        property string value: ""
        property string url: ""
        property bool first: false
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 34

        Rectangle {
            visible: !spec.first
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Colors.surfaceContainerHighest
        }

        RowLayout {
            anchors.fill: parent
            spacing: 10

            CustomText {
                Layout.preferredWidth: 92
                content: spec.label
                size: 13
                customColor: Colors.outline
            }

            CustomText {
                Layout.fillWidth: true
                content: spec.value
                size: 13
                weight: 500
                elide: Text.ElideRight
                customColor: spec.url !== "" && specArea.containsMouse ? Colors.primary : Colors.surfaceText
            }
        }

        MouseArea {
            id: specArea
            anchors.fill: parent
            enabled: spec.url !== ""
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["xdg-open", spec.url])
        }
    }

    StageView {
        id: aboutStages

        StagePage {
            stageId: "front"

            StageHero {
                lead: NebulaLogo {
                    id: logo
                    implicitWidth: 76
                    implicitHeight: 76
                    tonal: true
                    progress: 0

                    Timer {
                        interval: 160
                        running: true
                        onTriggered: logo.play()
                    }
                }
                title: "Nebula 1.0.0"
                subtitle: "A modern desktop shell for Wayland" + (root.revision !== "" ? " · " + root.revision.replace("*", "") + (root.dirty ? " with local changes" : "") : "")

                M3Button {
                    icon: "refresh"
                    label: "Restart shell"
                    onClicked: Quickshell.reload(true)
                }

                M3Button {
                    variant: "tonal"
                    icon: "rocket_launch"
                    label: "Run setup again"
                    onClicked: {
                        GlobalStates.settingsOpen = false
                        Quickshell.execDetached([Quickshell.shellDir + "/bin/nebula", "setup"])
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                columns: 2
                columnSpacing: 10
                rowSpacing: 10

                SpecTile {
                    icon: "laptop"
                    title: "This computer"
                    target: "system"

                    SpecRow { first: true; label: "Name"; value: root.shown(root.hostname) }
                    SpecRow { label: "Processor"; value: root.shown(ServiceSystemInfo.cpuName) }
                    SpecRow { label: "Memory"; value: ServiceSystemInfo.memTotalGb > 0 ? ServiceSystemInfo.memTotalGb.toFixed(1) + " GB" : "—" }
                    SpecRow { label: "Up for"; value: root.shown(ServiceSystemInfo.uptime) }
                }

                SpecTile {
                    icon: "deployed_code"
                    title: "Software"
                    target: "system"

                    SpecRow { first: true; label: "System"; value: root.shown(root.info.distro) }
                    SpecRow { label: "Kernel"; value: root.shown(root.info.kernel) }
                    SpecRow { label: "Compositor"; value: root.shown(root.info.compositor) }
                    SpecRow { label: "Runtime"; value: root.info.quickshell ? "Quickshell " + root.info.quickshell : "—" }
                }

                Rectangle {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    implicitHeight: storageCol.implicitHeight + 32
                    radius: 20
                    color: Colors.surfaceContainerHigh

                    ColumnLayout {
                        id: storageCol
                        x: 16
                        y: 16
                        width: parent.width - 32
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            MaterialIconSymbol { content: "hard_drive"; iconSize: 21; fill: 1; customColor: Colors.primary }

                            CustomText {
                                Layout.fillWidth: true
                                content: "Storage"
                                size: 14
                                weight: 500
                            }

                            CustomText {
                                content: root.drive ? root.drive.source + " · " + root.drive.fstype + " · " + root.drive.target : ""
                                size: 12
                                customColor: Colors.outline
                            }
                        }

                        RowLayout {
                            spacing: 10

                            CustomText {
                                content: ServiceStorage.formatBytes(root.usedBytes)
                                family: SettingsConfig.general.displayFont ?? "Rubik"
                                renderType: Text.QtRendering
                                size: 34
                                customColor: root.usedPct > 0.9 ? Colors.error : Colors.surfaceText
                            }

                            CustomText {
                                Layout.alignment: Qt.AlignBottom
                                Layout.bottomMargin: 6
                                content: "used of " + ServiceStorage.formatBytes(root.driveSize) + " · " + ServiceStorage.formatBytes(root.availBytes) + " free"
                                size: 13
                                customColor: Colors.outline
                            }
                        }

                        Row {
                            id: segBar
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            spacing: 3

                            readonly property real total: root.segments.reduce((s, e) => s + e.bytes, 0)

                            Repeater {
                                model: root.segments

                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: Math.max(4, Math.round((segBar.width - segBar.spacing * (root.segments.length - 1)) * modelData.bytes / Math.max(1, segBar.total)))
                                    height: segBar.height
                                    color: modelData.color
                                    topLeftRadius: index === 0 ? 11 : 3
                                    bottomLeftRadius: index === 0 ? 11 : 3
                                    topRightRadius: index === root.segments.length - 1 ? 11 : 3
                                    bottomRightRadius: index === root.segments.length - 1 ? 11 : 3
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 18

                            Repeater {
                                model: root.segments

                                ColumnLayout {
                                    required property var modelData
                                    spacing: 2

                                    RowLayout {
                                        spacing: 6

                                        Rectangle {
                                            Layout.preferredWidth: 10
                                            Layout.preferredHeight: 10
                                            radius: 3
                                            color: modelData.color
                                            border.width: modelData.label === "Free" ? 1 : 0
                                            border.color: Colors.outlineVariant
                                        }

                                        CustomText {
                                            content: modelData.label
                                            size: 12
                                            customColor: Colors.outline
                                        }
                                    }

                                    CustomText {
                                        content: ServiceStorage.formatBytes(modelData.bytes)
                                        size: 13
                                        weight: 600
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        RowLayout {
                            spacing: 8

                            M3Button {
                                variant: "tonal"
                                icon: "grid_view"
                                label: ServiceStorage.mapScanning ? "Usage map · scanning" : "Usage map"
                                onClicked: aboutStages.push("map")
                            }

                            M3Button {
                                visible: ServiceStorage.drives.length > 1
                                variant: "outlined"
                                icon: "sd_card"
                                label: "Other drives"
                                onClicked: aboutStages.push("drives")
                            }
                        }
                    }
                }

                SpecTile {
                    icon: "folder_managed"
                    title: "Config"
                    target: "config"

                    SpecRow { first: true; label: "Shell"; value: root.prettyDir }
                    SpecRow { label: "Folder"; value: "Open in files"; url: "file://" + root.shellDir }
                }

                SpecTile {
                    icon: "help"
                    title: "Help"
                    target: "help"

                    SpecRow { first: true; label: "GitHub"; value: "Source and releases"; url: root.links[0].url }
                    SpecRow { label: "Issues"; value: "Report a problem"; url: root.links[1].url }
                }
            }
        }

        StageLazy {
            stageId: "drives"

            StagePage {
                stageId: "drives"
                title: "Drives"
                aside: ServiceStorage.drives.length > 0 ? String(ServiceStorage.drives.length) : ""

                Repeater {
                    model: ServiceStorage.drives

                    StageRow {
                        required property var modelData
                        icon: modelData.target === "/" ? "hard_drive" : "sd_card"
                        title: modelData.target
                        subtitle: modelData.source + " · " + modelData.fstype
                        value: ServiceStorage.formatBytes(modelData.used) + " of " + ServiceStorage.formatBytes(modelData.size)

                        below: M3WavyProgressBar {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 12
                            progress: modelData.pct
                            activeThickness: 8
                            trackThickness: 8
                            waveAmplitude: 0
                            showStopIndicator: true
                            activeColor: modelData.pct > 0.9 ? Colors.error : Colors.primary
                            trackColor: Colors.surfaceContainerHighest
                        }
                    }
                }
            }
        }

        StageLazy {
            stageId: "system"

            StagePage {
                stageId: "system"
                title: "This computer"

                StageHeading { text: "Software" }
                StageInfoRow { title: "Nebula"; value: "1.0.0" + (root.revision !== "" ? " (" + root.revision + ")" : "") }
                StageInfoRow { title: "Quickshell"; value: root.shown(root.info.quickshell) }
                StageInfoRow { title: "Compositor"; value: root.shown(root.info.compositor) }
                StageInfoRow { title: "Kernel"; value: root.shown(root.info.kernel) }
                StageInfoRow { title: "Distro"; value: root.shown(root.info.distro) }

                StageHeading { text: "Hardware" }
                StageInfoRow { title: "Processor"; value: root.shown(ServiceSystemInfo.cpuName) }
                StageInfoRow { title: "Memory"; value: ServiceSystemInfo.memTotalGb > 0 ? ServiceSystemInfo.memTotalGb.toFixed(1) + " GB" : "—" }
                StageInfoRow { title: "Up for"; value: root.shown(ServiceSystemInfo.uptime) }
            }
        }

        StageLazy {
            stageId: "config"

            StagePage {
                stageId: "config"
                title: "Config"

                StageRow {
                    icon: "folder"
                    title: "Location"
                    subtitle: root.prettyDir
                    value: root.copied ? "Copied" : ""

                    M3IconButton {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        icon: "content_copy"
                        iconSize: 18
                        tip: "Copy the path"
                        onClicked: {
                            Quickshell.clipboardText = root.shellDir
                            root.copied = true
                            copiedReset.restart()
                        }
                    }
                }

                StageNavRow {
                    icon: "open_in_new"
                    title: "Open the folder"
                    onClicked: Quickshell.execDetached(["xdg-open", root.shellDir])
                }
            }
        }

        StageLazy {
            stageId: "help"

            StagePage {
                stageId: "help"
                title: "Help and feedback"

                Repeater {
                    model: root.links

                    StageNavRow {
                        required property var modelData
                        icon: modelData.icon
                        title: modelData.title
                        subtitle: modelData.subtitle
                        onClicked: Quickshell.execDetached(["xdg-open", modelData.url])
                    }
                }

                StageGap {}

                StageNavRow {
                    icon: "keyboard"
                    title: "Keyboard shortcuts"
                    subtitle: "Every shortcut, grouped"
                    onClicked: GlobalStates.settingsPage = 18
                }
            }
        }

        StageLazy {
            stageId: "map"

            StagePage {
                stageId: "map"
                title: "Usage map"

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 20

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                implicitWidth: 32; implicitHeight: 32
                                radius: 16
                                color: Colors.surfaceContainerHighest
                                opacity: ServiceStorage.canGoUp ? 1 : 0.4

                                Behavior on opacity { EffectsAnim { speed: "fast" } }

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: "arrow_upward"
                                    iconSize: 16
                                    customColor: Colors.primary
                                }

                                RippleEffect {
                                    anchors.fill: parent
                                    radius: 16
                                    enabled: ServiceStorage.canGoUp
                                    onClicked: ServiceStorage.goUp()
                                }
                            }

                            Flickable {
                                Layout.fillWidth: true
                                implicitHeight: 32
                                contentWidth: crumbRow.implicitWidth
                                contentHeight: height
                                clip: true
                                interactive: contentWidth > width

                                RowLayout {
                                    id: crumbRow
                                    height: 32
                                    spacing: 2

                                    Repeater {
                                        model: ServiceStorage.breadcrumb

                                        delegate: RowLayout {
                                            id: crumb
                                            required property var modelData
                                            required property int index
                                            spacing: 2

                                            readonly property bool last:
                                                crumb.index === ServiceStorage.breadcrumb.length - 1

                                            opacity: 0

                                            SequentialAnimation {
                                                running: true
                                                PauseAnimation {
                                                    duration: Math.min(crumb.index, 8) * 26
                                                }
                                                EffectsAnim {
                                                    target: crumb; property: "opacity"; to: 1
                                                }
                                            }

                                            MaterialIconSymbol {
                                                visible: crumb.index > 0
                                                content: "chevron_right"
                                                iconSize: 14
                                                customColor: Colors.outline
                                            }

                                            Rectangle {
                                                id: crumbPill
                                                implicitWidth: crumbText.implicitWidth + 16
                                                implicitHeight: 26
                                                radius: 13
                                                color: crumb.last ? Qt.alpha(Colors.primary, 0.16)
                                                     : crumbRipple.containsMouse ? Qt.alpha(Colors.primary, 0.07)
                                                     : "transparent"

                                                Behavior on color { EffectsColorAnim { speed: "fast" } }
                                                Behavior on implicitWidth { SpatialAnim { speed: "fast" } }

                                                CustomText {
                                                    id: crumbText
                                                    anchors.centerIn: parent
                                                    content: crumb.modelData.label
                                                    size: 12
                                                    weight: crumb.last ? 700 : 500
                                                    customColor: crumb.last ? Colors.primary : Colors.outline
                                                }

                                                RippleEffect {
                                                    id: crumbRipple
                                                    anchors.fill: parent
                                                    radius: 13
                                                    hoverColor: "transparent"
                                                    onClicked: ServiceStorage.jumpTo(crumb.modelData.path)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: rootSwitch
                                implicitWidth: rootRow.implicitWidth + 22
                                implicitHeight: 32
                                radius: 16
                                color: Colors.surfaceContainerHighest

                                readonly property bool atHome:
                                    ServiceStorage.currentPath === ServiceStorage.home

                                Behavior on implicitWidth { SpatialAnim { speed: "fast" } }

                                RowLayout {
                                    id: rootRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    MaterialIconSymbol {
                                        content: rootSwitch.atHome ? "hard_drive" : "home"
                                        iconSize: 15
                                        customColor: Colors.primary
                                    }
                                    CustomText {
                                        content: rootSwitch.atHome ? "Whole disk" : "Home"
                                        size: 12
                                        customColor: Colors.primary
                                    }
                                }

                                RippleEffect {
                                    anchors.fill: parent
                                    radius: 16
                                    onClicked: ServiceStorage.openRoot(
                                        rootSwitch.atHome ? "/" : ServiceStorage.home)
                                }
                            }

                            Rectangle {
                                implicitWidth: openRow.implicitWidth + 22
                                implicitHeight: 32
                                radius: 16
                                color: Colors.surfaceContainerHighest

                                RowLayout {
                                    id: openRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    MaterialIconSymbol {
                                        content: "folder_open"; iconSize: 15
                                        customColor: Colors.primary
                                    }
                                    CustomText {
                                        content: "Open"; size: 12
                                        customColor: Colors.primary
                                    }
                                }

                                RippleEffect {
                                    anchors.fill: parent
                                    radius: 16
                                    onClicked: ServiceStorage.openPath(ServiceStorage.currentPath)
                                }
                            }
                        }

                        StorageTreemap {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 380
                            items: ServiceStorage.entries
                            busy: ServiceStorage.mapScanning
                            scanKey: ServiceStorage.currentPath
                            itemsKey: ServiceStorage.childrenPath
                            onDrill: name => ServiceStorage.drillInto(name)
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: ServiceStorage.entries.length > 0
                                ? ServiceStorage.entries.length + " items  ·  click a tile to go deeper"
                                : ""
                            size: 11
                            customColor: Colors.outline

                            opacity: content === "" ? 0 : 1
                            Behavior on opacity { EffectsAnim {} }
                        }
                    }
                }
            }
        }
    }
}
