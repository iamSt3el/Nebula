import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    readonly property var layoutCodes: String(ServiceHyprConfig.value("input.kb_layout", "us")).split(",").map(s => s.trim()).filter(s => s !== "")
    readonly property string kbOptions: {
        const v = String(ServiceHyprConfig.value("input.kb_options", ""))
        return v === "[[EMPTY]]" ? "" : v
    }
    readonly property string switchGroup: root.kbOptions.split(",").find(t => t.startsWith("grp:")) ?? ""

    function layoutName(code) {
        return ServiceHyprConfig.kbLayouts.find(l => l.code === code)?.name ?? code
    }

    function setLayouts(codes) {
        ServiceHyprConfig.set("input.kb_layout", codes.join(","))
        if (codes.length > 1 && root.switchGroup === "")
            root.setSwitch("grp:alt_shift_toggle")
    }

    function setSwitch(grp) {
        const rest = root.kbOptions.split(",").map(s => s.trim()).filter(s => s !== "" && !s.startsWith("grp:"))
        if (grp !== "") rest.push(grp)
        ServiceHyprConfig.set("input.kb_options", rest.join(","))
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
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            anchors.topMargin: 5
            spacing: 0

            CustomText { Layout.topMargin: 24; content: "Keyboard"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            spacing: 2
                            CustomText { Layout.fillWidth: true; content: "Layouts"; size: 14 }
                            CustomText { content: "The first one is used at login"; size: 12; customColor: Colors.outline }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 8

                            Repeater {
                                model: root.layoutCodes

                                Rectangle {
                                    id: chip
                                    required property string modelData
                                    required property int index
                                    width: chipRow.implicitWidth + 20
                                    height: 32
                                    radius: 10
                                    color: Colors.secondaryContainer

                                    RowLayout {
                                        id: chipRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        MaterialIconSymbol { content: "language"; iconSize: 16; customColor: Colors.secondaryContainerText }
                                        CustomText { content: root.layoutName(chip.modelData); size: 13; customColor: Colors.secondaryContainerText }
                                        Rectangle {
                                            visible: chip.index === 0
                                            implicitWidth: defText.implicitWidth + 12
                                            implicitHeight: 18
                                            radius: 6
                                            color: Colors.primary
                                            CustomText { id: defText; anchors.centerIn: parent; content: "Default"; size: 10; weight: 600; customColor: Colors.primaryText }
                                        }
                                        M3IconButton {
                                            visible: root.layoutCodes.length > 1
                                            implicitWidth: 22; implicitHeight: 22
                                            icon: "close"
                                            iconSize: 14
                                            iconColor: Colors.secondaryContainerText
                                            onClicked: root.setLayouts(root.layoutCodes.filter((c, i) => i !== chip.index))
                                        }
                                    }
                                }
                            }

                            CustomListNew {
                                id: addLayout
                                width: 190
                                height: 32
                                color: Colors.surfaceContainerHighest
                                currentVal: "Add a layout"
                                list: ServiceHyprConfig.kbLayouts.filter(l => root.layoutCodes.indexOf(l.code) < 0)
                                onListChildClicked: child => {
                                    root.setLayouts(root.layoutCodes.concat([child.code]))
                                    Qt.callLater(() => addLayout.currentVal = "Add a layout")
                                }
                            }
                        }
                    }
                }

                CustomCard {
                    visible: root.layoutCodes.length > 1
                    autoRadius: false; topRadius: 5; bottomRadius: 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        CustomText { Layout.fillWidth: true; content: "Switch layouts with"; size: 14 }
                        M3ButtonGroup {
                            height: 32
                            textSize: 12
                            model: [
                                { value: "grp:alt_shift_toggle", label: "Alt + Shift" },
                                { value: "grp:win_space_toggle", label: "Super + Space" },
                                { value: "grp:caps_toggle", label: "Caps Lock" }
                            ]
                            activeCheck: function(value) { return root.switchGroup === value }
                            onSegmentClicked: value => root.setSwitch(value)
                        }
                    }
                }

                HyprSliderRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    title: "Repeat delay"
                    subtitle: "How long to hold a key before it repeats"
                    path: "input.repeat_delay"
                    from: 150; to: 1000; step: 25; unit: " ms"
                }
                HyprSliderRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    title: "Repeat rate"
                    path: "input.repeat_rate"
                    from: 10; to: 80; unit: "/s"
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        CustomText { Layout.fillWidth: true; content: "Try it"; size: 14 }
                        Rectangle {
                            Layout.preferredWidth: 300
                            Layout.preferredHeight: 38
                            radius: 12
                            color: Colors.surfaceContainerLowest
                            border.width: tryInput.activeFocus ? 2 : 1
                            border.color: tryInput.activeFocus ? Colors.primary : Colors.outlineVariant

                            TextInput {
                                id: tryInput
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                color: Colors.surfaceText
                                font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                                font.pixelSize: 13
                                selectByMouse: true
                            }
                            CustomText {
                                visible: tryInput.text === "" && !tryInput.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                                x: 14
                                content: "Hold a key here to test repeat"
                                size: 13
                                customColor: Colors.outline
                            }
                        }
                    }
                }

                HyprToggleRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    title: "Num Lock on at login"
                    path: "input.numlock_by_default"
                }
            }

            CustomText { Layout.topMargin: 16; content: "Mouse"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                HyprSliderRow {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    title: "Pointer speed"
                    path: "input.sensitivity"
                    from: -1; to: 1; step: 0.05; decimals: 2
                }
                HyprChoiceRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    title: "Acceleration"
                    subtitle: "Flat moves the same distance at any speed"
                    path: "input.accel_profile"
                    emptyValue: "adaptive"
                    model: [{ value: "adaptive", label: "Adaptive" }, { value: "flat", label: "Flat" }]
                }
                HyprChoiceRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    title: "Focus follows the mouse"
                    subtitle: "Hover focuses whatever is under the pointer; Click waits for a click"
                    path: "input.follow_mouse"
                    model: [
                        { value: 0, label: "Click" },
                        { value: 1, label: "Hover" },
                        { value: 2, label: "Detached" },
                        { value: 3, label: "Separate" }
                    ]
                }
                HyprChoiceRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    title: "After closing a window"
                    subtitle: "Which window gets focus next"
                    path: "input.focus_on_close"
                    model: [
                        { value: 0, label: "Next" },
                        { value: 1, label: "Under pointer" },
                        { value: 2, label: "Last used" }
                    ]
                }
                HyprSliderRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    title: "Scroll speed"
                    path: "input.scroll_factor"
                    from: 0.2; to: 2; step: 0.1; decimals: 1; unit: "×"
                }
                HyprToggleRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    title: "Natural scrolling"
                    subtitle: "Content moves with your fingers"
                    path: "input.natural_scroll"
                }
            }

            CustomText { visible: ServiceHyprConfig.hasTouchpad; Layout.topMargin: 16; content: "Touchpad"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                visible: ServiceHyprConfig.hasTouchpad
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                HyprToggleRow {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    title: "Natural scrolling"
                    path: "input.touchpad.natural_scroll"
                }
                HyprToggleRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    title: "Tap to click"
                    path: "input.touchpad.tap_to_click"
                }
                HyprToggleRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    title: "Ignore while typing"
                    path: "input.touchpad.disable_while_typing"
                }
                HyprToggleRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    title: "Click with fingers"
                    subtitle: "Pressing with one, two or three fingers clicks left, right or middle"
                    path: "input.touchpad.clickfinger_behavior"
                }
                HyprChoiceRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    title: "Drag with fingers"
                    subtitle: "Move windows and text by dragging with several fingers"
                    path: "input.touchpad.drag_3fg"
                    model: [{ value: 0, label: "Off" }, { value: 1, label: "3 fingers" }, { value: 2, label: "4 fingers" }]
                }
                HyprSliderRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    title: "Scroll speed"
                    path: "input.touchpad.scroll_factor"
                    from: 0.2; to: 2; step: 0.1; decimals: 1; unit: "×"
                }
                HyprToggleRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    title: "Invert workspace swipe"
                    path: "gestures.workspace_swipe_invert"
                }
                HyprToggleRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    title: "Swipe past the last workspace to make a new one"
                    path: "gestures.workspace_swipe_create_new"
                }
            }

            CustomText { Layout.topMargin: 16; content: "Cursor"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        CustomText { Layout.fillWidth: true; content: "Theme"; size: 14 }
                        CustomListNew {
                            Layout.preferredWidth: 220
                            Layout.preferredHeight: 32
                            color: Colors.surfaceContainerHighest
                            currentVal: ServiceHyprConfig.cursorTheme
                            list: ServiceHyprConfig.cursorThemes.map(t => ({ name: t }))
                            onListChildClicked: child => ServiceHyprConfig.setCursor(child.name, ServiceHyprConfig.cursorSize)
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        CustomText { Layout.fillWidth: true; content: "Size"; size: 14 }
                        M3ButtonGroup {
                            height: 32
                            textSize: 12
                            model: [{ value: 24, label: "24" }, { value: 32, label: "32" }, { value: 48, label: "48" }, { value: 64, label: "64" }]
                            activeCheck: function(value) { return ServiceHyprConfig.cursorSize === value }
                            onSegmentClicked: value => ServiceHyprConfig.setCursor(ServiceHyprConfig.cursorTheme, value)
                        }
                    }
                }

                HyprToggleRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    title: "Hide while typing"
                    path: "cursor.hide_on_key_press"
                }
                HyprSliderRow {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    title: "Hide when idle"
                    path: "cursor.inactive_timeout"
                    from: 0; to: 20; unit: " s"; zeroLabel: "Never"
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
