import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    signal closed()

    implicitHeight: col.implicitHeight + 28

    property var target: Hyprland.activeToplevel

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            if (Hyprland.activeToplevel)
                root.target = Hyprland.activeToplevel
        }
    }

    readonly property var ipc: root.target ? (root.target.lastIpcObject ?? {}) : ({})
    readonly property string address: {
        const a = root.target ? (root.target.address ?? "") : ""
        return a === "" ? "" : a.startsWith("0x") ? a : "0x" + a
    }
    readonly property string appClass: root.ipc["class"] ?? root.target?.wayland?.appId ?? ""
    readonly property string title: root.target ? (root.target.title ?? "") : ""
    readonly property int wsId: root.target?.workspace?.id ?? root.ipc.workspace?.id ?? 0
    readonly property bool floating: root.ipc.floating === true
    readonly property bool pinned: root.ipc.pinned === true
    readonly property bool fullscreen: (root.ipc.fullscreen ?? 0) > 0
    readonly property string iconSrc: root.appClass !== "" && ServiceApps.list.length >= 0
        ? IconUtil.themeIcon(DesktopEntries.heuristicLookup(root.appClass)?.icon ?? "", true) : ""

    readonly property var wsModel: {
        let n = Math.max(5, root.wsId)
        for (const w of Hyprland.workspaces.values) {
            if (w.id > 0 && w.id <= 10)
                n = Math.max(n, w.id)
        }
        n = Math.min(n, 9)
        const out = []
        for (let i = 1; i <= n; i++)
            out.push({ value: i, label: String(i) })
        out.push({ value: n + 1, icon: "add" })
        return out
    }

    readonly property var siblings: {
        if (!root.target || root.appClass === "")
            return []
        return Hyprland.toplevels.values.filter(t => t !== root.target
            && (t.lastIpcObject?.["class"] ?? t.wayland?.appId ?? "") === root.appClass).slice(0, 4)
    }

    function sel(a) {
        return `window = "address:${a}"`
    }

    function refreshSoon() {
        refresh.restart()
    }

    function act(v) {
        if (root.address === "")
            return
        const w = root.sel(root.address)
        if (v === "float") {
            Hyprland.dispatch(`hl.dsp.window.float({ ${w}, action = "toggle" })`)
        } else if (v === "fullscreen") {
            Hyprland.dispatch(`hl.dsp.window.fullscreen({ ${w}, action = "toggle" })`)
        } else if (v === "pin") {
            if (!root.floating && !root.pinned)
                Hyprland.dispatch(`hl.dsp.window.float({ ${w}, action = "set" })`)
            Hyprland.dispatch(`hl.dsp.window.pin({ ${w}, action = "toggle" })`)
        } else if (v === "copy") {
            Quickshell.clipboardText = root.title
            copied.restart()
        }
        root.refreshSoon()
    }

    function moveTo(ws) {
        if (root.address === "" || ws === root.wsId)
            return
        Hyprland.dispatch(`hl.dsp.window.move({ ${root.sel(root.address)}, workspace = ${ws}, follow = false })`)
        root.refreshSoon()
    }

    function closeWindow() {
        if (root.address === "")
            return
        Hyprland.dispatch(`hl.dsp.window.close({ ${root.sel(root.address)} })`)
        root.closed()
    }

    function focusWindow(t) {
        const a = t.address.startsWith("0x") ? t.address : "0x" + t.address
        Hyprland.dispatch(`hl.dsp.focus({ ${root.sel(a)} })`)
        root.closed()
    }

    Timer {
        id: refresh
        interval: 160
        onTriggered: Hyprland.refreshToplevels()
    }

    Timer {
        id: copied
        interval: 1400
    }

    onVisibleChanged: if (root.visible) Hyprland.refreshToplevels()
    Component.onCompleted: Hyprland.refreshToplevels()

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 12

        ColumnLayout {
            visible: !root.target
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 18
            Layout.bottomMargin: 18
            spacing: 8

            MaterialIconSymbol {
                Layout.alignment: Qt.AlignHCenter
                content: "desktop_windows"
                iconSize: 28
                customColor: Colors.outline
            }
            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: "No window focused"
                size: 13
                weight: 600
                customColor: Colors.outline
            }
        }

        RowLayout {
            visible: !!root.target
            Layout.fillWidth: true
            spacing: 8

            HeroTag { key: "app"; item: winIcon; target: true }

            IconImage {
                id: winIcon
                visible: root.iconSrc !== ""
                implicitSize: 20
                source: root.iconSrc
            }
            CustomText {
                Layout.fillWidth: true
                content: root.appClass + (root.wsId > 0 ? "  ·  Workspace " + root.wsId : "")
                    + (root.floating ? "  ·  Floating" : "")
                size: 12
                weight: 600
                customColor: Colors.outline
                elide: Text.ElideRight
            }
        }

        CustomText {
            visible: !!root.target
            Layout.fillWidth: true
            content: root.title
            size: 16
            weight: 600
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        RowLayout {
            visible: !!root.target
            Layout.fillWidth: true
            spacing: 8

            M3ButtonGroup {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                fillWidth: true
                iconSize: 20
                inactiveColor: Colors.surfaceContainerHigh
                model: [
                    { value: "float", icon: "picture_in_picture" },
                    { value: "fullscreen", icon: root.fullscreen ? "fullscreen_exit" : "fullscreen" },
                    { value: "pin", icon: "keep" },
                    { value: "copy", icon: copied.running ? "check" : "content_copy" }
                ]
                activeCheck: v => (v === "float" && root.floating) || (v === "fullscreen" && root.fullscreen)
                    || (v === "pin" && root.pinned) || (v === "copy" && copied.running)
                onSegmentClicked: v => root.act(v)
            }

            M3IconButton {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46
                icon: "close"
                color: Colors.errorContainer
                iconColor: Colors.errorContainerText
                iconHoverColor: Colors.errorContainerText
                onClicked: root.closeWindow()
            }
        }

        Rectangle {
            visible: !!root.target
            Layout.fillWidth: true
            Layout.preferredHeight: wsCol.implicitHeight + 24
            radius: 18
            color: Colors.surfaceContainer

            ColumnLayout {
                id: wsCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 10

                CustomText {
                    content: "Move to workspace"
                    size: 12
                    weight: 600
                    customColor: Colors.surfaceVariantText
                }

                M3ButtonGroup {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    fillWidth: true
                    textSize: 13
                    iconSize: 18
                    inactiveColor: Colors.surfaceContainerHigh
                    model: root.wsModel
                    activeCheck: v => v === root.wsId
                    onSegmentClicked: v => root.moveTo(v)
                }
            }
        }

        ColumnLayout {
            visible: root.siblings.length > 0
            Layout.fillWidth: true
            spacing: 4

            CustomText {
                Layout.leftMargin: 2
                Layout.bottomMargin: 2
                content: "Other " + root.appClass + " windows"
                size: 12
                weight: 600
                customColor: Colors.outline
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Repeater {
                model: root.siblings

                delegate: Rectangle {
                    id: sib
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 12
                    color: sibMa.containsMouse ? Colors.secondaryContainer : Colors.surfaceContainerLow
                    Behavior on color { EffectsColorAnim { speed: "fast" } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 10

                        CustomText {
                            Layout.fillWidth: true
                            content: sib.modelData.title ?? ""
                            size: 12
                            weight: 500
                            customColor: sibMa.containsMouse ? Colors.secondaryContainerText : Colors.surfaceText
                            elide: Text.ElideRight
                        }
                        CustomText {
                            content: "ws " + (sib.modelData.workspace?.id ?? "")
                            size: 11
                            customColor: sibMa.containsMouse ? Colors.secondaryContainerText : Colors.outline
                        }
                    }

                    MouseArea {
                        id: sibMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.focusWindow(sib.modelData)
                    }
                }
            }
        }
    }
}
