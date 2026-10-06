import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Bar
import Qt.labs.platform
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MaterialShapeFn
import QtQuick.Controls

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    property var monitorList: ServiceDisplay.monitorList

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
        id: pageFlick
        ScrollBar.vertical: CustomScrollBar {}
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
                            layer.enabled: true
                            roundedPolygon: MaterialShapeFn.getPill()
                            color: Colors.primaryContainer
                        }
                        Image {
                            id: profileArt
                            anchors.fill: parent
                            sourceSize.width: 136
                            sourceSize.height: 136
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

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 16
                            color: Colors.surfaceContainerHighest
                            border.width: nameInput.activeFocus ? 2 : 0
                            border.color: Colors.primary

                            TextInput {
                                id: nameInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                text: SettingsConfig.general.displayName ?? ""
                                color: Colors.surfaceText
                                font.pixelSize: 15
                                font.weight: 700
                                font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                                maximumLength: 32
                                selectByMouse: true
                                clip: true
                                onEditingFinished: {
                                    const n = text.trim()
                                    if (n !== (SettingsConfig.general.displayName ?? ""))
                                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, { displayName: n })
                                }
                                onAccepted: focus = false

                                CustomText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: nameInput.text === ""
                                    content: SettingsConfig.loginName
                                    size: 15
                                    weight: 700
                                    customColor: Colors.outline
                                }
                            }
                        }
                        CustomText {
                            Layout.fillWidth: true
                            content: "Shown on the dashboard. Empty uses your login name."
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

                            M3IconButton {
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
                    id: barLayoutCard
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    readonly property bool anyPill: BarLayout.edgeShapes("top").indexOf("pill") >= 0
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Bar Layout"; size: 14 }
                            CustomText { content: "Move, add and hide items and blocks, and pick each block's shape (stepped, flat or pill) · right-click the bar works too"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        M3Button {
                            icon: "edit"
                            label: "Edit bar"
                            onClicked: {
                                GlobalStates.settingsOpen = false
                                GlobalStates.barEditMode = true
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Weather Panel"; size: 14 }
                            CustomText { content: "Clicking the temperature opens the weather panel"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.general.barWeatherPanel ?? true
                            onToggled: function(state) {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { barWeatherPanel: state })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5
                    bottomRadius: barLayoutCard.anyPill ? 5 : 20
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
                        M3ButtonGroup {
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

                SidesEditor {
                    visible: barLayoutCard.anyPill
                    mode: "pill"
                    sides: ["top", "left", "right"]
                    maxFor: ({ top: 30, left: 10, right: 10 })
                    topRadius: 5
                    bottomRadius: 20
                    linkLabel: "Same margin on every side"
                    values: ({
                        top: SettingsConfig.general.pillMargin ?? 6,
                        left: SettingsConfig.general.pillLeftMargin ?? 6,
                        right: SettingsConfig.general.pillRightMargin ?? 6
                    })
                    onChanged: patch => {
                        const g = {}
                        if (patch.top !== undefined) g.pillMargin = patch.top
                        if (patch.left !== undefined) g.pillLeftMargin = patch.left
                        if (patch.right !== undefined) g.pillRightMargin = patch.right
                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, g)
                    }
                }
            }

            // ── Window Gaps ──────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Window Gaps"; size: 13; customColor: Colors.primary }

            SidesEditor {
                Layout.topMargin: 6
                barSide: ServiceGaps.barSide
                maxValue: 20
                values: ({
                    top: ServiceGaps.extraFor("top"),
                    right: ServiceGaps.extraFor("right"),
                    bottom: ServiceGaps.extraFor("bottom"),
                    left: ServiceGaps.extraFor("left")
                })
                onChanged: patch => {
                    const g = {}
                    if (patch.top !== undefined) g.gapTop = patch.top
                    if (patch.right !== undefined) g.gapRight = patch.right
                    if (patch.bottom !== undefined) g.gapBottom = patch.bottom
                    if (patch.left !== undefined) g.gapLeft = patch.left
                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, g)
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
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Per-monitor"; size: 14 }
                            CustomText { content: "Each monitor shows only its own workspaces"; size: 12; customColor: Colors.outline }
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

            CustomText { Layout.topMargin: 16; content: "Desktop"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: (SettingsConfig.general.desktopRipple ?? false) ? 5 : 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            CustomText { content: "Click Ripples"; size: 14 }
                            CustomText { Layout.fillWidth: true; wrapMode: Text.WordWrap; content: "Clicking the empty desktop sends a water ripple through the wallpaper"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.general.desktopRipple ?? false
                            onToggled: function(state) {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { desktopRipple: state })
                            }
                        }
                    }
                }

                CustomCard {
                    id: rippleStrengthCard
                    visible: SettingsConfig.general.desktopRipple ?? false
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    readonly property string current: SettingsConfig.general.desktopRippleStrength ?? "normal"
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Ripple Strength"; size: 14 }
                            CustomText { content: "How far the wallpaper bends"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        M3ButtonGroup {
                            model: [
                                { value: "subtle", label: "Subtle", icon: "water_drop" },
                                { value: "normal", label: "Normal", icon: "waves" },
                                { value: "splash", label: "Splash", icon: "tsunami" }
                            ]
                            activeCheck: function(value) { return rippleStrengthCard.current === value }
                            onSegmentClicked: function(value) {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { desktopRippleStrength: value })
                            }
                        }
                    }
                }

                CustomCard {
                    visible: SettingsConfig.general.desktopRipple ?? false
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            CustomText { content: "Ripple Trail"; size: 14 }
                            CustomText { Layout.fillWidth: true; wrapMode: Text.WordWrap; content: "Drag across the desktop to draw ripples, like a finger through water"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.general.desktopRippleDrag ?? true
                            onToggled: function(state) {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { desktopRippleDrag: state })
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
    ScrollFade {
        anchors.fill: parent
        flickable: pageFlick
    }
}
