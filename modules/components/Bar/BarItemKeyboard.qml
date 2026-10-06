import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.modules.utils
import qs.modules.customComponents

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: root.showLayout || root.capsOn

    readonly property bool showLayout: BarLayout.opt(root.itemId, "layout") !== false
    readonly property bool showCaps: BarLayout.opt(root.itemId, "caps") !== false

    property string keymap: ""
    property bool capsOn: false
    property var ledPaths: []

    readonly property string code: {
        const k = root.keymap
        if (k === "")
            return "—"
        const m = k.match(/\(([^)]{1,3})\)/)
        if (m)
            return m[1].toUpperCase()
        return k.slice(0, 2).toUpperCase()
    }

    implicitWidth: row.implicitWidth
    implicitHeight: 26

    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards ?? []
                    const main = kbs.find(k => k.main) ?? kbs[0]
                    if (main)
                        root.keymap = main.active_keymap ?? ""
                } catch (e) {}
            }
        }
    }

    Process {
        running: root.showCaps
        command: ["sh", "-c", "for f in /sys/class/leds/*::capslock; do echo \"$f/brightness\"; done"]
        stdout: StdioCollector {
            onStreamFinished: root.ledPaths = text.split("\n").filter(p => p.indexOf("*") < 0 && p.length > 0)
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return
            const k = event.data.indexOf(",")
            if (k >= 0)
                root.keymap = event.data.slice(k + 1)
        }
    }

    Instantiator {
        id: leds
        model: root.showCaps ? root.ledPaths : []
        delegate: FileView {
            required property string modelData
            path: modelData
            blockLoading: true
        }
    }

    Timer {
        interval: 400
        repeat: true
        running: root.showCaps && root.ledPaths.length > 0
        onTriggered: {
            let on = false
            for (let i = 0; i < leds.count; i++) {
                const f = leds.objectAt(i)
                if (!f)
                    continue
                f.reload()
                if (f.text().trim() !== "0")
                    on = true
            }
            if (on !== root.capsOn)
                root.capsOn = on
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showCaps && root.capsOn
            width: capsRow.implicitWidth + 10
            height: 26
            radius: 13
            color: Colors.primary

            Row {
                id: capsRow
                anchors.centerIn: parent
                spacing: 3
                MaterialIconSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "keyboard_capslock"
                    iconSize: 16
                    customColor: Colors.primaryText
                }
                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "CAPS"
                    size: 11
                    weight: 700
                    customColor: Colors.primaryText
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showLayout
            width: layoutRow.implicitWidth + 10
            height: 26
            radius: 13
            color: hov.containsMouse ? Colors.primaryContainer : Colors.surfaceContainer
            Behavior on color { EffectsColorAnim {} }

            Row {
                id: layoutRow
                anchors.centerIn: parent
                spacing: 5
                MaterialIconSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "keyboard"
                    iconSize: 16
                    customColor: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceVariantText
                }
                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: root.code
                    size: 12
                    weight: 700
                    customColor: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                }
            }

            MouseArea {
                id: hov
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: switcher.running = true
            }

            CustomToolTip {
                content: (root.keymap !== "" ? root.keymap : "Keyboard layout") + " · click to switch"
                visible: hov.containsMouse
            }
        }
    }

    Process {
        id: switcher
        command: ["hyprctl", "switchxkblayout", "all", "next"]
    }
}
