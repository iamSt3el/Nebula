import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Scope {
    id: root

    property bool open: false
    property point at: Qt.point(0, 0)
    property var targetScreen: null

    readonly property var terminals: ["kitty", "alacritty", "foot", "footclient", "wezterm", "org.wezfurlong.wezterm",
        "com.mitchellh.ghostty", "ghostty", "konsole", "org.kde.konsole", "xterm", "st", "tilix", "gnome-terminal-server"]

    function toggle() {
        if (root.open) root.open = false
        else if (!cursorProc.running) cursorProc.running = true
    }

    function shq(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function paste(entry, typeIt) {
        if (!entry) return
        root.open = false
        const e = root.shq(entry)
        const typed = typeIt && !ServiceCliphist.entryIsImage(entry)
        const script = typed
            ? "sleep 0.18; printf '%s' " + e + " | cliphist decode | wtype -k Shift_L -"
            : "sleep 0.15; printf '%s' " + e + " | cliphist decode | wl-copy; sleep 0.12; "
              + "cls=$(hyprctl -j activewindow | jq -r '.class // \"\"' | tr 'A-Z' 'a-z'); "
              + "case \" " + root.terminals.join(" ") + " \" in *\" $cls \"*) wtype -k Shift_L -M ctrl -M shift -k v -m shift -m ctrl ;; "
              + "*) wtype -k Shift_L -M ctrl -k v -m ctrl ;; esac"
        Quickshell.execDetached(["sh", "-c", script])
    }

    Process {
        id: cursorProc
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector { id: cursorOut }
        onExited: {
            let p = { x: 0, y: 0 }
            try { p = JSON.parse(cursorOut.text) } catch (err) {}
            const scr = Quickshell.screens.find(s => p.x >= s.x && p.x < s.x + s.width && p.y >= s.y && p.y < s.y + s.height)
                ?? Quickshell.screens[0]
            root.targetScreen = scr
            root.at = Qt.point(p.x - scr.x, p.y - scr.y)
            ServiceCliphist.updateSearch("")
            root.open = true
        }
    }

    GlobalShortcut {
        name: "clipboardPocket"
        onPressed: root.toggle()
    }

    IpcHandler {
        target: "clipboardPocket"
        function toggle(): void { root.toggle() }
        function close(): void { root.open = false }
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win
            screen: root.targetScreen
            anchors.left: true
            anchors.right: true
            anchors.top: true
            anchors.bottom: true
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:clipPocket"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            property int activeIndex: 0
            readonly property var shiftedDigits: [Qt.Key_Exclam, Qt.Key_At, Qt.Key_NumberSign, Qt.Key_Dollar, Qt.Key_Percent,
                Qt.Key_AsciiCircum, Qt.Key_Ampersand, Qt.Key_Asterisk, Qt.Key_ParenLeft]
            readonly property var rows: ServiceCliphist.filteredEntries.slice(0, 9)
            readonly property bool below: root.at.y + card.height + 12 < win.height

            function kindIcon(e) {
                const k = ServiceCliphist.entryKind(e)
                return k === "image" ? "image" : k === "link" ? "link" : "notes"
            }

            function move(d) {
                if (win.rows.length === 0) return
                win.activeIndex = (win.activeIndex + d + win.rows.length) % win.rows.length
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.open = false
            }

            Rectangle {
                id: card
                x: Math.max(12, Math.min(win.width - card.width - 12, root.at.x + 6))
                y: win.below ? root.at.y + 10 : Math.max(12, root.at.y - card.height - 10)
                width: 380
                height: col.implicitHeight + 20
                radius: 24
                color: Colors.surfaceContainer
                border.width: 1
                border.color: Qt.alpha(Colors.outlineVariant, 0.6)
                transformOrigin: win.below ? Item.TopLeft : Item.BottomLeft

                property real t: 0
                opacity: Math.min(1, card.t * 2)
                scale: 0.88 + 0.12 * card.t
                NumberAnimation on t {
                    from: 0
                    to: 1
                    duration: M3Motion.spatialDuration("fast")
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
                }

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: col
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 2

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        Layout.bottomMargin: 6
                        radius: 21
                        color: Colors.surfaceContainerHighest

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 8

                            MaterialIconSymbol {
                                content: "content_paste"
                                iconSize: 18
                                customColor: Colors.primary
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                CustomText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: search.text.length === 0
                                    content: "Paste… or type to search"
                                    size: 13
                                    customColor: Colors.outline
                                }

                                TextInput {
                                    id: search
                                    anchors.fill: parent
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    focus: true
                                    font.pixelSize: 13
                                    font.weight: 600
                                    font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                                    color: Colors.surfaceText
                                    Component.onCompleted: search.forceActiveFocus()
                                    onTextChanged: {
                                        ServiceCliphist.updateSearch(text)
                                        win.activeIndex = 0
                                    }
                                    Keys.onPressed: event => {
                                        const k = event.key
                                        const shift = (event.modifiers & Qt.ShiftModifier) !== 0
                                        if (k === Qt.Key_Escape) {
                                            if (search.text !== "") search.text = ""
                                            else root.open = false
                                            event.accepted = true
                                        } else if (k === Qt.Key_Down || k === Qt.Key_Tab) {
                                            win.move(1); event.accepted = true
                                        } else if (k === Qt.Key_Up || k === Qt.Key_Backtab) {
                                            win.move(-1); event.accepted = true
                                        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                                            root.paste(win.rows[win.activeIndex], shift); event.accepted = true
                                        } else if (search.text === "" && k >= Qt.Key_1 && k <= Qt.Key_9) {
                                            const i = k - Qt.Key_1
                                            if (i < win.rows.length) root.paste(win.rows[i], shift)
                                            event.accepted = true
                                        } else if (search.text === "" && win.shiftedDigits.indexOf(k) >= 0) {
                                            const i = win.shiftedDigits.indexOf(k)
                                            if (i < win.rows.length) root.paste(win.rows[i], true)
                                            event.accepted = true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: win.rows
                        delegate: Rectangle {
                            id: prow
                            required property var modelData
                            required property int index
                            readonly property bool active: prow.index === win.activeIndex
                            readonly property var info: ServiceCliphist.entryIsImage(prow.modelData) ? ServiceCliphist.imageInfo(prow.modelData) : null

                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: 12
                            color: prow.active ? Colors.primaryContainer : Qt.alpha(Colors.primaryContainer, 0)
                            Behavior on color { EffectsColorAnim { speed: "fast" } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 10
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    radius: 7
                                    color: prow.active ? Colors.primary : Colors.surfaceContainerHighest
                                    CustomText {
                                        anchors.centerIn: parent
                                        content: prow.index + 1
                                        size: 11
                                        weight: 700
                                        customColor: prow.active ? Colors.primaryText : Colors.surfaceVariantText
                                    }
                                }
                                MaterialIconSymbol {
                                    content: win.kindIcon(prow.modelData)
                                    iconSize: 17
                                    customColor: prow.active ? Colors.primaryContainerText : Colors.outline
                                }
                                CustomText {
                                    Layout.fillWidth: true
                                    content: prow.info ? "Image  " + prow.info.width + " × " + prow.info.height
                                        : ServiceCliphist.getEntryText(prow.modelData).replace(/\s+/g, " ")
                                    size: 13
                                    elide: Text.ElideRight
                                    customColor: prow.active ? Colors.primaryContainerText : Colors.surfaceText
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: win.activeIndex = prow.index
                                onClicked: mouse => root.paste(prow.modelData, (mouse.modifiers & Qt.ShiftModifier) !== 0)
                            }
                        }
                    }

                    CustomText {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        visible: win.rows.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        content: ServiceCliphist.entries.length === 0 ? "Nothing copied yet" : "No matches"
                        size: 13
                        customColor: Colors.outline
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Layout.leftMargin: 6
                        Layout.rightMargin: 6
                        spacing: 6

                        LauncherKeyHint { keys: "1–9"; label: "paste here" }
                        Item { Layout.fillWidth: true }
                        LauncherKeyHint { keys: "⇧"; label: "type it out" }
                    }
                }
            }
        }
    }

    component LauncherKeyHint: Row {
        property string keys: ""
        property string label: ""
        spacing: 6
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: keyText.implicitWidth + 12
            height: 20
            radius: 6
            color: Colors.surfaceContainerHighest
            CustomText {
                id: keyText
                anchors.centerIn: parent
                content: parent.parent.keys
                size: 11
                weight: 600
                customColor: Colors.surfaceVariantText
            }
        }
        CustomText {
            anchors.verticalCenter: parent.verticalCenter
            content: parent.label
            size: 11
            customColor: Colors.outline
        }
    }
}
