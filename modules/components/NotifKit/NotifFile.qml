import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import "NotifKinds.js" as Kinds

ColumnLayout {
    id: file

    property var notif: null
    property color ink: Colors.surfaceText
    property color subInk: Colors.surfaceVariantText
    signal opened()

    readonly property var info: Kinds.fileInfo(file.notif)
    readonly property bool ok: file.info.isFile
    readonly property string home: Quickshell.env("HOME") ?? ""
    readonly property string guess: file.info.path !== "" ? file.info.path
        : file.info.name !== "" ? file.home + "/Downloads/" + file.info.name : ""
    property string found: ""
    property real bytes: 0
    readonly property string dir: file.found !== "" ? file.found.slice(0, file.found.lastIndexOf("/")) : ""
    readonly property string dirName: file.dir === file.home + "/Downloads" ? "Downloads" : file.dir.slice(file.dir.lastIndexOf("/") + 1)
    readonly property string extLabel: file.info.ext.toUpperCase()
    readonly property string figure: file.bytes > 0 ? Kinds.humanBytes(file.bytes)
        : file.extLabel !== "" && file.extLabel.length <= 7 ? file.extLabel : "Done"
    readonly property string figureSub: file.bytes > 0 && file.extLabel !== ""
        ? file.extLabel + " " + file.info.word.toLowerCase() : file.info.word

    visible: file.ok
    spacing: 12

    onGuessChanged: file.probe()
    Component.onCompleted: file.probe()

    function probe() {
        file.found = ""
        file.bytes = 0
        if (!file.ok || file.guess === "")
            return
        stat.target = file.guess
        stat.command = ["stat", "-Lc", "%s", "--", file.guess]
        stat.running = true
    }

    Process {
        id: stat
        property string target: ""
        stdout: StdioCollector { id: statOut }
        onExited: code => {
            if (code !== 0 || stat.target !== file.guess)
                return
            file.bytes = parseInt(statOut.text.trim()) || 0
            file.found = stat.target
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 112
        radius: 18
        color: Colors.secondaryContainer
        clip: true

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: kindIcon.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 22
            anchors.rightMargin: 8
            spacing: 4

            CustomText {
                Layout.fillWidth: true
                content: file.figure
                family: SettingsConfig.general.displayFont ?? "Titan One"
                renderType: Text.QtRendering
                size: 38
                weight: 400
                customColor: Colors.secondaryContainerText
            }

            CustomText {
                Layout.fillWidth: true
                content: file.figureSub
                size: 12
                weight: 500
                customColor: Qt.alpha(Colors.secondaryContainerText, 0.8)
            }
        }

        MaterialIconSymbol {
            id: kindIcon
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            content: file.info.icon
            iconSize: 64
            customColor: Qt.alpha(Colors.secondaryContainerText, 0.32)
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        spacing: 1

        CustomText {
            Layout.fillWidth: true
            content: file.info.name !== "" ? file.info.name : (file.notif?.summary ?? "")
            size: 14
            weight: 600
            customColor: file.ink
        }

        CustomText {
            Layout.fillWidth: true
            content: (file.notif?.appName ?? "") + (file.found !== "" ? (file.notif?.appName ? ", saved to " : "Saved to ") + file.dirName : "")
            size: 12
            customColor: file.subInk
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: file.found !== ""
        spacing: 8

        M3Button {
            Layout.fillWidth: true
            icon: "open_in_new"
            label: "Open"
            onClicked: {
                ServiceApps.spawn(["xdg-open", file.found])
                file.opened()
            }
        }

        M3Button {
            Layout.fillWidth: true
            variant: "tonal"
            icon: "folder_open"
            label: "Show in folder"
            onClicked: {
                ServiceApps.spawn(["xdg-open", file.dir])
                file.opened()
            }
        }
    }
}
