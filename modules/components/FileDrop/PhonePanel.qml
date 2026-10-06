pragma ComponentBehavior: Bound

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

    function launch(args) {
        GlobalStates.panelHold = true
        Quickshell.execDetached(args)
    }
    anchors.fill: parent

    signal closed

    readonly property bool ready: ServicePhone.ready
    readonly property bool pairing: ServicePhone.reachable && !ServicePhone.paired
    readonly property string mode: !ServicePhone.found ? "none"
        : ServicePhone.justPaired ? "paired"
        : root.ready ? "ready"
        : root.pairing ? (ServicePhone.pairState === 2 ? "asked" : ServicePhone.pairState === 1 ? "waiting" : "found")
        : "away"

    readonly property var notifs: ServicePhone.notifications
    readonly property var missed: ServicePhone.missedCalls
    readonly property var call: ServicePhone.call
    readonly property int activityCount: (root.call ? 1 : 0) + root.missed.length + root.notifs.length
    readonly property var groups: {
        const out = []
        const at = {}
        for (const n of root.notifs) {
            const key = n.app || n.title || "?"
            if (!(key in at)) {
                at[key] = out.length
                out.push({ app: key, items: [] })
            }
            out[at[key]].items.push(n)
        }
        return out
    }
    readonly property var quick: ["Can't talk, I'll call you back", "In a meeting", "On my way"]

    property string tab: "activity"
    property bool sawActivity: false
    property bool dragging: false
    property real now: Date.now()
    property string openId: ""
    property real replyAt: -1
    property bool callReply: false
    property string sentTo: ""

    onTabChanged: if (root.tab === "activity") root.sawActivity = true

    Component.onCompleted: {
        ServicePhone.refresh()
        root.tab = root.activityCount > 0 || !root.ready ? "activity" : "send"
        root.sawActivity = root.tab === "activity"
    }
    Component.onDestruction: if (root.sawActivity && root.ready) ServicePhone.markRead()

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        onTriggered: root.now = Date.now()
    }

    Timer {
        id: sentTimer
        interval: 2500
        onTriggered: root.sentTo = ""
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

    function chooseFiles() {
        GlobalStates.fileDialogOpen = true
        picker.open()
    }

    function ago(t) {
        const s = Math.max(0, Math.floor((root.now - t) / 1000))
        if (s < 60) return "now"
        if (s < 3600) return Math.floor(s / 60) + " min"
        if (s < 86400) return Math.floor(s / 3600) + " h"
        return Qt.formatDateTime(new Date(t), "ddd hh:mm")
    }

    function clock(ms) {
        const s = Math.max(0, Math.floor(ms / 1000))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    function textBack(number, text) {
        if (text.trim() === "")
            return
        ServicePhone.textBack(number, text)
        root.sentTo = number
        sentTimer.restart()
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

    component Avatar: Rectangle {
        id: av
        property string name: ""
        property string photo: ""
        property real size: 32
        readonly property int tone: {
            let h = 0
            for (let i = 0; i < av.name.length; i++)
                h = (h * 31 + av.name.charCodeAt(i)) % 3
            return h
        }
        implicitWidth: av.size
        implicitHeight: av.size
        radius: av.size / 2
        color: av.tone === 0 ? Colors.tertiaryContainer : av.tone === 1 ? Colors.primaryContainer : Colors.secondaryContainer

        CustomText {
            anchors.centerIn: parent
            visible: pic.status !== Image.Ready
            content: av.name.charAt(0).toUpperCase()
            size: Math.round(av.size * 0.42)
            weight: 700
            customColor: av.tone === 0 ? Colors.tertiaryContainerText
                : av.tone === 1 ? Colors.primaryContainerText : Colors.secondaryContainerText
        }

        RoundedImage {
            id: pic
            anchors.fill: parent
            radius: av.size / 2
            source: av.photo
            sourceSize: Qt.size(96, 96)
        }
    }

    component Field: Rectangle {
        id: field
        property string hint: ""
        property string doneHint: ""
        property bool done: false
        property real h: 36
        signal submitted(string text)
        Layout.fillWidth: true
        implicitHeight: field.h
        radius: field.h / 2
        color: Colors.surfaceContainerHighest
        border.width: input.activeFocus ? 2 : 0
        border.color: Colors.primary

        function send() {
            if (input.text.trim() === "")
                return
            field.submitted(input.text)
            input.text = ""
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: (field.h - 28) / 2
            spacing: 8

            TextInput {
                id: input
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: TextInput.AlignVCenter
                color: Colors.surfaceText
                selectionColor: Colors.primary
                selectedTextColor: Colors.primaryText
                font.pixelSize: 13
                font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                selectByMouse: true
                clip: true
                onAccepted: field.send()
                Keys.onEscapePressed: { text = ""; focus = false }

                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: input.width
                    visible: input.text === ""
                    content: field.done ? field.doneHint : field.hint
                    size: 13
                    weight: 400
                    customColor: field.done ? Colors.primary : Colors.outline
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                color: input.text.trim() !== "" ? Colors.primary : Qt.alpha(Colors.primary, 0)
                Behavior on color { EffectsColorAnim { speed: "fast" } }

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: "send"
                    iconSize: 15
                    customColor: input.text.trim() !== "" ? Colors.primaryText : Colors.outline
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: field.send()
                }
            }
        }
    }

    component CardButton: Rectangle {
        id: cb
        property string icon: ""
        property string label: ""
        property color fill: Colors.primaryText
        property color ink: Colors.primary
        property color line: Qt.alpha(Colors.primary, 0)
        property bool active: true
        property real h: 40
        signal clicked
        implicitHeight: cb.h
        implicitWidth: cbRow.implicitWidth + cb.h * 0.8
        radius: cb.h / 2
        color: cbMouse.containsMouse && cb.active ? Qt.tint(cb.fill, Qt.alpha(cb.ink, 0.1)) : cb.fill
        border.width: cb.line.a > 0 ? 1.5 : 0
        border.color: cb.line
        opacity: cb.active ? 1 : 0.6
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        RowLayout {
            id: cbRow
            anchors.centerIn: parent
            spacing: 6
            MaterialIconSymbol {
                visible: cb.icon !== ""
                content: cb.icon
                iconSize: 17
                customColor: cb.ink
            }
            CustomText {
                content: cb.label
                size: 13
                weight: 600
                customColor: cb.ink
            }
        }

        MouseArea {
            id: cbMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: cb.active
            cursorShape: Qt.PointingHandCursor
            onClicked: cb.clicked()
        }
    }

    component Replies: ColumnLayout {
        id: replies
        property string number: ""
        property string who: ""
        property color chip: Colors.surfaceContainerHighest
        spacing: 8

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.quick
                delegate: M3Button {
                    required property string modelData
                    size: "xsmall"
                    variant: "tonal"
                    label: modelData
                    onClicked: root.textBack(replies.number, modelData)
                }
            }
        }

        Field {
            hint: "Text " + replies.who
            doneHint: "Sent"
            done: root.sentTo === replies.number
            onSubmitted: text => root.textBack(replies.number, text)
        }
    }

    component TabButton: Rectangle {
        id: tb
        property string key: ""
        property string label: ""
        property int badge: 0
        readonly property bool on: root.tab === tb.key
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: height / 2
        color: tb.on ? Colors.primary : tbMouse.containsMouse ? Colors.surfaceContainerHigh : Qt.alpha(Colors.surfaceContainerHigh, 0)
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        RowLayout {
            anchors.centerIn: parent
            spacing: 6

            CustomText {
                content: tb.label
                size: 13
                weight: 600
                customColor: tb.on ? Colors.primaryText : Colors.surfaceVariantText
            }

            Rectangle {
                visible: tb.badge > 0
                implicitWidth: Math.max(18, badgeText.implicitWidth + 8)
                implicitHeight: 18
                radius: 9
                color: tb.on ? Colors.primaryText : Colors.primary

                CustomText {
                    id: badgeText
                    anchors.centerIn: parent
                    content: tb.badge > 99 ? "99+" : String(tb.badge)
                    size: 11
                    weight: 700
                    customColor: tb.on ? Colors.primary : Colors.primaryText
                }
            }
        }

        MouseArea {
            id: tbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.tab = tb.key
        }
    }

    component Section: RowLayout {
        id: sec
        property string label: ""
        property string name: ""
        property string when: ""
        Layout.fillWidth: true
        spacing: 8

        Avatar { name: sec.name; size: 22 }

        CustomText {
            Layout.fillWidth: true
            content: sec.label
            size: 12
            weight: 700
            font.letterSpacing: 0.4
            customColor: Colors.surfaceVariantText
            elide: Text.ElideRight
        }

        CustomText {
            content: sec.when
            size: 11
            weight: 400
            customColor: Colors.outline
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                CustomText {
                    Layout.fillWidth: true
                    content: ServicePhone.found ? ServicePhone.label : "No phone yet"
                    size: 26
                    weight: 400
                    family: SettingsConfig.general.displayFont ?? "Titan One"
                    renderType: Text.QtRendering
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        spacing: 5
                        Rectangle {
                            implicitWidth: 7
                            implicitHeight: 7
                            radius: 4
                            color: root.ready || root.mode === "paired" ? Colors.tertiary
                                 : root.pairing ? Colors.primary : Colors.outline
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
                            size: 12
                            weight: 500
                            customColor: Colors.surfaceVariantText
                        }
                    }

                    RowLayout {
                        visible: root.ready && ServicePhone.battery >= 0
                        spacing: 3
                        MaterialIconSymbol {
                            content: ServicePhone.charging ? "bolt"
                                : ServicePhone.battery > 60 ? "battery_full" : ServicePhone.battery > 25 ? "battery_4_bar" : "battery_1_bar"
                            iconSize: 14
                            fill: 1
                            customColor: ServicePhone.low ? Colors.error : Colors.tertiary
                        }
                        CustomText {
                            content: ServicePhone.battery + "%"
                                + (ServicePhone.charging && ServicePhone.minutesToFull > 0 ? ", full in " + ServicePhone.minutesToFull + " min" : "")
                            size: 12
                            weight: 500
                            customColor: ServicePhone.low ? Colors.error : Colors.surfaceVariantText
                        }
                    }

                    RowLayout {
                        visible: root.ready && ServicePhone.bars >= 0
                        spacing: 5
                        Row {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1.5
                            Repeater {
                                model: 4
                                delegate: Rectangle {
                                    required property int index
                                    anchors.bottom: parent.bottom
                                    width: 2.5
                                    height: 4 + index * 2.4
                                    radius: 1
                                    color: index < ServicePhone.bars ? Colors.surfaceText : Colors.outlineVariant
                                }
                            }
                        }
                        CustomText {
                            visible: ServicePhone.netType !== ""
                            content: ServicePhone.netType
                            size: 12
                            weight: 500
                            customColor: Colors.surfaceVariantText
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            M3IconButton {
                visible: root.ready
                implicitWidth: 40
                implicitHeight: 40
                icon: "volume_up"
                iconSize: 18
                color: Colors.surfaceContainerHigh
                iconColor: Colors.primary
                iconHoverColor: Colors.primary
                onClicked: ServicePhone.ring()
            }

            M3IconButton {
                implicitWidth: 40
                implicitHeight: 40
                icon: "close"
                iconSize: 17
                color: Colors.surfaceContainerHigh
                iconColor: Colors.surfaceVariantText
                onClicked: root.closed()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.ready
            implicitHeight: 44
            radius: 22
            color: Colors.surfaceContainer

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                TabButton { key: "activity"; label: "Activity"; badge: root.activityCount }
                TabButton { key: "send"; label: "Send" }
                TabButton { key: "files"; label: "Files"; badge: 0 }
            }
        }

        Flickable {
            id: activityFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.ready && root.tab === "activity"
            contentHeight: activity.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            ColumnLayout {
                id: activity
                width: activityFlick.width
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    visible: root.call !== null
                    implicitHeight: callCol.implicitHeight + 24
                    radius: 22
                    color: Colors.primary

                    ColumnLayout {
                        id: callCol
                        x: 12
                        y: 12
                        width: parent.width - 24
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                implicitWidth: 44
                                implicitHeight: 44
                                radius: 22
                                color: Colors.primaryText

                                CustomText {
                                    anchors.centerIn: parent
                                    visible: callPic.status !== Image.Ready
                                    content: root.call ? root.call.name.charAt(0).toUpperCase() : ""
                                    size: 20
                                    weight: 400
                                    family: SettingsConfig.general.displayFont ?? "Titan One"
                                    renderType: Text.QtRendering
                                    customColor: Colors.primary
                                }

                                RoundedImage {
                                    id: callPic
                                    anchors.fill: parent
                                    radius: 22
                                    source: root.call ? root.call.photo : ""
                                    sourceSize: Qt.size(96, 96)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                CustomText {
                                    Layout.fillWidth: true
                                    content: root.call ? root.call.name + " is calling" : ""
                                    size: 16
                                    weight: 700
                                    customColor: Colors.primaryText
                                    elide: Text.ElideRight
                                }
                                CustomText {
                                    Layout.fillWidth: true
                                    content: root.call ? [root.call.name !== root.call.number ? root.call.number : "",
                                                          "ringing " + root.clock(root.now - root.call.since)]
                                                         .filter(t => t !== "").join(" · ") : ""
                                    size: 12
                                    weight: 400
                                    customColor: Qt.alpha(Colors.primaryText, 0.8)
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            CardButton {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                icon: "notifications_off"
                                label: ServicePhone.ringerMuted ? "Silenced" : "Silence"
                                active: !ServicePhone.ringerMuted
                                onClicked: ServicePhone.silenceRinger()
                            }

                            CardButton {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                icon: "sms"
                                label: "Text back"
                                fill: root.callReply ? Colors.primaryText : Qt.alpha(Colors.primaryText, 0)
                                ink: root.callReply ? Colors.primary : Colors.primaryText
                                line: Colors.primaryText
                                onClicked: root.callReply = !root.callReply
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            visible: root.callReply
                            implicitHeight: callReplies.implicitHeight + 20
                            radius: 14
                            color: Colors.surfaceContainer

                            Replies {
                                id: callReplies
                                x: 10
                                y: 10
                                width: parent.width - 20
                                number: root.call ? root.call.number : ""
                                who: root.call ? root.call.name : ""
                            }
                        }
                    }
                }

                Repeater {
                    model: root.missed

                    delegate: Rectangle {
                        id: miss
                        required property var modelData
                        readonly property bool open: root.replyAt === miss.modelData.at
                        Layout.fillWidth: true
                        implicitHeight: missCol.implicitHeight + 20
                        radius: 20
                        color: Colors.errorContainer

                        ColumnLayout {
                            id: missCol
                            x: 12
                            y: 10
                            width: parent.width - 22
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                MaterialIconSymbol {
                                    content: "phone_missed"
                                    iconSize: 20
                                    customColor: Colors.errorContainerText
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    CustomText {
                                        Layout.fillWidth: true
                                        content: "Missed call from " + miss.modelData.name
                                        size: 14
                                        weight: 600
                                        customColor: Colors.errorContainerText
                                        elide: Text.ElideRight
                                    }
                                    CustomText {
                                        Layout.fillWidth: true
                                        content: [miss.modelData.name !== miss.modelData.number ? miss.modelData.number : "",
                                                  root.ago(miss.modelData.at) === "now" ? "just now" : root.ago(miss.modelData.at) + " ago"]
                                                 .filter(t => t !== "").join(" · ")
                                        size: 12
                                        weight: 400
                                        customColor: Qt.alpha(Colors.errorContainerText, 0.8)
                                        elide: Text.ElideRight
                                    }
                                }

                                CardButton {
                                    h: 34
                                    label: miss.open ? "Close" : "Text back"
                                    fill: Colors.errorContainerText
                                    ink: Colors.errorContainer
                                    onClicked: root.replyAt = miss.open ? -1 : miss.modelData.at
                                }

                                M3IconButton {
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    icon: "close"
                                    iconSize: 15
                                    color: Qt.alpha(Colors.errorContainerText, 0)
                                    iconColor: Colors.errorContainerText
                                    iconHoverColor: Colors.errorContainerText
                                    onClicked: ServicePhone.forgetMissed(miss.modelData.at)
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                visible: miss.open
                                implicitHeight: missReplies.implicitHeight + 20
                                radius: 14
                                color: Colors.surfaceContainer

                                Replies {
                                    id: missReplies
                                    x: 10
                                    y: 10
                                    width: parent.width - 20
                                    number: miss.modelData.number
                                    who: miss.modelData.name
                                }
                            }
                        }
                    }
                }

                Repeater {
                    model: root.groups

                    delegate: ColumnLayout {
                        id: group
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 6

                        Section {
                            name: group.modelData.app
                            label: group.modelData.app.toUpperCase() + (group.modelData.items.length > 1 ? " · " + group.modelData.items.length : "")
                            when: ServicePhone.age(group.modelData.items[0].id)
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: items.implicitHeight
                            radius: 18
                            color: Colors.surfaceContainer

                            ColumnLayout {
                                id: items
                                width: parent.width
                                spacing: 0

                                Repeater {
                                    model: group.modelData.items

                                    delegate: Item {
                                        id: note
                                        required property var modelData
                                        required property int index
                                        readonly property bool expanded: root.openId === note.modelData.id
                                        Layout.fillWidth: true
                                        implicitHeight: noteCol.implicitHeight + 24

                                        Rectangle {
                                            visible: note.index > 0
                                            x: 12
                                            width: parent.width - 24
                                            height: 1
                                            color: Colors.surfaceContainerHighest
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.openId = note.expanded ? "" : note.modelData.id
                                        }

                                        ColumnLayout {
                                            id: noteCol
                                            x: 12
                                            y: 12
                                            width: parent.width - 24
                                            spacing: 8

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 3
                                                    CustomText {
                                                        Layout.fillWidth: true
                                                        content: note.modelData.title || note.modelData.app
                                                        size: 14
                                                        weight: 600
                                                        elide: Text.ElideRight
                                                    }
                                                    CustomText {
                                                        Layout.fillWidth: true
                                                        visible: content !== ""
                                                        content: note.modelData.text
                                                        size: 13
                                                        weight: 400
                                                        lineHeight: 1.3
                                                        customColor: Colors.surfaceVariantText
                                                        wrapMode: Text.WordWrap
                                                        maximumLineCount: note.expanded ? 10 : 2
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                M3IconButton {
                                                    Layout.alignment: Qt.AlignTop
                                                    visible: note.modelData.dismissable && note.expanded
                                                    implicitWidth: 28
                                                    implicitHeight: 28
                                                    icon: "close"
                                                    iconSize: 15
                                                    color: Qt.alpha(Colors.surfaceContainerHighest, 0)
                                                    onClicked: ServicePhone.dismiss(note.modelData.id)
                                                }
                                            }

                                            Field {
                                                visible: note.expanded && note.modelData.replyId !== ""
                                                hint: "Reply to " + (note.modelData.title || note.modelData.app)
                                                doneHint: "Sent"
                                                done: root.sentTo === note.modelData.id
                                                onSubmitted: text => {
                                                    ServicePhone.reply(note.modelData.id, text)
                                                    root.sentTo = note.modelData.id
                                                    sentTimer.restart()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 30
                    visible: root.activityCount === 0
                    spacing: 6

                    MaterialIconSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        content: ServicePhone.muted ? "notifications_off" : "done_all"
                        iconSize: 30
                        customColor: Colors.outline
                    }
                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: ServicePhone.muted ? "Notifications muted" : "You're all caught up"
                        size: 14
                        weight: 600
                    }
                    CustomText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        content: "Calls and notifications from " + ServicePhone.label + " show up here."
                        size: 12
                        weight: 400
                        customColor: Colors.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.ready && root.tab === "activity"
            spacing: 8

            M3Button {
                size: "xsmall"
                variant: "text"
                icon: ServicePhone.muted ? "notifications" : "notifications_off"
                label: ServicePhone.muted ? "Unmute" : "Mute for an hour"
                onClicked: ServicePhone.mute(ServicePhone.muted ? 0 : 3600000)
            }

            Item { Layout.fillWidth: true }

            M3Button {
                visible: root.notifs.length > 0 || root.missed.length > 0
                size: "xsmall"
                variant: "text"
                label: "Clear all"
                onClicked: {
                    ServicePhone.dismissAll()
                    ServicePhone.clearMissed()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.ready && root.tab === "send"
            spacing: 12

            Item {
                id: dropZone
                Layout.fillWidth: true
                Layout.fillHeight: true

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: root.dragging ? Qt.alpha(Colors.primary, 0.1) : Colors.surfaceContainerLow
                        strokeColor: root.dragging ? Colors.primary : Colors.outlineVariant
                        strokeWidth: 2
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [4, 3]

                        PathRectangle {
                            x: 1
                            y: 1
                            width: dropZone.width - 2
                            height: dropZone.height - 2
                            radius: 24
                        }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    spacing: 8

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 56
                        implicitHeight: 56
                        radius: 28
                        color: Colors.primaryContainer

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "upload_file"
                            iconSize: 26
                            customColor: Colors.primaryContainerText
                        }
                    }

                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: root.dragging ? "Let go to send" : "Drop files to send"
                        size: 15
                        weight: 600
                    }

                    CustomText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        content: "or click to choose · they land in the phone's Downloads"
                        size: 12
                        weight: 400
                        customColor: Colors.outline
                        wrapMode: Text.WordWrap
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chooseFiles()
                }
            }

            Field {
                h: 44
                hint: "Send a link or text"
                onSubmitted: text => ServicePhone.shareText(text)
            }

            CustomText {
                Layout.fillWidth: true
                Layout.topMargin: -4
                Layout.leftMargin: 16
                content: "Links open in the phone's browser"
                size: 11
                weight: 400
                customColor: Colors.outline
                elide: Text.ElideRight
            }

            M3Button {
                Layout.fillWidth: true
                size: "small"
                variant: "tonal"
                icon: "content_paste"
                label: "Send this PC's clipboard"
                onClicked: ServicePhone.sendClipboard()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.ready && root.tab === "files"
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                M3Button {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    size: "small"
                    variant: "tonal"
                    icon: "folder_open"
                    label: "Browse phone"
                    onClicked: {
                        GlobalStates.phoneOpen = false
                        GlobalStates.phoneBrowserOpen = true
                    }
                }

                M3Button {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    size: "small"
                    variant: "tonal"
                    icon: "download"
                    label: "Downloads"
                    onClicked: root.launch(["xdg-open", ServicePhone.downloads])
                }
            }

            CustomText {
                content: "Recent"
                size: 13
                weight: 600
                customColor: Colors.primary
            }

            ListView {
                id: feed
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: -6
                visible: feed.count > 0
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
                        anchors.rightMargin: 9
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
                            size: 13
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
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            visible: entry.modelData.kind === "in" || entry.modelData.kind === "textIn"
                            icon: entry.modelData.kind === "in" ? "open_in_new" : "content_copy"
                            iconSize: 14
                            iconColor: Colors.outline
                            onClicked: {
                                if (entry.modelData.kind === "in")
                                    root.launch(["xdg-open", entry.modelData.path])
                                else
                                    Quickshell.execDetached(["wl-copy", entry.modelData.name])
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: feed.count === 0
                spacing: 6

                Item { Layout.fillHeight: true }
                MaterialIconSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    content: "swap_vert"
                    iconSize: 30
                    customColor: Colors.outline
                }
                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: "Nothing sent yet"
                    size: 14
                    weight: 600
                }
                CustomText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    content: "Files from the phone land in your Downloads folder"
                    size: 12
                    weight: 400
                    customColor: Colors.surfaceVariantText
                    wrapMode: Text.WordWrap
                }
                Item { Layout.fillHeight: true }
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

            Rectangle {
                Layout.fillWidth: true
                visible: root.mode === "waiting" || root.mode === "asked"
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
                    onClicked: {
                        ServicePhone.justPaired = false
                        root.tab = "send"
                    }
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
                    onClicked: {
                        GlobalStates.panelHold = true
                        ServicePhone.openKdeConnect()
                    }
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

        Item {
            Layout.fillHeight: true
            visible: root.mode !== "ready"
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 8
        visible: root.dragging && root.tab !== "send"
        radius: 22
        color: Qt.alpha(Colors.surface, 0.92)
        border.width: 2
        border.color: Colors.primary

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8
            MaterialIconSymbol {
                Layout.alignment: Qt.AlignHCenter
                content: "upload_file"
                iconSize: 34
                customColor: Colors.primary
            }
            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: "Drop to send to " + ServicePhone.label
                size: 15
                weight: 600
            }
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
