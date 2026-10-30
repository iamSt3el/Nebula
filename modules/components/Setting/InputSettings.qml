import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

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
        if (grp !== "")
            rest.push(grp)
        ServiceHyprConfig.set("input.kb_options", rest.join(","))
    }

    property string group: ""
    property string query: ""
    readonly property bool inputOn: Features.hyprInput
    readonly property bool bindsOn: Features.hyprBinds
    readonly property var entries: ServiceKeybinds.entries
    readonly property var groupNames: ServiceKeybinds.groupOrder.filter(g => root.entries.some(e => e.group === g))
    readonly property var changed: root.entries.filter(e => e.changed && !e.placeholder)
    readonly property var matches: {
        const q = root.query.toLowerCase()
        if (q === "")
            return []
        return root.entries.filter(e => (e.name ?? "").toLowerCase().indexOf(q) >= 0
            || (e.desc ?? "").toLowerCase().indexOf(q) >= 0
            || ServiceKeybinds.pretty(e.key ?? "").toLowerCase().indexOf(q) >= 0).slice(0, 40)
    }
    readonly property var groupMeta: ({
        "Nebula": { icon: "auto_awesome", sub: "Launcher, clipboard, tools, notes, pie menu" },
        "Windows": { icon: "select_window", sub: "Close, float, focus, move, resize, swap" },
        "Workspaces": { icon: "view_week", sub: "Go to, send to, next and previous" },
        "Apps": { icon: "apps", sub: "Terminal, browser, files, your commands" },
        "Media": { icon: "music_note", sub: "Volume, brightness and player keys" }
    })

    function count(g) {
        return root.entries.filter(e => e.group === g && !e.unset).length
    }

    function fileOf(g) {
        return g === "Nebula" ? "nebula/keybinds.lua" : "lua/keybinds.lua"
    }

    function openGroup(g) {
        root.group = g
        stages.push("group")
    }

    function isMouse(e) {
        return !!e.mouse || /mouse/i.test(e.key ?? "")
    }

    function keyCountIn(g) {
        return root.entries.filter(e => e.group === g && !e.unset && !root.isMouse(e)).length
    }

    readonly property var mouseBinds: root.entries.filter(e => !e.unset && !e.placeholder && root.isMouse(e))
    readonly property int keyCount: root.entries.filter(e => !e.unset && !root.isMouse(e)).length
    readonly property int topGroupCount: Math.max(0, ...root.groupNames.map(g => root.keyCountIn(g)))

    component DeviceCard: CustomCard {
        id: dev
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property string target: ""
        property bool lead: false
        autoRadius: false; topRadius: 28; bottomRadius: 28
        color: Colors.surfaceContainer
        contentSpacing: 3

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 11
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: 16
                color: dev.lead ? Colors.primary : Colors.surfaceContainerHighest

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: dev.icon
                    iconSize: 24
                    fill: 1
                    customColor: dev.lead ? Colors.primaryText : Colors.primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                CustomText {
                    Layout.fillWidth: true
                    content: dev.title
                    size: 16
                    weight: 600
                    elide: Text.ElideRight
                }

                CustomText {
                    Layout.fillWidth: true
                    content: dev.subtitle
                    size: 12
                    elide: Text.ElideRight
                    customColor: Colors.outline
                }
            }

            M3Button {
                variant: "text"
                label: "More"
                onClicked: stages.push(dev.target)
            }
        }
    }

    onVisibleChanged: if (!visible) editor.stopListening()
    Component.onDestruction: editor.stopListening()

    Connections {
        target: GlobalStates
        function onSettingsOpenChanged() {
            if (!GlobalStates.settingsOpen)
                editor.stopListening()
        }
    }

    Connections {
        target: stages
        function onCurrentChanged() {
            if (stages.current !== "edit")
                editor.stopListening()
        }
    }

    Item {
        id: editor

        property var entry: null
        property bool isNew: false
        property bool listening: false
        property string recorded: ""
        property string held: ""
        property string resolution: "swap"
        property bool locked: false
        property bool repeating: false
        property bool release: false

        readonly property var conflict: editor.recorded !== "" ? ServiceKeybinds.owner(editor.recorded, editor.entry?.id ?? "") : null
        readonly property bool conflictEditable: !!editor.conflict?.editable && !editor.conflict?.placeholder
        readonly property string originalKey: editor.entry?.key ?? ""
        readonly property bool canSave: editor.recorded !== "" && !editor.listening
            && (!editor.isNew || commandInput.text.trim() !== "")
            && (!editor.conflict || editor.resolution === "both" || editor.conflictEditable)

        function openFor(e) {
            editor.entry = e
            editor.isNew = e === null
            editor.recorded = ""
            editor.held = ""
            editor.locked = e?.locked ?? false
            editor.repeating = e?.repeating ?? false
            editor.release = e?.release ?? false
            editor.resolution = "swap"
            commandInput.text = ""
            nameInput.text = ""
            stages.push("edit")
            editor.startListening()
        }

        function startListening() {
            editor.listening = true
            editor.held = ""
            ServiceHyprConfig.beginRecord()
            catcher.forceActiveFocus()
        }

        function stopListening() {
            if (!editor.listening) return
            editor.listening = false
            ServiceHyprConfig.endRecord()
        }

        function close() {
            editor.stopListening()
            if (stages.current === "edit")
                stages.back()
        }

        function save() {
            if (!editor.canSave) return
            const flags = { locked: editor.locked, repeating: editor.repeating, release: editor.release }
            if (editor.isNew) {
                ServiceHyprConfig.addCommand(editor.recorded, commandInput.text.trim(), nameInput.text.trim())
            } else {
                const c = editor.conflict
                if (c && editor.conflictEditable) {
                    if (editor.resolution === "swap") ServiceHyprConfig.setBind(c, editor.originalKey, null)
                    else if (editor.resolution === "replace") ServiceHyprConfig.setBind(c, "", null)
                }
                ServiceHyprConfig.setBind(editor.entry, editor.recorded, flags)
            }
            editor.close()
        }

        readonly property var symbolKeys: ({
            [Qt.Key_QuoteLeft]: "grave", [Qt.Key_AsciiTilde]: "grave",
            [Qt.Key_Minus]: "minus", [Qt.Key_Underscore]: "minus",
            [Qt.Key_Equal]: "equal", [Qt.Key_Plus]: "equal",
            [Qt.Key_BracketLeft]: "bracketleft", [Qt.Key_BraceLeft]: "bracketleft",
            [Qt.Key_BracketRight]: "bracketright", [Qt.Key_BraceRight]: "bracketright",
            [Qt.Key_Backslash]: "backslash", [Qt.Key_Bar]: "backslash",
            [Qt.Key_Semicolon]: "semicolon", [Qt.Key_Colon]: "semicolon",
            [Qt.Key_Apostrophe]: "apostrophe", [Qt.Key_QuoteDbl]: "apostrophe",
            [Qt.Key_Comma]: "comma", [Qt.Key_Less]: "comma",
            [Qt.Key_Period]: "period", [Qt.Key_Greater]: "period",
            [Qt.Key_Slash]: "slash", [Qt.Key_Question]: "slash",
            [Qt.Key_Exclam]: "1", [Qt.Key_At]: "2", [Qt.Key_NumberSign]: "3", [Qt.Key_Dollar]: "4",
            [Qt.Key_Percent]: "5", [Qt.Key_AsciiCircum]: "6", [Qt.Key_Ampersand]: "7", [Qt.Key_Asterisk]: "8",
            [Qt.Key_ParenLeft]: "9", [Qt.Key_ParenRight]: "0",
            [Qt.Key_Return]: "RETURN", [Qt.Key_Enter]: "RETURN", [Qt.Key_Tab]: "TAB", [Qt.Key_Backtab]: "TAB",
            [Qt.Key_Space]: "SPACE", [Qt.Key_Backspace]: "BACKSPACE", [Qt.Key_Delete]: "DELETE",
            [Qt.Key_Insert]: "Insert", [Qt.Key_Home]: "Home", [Qt.Key_End]: "End",
            [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next", [Qt.Key_Print]: "PRINT",
            [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down"
        })

        readonly property var modifierKeys: [Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Shift,
            Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr, Qt.Key_Hyper_L, Qt.Key_Hyper_R]

        function modsOf(m) {
            const out = []
            if (m & Qt.MetaModifier) out.push("SUPER")
            if (m & Qt.ShiftModifier) out.push("SHIFT")
            if (m & Qt.ControlModifier) out.push("CTRL")
            if (m & Qt.AltModifier) out.push("ALT")
            return out
        }

        function keyName(e) {
            if (e.key >= Qt.Key_A && e.key <= Qt.Key_Z) return String.fromCharCode(e.key)
            if (e.key >= Qt.Key_0 && e.key <= Qt.Key_9) return String.fromCharCode(e.key)
            if (e.key >= Qt.Key_F1 && e.key <= Qt.Key_F35) return "F" + (e.key - Qt.Key_F1 + 1)
            return editor.symbolKeys[e.key] ?? ""
        }

        Item {
            id: catcher
            focus: stages.current === "edit"
            Keys.onPressed: event => {
                event.accepted = true
                const mods = editor.modsOf(event.modifiers)
                if (!editor.listening) {
                    if (event.key === Qt.Key_Escape) editor.close()
                    else if (event.key === Qt.Key_Return && editor.canSave) editor.save()
                    return
                }
                if (event.key === Qt.Key_Escape && mods.length === 0) {
                    editor.stopListening()
                    return
                }
                if (editor.modifierKeys.indexOf(event.key) >= 0) {
                    editor.held = mods.join(" + ")
                    return
                }
                const k = editor.keyName(event)
                if (k === "") return
                editor.recorded = mods.concat([k]).join(" + ")
                editor.stopListening()
                if (editor.isNew) commandInput.focusInput()
            }
            Keys.onReleased: event => {
                if (editor.listening) editor.held = editor.modsOf(event.modifiers).join(" + ")
            }
        }
    }

    StageView {
        id: stages

        StagePage {
            stageId: "front"

            HyprTargetRow { area: "input"; visible: root.inputOn }

            HyprTargetRow { area: "binds"; visible: root.bindsOn }

            StageFieldRow {
                visible: root.bindsOn
                icon: "search"
                title: "Find a shortcut"
                subtitle: "An action, a key or part of a command"
                fieldWidth: 260
                allowEmpty: true
                placeholder: "Search"
                onTypedChanged: root.query = typed.trim()
            }

            StageHeading {
                visible: root.bindsOn && root.query !== ""
                text: root.matches.length === 0 ? "Nothing matches" : "Matches"
                aside: root.matches.length > 0 ? String(root.matches.length) : ""
            }

            Repeater {
                model: root.bindsOn ? root.matches : []
                BindRow {
                    required property var modelData
                    entry: modelData
                }
            }

            DeviceCard {
                Layout.topMargin: 10
                icon: "keyboard"
                lead: true
                title: root.inputOn ? "Keyboard" : "Keyboard shortcuts"
                subtitle: !root.inputOn ? root.keyCount + " shortcuts"
                    : (ServiceHyprConfig.keyboardName !== "" ? ServiceHyprConfig.keyboardName + " · " : "") + root.layoutCodes.map(c => root.layoutName(c)).join(", ")
                target: root.inputOn ? "keyboard" : ""

                Flow {
                    visible: root.inputOn
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.layoutCodes

                        Rectangle {
                            id: layoutChip
                            required property string modelData
                            required property int index
                            width: layoutChipRow.implicitWidth + 24
                            height: 36
                            radius: 18
                            color: Colors.secondaryContainer

                            RowLayout {
                                id: layoutChipRow
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialIconSymbol { content: "language"; iconSize: 16; customColor: Colors.secondaryContainerText }
                                CustomText { content: root.layoutName(layoutChip.modelData); size: 13; customColor: Colors.secondaryContainerText }
                                Rectangle {
                                    visible: layoutChip.index === 0
                                    implicitWidth: defaultText.implicitWidth + 12
                                    implicitHeight: 18
                                    radius: 6
                                    color: Colors.primary
                                    CustomText { id: defaultText; anchors.centerIn: parent; content: "Default"; size: 10; weight: 600; customColor: Colors.primaryText }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: addRow.implicitWidth + 24
                        height: 36
                        radius: 18
                        color: "transparent"
                        border.width: 1
                        border.color: Colors.outlineVariant

                        RowLayout {
                            id: addRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialIconSymbol { content: "add"; iconSize: 16; customColor: Colors.primary }
                            CustomText { content: "Layout"; size: 13 }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            radius: 18
                            onClicked: stages.push("keyboard")
                        }
                    }
                }

                RowLayout {
                    visible: root.inputOn && root.layoutCodes.length > 1
                    Layout.fillWidth: true
                    Layout.topMargin: 9
                    spacing: 12

                    CustomText {
                        Layout.fillWidth: true
                        content: "Switch layouts with"
                        size: 13
                        customColor: Colors.outline
                    }

                    CustomListNew {
                        readonly property var choices: [
                            { value: "grp:alt_shift_toggle", name: "Alt + Shift" },
                            { value: "grp:win_space_toggle", name: "Super + Space" },
                            { value: "grp:caps_toggle", name: "Caps Lock" }
                        ]
                        Layout.preferredWidth: 170
                        Layout.preferredHeight: 32
                        color: Colors.surfaceContainerHighest
                        currentVal: choices.find(c => c.value === root.switchGroup)?.name ?? ""
                        list: choices
                        onListChildClicked: child => {
                            if (child && child.value !== root.switchGroup)
                                root.setSwitch(child.value)
                        }
                    }
                }

                StageHeading {
                    visible: root.bindsOn
                    text: "Shortcuts on the keyboard"
                    aside: root.keyCount + (root.changed.length > 0 ? " · " + root.changed.length + " changed by you" : "")
                }

                GridLayout {
                    visible: root.bindsOn
                    Layout.fillWidth: true
                    columns: Math.max(1, root.groupNames.length)
                    columnSpacing: 6
                    rowSpacing: 6

                    Repeater {
                        model: root.groupNames

                        Rectangle {
                            id: groupTile
                            required property string modelData
                            readonly property int n: root.keyCountIn(groupTile.modelData)
                            readonly property bool most: groupTile.n > 0 && groupTile.n === root.topGroupCount
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 78
                            radius: 20
                            color: groupTile.most ? Colors.primaryContainer : Colors.surfaceContainerHigh

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 2

                                CustomText {
                                    content: String(groupTile.n)
                                    family: SettingsConfig.general.displayFont ?? "Rubik"
                                    renderType: Text.QtRendering
                                    size: 26
                                    customColor: groupTile.most ? Colors.primaryContainerText : Colors.surfaceText
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    content: groupTile.modelData
                                    size: 12
                                    elide: Text.ElideRight
                                    customColor: groupTile.most ? Colors.primaryContainerText : Colors.outline
                                }
                            }

                            RippleEffect {
                                anchors.fill: parent
                                radius: groupTile.radius
                                onClicked: root.openGroup(groupTile.modelData)
                            }
                        }
                    }
                }

                StageGap { visible: root.bindsOn && root.changed.length > 0 }

                Repeater {
                    model: root.bindsOn && root.query === "" ? root.changed : []
                    BindRow {
                        required property var modelData
                        entry: modelData
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    spacing: 8

                    CustomText {
                        visible: root.inputOn
                        Layout.fillWidth: true
                        content: "Key repeat: wait " + ServiceHyprConfig.value("input.repeat_delay", 600) + " ms, then " + ServiceHyprConfig.value("input.repeat_rate", 25) + " a second"
                            + (ServiceHyprConfig.value("input.numlock_by_default", false) ? " · Num Lock on at login" : "")
                        size: 12
                        wrapMode: Text.WordWrap
                        customColor: Colors.outline
                    }

                    Item { visible: !root.inputOn; Layout.fillWidth: true }

                    M3Button {
                        visible: root.bindsOn && root.changed.length > 0
                        variant: "tonal"
                        icon: "restart_alt"
                        label: "Reset all"
                        onClicked: ServiceHyprConfig.resetAllBinds()
                    }

                    M3Button {
                        visible: root.bindsOn
                        variant: "tonal"
                        icon: "add"
                        label: "Add shortcut"
                        onClicked: editor.openFor(null)
                    }
                }
            }

            DeviceCard {
                Layout.topMargin: 10
                icon: "mouse"
                title: root.inputOn ? "Mouse" : "Mouse shortcuts"
                subtitle: !root.inputOn ? root.mouseBinds.length + " shortcuts"
                    : ServiceHyprConfig.mouseName !== "" ? ServiceHyprConfig.mouseName : "Speed, acceleration and focus"
                target: root.inputOn ? "mouse" : ""

                HyprSliderRow {
                    visible: root.inputOn
                    title: "Pointer speed"
                    path: "input.sensitivity"
                    from: -1; to: 1; step: 0.05; decimals: 2
                }

                HyprChoiceRow {
                    visible: root.inputOn
                    title: "Acceleration"
                    subtitle: "Flat moves the same distance at any speed"
                    path: "input.accel_profile"
                    emptyValue: "adaptive"
                    model: [{ value: "adaptive", label: "Adaptive" }, { value: "flat", label: "Flat" }]
                }

                HyprChoiceRow {
                    visible: root.inputOn
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

                StageHeading {
                    visible: root.bindsOn
                    text: "Shortcuts on the mouse"
                    aside: String(root.mouseBinds.length)
                }

                StageNote {
                    visible: root.bindsOn && root.mouseBinds.length === 0
                    content: "No mouse shortcuts yet."
                }

                Repeater {
                    model: root.bindsOn ? root.mouseBinds : []
                    BindRow {
                        required property var modelData
                        entry: modelData
                    }
                }
            }

            DeviceCard {
                visible: root.inputOn && ServiceHyprConfig.hasTouchpad
                Layout.topMargin: 10
                icon: "touchpad_mouse"
                title: "Touchpad"
                subtitle: ServiceHyprConfig.touchpadName !== "" ? ServiceHyprConfig.touchpadName : "Taps, fingers and swipes"
                target: "touchpad"

                HyprToggleRow {
                    title: "Tap to click"
                    path: "input.touchpad.tap_to_click"
                }

                HyprToggleRow {
                    title: "Natural scrolling"
                    subtitle: "Content moves with your fingers"
                    path: "input.touchpad.natural_scroll"
                }

                HyprToggleRow {
                    title: "Ignore while typing"
                    path: "input.touchpad.disable_while_typing"
                }

                StageHeading { text: "Gestures" }

                HyprToggleRow {
                    title: "Invert workspace swipe"
                    path: "gestures.workspace_swipe_invert"
                }

                HyprToggleRow {
                    title: "Swipe past the last workspace to make a new one"
                    path: "gestures.workspace_swipe_create_new"
                }
            }

            StageGap {}

            StageNavRow {
                visible: root.inputOn
                icon: "arrow_selector_tool"
                title: "Cursor"
                subtitle: ServiceHyprConfig.cursorTheme + " · " + ServiceHyprConfig.cursorSize + " px"
                target: "cursor"
            }

            StageNote {
                visible: root.bindsOn
                content: "Shortcut changes go into " + ServiceHyprConfig.prettyPath(ServiceHyprConfig.fileOf("binds"))
                    + ". Your own keybind lines are never rewritten; a changed shortcut is unbound and bound again there."
            }
        }

        StageLazy {
            stageId: "keyboard"

            StagePage {
                stageId: "keyboard"
                title: "Keyboard"

                StageRow {
                    title: "Layouts"
                    subtitle: "The first one is used at login"

                    below: Flow {
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

                StageChoiceRow {
                    visible: root.layoutCodes.length > 1
                    title: "Switch layouts with"
                    options: [
                        { value: "grp:alt_shift_toggle", label: "Alt + Shift" },
                        { value: "grp:win_space_toggle", label: "Super + Space" },
                        { value: "grp:caps_toggle", label: "Caps Lock" }
                    ]
                    current: root.switchGroup
                    onPicked: v => root.setSwitch(v)
                }

                StageGap {}

                HyprSliderRow {
                    title: "Repeat delay"
                    subtitle: "How long to hold a key before it repeats"
                    path: "input.repeat_delay"
                    from: 150; to: 1000; step: 25; unit: " ms"
                }

                HyprSliderRow {
                    title: "Repeat rate"
                    path: "input.repeat_rate"
                    from: 10; to: 80; unit: "/s"
                }

                StageFieldRow {
                    title: "Try it"
                    subtitle: "Hold a key here to test repeat"
                    fieldWidth: 280
                    allowEmpty: true
                    placeholder: "Type here"
                }

                StageGap {}

                HyprToggleRow {
                    title: "Num Lock on at login"
                    path: "input.numlock_by_default"
                }
            }
        }

        StageLazy {
            stageId: "mouse"

            StagePage {
                stageId: "mouse"
                title: "Mouse"

                HyprSliderRow {
                    title: "Pointer speed"
                    path: "input.sensitivity"
                    from: -1; to: 1; step: 0.05; decimals: 2
                }

                HyprChoiceRow {
                    title: "Acceleration"
                    subtitle: "Flat moves the same distance at any speed"
                    path: "input.accel_profile"
                    emptyValue: "adaptive"
                    model: [{ value: "adaptive", label: "Adaptive" }, { value: "flat", label: "Flat" }]
                }

                StageGap {}

                HyprSliderRow {
                    title: "Scroll speed"
                    path: "input.scroll_factor"
                    from: 0.2; to: 2; step: 0.1; decimals: 1; unit: "×"
                }

                HyprToggleRow {
                    title: "Natural scrolling"
                    subtitle: "Content moves with your fingers"
                    path: "input.natural_scroll"
                }

                StageHeading { text: "Focus" }

                HyprChoiceRow {
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
                    title: "After closing a window"
                    subtitle: "Which window gets focus next"
                    path: "input.focus_on_close"
                    model: [
                        { value: 0, label: "Next" },
                        { value: 1, label: "Under pointer" },
                        { value: 2, label: "Last used" }
                    ]
                }
            }
        }

        StageLazy {
            stageId: "touchpad"

            StagePage {
                stageId: "touchpad"
                title: "Touchpad"

                HyprToggleRow {
                    title: "Tap to click"
                    path: "input.touchpad.tap_to_click"
                }

                HyprToggleRow {
                    title: "Natural scrolling"
                    path: "input.touchpad.natural_scroll"
                }

                HyprToggleRow {
                    title: "Ignore while typing"
                    path: "input.touchpad.disable_while_typing"
                }

                StageGap {}

                HyprToggleRow {
                    title: "Click with fingers"
                    subtitle: "Pressing with one, two or three fingers clicks left, right or middle"
                    path: "input.touchpad.clickfinger_behavior"
                }

                HyprChoiceRow {
                    title: "Drag with fingers"
                    subtitle: "Move windows and text by dragging with several fingers"
                    path: "input.touchpad.drag_3fg"
                    model: [{ value: 0, label: "Off" }, { value: 1, label: "3 fingers" }, { value: 2, label: "4 fingers" }]
                }

                HyprSliderRow {
                    title: "Scroll speed"
                    path: "input.touchpad.scroll_factor"
                    from: 0.2; to: 2; step: 0.1; decimals: 1; unit: "×"
                }

                StageHeading { text: "Workspace swipe" }

                HyprToggleRow {
                    title: "Invert workspace swipe"
                    path: "gestures.workspace_swipe_invert"
                }

                HyprToggleRow {
                    title: "Swipe past the last workspace to make a new one"
                    path: "gestures.workspace_swipe_create_new"
                }
            }
        }

        StageLazy {
            stageId: "cursor"

            StagePage {
                stageId: "cursor"
                title: "Cursor"

                StageDropdownRow {
                    title: "Theme"
                    options: ServiceHyprConfig.cursorThemes
                    current: ServiceHyprConfig.cursorTheme
                    dropdownWidth: 220
                    onPicked: name => ServiceHyprConfig.setCursor(name, ServiceHyprConfig.cursorSize)
                }

                StageSpinRow {
                    title: "Size"
                    from: 16
                    to: 96
                    step: 8
                    suffix: " px"
                    current: ServiceHyprConfig.cursorSize
                    onStepped: v => ServiceHyprConfig.setCursor(ServiceHyprConfig.cursorTheme, v)
                }

                StageGap {}

                HyprToggleRow {
                    title: "Hide while typing"
                    path: "cursor.hide_on_key_press"
                }

                HyprSliderRow {
                    title: "Hide when idle"
                    path: "cursor.inactive_timeout"
                    from: 0; to: 20; unit: " s"; zeroLabel: "Never"
                }
            }
        }

        StageLazy {
            stageId: "group"

            StagePage {
                id: groupPage
                stageId: "group"
                title: root.group
                aside: root.fileOf(root.group)

                readonly property var rows: root.entries.filter(e => e.group === root.group)
                property int built: 0

                function feed(step) {
                    const n = Math.min(groupPage.built + step, groupPage.rows.length)
                    for (; groupPage.built < n; groupPage.built++)
                        rowModel.append({ i: groupPage.built })
                }

                onRowsChanged: {
                    if (rowModel.count === groupPage.rows.length)
                        return
                    rowModel.clear()
                    groupPage.built = 0
                    groupPage.feed(8)
                }

                ListModel { id: rowModel }

                Timer {
                    interval: 16
                    repeat: true
                    running: groupPage.built < groupPage.rows.length
                    onTriggered: groupPage.feed(3)
                }

                Repeater {
                    model: rowModel

                    BindRow {
                        required property int i
                        entry: groupPage.rows[i] ?? ({})
                    }
                }
            }
        }

        StagePage {
            stageId: "edit"
            title: editor.isNew ? "New shortcut" : "Change shortcut"

            StageHero {
                tone: "plain"
                icon: editor.isNew ? "terminal" : (editor.entry?.icon ?? "keyboard")
                title: editor.isNew ? "Run a command" : (editor.entry?.name ?? "")
                subtitle: editor.isNew ? "Pick the keys, then the command they run" : (editor.entry?.desc ?? "")
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: recCol.implicitHeight + 36
                radius: 20
                color: Colors.surfaceContainerHigh
                border.width: editor.listening ? 2 : 1
                border.color: editor.listening ? Colors.primary : Colors.outlineVariant

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!editor.listening) editor.startListening()
                }

                ColumnLayout {
                    id: recCol
                    anchors.centerIn: parent
                    spacing: 12

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: Math.max(bigCaps.implicitWidth, placeholderText.implicitWidth)
                        implicitHeight: 48

                        HyprKeyCaps {
                            id: bigCaps
                            anchors.centerIn: parent
                            visible: (editor.listening ? editor.held : editor.recorded) !== ""
                            keyString: editor.listening ? editor.held : editor.recorded
                            capSize: 46
                            capColor: editor.listening ? Colors.surfaceContainerHighest : Colors.primary
                            textColor: editor.listening ? Colors.surfaceText : Colors.primaryText
                        }
                        CustomText {
                            id: placeholderText
                            anchors.centerIn: parent
                            visible: !bigCaps.visible
                            content: editor.listening ? "Press the new keys" : "Click to record"
                            size: 18
                            customColor: Colors.outline
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8
                        Rectangle {
                            visible: editor.listening
                            implicitWidth: 8; implicitHeight: 8; radius: 4
                            color: Colors.primary
                            SequentialAnimation on opacity {
                                running: editor.listening
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 600 }
                                NumberAnimation { to: 1; duration: 600 }
                            }
                        }
                        CustomText {
                            content: editor.listening ? "Listening · Esc stops" : "Click to record again"
                            size: 12
                            customColor: Colors.surfaceVariantText
                        }
                    }

                    RowLayout {
                        visible: !editor.isNew && editor.originalKey !== ""
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        CustomText { content: "Was"; size: 12; customColor: Colors.outline }
                        HyprKeyCaps { keyString: editor.originalKey; capSize: 22 }
                    }
                }
            }

            ColumnLayout {
                visible: editor.isNew
                Layout.fillWidth: true
                spacing: 8

                DialogField { id: commandInput; placeholder: "Command, for example kitty -e btop" }
                DialogField { id: nameInput; placeholder: "Name (optional)" }
            }

            Rectangle {
                visible: !!editor.conflict
                Layout.fillWidth: true
                implicitHeight: conflictCol.implicitHeight + 28
                radius: 20
                color: Colors.errorContainer

                ColumnLayout {
                    id: conflictCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 8

                    RowLayout {
                        spacing: 10
                        MaterialIconSymbol { content: "error"; iconSize: 20; customColor: Colors.errorContainerText }
                        CustomText {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            content: ServiceKeybinds.pretty(editor.recorded) + " already runs " + (editor.conflict?.name ?? "") + " (" + (editor.conflict?.group ?? "") + ")."
                                + (editor.conflictEditable ? " Pick what happens to it." : " That one can only be changed in its file.")
                            size: 14
                            customColor: Colors.errorContainerText
                        }
                    }

                    Repeater {
                        model: editor.conflictEditable
                            ? [
                                { value: "swap", label: editor.originalKey !== "" ? "Swap · " + (editor.conflict?.name ?? "") + " moves to " + ServiceKeybinds.pretty(editor.originalKey) : "Move · " + (editor.conflict?.name ?? "") + " is left without a shortcut" },
                                { value: "replace", label: "Replace · " + (editor.conflict?.name ?? "") + " is left without a shortcut" },
                                { value: "both", label: "Keep both · each press runs both" }
                            ]
                            : [{ value: "both", label: "Keep both · each press runs both" }]

                        Item {
                            id: opt
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: 30
                            implicitHeight: 26

                            RowLayout {
                                anchors.fill: parent
                                spacing: 10

                            Rectangle {
                                implicitWidth: 18; implicitHeight: 18; radius: 9
                                color: "transparent"
                                border.width: 2
                                border.color: Colors.errorContainerText
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: editor.resolution === opt.modelData.value
                                    width: 10; height: 10; radius: 5
                                    color: Colors.errorContainerText
                                }
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: opt.modelData.label
                                size: 13
                                customColor: Colors.errorContainerText
                            }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: editor.resolution = opt.modelData.value
                            }
                        }
                    }
                }
            }

            StageGap {}

            StageSwitchRow {
                title: "Works on the lock screen"
                subtitle: "Fires even while the session is locked"
                checked: editor.locked
                onToggled: on => editor.locked = on
            }

            StageSwitchRow {
                title: "Repeat while held"
                subtitle: "For resize or volume style actions"
                checked: editor.repeating
                onToggled: on => editor.repeating = on
            }

            StageSwitchRow {
                title: "Run on key release"
                subtitle: "Useful for a lone Super tap"
                checked: editor.release
                onToggled: on => editor.release = on
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 8

                M3Button {
                    visible: !editor.isNew && !!editor.entry?.changed && !editor.entry?.addedBind
                    variant: "text"
                    label: "Reset to " + ServiceKeybinds.pretty(editor.entry?.origKey ?? "")
                    onClicked: {
                        ServiceHyprConfig.resetBind(editor.entry)
                        editor.close()
                    }
                }
                Item { Layout.fillWidth: true }
                M3Button { variant: "text"; label: "Cancel"; onClicked: editor.close() }
                M3Button { variant: "filled"; label: "Save"; enabledButton: editor.canSave; onClicked: editor.save() }
            }
        }
    }

    component BindRow: CustomCard {
        id: row
        property var entry: ({})

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                implicitWidth: 36
                implicitHeight: 36
                radius: 18
                color: Colors.surfaceContainerHighest
                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: row.entry.icon ?? "keyboard"
                    iconSize: 19
                    customColor: Colors.primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    spacing: 8
                    CustomText { content: row.entry.name ?? ""; size: 14 }
                    RowLayout {
                        visible: !!row.entry.locked
                        spacing: 3
                        MaterialIconSymbol { content: "lock"; iconSize: 13; customColor: Colors.tertiary }
                        CustomText { content: "on lock screen"; size: 11; customColor: Colors.tertiary }
                    }
                    Rectangle {
                        visible: !!row.entry.changed && !row.entry.unset
                        implicitWidth: chText.implicitWidth + 12
                        implicitHeight: 18
                        radius: 9
                        color: Colors.secondaryContainer
                        CustomText { id: chText; anchors.centerIn: parent; content: "Changed"; size: 10; weight: 600; customColor: Colors.secondaryContainerText }
                    }
                }
                CustomText {
                    visible: (row.entry.desc ?? "") !== ""
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    content: row.entry.desc ?? ""
                    size: 12
                    customColor: Colors.outline
                }
            }

            HyprKeyCaps {
                visible: !row.entry.unset
                keyString: row.entry.key ?? ""
            }

            Rectangle {
                visible: !!row.entry.unset
                implicitWidth: unsetText.implicitWidth + 24
                implicitHeight: 28
                radius: 9
                color: "transparent"
                border.width: 1
                border.color: Colors.outlineVariant
                CustomText { id: unsetText; anchors.centerIn: parent; content: "Not set"; size: 12; customColor: Colors.outline }
            }

            Loader {
                active: !!row.entry.changed && !row.entry.placeholder
                visible: active
                sourceComponent: M3IconButton {
                    implicitWidth: 36; implicitHeight: 36
                    icon: row.entry.addedBind ? "delete" : "undo"
                    iconSize: 18
                    iconColor: Colors.outline
                    onClicked: ServiceHyprConfig.resetBind(row.entry)
                }
            }

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: row.entry.editable && rowHover.hovered ? Colors.surfaceContainerHighest : Qt.alpha(Colors.surfaceContainerHighest, 0)
                Behavior on color { EffectsColorAnim { speed: "fast" } }

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: !row.entry.editable ? "lock_open_right" : row.entry.unset ? "add" : "edit"
                    iconSize: row.entry.editable ? 18 : 16
                    customColor: row.entry.editable ? Colors.surfaceText : Colors.outlineVariant
                }
            }
        }

        HoverHandler {
            id: rowHover
            enabled: !!row.entry.editable
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: !!row.entry.editable
            onTapped: editor.openFor(row.entry)
        }
    }

    component DialogField: Rectangle {
        id: field
        property string placeholder: ""
        property alias text: input.text
        function focusInput() { input.forceActiveFocus() }
        Layout.fillWidth: true
        implicitHeight: 42
        radius: 12
        color: Colors.surfaceContainerLowest
        border.width: input.activeFocus ? 2 : 1
        border.color: input.activeFocus ? Colors.primary : Colors.outlineVariant

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: Colors.surfaceText
            font.family: SettingsConfig.general.defaultFont ?? "Rubik"
            font.pixelSize: 13
            selectByMouse: true
            Keys.onEscapePressed: editor.close()
            Keys.onReturnPressed: editor.save()
        }
        CustomText {
            visible: input.text === ""
            anchors.verticalCenter: parent.verticalCenter
            x: 14
            content: field.placeholder
            size: 13
            customColor: Colors.outline
        }
    }
}
