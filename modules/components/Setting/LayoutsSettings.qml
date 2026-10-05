import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.platform as P
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    readonly property string cli: Quickshell.shellDir + "/bin/nebula"
    property var layouts: []
    property string dir: ""
    property bool canUndo: false
    property bool loaded: false
    property bool saving: false
    property var pick: ["bar", "widgets", "dashboard", "panels", "lockscreen", "look"]
    property string toast: ""
    property string busyId: ""
    property string armedDelete: ""
    property string active: ""
    readonly property string typedId: root.slug(nameIn.text)
    readonly property var clash: nameIn.text.trim() === "" ? null : (root.layouts.find(l => l.id === root.typedId) ?? null)

    readonly property var sectionMeta: [
        { id: "bar", label: "Bar and dock", icon: "toolbar" },
        { id: "widgets", label: "Widgets", icon: "widgets" },
        { id: "dashboard", label: "Dashboard", icon: "space_dashboard" },
        { id: "panels", label: "Panel styles", icon: "view_carousel" },
        { id: "lockscreen", label: "Lock screen", icon: "lock" },
        { id: "look", label: "Wallpaper", icon: "wallpaper" }
    ]

    function slug(name) {
        const s = name.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
        return s || "layout"
    }

    function iconFor(id) {
        const m = root.sectionMeta.find(s => s.id === id)
        return m ? m.icon : "circle"
    }

    function refresh() {
        listProc.running = false
        listProc.running = true
    }

    function run(args, message) {
        actProc.message = message
        actProc.command = [root.cli, "layout"].concat(args)
        actProc.running = true
    }

    function togglePick(id) {
        const i = root.pick.indexOf(id)
        root.pick = i >= 0 ? root.pick.filter(x => x !== id) : root.pick.concat([id])
    }

    function describe(r) {
        const parts = []
        if (r.barSide !== undefined)
            parts.push(r.barSide.charAt(0).toUpperCase() + r.barSide.slice(1) + " bar · " + r.barItems + " items")
        if (r.widgets !== undefined)
            parts.push(r.widgets + (r.widgets === 1 ? " widget" : " widgets"))
        if (r.dashboardItems !== undefined)
            parts.push(r.dashboardItems + " dashboard cards")
        return parts.join(" · ")
    }

    function cap(s) {
        return s ? s.charAt(0).toUpperCase() + s.slice(1) : ""
    }

    function details(r) {
        const out = []
        const has = id => (r.sections ?? []).indexOf(id) >= 0
        if (has("bar"))
            out.push({ icon: "toolbar", label: "Bar and dock", value: root.cap(r.barSide ?? "top") + " · " + (r.barItems ?? 0) + " items" })
        if (has("widgets"))
            out.push({ icon: "widgets", label: "Widgets", value: (r.widgets ?? 0) + " on the desktop" })
        if (has("dashboard"))
            out.push({ icon: "space_dashboard", label: "Dashboard", value: (r.dashboardItems ?? 0) + ((r.dashboardItems ?? 0) === 1 ? " card" : " cards") })
        if (has("panels")) {
            const bits = []
            if (r.launcherStyle) bits.push(root.cap(r.launcherStyle) + " launcher")
            if (r.clipboardStyle) bits.push(root.cap(r.clipboardStyle) + " clipboard")
            if (r.notifStyle) bits.push(root.cap(r.notifStyle) + " popups")
            out.push({ icon: "view_carousel", label: "Panel styles", value: bits.length ? bits.join(" · ") : "Defaults" })
        }
        if (has("lockscreen"))
            out.push({ icon: "lock", label: "Lock screen", value: root.cap(r.lockLayout ?? "") || "Default" })
        if (has("look")) {
            const wp = (r.wallpaper ?? "").split("/").pop()
            out.push({ icon: "wallpaper", label: "Wallpaper", value: (wp || "None") + (r.mode ? " · " + r.mode : "") })
        }
        return out
    }

    function when(iso) {
        if (!iso)
            return ""
        const d = new Date(iso)
        const now = new Date()
        if (d.toDateString() === now.toDateString())
            return "Today " + Qt.formatTime(d, "hh:mm")
        return Qt.formatDate(d, "d MMM yyyy")
    }

    Component.onCompleted: root.refresh()

    Process {
        id: listProc
        command: [root.cli, "layout", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    root.layouts = d.layouts ?? []
                    root.dir = d.dir ?? ""
                    root.canUndo = !!d.canUndo
                    root.active = d.active ?? ""
                } catch (e) {
                    root.layouts = []
                }
                root.loaded = true
            }
        }
    }

    Process {
        id: actProc
        property string message: ""
        stdout: StdioCollector { id: actOut }
        stderr: StdioCollector { id: actErr }
        onExited: code => {
            root.busyId = ""
            const err = actErr.text.trim().split("\n").pop().replace(/^\[nebula\]\s*/, "")
            root.toast = code === 0 ? actProc.message : (err || "Something went wrong")
            toastTimer.restart()
            root.refresh()
        }
    }

    Timer {
        id: settingsSettled
        interval: 600
        onTriggered: if (!actProc.running) root.refresh()
    }

    Connections {
        target: SettingsConfig
        function onBarChanged() { settingsSettled.restart() }
        function onWidgetsChanged() { settingsSettled.restart() }
        function onDashboardChanged() { settingsSettled.restart() }
        function onLockscreenChanged() { settingsSettled.restart() }
        function onGeneralChanged() { settingsSettled.restart() }
    }

    Timer {
        id: toastTimer
        interval: 4000
        onTriggered: {
            root.toast = ""
            root.armedDelete = ""
        }
    }

    P.FileDialog {
        id: importPicker
        title: "Import a Nebula layout"
        nameFilters: ["Nebula layouts (*.json)"]
        onAccepted: {
            GlobalStates.fileDialogOpen = false
            root.run(["import", importPicker.file.toString().replace(/^file:\/\//, "")], "Layout imported")
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }

    component SectionLabel: CustomText {
        Layout.topMargin: 20
        size: 13
        customColor: Colors.primary
    }

    component Pill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property bool filled: false
        property bool enabledState: true
        signal clicked()
        implicitWidth: pillRow.implicitWidth + (pill.label !== "" ? 28 : 16)
        implicitHeight: 36
        radius: 18
        opacity: pill.enabledState ? 1 : 0.45
        color: pill.filled ? Colors.primary : Colors.surfaceContainerHighest
        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 6
            MaterialIconSymbol { visible: pill.icon !== ""; content: pill.icon; iconSize: 17; customColor: pill.filled ? Colors.primaryText : Colors.surfaceText }
            CustomText { visible: pill.label !== ""; content: pill.label; size: 13; weight: 600; customColor: pill.filled ? Colors.primaryText : Colors.surfaceText }
        }
        RippleEffect {
            anchors.fill: parent
            radius: pill.radius
            enabled: pill.enabledState
            onClicked: pill.clicked()
        }
    }

    Flickable {
        id: flick
        ScrollBar.vertical: CustomScrollBar {}
        anchors.fill: parent
        contentHeight: column.implicitHeight
        contentWidth: width
        clip: true

        ColumnLayout {
            id: column
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors { leftMargin: 5; rightMargin: 5; topMargin: 5 }
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                Pill { icon: "folder_open"; onClicked: Quickshell.execDetached(["xdg-open", root.dir]) }
                Pill {
                    icon: "upload_file"
                    label: "Import"
                    onClicked: {
                        GlobalStates.fileDialogOpen = true
                        importPicker.open()
                    }
                }
                Pill { icon: "add"; label: "Save as new"; filled: true; onClicked: root.saving = !root.saving }
            }

            CustomText {
                Layout.topMargin: 6
                Layout.fillWidth: true
                content: "A layout is a snapshot of how your shell is arranged: the bar, desktop widgets, dashboard, panel styles, lock screen and, if you like, the wallpaper. The one you're using is marked Current; after you change things, press Update on it to keep the changes, or Save as new to keep both. Each layout is a JSON file you can share."
                size: 12
                customColor: Colors.outline
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }

            CustomText {
                Layout.topMargin: 8
                visible: root.toast !== ""
                content: root.toast
                size: 12
                weight: 600
                customColor: Colors.primary
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 14
                visible: root.saving
                Layout.preferredHeight: saveCol.implicitHeight + 32
                radius: 20
                color: Colors.surfaceContainer

                ColumnLayout {
                    id: saveCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 12

                    CustomText { content: "Save what you have now as a new layout"; size: 15; weight: 700 }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: 12
                        color: Colors.surfaceContainerHighest
                        border.width: nameIn.activeFocus ? 2 : 0
                        border.color: Colors.primary
                        TextInput {
                            id: nameIn
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            verticalAlignment: TextInput.AlignVCenter
                            color: Colors.surfaceText
                            font.pixelSize: 14
                            font.family: "Rubik"
                            clip: true
                            onAccepted: saveButton.clicked()
                            CustomText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: nameIn.text === "" && !nameIn.activeFocus
                                content: "Name, e.g. Work, Gaming, Minimal"
                                size: 14
                                customColor: Colors.outline
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.clash !== null
                        spacing: 8
                        MaterialIconSymbol { content: "warning"; iconSize: 16; customColor: Colors.error }
                        CustomText {
                            Layout.fillWidth: true
                            content: "“" + (root.clash?.name ?? "") + "” already exists. Saving replaces it."
                            size: 12
                            weight: 600
                            customColor: Colors.error
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: root.sectionMeta
                            Rectangle {
                                id: chip
                                required property var modelData
                                readonly property bool on: root.pick.indexOf(chip.modelData.id) >= 0
                                width: chipRow.implicitWidth + 24
                                height: 34
                                radius: 10
                                color: chip.on ? Colors.secondaryContainer : "transparent"
                                border.width: chip.on ? 0 : 1
                                border.color: Colors.outlineVariant
                                RowLayout {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    MaterialIconSymbol { content: chip.on ? "check" : chip.modelData.icon; iconSize: 16; customColor: chip.on ? Colors.secondaryContainerText : Colors.surfaceVariantText }
                                    CustomText { content: chip.modelData.label; size: 12; weight: 600; customColor: chip.on ? Colors.secondaryContainerText : Colors.surfaceVariantText }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.togglePick(chip.modelData.id)
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Item { Layout.fillWidth: true }
                        Pill { label: "Cancel"; onClicked: root.saving = false }
                        Pill {
                            id: saveButton
                            icon: root.clash ? "sync_alt" : "save"
                            label: root.clash ? "Replace" : "Save"
                            filled: true
                            enabledState: nameIn.text.trim() !== "" && root.pick.length > 0
                            onClicked: {
                                if (nameIn.text.trim() === "" || root.pick.length === 0)
                                    return
                                root.run(["save", nameIn.text.trim(), "--only", root.pick.join(",")],
                                         (root.clash ? "Replaced “" : "Saved “") + nameIn.text.trim() + "”")
                                nameIn.text = ""
                                root.saving = false
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 14
                visible: root.canUndo
                implicitHeight: 56
                radius: 18
                color: Colors.secondaryContainer
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 10
                    spacing: 10
                    MaterialIconSymbol { content: "history"; iconSize: 20; customColor: Colors.secondaryContainerText }
                    CustomText { Layout.fillWidth: true; content: "Your previous layout was kept when you loaded one."; size: 13; customColor: Colors.secondaryContainerText }
                    Pill { icon: "undo"; label: "Undo"; filled: true; onClicked: root.run(["undo"], "Previous layout restored") }
                }
            }

            SectionLabel { content: "Saved layouts" }

            CustomCard {
                id: emptyCard
                visible: root.loaded && root.layouts.length === 0
                Layout.topMargin: 6
                autoRadius: false; topRadius: 20; bottomRadius: 20
                Item {
                    Layout.fillWidth: true
                    implicitHeight: emptyCol.implicitHeight + 32
                    Column {
                        id: emptyCol
                        x: Math.round((emptyCard.width - 28 - width) / 2)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        MaterialIconSymbol { anchors.horizontalCenter: parent.horizontalCenter; content: "dashboard_customize"; iconSize: 34; customColor: Colors.outline }
                        CustomText { anchors.horizontalCenter: parent.horizontalCenter; content: "No layouts yet"; size: 15 }
                        CustomText { anchors.horizontalCenter: parent.horizontalCenter; content: "Save the one you have now, then experiment freely"; size: 12; customColor: Colors.outline }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 12

                Repeater {
                    model: root.layouts

                    Rectangle {
                        id: card
                        required property var modelData
                        readonly property bool busy: root.busyId === card.modelData.id
                        readonly property var rows: root.details(card.modelData)
                        readonly property bool current: !!card.modelData.current
                        readonly property bool modified: card.current && !!card.modelData.modified
                        Layout.fillWidth: true
                        implicitHeight: cardCol.implicitHeight + 32
                        radius: 22
                        color: Colors.surfaceContainerHigh
                        border.width: card.current ? 2 : 0
                        border.color: Colors.primary

                        ColumnLayout {
                            id: cardCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 16
                            spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Rectangle {
                                    Layout.preferredWidth: 44
                                    Layout.preferredHeight: 44
                                    radius: 14
                                    color: Colors.primaryContainer
                                    MaterialIconSymbol {
                                        anchors.centerIn: parent
                                        content: "dashboard_customize"
                                        iconSize: 22
                                        customColor: Colors.primaryContainerText
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        CustomText { content: card.modelData.name; size: 16; weight: 700 }
                                        Rectangle {
                                            visible: card.current
                                            implicitWidth: currentTag.implicitWidth + 16
                                            implicitHeight: 22
                                            radius: 11
                                            color: Colors.primary
                                            CustomText {
                                                id: currentTag
                                                anchors.centerIn: parent
                                                content: "Current"
                                                size: 11
                                                weight: 700
                                                customColor: Colors.primaryText
                                            }
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    CustomText {
                                        Layout.fillWidth: true
                                        content: card.modified ? "Edited since you saved it · " + root.when(card.modelData.saved)
                                                               : "Saved " + root.when(card.modelData.saved)
                                        size: 12
                                        weight: card.modified ? 600 : 400
                                        customColor: card.modified ? Colors.tertiary : Colors.outline
                                    }
                                }

                                M3IconButton {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    icon: "ios_share"
                                    iconSize: 17
                                    onClicked: root.run(["export", card.modelData.id, Quickshell.env("HOME") + "/Downloads"], "Copied to Downloads")
                                }
                                M3IconButton {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    icon: root.armedDelete === card.modelData.id ? "delete_forever" : "delete"
                                    iconSize: 17
                                    onClicked: {
                                        if (root.armedDelete !== card.modelData.id) {
                                            root.armedDelete = card.modelData.id
                                            root.toast = "Click delete again to remove “" + card.modelData.name + "”"
                                            toastTimer.restart()
                                            return
                                        }
                                        root.armedDelete = ""
                                        root.run(["delete", card.modelData.id], "Deleted “" + card.modelData.name + "”")
                                    }
                                }
                                Pill {
                                    visible: !card.current || card.modified
                                    icon: card.busy ? "hourglass_top" : card.modified ? "undo" : "check"
                                    label: card.modified ? "Revert" : "Apply"
                                    filled: !card.current
                                    onClicked: {
                                        root.busyId = card.modelData.id
                                        root.run(["load", card.modelData.id],
                                                 (card.modified ? "Reverted to “" : "Applied “") + card.modelData.name + "”")
                                    }
                                }
                                Pill {
                                    visible: card.modified
                                    icon: "save"
                                    label: "Update"
                                    filled: true
                                    onClicked: {
                                        root.busyId = card.modelData.id
                                        root.run(["update", card.modelData.id], "Updated “" + card.modelData.name + "”")
                                    }
                                }
                                Pill {
                                    visible: card.current && !card.modified
                                    icon: "check"
                                    label: "In use"
                                    enabledState: false
                                }
                            }

                            GridLayout {
                                id: detailGrid
                                Layout.fillWidth: true
                                visible: card.rows.length > 0
                                columns: Math.max(1, Math.min(3, Math.floor(detailGrid.width / 220)))
                                columnSpacing: 8
                                rowSpacing: 8

                                Repeater {
                                    model: card.rows

                                    Rectangle {
                                        id: tile
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        implicitHeight: 58
                                        radius: 14
                                        color: Colors.surfaceContainerHighest

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 10
                                            MaterialIconSymbol { content: tile.modelData.icon; iconSize: 20; customColor: Colors.primary }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                CustomText { Layout.fillWidth: true; content: tile.modelData.label; size: 11; customColor: Colors.outline }
                                                CustomText { Layout.fillWidth: true; content: tile.modelData.value; size: 13; weight: 600; elide: Text.ElideRight }
                                            }
                                        }
                                    }
                                }
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
        flickable: flick
    }
}
