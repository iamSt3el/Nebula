import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    property string filter: "All"
    readonly property var entries: ServiceKeybinds.entries
    readonly property var groupNames: ServiceKeybinds.groupOrder.filter(g => root.entries.some(e => e.group === g))
    readonly property bool anyChanged: root.entries.some(e => e.changed)

    function count(g) {
        return root.entries.filter(e => (g === "All" || e.group === g) && !e.unset).length
    }

    onVisibleChanged: if (!visible) dialog.close()
    Component.onDestruction: dialog.stopListening()

    Connections {
        target: GlobalStates
        function onSettingsOpenChanged() {
            if (!GlobalStates.settingsOpen) dialog.close()
        }
    }

    function fileOf(g) {
        return g === "Nebula" ? "nebula/keybinds.lua" : "lua/keybinds.lua"
    }

    Flickable {
        id: pageFlick
        ScrollBar.vertical: CustomScrollBar {}
        anchors.fill: parent
        contentHeight: column.implicitHeight
        contentWidth: width
        clip: true
        interactive: !dialog.visible

        ColumnLayout {
            id: column
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            anchors.topMargin: 5
            spacing: 0

            CustomText {
                Layout.topMargin: 6
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                content: "Changes are saved to ~/.config/hypr/nebula/settings.lua; your own keybind files stay as they are."
                size: 12
                customColor: Colors.outline
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 14
                spacing: 8

                Repeater {
                    model: ["All"].concat(root.groupNames)

                    M3Button {
                        required property string modelData
                        variant: "tonal"
                        toggled: root.filter === modelData
                        label: modelData + "  " + root.count(modelData)
                        onClicked: root.filter = modelData
                    }
                }
                Item { Layout.fillWidth: true }
                M3Button {
                    visible: root.anyChanged
                    variant: "text"
                    label: "Reset all"
                    onClicked: ServiceHyprConfig.resetAllBinds()
                }
                M3Button {
                    variant: "tonal"
                    icon: "add"
                    label: "Add shortcut"
                    onClicked: dialog.openFor(null)
                }
            }

            Repeater {
                model: root.groupNames.filter(g => root.filter === "All" || root.filter === g)

                ColumnLayout {
                    id: groupCol
                    required property string modelData
                    readonly property var rows: root.entries.filter(e => e.group === groupCol.modelData)
                    Layout.fillWidth: true
                    spacing: 0

                    RowLayout {
                        Layout.topMargin: 18
                        spacing: 8
                        CustomText { content: groupCol.modelData; size: 13; customColor: Colors.primary }
                        CustomText { content: root.fileOf(groupCol.modelData); size: 11; customColor: Colors.outline; family: "JetBrains Mono" }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        spacing: 3

                        Repeater {
                            model: groupCol.rows

                            BindRow {
                                required property var modelData
                                required property int index
                                entry: modelData
                                autoRadius: false
                                topRadius: index === 0 ? 20 : 5
                                bottomRadius: index === groupCol.rows.length - 1 ? 20 : 5
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 24 }
        }
    }

    ScrollFade {
        anchors.fill: parent
        flickable: pageFlick
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

            M3IconButton {
                visible: !!row.entry.changed && !row.entry.placeholder
                implicitWidth: 36; implicitHeight: 36
                icon: row.entry.addedBind ? "delete" : "undo"
                iconSize: 18
                iconColor: Colors.outline
                onClicked: ServiceHyprConfig.resetBind(row.entry)
            }

            M3IconButton {
                visible: !!row.entry.editable
                implicitWidth: 36; implicitHeight: 36
                icon: row.entry.unset ? "add" : "edit"
                iconSize: 18
                onClicked: dialog.openFor(row.entry)
            }

            MaterialIconSymbol {
                visible: !row.entry.editable
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignHCenter
                content: "lock_open_right"
                iconSize: 16
                customColor: Colors.outlineVariant
            }
        }
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        anchors.margins: -5
        color: Qt.alpha(Colors.shadow, 0.55)
        radius: 20
        visible: dialog.visible
        opacity: dialog.visible ? 1 : 0

        MouseArea {
            anchors.fill: parent
            onClicked: dialog.close()
        }
    }

    Rectangle {
        id: dialog
        visible: false
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 580)
        height: dialogCol.implicitHeight + 48
        radius: 28
        color: Colors.surfaceContainerHigh

        property var entry: null
        property bool isNew: false
        property bool listening: false
        property string recorded: ""
        property string held: ""
        property string resolution: "swap"
        property bool locked: false
        property bool repeating: false
        property bool release: false

        readonly property var conflict: dialog.recorded !== "" ? ServiceKeybinds.owner(dialog.recorded, dialog.entry?.id ?? "") : null
        readonly property bool conflictEditable: !!dialog.conflict?.editable && !dialog.conflict?.placeholder
        readonly property string originalKey: dialog.entry?.key ?? ""
        readonly property bool canSave: dialog.recorded !== "" && !dialog.listening
            && (!dialog.isNew || commandInput.text.trim() !== "")
            && (!dialog.conflict || dialog.resolution === "both" || dialog.conflictEditable)

        function openFor(e) {
            dialog.entry = e
            dialog.isNew = e === null
            dialog.recorded = ""
            dialog.held = ""
            dialog.locked = e?.locked ?? false
            dialog.repeating = e?.repeating ?? false
            dialog.release = e?.release ?? false
            dialog.resolution = "swap"
            commandInput.text = ""
            nameInput.text = ""
            dialog.visible = true
            dialog.startListening()
        }

        function startListening() {
            dialog.listening = true
            dialog.held = ""
            ServiceHyprConfig.beginRecord()
            catcher.forceActiveFocus()
        }

        function stopListening() {
            if (!dialog.listening) return
            dialog.listening = false
            ServiceHyprConfig.endRecord()
        }

        function close() {
            dialog.stopListening()
            dialog.visible = false
        }

        function save() {
            if (!dialog.canSave) return
            const flags = { locked: dialog.locked, repeating: dialog.repeating, release: dialog.release }
            if (dialog.isNew) {
                ServiceHyprConfig.addCommand(dialog.recorded, commandInput.text.trim(), nameInput.text.trim())
            } else {
                const c = dialog.conflict
                if (c && dialog.conflictEditable) {
                    if (dialog.resolution === "swap") ServiceHyprConfig.setBind(c, dialog.originalKey, null)
                    else if (dialog.resolution === "replace") ServiceHyprConfig.setBind(c, "", null)
                }
                ServiceHyprConfig.setBind(dialog.entry, dialog.recorded, flags)
            }
            dialog.close()
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
            return dialog.symbolKeys[e.key] ?? ""
        }

        MouseArea { anchors.fill: parent }

        Item {
            id: catcher
            focus: dialog.visible
            Keys.onPressed: event => {
                event.accepted = true
                const mods = dialog.modsOf(event.modifiers)
                if (!dialog.listening) {
                    if (event.key === Qt.Key_Escape) dialog.close()
                    else if (event.key === Qt.Key_Return && dialog.canSave) dialog.save()
                    return
                }
                if (event.key === Qt.Key_Escape && mods.length === 0) {
                    dialog.stopListening()
                    return
                }
                if (dialog.modifierKeys.indexOf(event.key) >= 0) {
                    dialog.held = mods.join(" + ")
                    return
                }
                const k = dialog.keyName(event)
                if (k === "") return
                dialog.recorded = mods.concat([k]).join(" + ")
                dialog.stopListening()
                if (dialog.isNew) commandInput.focusInput()
            }
            Keys.onReleased: event => {
                if (dialog.listening) dialog.held = dialog.modsOf(event.modifiers).join(" + ")
            }
        }

        ColumnLayout {
            id: dialogCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 16

            RowLayout {
                spacing: 14
                Rectangle {
                    implicitWidth: 44
                    implicitHeight: 44
                    radius: 22
                    color: Colors.secondaryContainer
                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: dialog.isNew ? "terminal" : (dialog.entry?.icon ?? "keyboard")
                        iconSize: 22
                        customColor: Colors.secondaryContainerText
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    CustomText { content: dialog.isNew ? "New shortcut" : "Change shortcut"; size: 22; weight: 600 }
                    CustomText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        content: dialog.isNew ? "Run a command with a key combination" : (dialog.entry?.name ?? "") + (dialog.entry?.desc ? " · " + dialog.entry.desc : "")
                        size: 13
                        customColor: Colors.surfaceVariantText
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: recCol.implicitHeight + 36
                radius: 20
                color: Colors.surface
                border.width: dialog.listening ? 2 : 1
                border.color: dialog.listening ? Colors.primary : Colors.outlineVariant

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!dialog.listening) dialog.startListening()
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
                            visible: (dialog.listening ? dialog.held : dialog.recorded) !== ""
                            keyString: dialog.listening ? dialog.held : dialog.recorded
                            capSize: 46
                            capColor: dialog.listening ? Colors.surfaceContainerHighest : Colors.primary
                            textColor: dialog.listening ? Colors.surfaceText : Colors.primaryText
                        }
                        CustomText {
                            id: placeholderText
                            anchors.centerIn: parent
                            visible: !bigCaps.visible
                            content: dialog.listening ? "Press the new keys" : "Click to record"
                            size: 18
                            customColor: Colors.outline
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8
                        Rectangle {
                            visible: dialog.listening
                            implicitWidth: 8; implicitHeight: 8; radius: 4
                            color: Colors.primary
                            SequentialAnimation on opacity {
                                running: dialog.listening
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 600 }
                                NumberAnimation { to: 1; duration: 600 }
                            }
                        }
                        CustomText {
                            content: dialog.listening ? "Listening · Esc stops" : "Click to record again"
                            size: 12
                            customColor: Colors.surfaceVariantText
                        }
                    }

                    RowLayout {
                        visible: !dialog.isNew && dialog.originalKey !== ""
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        CustomText { content: "Was"; size: 12; customColor: Colors.outline }
                        HyprKeyCaps { keyString: dialog.originalKey; capSize: 22 }
                    }
                }
            }

            ColumnLayout {
                visible: dialog.isNew
                Layout.fillWidth: true
                spacing: 8

                DialogField { id: commandInput; placeholder: "Command, for example kitty -e btop" }
                DialogField { id: nameInput; placeholder: "Name (optional)" }
            }

            Rectangle {
                visible: !!dialog.conflict
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
                            content: ServiceKeybinds.pretty(dialog.recorded) + " already runs " + (dialog.conflict?.name ?? "") + " (" + (dialog.conflict?.group ?? "") + ")."
                                + (dialog.conflictEditable ? " Pick what happens to it." : " That one can only be changed in its file.")
                            size: 14
                            customColor: Colors.errorContainerText
                        }
                    }

                    Repeater {
                        model: dialog.conflictEditable
                            ? [
                                { value: "swap", label: dialog.originalKey !== "" ? "Swap · " + (dialog.conflict?.name ?? "") + " moves to " + ServiceKeybinds.pretty(dialog.originalKey) : "Move · " + (dialog.conflict?.name ?? "") + " is left without a shortcut" },
                                { value: "replace", label: "Replace · " + (dialog.conflict?.name ?? "") + " is left without a shortcut" },
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
                                    visible: dialog.resolution === opt.modelData.value
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
                                onClicked: dialog.resolution = opt.modelData.value
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                DialogSwitch { first: true; title: "Works on the lock screen"; subtitle: "Fires even while the session is locked"; on: dialog.locked; onFlipped: s => dialog.locked = s }
                DialogSwitch { title: "Repeat while held"; subtitle: "For resize or volume style actions"; on: dialog.repeating; onFlipped: s => dialog.repeating = s }
                DialogSwitch { last: true; title: "Run on key release"; subtitle: "Useful for a lone Super tap"; on: dialog.release; onFlipped: s => dialog.release = s }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                M3Button {
                    visible: !dialog.isNew && !!dialog.entry?.changed && !dialog.entry?.addedBind
                    variant: "text"
                    label: "Reset to " + ServiceKeybinds.pretty(dialog.entry?.origKey ?? "")
                    onClicked: {
                        ServiceHyprConfig.resetBind(dialog.entry)
                        dialog.close()
                    }
                }
                Item { Layout.fillWidth: true }
                M3Button { variant: "text"; label: "Cancel"; onClicked: dialog.close() }
                M3Button { variant: "filled"; label: "Save"; enabledButton: dialog.canSave; onClicked: dialog.save() }
            }
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
            Keys.onEscapePressed: dialog.close()
            Keys.onReturnPressed: dialog.save()
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

    component DialogSwitch: Rectangle {
        id: sw
        property bool first: false
        property bool last: false
        property string title: ""
        property string subtitle: ""
        property bool on: false
        signal flipped(bool state)
        Layout.fillWidth: true
        implicitHeight: 58
        topLeftRadius: sw.first ? 16 : 5
        topRightRadius: sw.first ? 16 : 5
        bottomLeftRadius: sw.last ? 16 : 5
        bottomRightRadius: sw.last ? 16 : 5
        color: Colors.surfaceContainerHighest

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                CustomText { content: sw.title; size: 14 }
                CustomText { content: sw.subtitle; size: 12; customColor: Colors.surfaceVariantText }
            }
            Item { Layout.fillWidth: true }
            CustomToogle {
                isToggleOn: sw.on
                onToggled: function(state) { sw.flipped(state) }
            }
        }
    }
}
