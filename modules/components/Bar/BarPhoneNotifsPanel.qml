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
    readonly property var list: ServicePhone.notifications
    readonly property int count: root.list.length
    property string expandedId: ""
    property string sentId: ""

    readonly property string openId: {
        if (root.list.some(n => n.id === root.expandedId))
            return root.expandedId
        const r = root.list.find(n => n.replyId !== "")
        return r ? r.id : root.count > 0 ? root.list[0].id : ""
    }

    readonly property real headH: header.implicitHeight + 28
    readonly property real listRoom: Math.max(140, root.maxHeight - root.headH - 14)
    readonly property real listH: root.count === 0 ? empty.implicitHeight : Math.min(root.listRoom, rows.implicitHeight)

    implicitWidth: 420
    implicitHeight: root.headH + root.listH + 14

    onVisibleChanged: {
        GlobalStates.phoneNotifsPanelOpen = root.visible
        if (root.visible) {
            ServicePhone.peek = null
            ServicePhone.refreshNotifications()
        } else {
            ServicePhone.markRead()
        }
    }
    Component.onCompleted: GlobalStates.phoneNotifsPanelOpen = root.visible
    Component.onDestruction: {
        GlobalStates.phoneNotifsPanelOpen = false
        ServicePhone.markRead()
    }

    Timer {
        id: sentTimer
        interval: 2000
        onTriggered: root.sentId = ""
    }

    RowLayout {
        id: header
        x: 16
        y: 14
        width: root.width - 32
        spacing: 10

        Rectangle {
            implicitWidth: 36
            implicitHeight: 36
            radius: 12
            color: Colors.secondaryContainer
            MaterialIconSymbol {
                anchors.centerIn: parent
                content: ServicePhone.muted ? "notifications_off" : "smartphone"
                iconSize: 19
                customColor: Colors.secondaryContainerText
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            CustomText {
                Layout.fillWidth: true
                content: ServicePhone.label
                size: 15
                weight: 600
                elide: Text.ElideRight
            }
            CustomText {
                Layout.fillWidth: true
                content: !ServicePhone.ready ? "Not nearby"
                    : (root.count === 0 ? "Nothing new" : root.count === 1 ? "1 notification" : root.count + " notifications")
                      + (ServicePhone.muted ? ", muted" : "")
                size: 12
                weight: 400
                customColor: Colors.surfaceVariantText
                elide: Text.ElideRight
            }
        }

        M3Button {
            size: "xsmall"
            variant: "tonal"
            toggled: ServicePhone.muted
            icon: ServicePhone.muted ? "notifications_off" : ""
            label: ServicePhone.muted ? "Unmute" : "Mute 1 hour"
            onClicked: ServicePhone.mute(ServicePhone.muted ? 0 : 3600000)
        }

        M3Button {
            visible: root.count > 0
            size: "xsmall"
            variant: "tonal"
            label: "Clear all"
            onClicked: ServicePhone.dismissAll()
        }
    }

    ColumnLayout {
        id: empty
        visible: root.count === 0
        y: root.headH
        x: 16
        width: root.width - 32
        spacing: 6

        Item { implicitHeight: 6 }
        MaterialIconSymbol {
            Layout.alignment: Qt.AlignHCenter
            content: ServicePhone.ready ? "done_all" : "mobile_off"
            iconSize: 30
            customColor: Colors.outline
        }
        CustomText {
            Layout.alignment: Qt.AlignHCenter
            content: ServicePhone.ready ? "You're all caught up" : "Your phone isn't on this Wi-Fi"
            size: 14
            weight: 600
        }
        CustomText {
            Layout.fillWidth: true
            Layout.bottomMargin: 10
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            content: ServicePhone.ready
                ? "New notifications from your phone land here. If none ever show, allow notification sync in the KDE Connect app on the phone."
                : "They'll show here again once it's back nearby."
            size: 12
            weight: 400
            customColor: Colors.surfaceVariantText
        }
    }

    Flickable {
        id: flick
        visible: root.count > 0
        x: 10
        y: root.headH
        width: root.width - 20
        height: root.listH
        contentHeight: rows.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ColumnLayout {
            id: rows
            width: flick.width
            spacing: 4

            Repeater {
                model: root.list

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool expanded: root.openId === row.modelData.id
                    readonly property bool canReply: row.modelData.replyId !== ""
                    readonly property string age: ServicePhone.age(row.modelData.id)
                    readonly property bool unread: ServicePhone.unreadIds[row.modelData.id] === true
                    Layout.fillWidth: true
                    implicitHeight: body.implicitHeight + 20
                    radius: 16
                    color: row.expanded ? Colors.surfaceContainerHigh
                         : rowHover.hovered ? Colors.surfaceContainer : Qt.alpha(Colors.surfaceContainer, 0)
                    Behavior on color { EffectsColorAnim { speed: "fast" } }

                    HoverHandler { id: rowHover }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: row.expanded ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: root.expandedId = row.modelData.id
                    }

                    ColumnLayout {
                        id: body
                        x: 10
                        y: 10
                        width: row.width - 20
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            PhoneNotifAvatar {
                                Layout.alignment: Qt.AlignTop
                                notif: row.modelData
                                size: 34
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Rectangle {
                                        visible: row.unread
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: 8
                                        implicitHeight: 8
                                        radius: 4
                                        color: Colors.primary
                                    }
                                    CustomText {
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: implicitWidth
                                        content: row.modelData.title || row.modelData.app
                                        size: 13
                                        weight: 600
                                        elide: Text.ElideRight
                                    }
                                    CustomText {
                                        content: [row.modelData.title ? row.modelData.app : "", row.age].filter(t => t !== "").join(", ")
                                        size: 11
                                        weight: 400
                                        customColor: Colors.outline
                                        elide: Text.ElideRight
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    visible: content !== ""
                                    content: row.modelData.text
                                    size: 13
                                    weight: 400
                                    customColor: Colors.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: row.expanded ? 8 : 2
                                    elide: Text.ElideRight
                                }
                            }

                            M3IconButton {
                                Layout.alignment: Qt.AlignTop
                                readonly property bool live: row.modelData.dismissable && (rowHover.hovered || row.expanded)
                                visible: row.modelData.dismissable
                                enabledButton: live
                                opacity: live ? 1 : 0
                                implicitWidth: 28
                                implicitHeight: 28
                                icon: "close"
                                iconSize: 16
                                color: "transparent"
                                onClicked: ServicePhone.dismiss(row.modelData.id)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 44
                            visible: row.expanded && row.canReply
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: 17
                                color: Colors.surfaceContainerHighest
                                border.width: replyIn.activeFocus ? 2 : 0
                                border.color: Colors.primary

                                TextInput {
                                    id: replyIn
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
                                    onAccepted: send()
                                    Keys.onEscapePressed: { text = ""; focus = false }

                                    function send() {
                                        if (text.trim() === "") return
                                        ServicePhone.reply(row.modelData.id, text)
                                        text = ""
                                        root.sentId = row.modelData.id
                                        sentTimer.restart()
                                    }

                                    CustomText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: replyIn.text === ""
                                        content: root.sentId === row.modelData.id ? "Sent"
                                            : "Reply to " + (row.modelData.title || row.modelData.app)
                                        size: 13
                                        weight: 400
                                        customColor: root.sentId === row.modelData.id ? Colors.primary : Colors.outline
                                        elide: Text.ElideRight
                                        width: replyIn.width
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
                                enabledButton: replyIn.text.trim() !== ""
                                opacity: enabledButton ? 1 : 0.5
                                onClicked: replyIn.send()
                            }
                        }

                        M3Button {
                            Layout.leftMargin: 44
                            visible: row.expanded && row.modelData.dismissable
                            size: "xsmall"
                            variant: "text"
                            icon: "done_all"
                            label: "Mark as read"
                            onClicked: ServicePhone.dismiss(row.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
