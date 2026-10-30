import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import Qt.labs.platform

ColumnLayout {
    id: row

    required property string area

    readonly property var target: ServiceHyprConfig.target(row.area)
    readonly property bool own: row.target.mode === "own"
    readonly property string file: ServiceHyprConfig.fileOf(row.area)
    readonly property var status: ServiceHyprConfig.statusOf(row.area)
    readonly property bool unloaded: !!row.status && row.status.exists && !row.status.required

    Layout.fillWidth: true
    spacing: 3

    StageRow {
        icon: row.own ? "description" : "folder_special"
        tonal: false
        title: "Saved in " + ServiceHyprConfig.prettyPath(row.file)
        subtitle: row.own
            ? "Nebula only writes inside its marked block at the end of this file"
            : (row.status && row.status.exists ? "A file Nebula owns, loaded from your hyprland.lua" : "Created the first time you change something here")

        M3Button {
            variant: "tonal"
            icon: "edit_document"
            label: row.own ? "Other file" : "Use my file"
            onClicked: {
                GlobalStates.fileDialogOpen = true
                picker.open()
            }
        }

        M3Button {
            visible: row.own
            variant: "text"
            label: "Nebula file"
            onClicked: ServiceHyprConfig.setTarget(row.area, "nebula", "")
        }

        M3Button {
            visible: !!row.status && row.status.exists
            variant: "text"
            icon: "delete_sweep"
            label: row.own ? "Remove block" : "Clear"
            onClicked: ServiceHyprConfig.removeBlock(row.area)
        }
    }

    StageRow {
        visible: row.unloaded
        icon: "warning"
        danger: true
        title: "Hyprland doesn't load this file"
        subtitle: row.status && row.status.module !== ""
            ? "Add require(\"" + row.status.module + "\") to your hyprland.lua, or let Nebula add it"
            : "Pick a file inside ~/.config/hypr so Hyprland can load it"

        M3Button {
            visible: !!row.status && row.status.module !== ""
            variant: "tonal"
            label: "Add it"
            onClicked: ServiceHyprConfig.requireFile(row.area)
        }
    }

    FileDialog {
        id: picker
        title: "Choose the file for " + (ServiceHyprConfig.areaNames[row.area] ?? row.area)
        folder: "file://" + ServiceHyprConfig.hyprDir
        nameFilters: ["Lua files (*.lua)"]
        fileMode: FileDialog.OpenFile
        onAccepted: {
            GlobalStates.fileDialogOpen = false
            ServiceHyprConfig.setTarget(row.area, "own", picker.file.toString().replace(/^file:\/\//, ""))
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }
}
