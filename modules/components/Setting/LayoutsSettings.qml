import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt.labs.platform as P
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    readonly property string cli: Quickshell.shellDir + "/bin/nebula"
    property var layouts: []
    property string dir: ""
    property bool canUndo: false
    property bool loaded: false
    property var pick: ["bar", "widgets", "panels", "lockscreen"]
    property string toast: ""
    property string busyId: ""
    property string armedDelete: ""
    property string selectedId: ""
    readonly property var current: root.layouts.find(l => !!l.current) ?? null
    readonly property var selected: root.layouts.find(l => l.id === root.selectedId) ?? null
    readonly property string typedName: nameField.typed.trim()
    readonly property var clash: root.typedName === "" ? null : (root.layouts.find(l => l.id === root.slug(root.typedName)) ?? null)
    readonly property var sectionMeta: [
        { id: "bar", label: "Bar and dock", icon: "toolbar", hint: "Edges, blocks, items and the dock" },
        { id: "widgets", label: "Widgets", icon: "widgets", hint: "Which widgets and where" },
        { id: "panels", label: "Panel styles", icon: "view_carousel", hint: "Launcher, clipboard, popups" },
        { id: "lockscreen", label: "Lock screen", icon: "lock", hint: "Layout and clock" }
    ]

    function slug(name) {
        const s = name.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
        return s || "layout"
    }

    property bool refreshPending: false

    function refresh() {
        if (ServiceLayouts.busy || ServiceLayouts.moving) {
            root.refreshPending = true
            return
        }
        root.refreshPending = false
        listProc.running = false
        listProc.running = true
    }

    function setMotion(on) {
        SettingsConfig.general = Object.assign({}, SettingsConfig.general, { layoutMotion: on })
    }

    function say(message) {
        root.toast = message
        toastTimer.restart()
    }

    function run(args, message) {
        actProc.message = message
        actProc.command = [root.cli, "layout"].concat(args)
        actProc.running = true
    }

    function runLayout(args, message) {
        const page = root
        const ok = ServiceLayouts.run(args, (code, out, err) => {
            try {
                page.busyId = ""
                const e = err.trim().split("\n").pop().replace(/^\[nebula\]\s*/, "")
                page.say(code === 0 ? message : (e || "Something went wrong"))
                page.refresh()
            } catch (x) {}
        })
        if (!ok)
            root.busyId = ""
    }

    function apply(l) {
        const modified = !!l.current && !!l.modified
        root.busyId = l.id
        root.runLayout(["load", l.id], (modified ? "Reverted to “" : "Applied “") + l.name + "”")
    }

    function update(l) {
        root.busyId = l.id
        root.run(["update", l.id], "Updated “" + l.name + "”")
    }

    function togglePick(id) {
        const i = root.pick.indexOf(id)
        root.pick = i >= 0 ? root.pick.filter(x => x !== id) : root.pick.concat([id])
    }

    function cap(s) {
        return s ? s.charAt(0).toUpperCase() + s.slice(1) : ""
    }

    function details(r) {
        if (!r)
            return []
        const out = []
        const has = id => (r.sections ?? []).indexOf(id) >= 0
        if (has("bar"))
            out.push({ icon: "toolbar", label: "Bar edges", value: root.cap(r.barSide ?? "top") + " · " + (r.barItems ?? 0) + " items" })
        if (has("widgets"))
            out.push({ icon: "widgets", label: "Widgets", value: (r.widgets ?? 0) + " on the desktop" })
        if (has("panels")) {
            const bits = []
            if (r.launcherStyle) bits.push(root.cap(r.launcherStyle) + " launcher")
            if (r.clipboardStyle) bits.push(root.cap(r.clipboardStyle) + " clipboard")
            if (r.notifStyle) bits.push(root.cap(r.notifStyle) + " popups")
            out.push({ icon: "view_carousel", label: "Panel styles", value: bits.length ? bits.join(" · ") : "Defaults" })
        }
        if (has("lockscreen"))
            out.push({ icon: "lock", label: "Lock screen", value: root.cap(r.lockLayout ?? "") || "Default" })
        return out
    }

    function when(iso) {
        if (!iso)
            return ""
        const d = new Date(iso)
        if (d.toDateString() === new Date().toDateString())
            return "today " + Qt.formatTime(d, "hh:mm")
        return Qt.formatDate(d, "d MMM yyyy")
    }

    function status(l) {
        if (!l)
            return ""
        if (l.current && l.modified)
            return "In use · edited since you saved it " + root.when(l.saved)
        return (l.current ? "In use · saved " : "Saved ") + root.when(l.saved)
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
        stdout: StdioCollector {}
        stderr: StdioCollector { id: actErr }
        onExited: code => {
            root.busyId = ""
            const err = actErr.text.trim().split("\n").pop().replace(/^\[nebula\]\s*/, "")
            root.say(code === 0 ? actProc.message : (err || "Something went wrong"))
            root.refresh()
        }
    }

    Timer {
        id: settingsSettled
        interval: 600
        onTriggered: if (!actProc.running) root.refresh()
    }

    Connections {
        target: ServiceLayouts
        function onBusyChanged() { if (!ServiceLayouts.busy && !ServiceLayouts.moving && root.refreshPending) root.refresh() }
        function onMovingChanged() { if (!ServiceLayouts.busy && !ServiceLayouts.moving && root.refreshPending) root.refresh() }
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

    component Toast: CustomText {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.bottomMargin: 6
        visible: root.toast !== ""
        content: root.toast
        size: 12
        weight: 600
        wrapMode: Text.WordWrap
        customColor: Colors.primary
    }

    StageView {
        id: stages

        StagePage {
            stageId: "front"

            Toast {}

            StageHero {
                tone: root.current ? "primary" : "plain"
                icon: "dashboard_customize"
                title: root.current ? root.current.name : "No saved layout in use"
                subtitle: root.current ? root.status(root.current) : "Save what you have now to come back to it any time"

                M3Button {
                    visible: !!root.current && !!root.current.modified
                    icon: "save"
                    label: "Update"
                    onClicked: root.update(root.current)
                }

                M3Button {
                    visible: !!root.current && !!root.current.modified
                    variant: "tonal"
                    icon: "undo"
                    label: "Revert"
                    onClicked: root.apply(root.current)
                }

                M3Button {
                    visible: !root.current
                    icon: "add"
                    label: "Save as new"
                    onClicked: stages.push("save")
                }
            }

            StageRow {
                visible: root.canUndo
                Layout.topMargin: 8
                tonal: true
                icon: "history"
                title: "Your previous layout was kept"
                subtitle: "Go back to how things were before you loaded one"

                M3Button {
                    icon: "undo"
                    label: "Undo"
                    onClicked: root.runLayout(["undo"], "Previous layout restored")
                }
            }

            StageHeading {
                text: "Saved layouts"
                aside: root.layouts.length > 0 ? String(root.layouts.length) : ""
            }

            StageNote {
                visible: root.loaded && root.layouts.length === 0
                content: "No layouts yet. Save the one you have now, then experiment freely."
            }

            Repeater {
                model: root.layouts

                StageNavRow {
                    required property var modelData
                    icon: "dashboard_customize"
                    tonal: !!modelData.current
                    title: modelData.name
                    subtitle: root.status(modelData)
                    onClicked: {
                        root.selectedId = modelData.id
                        stages.push("layout")
                    }
                }
            }

            StageGap {}

            StageNavRow {
                icon: "add"
                title: "Save what I have now"
                subtitle: "Name it, then experiment freely"
                target: "save"
            }

            StageNavRow {
                icon: "upload_file"
                title: "Import a Nebula layout"
                subtitle: "A .json file someone shared"
                onClicked: {
                    GlobalStates.fileDialogOpen = true
                    importPicker.open()
                }
            }

            StageHeading { text: "Switching" }

            StageSwitchRow {
                icon: "animation"
                title: "Animate layout changes"
                subtitle: ServiceLayouts.animate ? "Items fly to their new places" : "Layouts swap instantly"
                checked: ServiceLayouts.animate
                onToggled: on => root.setMotion(on)
            }

            StageNote {
                content: "Super + Alt + ] and Super + Alt + [ step through your layouts."
            }

            StageNavRow {
                icon: "folder_open"
                title: "Open the layouts folder"
                subtitle: root.dir
                onClicked: Quickshell.execDetached(["xdg-open", root.dir])
            }
        }

        StageLazy {
            stageId: "layout"

            StagePage {
                stageId: "layout"
                title: root.selected ? root.selected.name : ""
                aside: root.selected && root.selected.current ? "In use" : ""

                Toast {}

                StageHero {
                    tone: root.selected && root.selected.current ? "primary" : "plain"
                    icon: "dashboard_customize"
                    title: root.selected ? root.selected.name : ""
                    subtitle: root.status(root.selected)

                    M3Button {
                        visible: !!root.selected && (!root.selected.current || !!root.selected.modified)
                        icon: root.busyId === root.selectedId ? "hourglass_top" : root.selected && root.selected.modified ? "undo" : "check"
                        label: root.selected && root.selected.modified ? "Revert" : "Switch to this"
                        onClicked: root.apply(root.selected)
                    }

                    M3Button {
                        visible: !!root.selected && !!root.selected.current && !!root.selected.modified
                        icon: "save"
                        label: "Update"
                        onClicked: root.update(root.selected)
                    }
                }

                StageNote {
                    visible: !!root.selected && !root.selected.current
                    content: "Switching keeps what you have now as the undo point, so you can come back in one click."
                }

                StageHeading { text: "What it restores" }

                Repeater {
                    model: root.details(root.selected)

                    StageRow {
                        required property var modelData
                        icon: modelData.icon
                        title: modelData.label
                        value: modelData.value
                    }
                }

                StageGap {}

                StageNavRow {
                    icon: "ios_share"
                    title: "Export"
                    subtitle: "Copies the layout file to Downloads"
                    onClicked: root.run(["export", root.selectedId, Quickshell.env("HOME") + "/Downloads"], "Copied to Downloads")
                }

                StageRow {
                    danger: true
                    clickable: true
                    icon: root.armedDelete === root.selectedId ? "delete_forever" : "delete"
                    title: root.armedDelete === root.selectedId ? "Click again to delete" : "Delete"
                    subtitle: "Removes the saved file; what you have now stays"
                    onClicked: {
                        if (!root.selected)
                            return
                        if (root.armedDelete !== root.selectedId) {
                            root.armedDelete = root.selectedId
                            toastTimer.restart()
                            return
                        }
                        const name = root.selected.name
                        root.armedDelete = ""
                        root.run(["delete", root.selectedId], "Deleted “" + name + "”")
                        stages.back()
                    }
                }
            }
        }

        StagePage {
            stageId: "save"
            title: "Save as new"

            StageFieldRow {
                id: nameField
                icon: "edit"
                title: "Name"
                subtitle: root.clash ? "“" + root.clash.name + "” already exists. Saving replaces it." : "e.g. Work, Gaming, Minimal"
                fieldWidth: 240
                placeholder: "Layout name"
            }

            StageHeading { text: "Include" }

            Repeater {
                model: root.sectionMeta

                StageSwitchRow {
                    required property var modelData
                    icon: modelData.icon
                    title: modelData.label
                    subtitle: modelData.hint
                    checked: root.pick.indexOf(modelData.id) >= 0
                    onToggled: root.togglePick(modelData.id)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 12
                spacing: 8

                Item { Layout.fillWidth: true }

                M3Button {
                    variant: "outlined"
                    label: "Cancel"
                    onClicked: stages.back()
                }

                M3Button {
                    icon: root.clash ? "sync_alt" : "save"
                    label: root.clash ? "Replace" : "Save layout"
                    enabledButton: root.typedName !== "" && root.pick.length > 0
                    onClicked: {
                        if (root.typedName === "" || root.pick.length === 0)
                            return
                        root.run(["save", root.typedName, "--only", root.pick.join(",")],
                                 (root.clash ? "Replaced “" : "Saved “") + root.typedName + "”")
                        nameField.clear()
                        stages.back()
                    }
                }
            }
        }
    }
}
