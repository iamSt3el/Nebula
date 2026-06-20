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

    FileDialog {
        id: imagePicker
        title: "Select a profile image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp *.gif)"]
        onAccepted: {
            SettingsConfig.general = Object.assign({}, SettingsConfig.general, {
                profile: imagePicker.file.toString().replace(/^file:\/\//, "")
            });
            GlobalStates.fileDialogOpen = false;
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
                MaterialIconSymbol {
                    content: "tune"
                    iconSize: 20
                }
                CustomText {
                    content: "General"
                    size: 20
                    customColor: Colors.primary
                }
            }

            // ── Profile ──────────────────────────────────────────────────
            CustomText {
                Layout.topMargin: 24
                content: "Profile"
                size: 13
                customColor: Colors.primary
            }

            CustomCard {
                Layout.topMargin: 6
                autoRadius: false
                topRadius: 20
                bottomRadius: 20

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
                            source: SettingsConfig.profileImage
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

                        CustomText {
                            content: "St3el"
                            size: 16
                            weight: 700
                        }
                        CustomText {
                            content: "Shown in overview and lock screen"
                            size: 12
                            customColor: Colors.outline
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                topLeftRadius: 16
                                bottomLeftRadius: 16
                                topRightRadius: 6
                                bottomRightRadius: 6
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
                                topLeftRadius: 6
                                bottomLeftRadius: 6
                                topRightRadius: 16
                                bottomRightRadius: 16
                                icon: "image"
                                iconSize: 18
                                onClicked: {
                                    GlobalStates.fileDialogOpen = true;
                                    imagePicker.open();
                                }
                            }
                        }
                    }
                }
            }

            // ── Appearance ───────────────────────────────────────────────
            CustomText {
                Layout.topMargin: 16
                content: "Appearance"
                size: 13
                customColor: Colors.primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    autoRadius: false
                    topRadius: 20
                    bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText {
                                content: "Body Font"
                                size: 14
                            }
                            CustomText {
                                content: "Applied globally to all UI text"
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        CustomListNew {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 180
                            color: Colors.surfaceContainerHighest
                            currentVal: SettingsConfig.general.defaultFont
                            list: Settings.fonts
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.general.defaultFont)
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, {
                                        defaultFont: currentVal
                                    });
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false
                    topRadius: 5
                    bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText {
                                content: "Display Font"
                                size: 14
                            }
                            CustomText {
                                content: "Used in clocks, date widgets, and headings"
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        CustomListNew {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 180
                            color: Colors.surfaceContainerHighest
                            currentVal: SettingsConfig.general.displayFont ?? "Titan One"
                            list: Settings.displayFonts
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== (SettingsConfig.general.displayFont ?? "Titan One"))
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, {
                                        displayFont: currentVal
                                    });
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false
                    topRadius: 5
                    bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText {
                                content: "Font Size"
                                size: 14
                            }
                            CustomText {
                                content: "Scale applied to all text"
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        M3Slider {
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 30
                            stepCount: 4
                            stepLabels: ["compact", "normal", "large", "xlarge"]
                            currentStep: ({
                                    "compact": 0,
                                    "normal": 1,
                                    "large": 2,
                                    "xlarge": 3
                                })[SettingsConfig.general.fontScale ?? "normal"] ?? 1
                            onStepChanged: step => {
                                var val = ["compact", "normal", "large", "xlarge"][step];
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, {
                                    fontScale: val
                                });
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false
                    topRadius: 5
                    bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText {
                                content: "Font Weight"
                                size: 14
                            }
                            CustomText {
                                content: "Default weight for body text"
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        M3Slider {
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 30
                            stepCount: 6
                            stepLabels: ["thin", "regular", "medium", "semibold", "bold", "extrabold"]
                            currentStep: ({
                                    "thin": 0,
                                    "regular": 1,
                                    "medium": 2,
                                    "semibold": 3,
                                    "bold": 4,
                                    "extrabold": 5
                                })[SettingsConfig.general.fontWeight ?? "extrabold"] ?? 5
                            onStepChanged: step => {
                                var val = ["thin", "regular", "medium", "semibold", "bold", "extrabold"][step];
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, {
                                    fontWeight: val
                                });
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false
                    topRadius: 5
                    bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText {
                                content: "Flat Bar Mode"
                                size: 14
                            }
                            CustomText {
                                content: "Single-height bar without stepped sections"
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        CustomToogle {
                            isToggleOn: SettingsConfig.general.flatBarMode ?? true
                            onToggled: function (state) {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, {
                                    flatBarMode: state
                                });
                            }
                        }
                    }
                }
            }

            // ── Workspaces ───────────────────────────────────────────────
            CustomText {
                Layout.topMargin: 16
                content: "Workspaces"
                size: 13
                customColor: Colors.primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    autoRadius: false
                    topRadius: 20
                    bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText {
                                content: "Workspace Count"
                                size: 14
                            }
                            CustomText {
                                content: "Number of workspaces shown in the bar"
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            inc: 1
                            limit: 20
                            value: SettingsConfig.general.workspaceCount ?? 10
                            onValChanged: {
                                if (val !== value)
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, {
                                        workspaceCount: val
                                    });
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false
                    topRadius: 5
                    bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText {
                                content: "Show Numbers"
                                size: 14
                            }
                            CustomText {
                                content: "Display index on each workspace indicator"
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        CustomToogle {
                            isToggleOn: SettingsConfig.general.showWorkspaceNumbers ?? false
                            onToggled: function (state) {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, {
                                    showWorkspaceNumbers: state
                                });
                            }
                        }
                    }
                }
            }

            // ── Dock ─────────────────────────────────────────────────────
            CustomText {
                Layout.topMargin: 16
                content: "Dock"
                size: 13
                customColor: Colors.primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    autoRadius: false
                    topRadius: 20
                    bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText {
                                content: "Show Dock"
                                size: 14
                            }
                            CustomText {
                                content: "Show or hide the application dock"
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        CustomToogle {
                            isToggleOn: SettingsConfig.general.dock
                            onToggled: function (state) {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, {
                                    dock: state
                                });
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false
                    topRadius: 5
                    bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText {
                                content: "Auto-hide"
                                size: 14
                            }
                            CustomText {
                                content: "Dock hides when a window overlaps it"
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        CustomToogle {
                            isToggleOn: SettingsConfig.general.dockAutoHide
                            onToggled: function (state) {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, {
                                    dockAutoHide: state
                                });
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false
                    topRadius: 5
                    bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText {
                                content: "Music Player"
                                size: 14
                            }
                            CustomText {
                                content: "Show the mini player in the dock"
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        CustomToogle {
                            isToggleOn: SettingsConfig.general.dockMusicPlayer
                            onToggled: function (state) {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, {
                                    dockMusicPlayer: state
                                });
                            }
                        }
                    }
                }
            }

            Item {
                Layout.preferredHeight: 20
            }
        }
    }

    Loader {
        id: colorPicker
        active: false
        visible: active
        onActiveChanged: {
            if (active)
                grab.active = false;
            else
                grab.active = true;
        }
        sourceComponent: CustomCircularColorPicker {
            onClose: colorPicker.active = false
            onColorsChanged: (first, second, third) => {
                SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, {
                    firstColor: first.toString(),
                    secondColor: second.toString(),
                    thirdColor: third.toString()
                });
            }
        }
    }
}
