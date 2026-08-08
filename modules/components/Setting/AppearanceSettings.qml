import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import Qt.labs.platform
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MaterialShapeFn

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    property var monitorList: ServiceDisplay.monitorList

    // ── Dashboard section order ───────────────────────────────────────────
    // Mirrors Dashboard.qml's normalisation so the settings list and the
    // dashboard can never disagree about what the saved order means.
    readonly property var dashSections: [
        { key: "profile",      label: "Profile",      icon: "person" },
        { key: "controls",     label: "Controls",     icon: "tune" },
        { key: "quickActions", label: "Quick",        icon: "apps" },
        { key: "notifications", label: "Alerts",      icon: "notifications" },
        { key: "calendar",     label: "Calendar",     icon: "calendar_month" }
    ]

    readonly property var dashDefaultOrder: dashSections.map(s => s.key)

    readonly property var dashOrder: {
        const saved = SettingsConfig.dashboard?.order
        if (!Array.isArray(saved) || saved.length === 0) return root.dashDefaultOrder
        const known = saved.filter(k => root.dashDefaultOrder.indexOf(k) !== -1)
        const missing = root.dashDefaultOrder.filter(k => known.indexOf(k) === -1)
        return known.concat(missing)
    }

    function dashMeta(key) {
        for (var i = 0; i < root.dashSections.length; i++)
            if (root.dashSections[i].key === key) return root.dashSections[i]
        return { key: key, label: key, icon: "widgets" }
    }

    // The grid reorders live as you drag, so it needs a mutable model of its
    // own rather than reading the settings array directly — the settings write
    // only happens once, on drop.
    ListModel { id: dashModel }

    function dashRebuild() {
        dashModel.clear()
        const o = root.dashOrder
        for (var i = 0; i < o.length; i++) dashModel.append({ secKey: o[i] })
    }

    function dashPersistOrder() {
        var arr = []
        for (var i = 0; i < dashModel.count; i++) arr.push(dashModel.get(i).secKey)
        SettingsConfig.dashboard = Object.assign({}, SettingsConfig.dashboard, { order: arr })
    }

    Component.onCompleted: root.dashRebuild()

    // Re-sync only when the saved order actually differs from what the grid is
    // showing. Without the comparison, our own write on drop would rebuild the
    // model and fight the drag that produced it.
    onDashOrderChanged: {
        if (dashModel.count !== root.dashOrder.length) { root.dashRebuild(); return }
        for (var i = 0; i < dashModel.count; i++) {
            if (dashModel.get(i).secKey !== root.dashOrder[i]) { root.dashRebuild(); return }
        }
    }

    FileDialog {
        id: imagePicker
        title: "Select a profile image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp *.gif)"]
        onAccepted: {
            SettingsConfig.general = Object.assign({}, SettingsConfig.general, {
                profile: imagePicker.file.toString().replace(/^file:\/\//, "")
            })
            GlobalStates.fileDialogOpen = false
        }
        onRejected: GlobalStates.fileDialogOpen = false
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
                MaterialIconSymbol { content: "brush"; iconSize: 20 }
                CustomText { content: "Appearance"; size: 20; customColor: Colors.primary }
            }

            // ── Profile ──────────────────────────────────────────────────
            CustomText { Layout.topMargin: 24; content: "Profile"; size: 13; customColor: Colors.primary }

            CustomCard {
                Layout.topMargin: 6
                autoRadius: false; topRadius: 20; bottomRadius: 20

                RowLayout {
                    spacing: 16

                    Item {
                        Layout.preferredWidth: 68
                        Layout.preferredHeight: 68
                        Layout.alignment: Qt.AlignVCenter

                        MaterialShapes.ShapeCanvas {
                            id: artMask
                            anchors.fill: parent
                            roundedPolygon: MaterialShapeFn.getPill()
                            color: Colors.primaryContainer
                        }
                        Image {
                            id: profileArt
                            anchors.fill: parent
                            sourceSize: Qt.size(width, height)
                            source: SettingsConfig.general.profile
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                            layer.enabled: true
                        }
                        MultiEffect {
                            source: profileArt
                            anchors.fill: profileArt
                            maskEnabled: true
                            maskSource: artMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6

                        CustomText { content: "St3el"; size: 16; weight: 700 }
                        CustomText {
                            content: "Shown in overview and lock screen"
                            size: 12; customColor: Colors.outline
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                topLeftRadius: 16; bottomLeftRadius: 16
                                topRightRadius: 6;  bottomRightRadius: 6
                                color: Colors.surfaceContainerHighest
                                clip: true

                                CustomText {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    content: SettingsConfig.general.profile
                                    size: 11
                                    elide: Text.ElideLeft
                                }
                            }

                            CustomButton {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 32
                                topLeftRadius: 6;   bottomLeftRadius: 6
                                topRightRadius: 16; bottomRightRadius: 16
                                icon: "image"
                                iconSize: 18
                                onClicked: {
                                    GlobalStates.fileDialogOpen = true
                                    imagePicker.open()
                                }
                            }
                        }
                    }
                }
            }

            // ── Fonts ────────────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Fonts"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Body Font"; size: 14 }
                            CustomText { content: "Applied globally to all UI text"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 180
                            color: Colors.surfaceContainerHighest
                            currentVal: SettingsConfig.general.defaultFont
                            list: Settings.fonts
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.general.defaultFont)
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { defaultFont: currentVal })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Display Font"; size: 14 }
                            CustomText { content: "Used in clocks, date widgets, and headings"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 180
                            color: Colors.surfaceContainerHighest
                            currentVal: SettingsConfig.general.displayFont ?? "Titan One"
                            list: Settings.displayFonts
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== (SettingsConfig.general.displayFont ?? "Titan One"))
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { displayFont: currentVal })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Font Size"; size: 14 }
                            CustomText { content: "Scale applied to all text"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        M3Slider {
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 30
                            stepCount: 4
                            stepLabels: ["compact", "normal", "large", "xlarge"]
                            currentStep: ({ "compact": 0, "normal": 1, "large": 2, "xlarge": 3 })[SettingsConfig.general.fontScale ?? "normal"] ?? 1
                            onStepChanged: step => {
                                var val = ["compact", "normal", "large", "xlarge"][step]
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { fontScale: val })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Font Weight"; size: 14 }
                            CustomText { content: "Default weight for body text"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        M3Slider {
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 30
                            stepCount: 6
                            stepLabels: ["thin", "regular", "medium", "semibold", "bold", "extrabold"]
                            currentStep: ({ "thin": 0, "regular": 1, "medium": 2, "semibold": 3, "bold": 4, "extrabold": 5 })[SettingsConfig.general.fontWeight ?? "extrabold"] ?? 5
                            onStepChanged: step => {
                                var val = ["thin", "regular", "medium", "semibold", "bold", "extrabold"][step]
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { fontWeight: val })
                            }
                        }
                    }
                }
            }

            // ── Bar ──────────────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Bar"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    id: barModeCard
                    autoRadius: false; topRadius: 20; bottomRadius: 5

                    readonly property string currentBarMode: SettingsConfig.general.barMode
                        ?? (SettingsConfig.general.flatBarMode === false ? "stepped" : "flat")

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Bar Mode"; size: 14 }
                            CustomText { content: "Shape of the top bar"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        ButtonGroup {
                            model: [
                                { value: "stepped", label: "Stepped", icon: "view_agenda" },
                                { value: "flat",    label: "Flat",    icon: "remove" },
                                { value: "pill",    label: "Pill",    icon: "circle" }
                            ]
                            activeCheck: function(value) { return barModeCard.currentBarMode === value }
                            onSegmentClicked: function(value) {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { barMode: value })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Bar Centre"; size: 14 }
                            CustomText { content: "What sits in the middle of the bar; all of them expand on hover"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        ButtonGroup {
                            model: [
                                { value: "clock", label: "Clock", icon: "schedule" },
                                { value: "music", label: "Music", icon: "music_note" },
                                { value: "both",  label: "Both",  icon: "splitscreen" }
                            ]
                            activeCheck: function(value) {
                                return (SettingsConfig.general.barCenter ?? "clock") === value
                            }
                            onSegmentClicked: function(value) {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { barCenter: value })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5
                    bottomRadius: barModeCard.currentBarMode === "pill" ? 5 : 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Primary Monitor"; size: 14 }
                            CustomText {
                                content: {
                                    const pm = SettingsConfig.general.primaryMonitor ?? ""
                                    return pm === ""
                                        ? "All monitors show the full bar"
                                        : pm + " shows full bar · others show minimal bar"
                                }
                                size: 12; customColor: Colors.outline
                            }
                        }
                        Item { Layout.fillWidth: true }
                        ButtonGroup {
                            height: 30
                            model: {
                                const all = [{ value: "", label: "All", icon: "devices" }]
                                return all.concat(root.monitorList.map(m => ({
                                    value: m.name, label: m.name
                                })))
                            }
                            activeCheck: function(v) {
                                return (SettingsConfig.general.primaryMonitor ?? "") === v
                            }
                            onSegmentClicked: function(v) {
                                SettingsConfig.general = Object.assign(
                                    {}, SettingsConfig.general, { primaryMonitor: v })
                            }
                            inactiveColor: Colors.surfaceContainerHighest
                            textSize: 11; iconSize: 14
                        }
                    }
                }

                CustomCard {
                    visible: barModeCard.currentBarMode === "pill"
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Top Margin"; size: 14 }
                            CustomText { content: "Gap between pill and top screen edge"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        M3Slider {
                            Layout.preferredWidth: 160
                            stepCount: 31
                            currentStep: SettingsConfig.general.pillMargin ?? 6
                            onStepChanged: step => {
                                if (step !== (SettingsConfig.general.pillMargin ?? 6))
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { pillMargin: step })
                            }
                        }
                    }
                }

                CustomCard {
                    visible: barModeCard.currentBarMode === "pill"
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 24

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            ColumnLayout {
                                Layout.preferredWidth: 170
                                Layout.maximumWidth: 170
                                spacing: 2
                                CustomText { content: "Left Margin"; size: 14 }
                                CustomText { Layout.fillWidth: true; wrapMode: Text.WordWrap; content: "Gap between pill and left screen edge"; size: 12; customColor: Colors.outline }
                            }
                            Item { Layout.fillWidth: true }
                            M3Slider {
                                Layout.preferredWidth: 160
                                stepCount: 11
                                currentStep: SettingsConfig.general.pillLeftMargin ?? 6
                                onStepChanged: step => {
                                    if (step !== (SettingsConfig.general.pillLeftMargin ?? 6))
                                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, { pillLeftMargin: step })
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            ColumnLayout {
                                Layout.preferredWidth: 170
                                Layout.maximumWidth: 170
                                spacing: 2
                                CustomText { content: "Right Margin"; size: 14 }
                                CustomText { Layout.fillWidth: true; wrapMode: Text.WordWrap; content: "Gap between pill and right screen edge"; size: 12; customColor: Colors.outline }
                            }
                            Item { Layout.fillWidth: true }
                            M3Slider {
                                Layout.preferredWidth: 160
                                stepCount: 11
                                currentStep: SettingsConfig.general.pillRightMargin ?? 6
                                onStepChanged: step => {
                                    if (step !== (SettingsConfig.general.pillRightMargin ?? 6))
                                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, { pillRightMargin: step })
                                }
                            }
                        }
                    }
                }
            }

            // ── Window Gaps ──────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Window Gaps"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 24

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            ColumnLayout {
                                Layout.preferredWidth: 170
                                Layout.maximumWidth: 170
                                spacing: 2
                                CustomText { content: "Top Extra"; size: 14 }
                                CustomText { Layout.fillWidth: true; wrapMode: Text.WordWrap; content: "Added on top of bar height (auto-calculated)"; size: 12; customColor: Colors.outline }
                            }
                            Item { Layout.fillWidth: true }
                            M3Slider {
                                Layout.preferredWidth: 160
                                stepCount: 21
                                currentStep: SettingsConfig.general.gapTop ?? 0
                                onStepChanged: step => {
                                    if (step !== (SettingsConfig.general.gapTop ?? 0))
                                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, { gapTop: step })
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            ColumnLayout {
                                Layout.preferredWidth: 170
                                Layout.maximumWidth: 170
                                spacing: 2
                                CustomText { content: "Bottom"; size: 14 }
                                CustomText { Layout.fillWidth: true; wrapMode: Text.WordWrap; content: "Gap from bottom screen edge"; size: 12; customColor: Colors.outline }
                            }
                            Item { Layout.fillWidth: true }
                            M3Slider {
                                Layout.preferredWidth: 160
                                stepCount: 21
                                currentStep: SettingsConfig.general.gapBottom ?? 5
                                onStepChanged: step => {
                                    if (step !== (SettingsConfig.general.gapBottom ?? 5))
                                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, { gapBottom: step })
                                }
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 24

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            ColumnLayout {
                                Layout.preferredWidth: 170
                                Layout.maximumWidth: 170
                                spacing: 2
                                CustomText { content: "Left"; size: 14 }
                                CustomText { Layout.fillWidth: true; wrapMode: Text.WordWrap; content: "Gap from left screen edge"; size: 12; customColor: Colors.outline }
                            }
                            Item { Layout.fillWidth: true }
                            M3Slider {
                                Layout.preferredWidth: 160
                                stepCount: 21
                                currentStep: SettingsConfig.general.gapLeft ?? 5
                                onStepChanged: step => {
                                    if (step !== (SettingsConfig.general.gapLeft ?? 5))
                                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, { gapLeft: step })
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            ColumnLayout {
                                Layout.preferredWidth: 170
                                Layout.maximumWidth: 170
                                spacing: 2
                                CustomText { content: "Right"; size: 14 }
                                CustomText { Layout.fillWidth: true; wrapMode: Text.WordWrap; content: "Gap from right screen edge"; size: 12; customColor: Colors.outline }
                            }
                            Item { Layout.fillWidth: true }
                            M3Slider {
                                Layout.preferredWidth: 160
                                stepCount: 21
                                currentStep: SettingsConfig.general.gapRight ?? 5
                                onStepChanged: step => {
                                    if (step !== (SettingsConfig.general.gapRight ?? 5))
                                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, { gapRight: step })
                                }
                            }
                        }
                    }
                }
            }

            // ── Workspaces ───────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Workspaces"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Workspace Count"; size: 14 }
                            CustomText { content: "Number of workspaces shown in the bar"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            inc: 1
                            limit: 20
                            value: SettingsConfig.general.workspaceCount ?? 10
                            onValChanged: {
                                if (val !== value)
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { workspaceCount: val })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 24

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            ColumnLayout {
                                Layout.preferredWidth: 170
                                Layout.maximumWidth: 170
                                spacing: 2
                                CustomText { content: "Show Numbers"; size: 14 }
                                CustomText { Layout.fillWidth: true; wrapMode: Text.WordWrap; content: "Display index on each workspace indicator"; size: 12; customColor: Colors.outline }
                            }
                            Item { Layout.fillWidth: true }
                            CustomToogle {
                                isToggleOn: SettingsConfig.general.showWorkspaceNumbers ?? false
                                onToggled: function(state) {
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { showWorkspaceNumbers: state })
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            ColumnLayout {
                                Layout.preferredWidth: 170
                                Layout.maximumWidth: 170
                                spacing: 2
                                CustomText { content: "Per-monitor"; size: 14 }
                                CustomText { Layout.fillWidth: true; wrapMode: Text.WordWrap; content: "Each monitor shows only its own workspaces"; size: 12; customColor: Colors.outline }
                            }
                            Item { Layout.fillWidth: true }
                            CustomToogle {
                                isToggleOn: SettingsConfig.general.perMonitorWorkspaces ?? false
                                onToggled: function(state) {
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { perMonitorWorkspaces: state })
                                }
                            }
                        }
                    }
                }
            }

            // ── Dock ─────────────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Dock"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Show Dock"; size: 14 }
                            CustomText { content: "Show or hide the application dock"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.general.dock
                            onToggled: function(state) {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { dock: state })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 24

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            ColumnLayout {
                                Layout.preferredWidth: 170
                                Layout.maximumWidth: 170
                                spacing: 2
                                CustomText { content: "Auto-hide"; size: 14 }
                                CustomText { Layout.fillWidth: true; wrapMode: Text.WordWrap; content: "Dock hides when a window overlaps it"; size: 12; customColor: Colors.outline }
                            }
                            Item { Layout.fillWidth: true }
                            CustomToogle {
                                isToggleOn: SettingsConfig.general.dockAutoHide
                                onToggled: function(state) {
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { dockAutoHide: state })
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            ColumnLayout {
                                Layout.preferredWidth: 170
                                Layout.maximumWidth: 170
                                spacing: 2
                                CustomText { content: "Music Player"; size: 14 }
                                CustomText { Layout.fillWidth: true; wrapMode: Text.WordWrap; content: "Show the mini player in the dock"; size: 12; customColor: Colors.outline }
                            }
                            Item { Layout.fillWidth: true }
                            CustomToogle {
                                isToggleOn: SettingsConfig.general.dockMusicPlayer
                                onToggled: function(state) {
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { dockMusicPlayer: state })
                                }
                            }
                        }
                    }
                }
            }

            // ── Dashboard ────────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Dashboard"; size: 13; customColor: Colors.primary }

            CustomText {
                Layout.topMargin: 2
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                content: "Click a card to show or hide it, drag to reorder. Cards read left to right, top to bottom \u2014 the same order they stack in the dashboard, which sizes itself to whatever you leave on."
                size: 12
                customColor: Colors.outline
            }

            GridView {
                id: dashGrid
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.preferredHeight: {
                    const perRow = Math.max(1, Math.floor(width / cellWidth))
                    return Math.ceil(count / perRow) * cellHeight
                }

                cellWidth: 112
                cellHeight: 96
                interactive: false
                model: dashModel

                // Cards slide out of the way as a drag passes over them
                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutQuad }
                }

                delegate: Item {
                    id: slot
                    required property int index
                    required property string secKey

                    width: dashGrid.cellWidth
                    height: dashGrid.cellHeight
                    // Lift the whole slot so the dragged card is never painted
                    // under a neighbour as it leaves its own cell
                    z: dragArea.drag.active ? 2 : 1

                    readonly property var meta: root.dashMeta(secKey)
                    readonly property bool on: SettingsConfig.dashboard?.[secKey] ?? true

                    DropArea {
                        anchors.fill: parent
                        onEntered: function(drag) {
                            const from = drag.source.slotIndex
                            if (from !== slot.index) dashModel.move(from, slot.index, 1)
                        }
                    }

                    Rectangle {
                        id: card
                        property int slotIndex: slot.index

                        width: 104
                        height: 88
                        x: (slot.width  - width)  / 2
                        y: (slot.height - height) / 2
                        radius: 18

                        color: slot.on ? Qt.alpha(Colors.primary, 0.13)
                                       : Colors.surfaceContainerHigh
                        border.width: slot.on ? 2 : 0
                        border.color: Colors.primary

                        scale: dragArea.drag.active ? 1.06 : 1
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Drag.active: dragArea.drag.active
                        Drag.source: card
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIconSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                content: slot.meta.icon
                                iconSize: 24
                                fill: slot.on ? 1 : 0
                                customColor: slot.on ? Colors.primary : Colors.outline
                            }

                            CustomText {
                                Layout.alignment: Qt.AlignHCenter
                                content: slot.meta.label
                                size: 12
                                weight: slot.on ? 700 : 500
                                customColor: slot.on ? Colors.primary : Colors.surfaceText
                            }
                        }

                        MaterialIconSymbol {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 7
                            visible: slot.on
                            content: "check_circle"
                            iconSize: 14
                            fill: 1
                            customColor: Colors.primary
                        }

                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            drag.target: card
                            drag.axis: Drag.XAndYAxis

                            // Dragging moves the card by writing x/y directly,
                            // which breaks the centring bindings — they have to
                            // be restored explicitly once the card is dropped.
                            property bool didDrag: false
                            onPressed: didDrag = false
                            onPositionChanged: if (drag.active) didDrag = true

                            onReleased: {
                                card.Drag.drop()
                                card.x = Qt.binding(() => (slot.width  - card.width)  / 2)
                                card.y = Qt.binding(() => (slot.height - card.height) / 2)
                                if (didDrag) root.dashPersistOrder()
                            }

                            onClicked: {
                                if (didDrag) return   // a drag is not a toggle
                                var patch = {}
                                patch[slot.secKey] = !slot.on
                                SettingsConfig.dashboard = Object.assign({}, SettingsConfig.dashboard, patch)
                            }
                        }
                    }
                }
            }


            // ── Game Mode ────────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Game Mode"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Game Mode"; size: 14; customColor: Colors.primary }
                            CustomText { content: "Reopen this panel with your settings shortcut to switch it back off"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: ServiceGameMode.active
                            onToggled: function(state) {
                                ServiceGameMode.active = state
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Hide Bar"; size: 14 }
                            CustomText { content: "Hides the top bar and drops window gaps to zero"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.gameMode?.hideBar ?? true
                            onToggled: function(state) {
                                SettingsConfig.gameMode = Object.assign({}, SettingsConfig.gameMode, { hideBar: state })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Hide Widgets & Dock"; size: 14 }
                            CustomText { content: "Hides desktop widgets, the dock and the music visualizer"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.gameMode?.hideWidgets ?? true
                            onToggled: function(state) {
                                SettingsConfig.gameMode = Object.assign({}, SettingsConfig.gameMode, { hideWidgets: state })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Do Not Disturb"; size: 14 }
                            CustomText { content: "Holds back notification banners; they still reach the center"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.gameMode?.dnd ?? true
                            onToggled: function(state) {
                                SettingsConfig.gameMode = Object.assign({}, SettingsConfig.gameMode, { dnd: state })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Performance Tweaks"; size: 14 }
                            CustomText { content: "Turns off blur, shadows and animations; reloads your Hyprland config on exit"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.gameMode?.hyprPerf ?? true
                            onToggled: function(state) {
                                SettingsConfig.gameMode = Object.assign({}, SettingsConfig.gameMode, { hyprPerf: state })
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
