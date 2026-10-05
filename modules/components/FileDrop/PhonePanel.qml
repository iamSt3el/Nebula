import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import Qt.labs.platform

Item {
    id: root
    anchors.fill: parent

    signal closed

    readonly property bool ready: ServicePhone.ready
    readonly property bool pairing: ServicePhone.reachable && !ServicePhone.paired
    readonly property string mode: !ServicePhone.found ? "none"
        : ServicePhone.justPaired ? "paired"
        : root.ready ? "ready"
        : root.pairing ? (ServicePhone.pairState === 2 ? "asked" : ServicePhone.pairState === 1 ? "waiting" : "found")
        : "away"

    property bool dragging: false
    property real now: Date.now()

    Component.onCompleted: ServicePhone.refresh()

    Timer {
        interval: 1000
        running: root.mode === "waiting" || root.mode === "ready"
        repeat: true
        onTriggered: root.now = Date.now()
    }

    FileDialog {
        id: picker
        title: "Send to " + ServicePhone.label
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            GlobalStates.fileDialogOpen = false
            ServicePhone.share(root.paths(picker.files))
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }

    function paths(urls) {
        const out = []
        for (let i = 0; i < urls.length; i++)
            out.push(decodeURIComponent(urls[i].toString().replace(/^file:\/\//, "")))
        return out
    }

    function ago(t) {
        const s = Math.max(0, Math.floor((root.now - t) / 1000))
        if (s < 60) return "now"
        if (s < 3600) return Math.floor(s / 60) + " min"
        return Math.floor(s / 3600) + " h"
    }

    function iconFor(kind) {
        switch (kind) {
        case "in": return "download"
        case "out": return "upload"
        case "link": return "link"
        case "text":
        case "textIn": return "notes"
        case "clip": return "content_paste"
        }
        return "swap_vert"
    }

    function noteFor(e) {
        if (!e.ok) return "failed"
        switch (e.kind) {
        case "in": return "received · " + root.ago(e.at)
        case "textIn": return "text · " + root.ago(e.at)
        case "link": return "opened on phone"
        }
        return "sent · " + root.ago(e.at)
    }

    component Chip: Rectangle {
        id: chip
        property string icon: ""
        property string text: ""
        implicitWidth: chipRow.implicitWidth + 20
        implicitHeight: 30
        radius: 10
        color: Colors.surfaceContainer

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            MaterialIconSymbol { content: chip.icon; iconSize: 16; fill: 1; customColor: Colors.primary }
            CustomText { content: chip.text; size: 12; weight: 600 }
        }
    }

    component BigAction: Rectangle {
        id: act
        property string icon: ""
        property string text: ""
        property bool lead: false
        signal activated
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 72
        radius: 20
        color: act.lead ? (actMouse.containsMouse ? Qt.lighter(Colors.primary, 1.04) : Colors.primary)
                        : (actMouse.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainer)
        Behavior on color { EffectsColorAnim {} }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6
            MaterialIconSymbol {
                Layout.alignment: Qt.AlignHCenter
                content: act.icon
                iconSize: 22
                fill: 1
                customColor: act.lead ? Colors.primaryText : Colors.surfaceText
            }
            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: act.text
                size: 11
                weight: 600
                customColor: act.lead ? Colors.primaryText : Colors.surfaceText
            }
        }

        MouseArea {
            id: actMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: act.activated()
        }
    }

    component KeyBox: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 84
        radius: 20
        color: Colors.surfaceContainer

        CustomText {
            anchors.centerIn: parent
            content: ServicePhone.verifyKey.replace(/(.{4})(?=.)/, "$1 ")
            size: 30
            weight: 700
            family: "Fira Code"
            font.letterSpacing: 4
            customColor: Colors.primary
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            Rectangle {
                implicitWidth: 92
                implicitHeight: 160
                radius: 22
                color: Colors.surfaceContainerHighest

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: 17
                    color: Colors.surfaceContainerLow

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.ready
                            content: Qt.formatTime(new Date(root.now), "h:mm")
                            size: 22
                            weight: 400
                            family: SettingsConfig.general.displayFont ?? "Titan One"
                            renderType: Text.QtRendering
                            customColor: Colors.primary
                        }

                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.ready
                            content: Qt.formatDate(new Date(root.now), "ddd d MMM")
                            size: 9
                            weight: 400
                            customColor: Colors.outline
                        }

                        MaterialIconSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            visible: !root.ready
                            content: root.mode === "none" || root.mode === "away" ? "phonelink_off" : "phonelink_ring"
                            iconSize: 30
                            customColor: root.mode === "none" || root.mode === "away" ? Colors.outline : Colors.primary
                        }

                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 8
                            visible: root.ready
                            spacing: 3
                            Repeater {
                                model: 3
                                delegate: Rectangle {
                                    required property int index
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: index < Math.min(3, ServicePhone.notifs) ? Colors.primaryContainer : Colors.outlineVariant
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 11
                    width: 8
                    height: 8
                    radius: 4
                    color: Colors.surface
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        implicitWidth: statusRow.implicitWidth + 20
                        implicitHeight: 24
                        radius: 12
                        color: root.ready || root.mode === "paired" ? Colors.tertiaryContainer
                             : root.pairing ? Colors.primaryContainer : Colors.surfaceContainerHigh

                        RowLayout {
                            id: statusRow
                            anchors.centerIn: parent
                            spacing: 5

                            Rectangle {
                                implicitWidth: 6
                                implicitHeight: 6
                                radius: 3
                                color: root.ready || root.mode === "paired" ? Colors.tertiaryContainerText
                                     : root.pairing ? Colors.primaryContainerText : Colors.outline
                            }

                            CustomText {
                                content: {
                                    switch (root.mode) {
                                    case "ready":
                                    case "paired": return "Connected"
                                    case "found": return "Not paired"
                                    case "waiting": return "Waiting for the phone"
                                    case "asked": return "Wants to pair"
                                    case "away": return ServicePhone.looking ? "Looking…" : "Not nearby"
                                    }
                                    return "No phone"
                                }
                                size: 11
                                weight: 700
                                customColor: root.ready || root.mode === "paired" ? Colors.tertiaryContainerText
                                           : root.pairing ? Colors.primaryContainerText : Colors.outline
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    M3IconButton {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        icon: "close"
                        iconSize: 17
                        iconColor: Colors.outline
                        onClicked: root.closed()
                    }
                }

                CustomText {
                    Layout.fillWidth: true
                    content: ServicePhone.found ? ServicePhone.label : "No phone yet"
                    size: 26
                    weight: 400
                    family: SettingsConfig.general.displayFont ?? "Titan One"
                    renderType: Text.QtRendering
                    elide: Text.ElideRight
                }

                CustomText {
                    Layout.fillWidth: true
                    content: ServicePhone.reachable && ServicePhone.ip !== "" ? "Wi-Fi · " + ServicePhone.ip + " · KDE Connect" : "KDE Connect"
                    size: 12
                    weight: 400
                    customColor: Colors.outline
                    elide: Text.ElideRight
                }

                RowLayout {
                    visible: root.ready
                    spacing: 6

                    Chip {
                        visible: ServicePhone.battery >= 0
                        icon: ServicePhone.charging ? "battery_charging_80" : ServicePhone.battery > 60 ? "battery_full" : ServicePhone.battery > 25 ? "battery_4_bar" : "battery_1_bar"
                        text: ServicePhone.battery + "%"
                    }

                    Chip {
                        icon: "notifications"
                        text: String(ServicePhone.notifs)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.mode === "ready"
            spacing: 8

            BigAction { icon: "content_paste"; text: "Clipboard"; lead: true; onActivated: ServicePhone.sendClipboard() }
            BigAction { icon: "volume_up"; text: "Ring"; onActivated: ServicePhone.ring() }
            BigAction {
                icon: "folder_open"
                text: "Browse"
                onActivated: {
                    GlobalStates.phoneOpen = false
                    GlobalStates.phoneBrowserOpen = true
                }
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: 108
            visible: root.mode === "ready"

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: root.dragging ? Qt.alpha(Colors.primary, 0.08) : Colors.surfaceContainer
                    strokeColor: root.dragging ? Colors.primary : Colors.outlineVariant
                    strokeWidth: 2
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [4, 3]

                    PathRectangle {
                        x: 1
                        y: 1
                        width: root.width - 42
                        height: 106
                        radius: 20
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 14

                Rectangle {
                    implicitWidth: 48
                    implicitHeight: 48
                    radius: 24
                    color: Colors.surfaceContainerHighest

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "upload_file"
                        iconSize: 24
                        customColor: Colors.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    CustomText {
                        content: root.dragging ? "Let go to send" : "Drop files to send"
                        size: 14
                        weight: 600
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: "or click to choose · links open in the phone's browser"
                        size: 11
                        weight: 400
                        customColor: Colors.outline
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    GlobalStates.fileDialogOpen = true
                    picker.open()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            radius: 22
            visible: root.mode === "ready"
            color: Colors.surfaceContainer
            border.width: textIn.activeFocus ? 2 : 0
            border.color: Colors.primary

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 6
                spacing: 8

                TextInput {
                    id: textIn
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colors.surfaceText
                    font.pixelSize: 13
                    font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                    selectByMouse: true
                    clip: true
                    onAccepted: send()

                    function send() {
                        if (text.trim() === "") return
                        ServicePhone.shareText(text)
                        text = ""
                    }

                    CustomText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: textIn.text === ""
                        content: "Send a link or text"
                        size: 13
                        weight: 400
                        customColor: Colors.outline
                    }
                }

                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 16
                    color: textIn.text.trim() !== "" ? Colors.primary : Colors.surfaceContainerHighest

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "send"
                        iconSize: 16
                        customColor: textIn.text.trim() !== "" ? Colors.primaryText : Colors.outline
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: textIn.send()
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.mode !== "ready"
            spacing: 14

            CustomText {
                Layout.fillWidth: true
                visible: root.mode !== "paired"
                content: {
                    switch (root.mode) {
                    case "found": return ServicePhone.label + " is on your Wi-Fi with KDE Connect open, but not paired with this PC yet."
                    case "waiting": return "Accept the request on " + ServicePhone.label + ". Both screens should show this key:"
                    case "asked": return ServicePhone.label + " wants to pair. Check the key matches the one on the phone."
                    case "away": return "Open KDE Connect on " + ServicePhone.label + " and make sure it's on the same Wi-Fi. It reconnects by itself, nothing to scan."
                    }
                    return "Install KDE Connect on your phone, open it, and join the same Wi-Fi as this PC. It shows up here to pair."
                }
                size: 13
                weight: 400
                lineHeight: 1.4
                customColor: Colors.surfaceVariantText
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }

            KeyBox { visible: root.mode === "waiting" || root.mode === "asked" }

            RowLayout {
                Layout.fillWidth: true
                visible: root.mode === "waiting"
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 4
                    radius: 2
                    color: Colors.surfaceContainerHighest

                    Rectangle {
                        width: parent.width * Math.max(0, 1 - (root.now - ServicePhone.pairSince) / 30000)
                        height: parent.height
                        radius: 2
                        color: Colors.primary
                    }
                }

                CustomText {
                    content: Math.max(0, 30 - Math.floor((root.now - ServicePhone.pairSince) / 1000)) + " s"
                    size: 12
                    weight: 500
                    customColor: Colors.outline
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.mode === "paired"
                spacing: 10

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 84
                    implicitHeight: 84
                    radius: 42
                    color: Colors.tertiaryContainer

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "check"
                        iconSize: 42
                        fill: 1
                        customColor: Colors.tertiaryContainerText
                    }
                }

                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: "Paired"
                    size: 22
                    weight: 400
                    family: SettingsConfig.general.displayFont ?? "Titan One"
                    renderType: Text.QtRendering
                }

                CustomText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    content: ServicePhone.label + " reconnects by itself whenever it's on this Wi-Fi. Nothing to scan again."
                    size: 13
                    weight: 400
                    customColor: Colors.surfaceVariantText
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                M3Button {
                    Layout.fillWidth: true
                    visible: root.mode === "found"
                    variant: "filled"
                    icon: "link"
                    label: "Pair"
                    onClicked: ServicePhone.requestPair()
                }

                M3Button {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    visible: root.mode === "asked"
                    variant: "tonal"
                    label: "Reject"
                    onClicked: ServicePhone.cancelPair()
                }

                M3Button {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    visible: root.mode === "asked"
                    variant: "filled"
                    icon: "check"
                    label: "Accept"
                    onClicked: ServicePhone.acceptPair()
                }

                M3Button {
                    Layout.fillWidth: true
                    visible: root.mode === "waiting"
                    variant: "outlined"
                    label: "Cancel"
                    onClicked: ServicePhone.cancelPair()
                }

                M3Button {
                    Layout.fillWidth: true
                    visible: root.mode === "paired"
                    variant: "filled"
                    label: "Send something"
                    onClicked: ServicePhone.justPaired = false
                }

                M3Button {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    visible: root.mode === "away" || root.mode === "none"
                    variant: "filled"
                    icon: "refresh"
                    label: ServicePhone.looking ? "Looking…" : "Look again"
                    onClicked: ServicePhone.lookAgain()
                }

                M3Button {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    visible: root.mode === "away" || root.mode === "none"
                    variant: "tonal"
                    icon: "settings"
                    label: "KDE Connect"
                    onClicked: ServicePhone.openKdeConnect()
                }
            }

            Repeater {
                model: root.mode === "found" ? ServicePhone.others : []

                delegate: RowLayout {
                    id: oldRow
                    required property var modelData
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    CustomText {
                        content: "Old phone: " + oldRow.modelData.name + " ·"
                        size: 11
                        weight: 400
                        customColor: Colors.outline
                    }

                    CustomText {
                        content: "Forget"
                        size: 11
                        weight: 600
                        customColor: Colors.surfaceVariantText

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ServicePhone.forget(oldRow.modelData.id)
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 8

            CustomText {
                Layout.fillWidth: true
                content: "Recent"
                size: 13
                weight: 500
                customColor: Colors.primary
            }

            CustomText {
                content: "Open Downloads"
                size: 11
                weight: 400
                customColor: Colors.outline

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["xdg-open", ServicePhone.downloads])
                }
            }
        }

        ListView {
            id: feed
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: -8
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: ServicePhone.transfers

            delegate: Rectangle {
                id: entry
                required property var modelData
                width: feed.width
                height: 46
                radius: 14
                color: Colors.surfaceContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 10

                    MaterialIconSymbol {
                        content: root.iconFor(entry.modelData.kind)
                        iconSize: 18
                        customColor: !entry.modelData.ok ? Colors.error
                                   : entry.modelData.kind === "in" || entry.modelData.kind === "textIn" ? Colors.primary : Colors.outline
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: entry.modelData.name ?? ""
                        size: 12
                        weight: 600
                        elide: Text.ElideMiddle
                    }

                    CustomText {
                        content: root.noteFor(entry.modelData)
                        size: 11
                        weight: 400
                        customColor: entry.modelData.ok ? Colors.outline : Colors.error
                    }

                    M3IconButton {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        visible: entry.modelData.kind === "in" || entry.modelData.kind === "textIn"
                        icon: entry.modelData.kind === "in" ? "open_in_new" : "content_copy"
                        iconSize: 14
                        iconColor: Colors.outline
                        onClicked: {
                            if (entry.modelData.kind === "in")
                                Quickshell.execDetached(["xdg-open", entry.modelData.path])
                            else
                                Quickshell.execDetached(["wl-copy", entry.modelData.name])
                        }
                    }
                }
            }
        }

        CustomText {
            Layout.fillWidth: true
            visible: feed.count === 0
            content: "Nothing sent yet. Files from the phone land in " + ServicePhone.downloads
            size: 11
            weight: 400
            customColor: Colors.outline
            elide: Text.ElideMiddle
        }
    }

    DropArea {
        anchors.fill: parent
        enabled: root.ready
        keys: ["text/uri-list"]
        onEntered: root.dragging = true
        onExited: root.dragging = false
        onDropped: drop => {
            root.dragging = false
            ServicePhone.share(root.paths(drop.urls))
            drop.accept()
        }
    }
}
