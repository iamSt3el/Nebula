pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings

Item {
    id: root

    property real maxHeight: 640
    readonly property var call: ServicePhone.call
    readonly property var missed: ServicePhone.missedCalls
    readonly property var quick: ["Can't talk, I'll call you back", "In a meeting", "On my way"]
    property real now: Date.now()
    property string sentTo: ""
    property real replyAt: -1

    readonly property real listRoom: Math.max(120, root.maxHeight - 32 - (missedHead.visible ? missedHead.implicitHeight + 14 : 0)
        - (callBox.visible ? callBox.implicitHeight + 14 : 0) - (divider.visible ? 15 : 0))

    implicitWidth: 400
    implicitHeight: body.implicitHeight + 32

    onVisibleChanged: {
        GlobalStates.phoneCallPanelOpen = root.visible
        if (!root.visible) {
            root.replyAt = -1
            root.sentTo = ""
        }
    }
    Component.onCompleted: GlobalStates.phoneCallPanelOpen = root.visible
    Component.onDestruction: GlobalStates.phoneCallPanelOpen = false

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    Timer {
        id: sentTimer
        interval: 2500
        onTriggered: root.sentTo = ""
    }

    function send(number, text) {
        if (text.trim() === "")
            return
        ServicePhone.textBack(number, text)
        root.sentTo = number
        sentTimer.restart()
    }

    function clock(ms) {
        const s = Math.max(0, Math.floor(ms / 1000))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    function ago(at) {
        const m = Math.floor((root.now - at) / 60000)
        if (m < 1) return "just now"
        if (m < 60) return m + " min ago"
        const h = Math.floor(m / 60)
        if (h < 24) return h + " h ago"
        return Qt.formatDateTime(new Date(at), "ddd hh:mm")
    }

    component Replies: ColumnLayout {
        id: replies
        property string number: ""
        spacing: 8

        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.quick
                delegate: M3Button {
                    required property string modelData
                    size: "xsmall"
                    variant: "tonal"
                    label: modelData
                    onClicked: root.send(replies.number, modelData)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 17
                color: Colors.surfaceContainerHighest
                border.width: msgIn.activeFocus ? 2 : 0
                border.color: Colors.primary

                TextInput {
                    id: msgIn
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colors.surfaceText
                    selectionColor: Colors.primary
                    selectedTextColor: Colors.primaryText
                    font.pixelSize: 13
                    font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                    selectByMouse: true
                    clip: true
                    onAccepted: { root.send(replies.number, text); text = "" }
                    Keys.onEscapePressed: { text = ""; focus = false }

                    CustomText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: msgIn.text === ""
                        content: root.sentTo === replies.number ? "Sent" : "Write a message"
                        size: 13
                        weight: 400
                        customColor: root.sentTo === replies.number ? Colors.primary : Colors.outline
                    }
                }
            }

            M3IconButton {
                implicitWidth: 34
                implicitHeight: 34
                icon: "send"
                iconSize: 17
                color: Colors.primary
                iconColor: Colors.primaryText
                iconHoverColor: Colors.primaryText
                enabledButton: msgIn.text.trim() !== ""
                opacity: enabledButton ? 1 : 0.5
                onClicked: { root.send(replies.number, msgIn.text); msgIn.text = "" }
            }
        }
    }

    ColumnLayout {
        id: body
        x: 16
        y: 16
        width: root.width - 32
        spacing: 14

        ColumnLayout {
            id: callBox
            Layout.fillWidth: true
            visible: root.call !== null
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                PhoneNotifAvatar {
                    notif: root.call ? { app: root.call.name, title: root.call.name, icon: root.call.photo } : null
                    size: 64
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    CustomText {
                        Layout.fillWidth: true
                        content: root.call ? root.call.name : ""
                        size: 20
                        weight: 600
                        elide: Text.ElideRight
                    }
                    CustomText {
                        Layout.fillWidth: true
                        content: root.call ? [root.call.name !== root.call.number ? root.call.number : "",
                                              "ringing " + root.clock(root.now - root.call.since)]
                                             .filter(t => t !== "").join(", ") : ""
                        size: 13
                        weight: 400
                        customColor: Colors.surfaceVariantText
                        elide: Text.ElideRight
                    }
                }
            }

            M3Button {
                Layout.fillWidth: true
                size: "small"
                variant: "filled"
                icon: "notifications_off"
                label: ServicePhone.ringerMuted ? "Ringer silenced" : "Silence ringer"
                enabledButton: !ServicePhone.ringerMuted
                opacity: enabledButton ? 1 : 0.6
                onClicked: ServicePhone.silenceRinger()
            }

            CustomText {
                content: "Text back instead"
                size: 13
                weight: 600
                customColor: Colors.surfaceVariantText
            }

            Replies {
                Layout.fillWidth: true
                number: root.call ? root.call.number : ""
            }
        }

        Rectangle {
            id: divider
            Layout.fillWidth: true
            visible: root.call !== null && root.missed.length > 0
            implicitHeight: 1
            color: Colors.outlineVariant
        }

        RowLayout {
            id: missedHead
            Layout.fillWidth: true
            visible: root.call === null || root.missed.length > 0
            spacing: 10

            CustomText {
                Layout.fillWidth: true
                content: root.missed.length === 0 ? "No missed calls"
                    : root.missed.length === 1 ? "1 missed call" : root.missed.length + " missed calls"
                size: 15
                weight: 600
            }

            M3Button {
                visible: root.missed.length > 0
                size: "xsmall"
                variant: "tonal"
                label: "Clear all"
                onClicked: ServicePhone.clearMissed()
            }
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            visible: root.missed.length > 0
            implicitHeight: Math.min(rows.implicitHeight, root.listRoom)
            contentHeight: rows.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            ColumnLayout {
                id: rows
                width: flick.width
                spacing: 4

                Repeater {
                    model: root.missed

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property bool expanded: root.replyAt === row.modelData.at
                        Layout.fillWidth: true
                        implicitHeight: rowBody.implicitHeight + 20
                        radius: 16
                        color: row.expanded ? Colors.surfaceContainerHigh
                             : rowHover.hovered ? Colors.surfaceContainer : Qt.alpha(Colors.surfaceContainer, 0)
                        Behavior on color { EffectsColorAnim { speed: "fast" } }

                        HoverHandler { id: rowHover }

                        ColumnLayout {
                            id: rowBody
                            x: 10
                            y: 10
                            width: row.width - 20
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                PhoneNotifAvatar {
                                    notif: { "app": row.modelData.name, "title": row.modelData.name, "icon": "" }
                                    size: 34
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    CustomText {
                                        Layout.fillWidth: true
                                        content: row.modelData.name
                                        size: 13
                                        weight: 600
                                        elide: Text.ElideRight
                                    }
                                    CustomText {
                                        Layout.fillWidth: true
                                        content: [row.modelData.name !== row.modelData.number ? row.modelData.number : "",
                                                  root.ago(row.modelData.at)].filter(t => t !== "").join(", ")
                                        size: 11
                                        weight: 400
                                        customColor: Colors.outline
                                        elide: Text.ElideRight
                                    }
                                }

                                M3IconButton {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    icon: "sms"
                                    iconSize: 17
                                    color: row.expanded ? Colors.primary : Colors.surfaceContainerHighest
                                    iconColor: row.expanded ? Colors.primaryText : Colors.surfaceText
                                    iconHoverColor: row.expanded ? Colors.primaryText : Colors.surfaceText
                                    onClicked: root.replyAt = row.expanded ? -1 : row.modelData.at
                                }

                                M3IconButton {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    icon: "close"
                                    iconSize: 16
                                    color: Qt.alpha(Colors.surfaceContainerHighest, 0)
                                    onClicked: ServicePhone.forgetMissed(row.modelData.at)
                                }
                            }

                            Replies {
                                Layout.fillWidth: true
                                visible: row.expanded
                                number: row.modelData.number
                            }
                        }
                    }
                }
            }
        }
    }
}
