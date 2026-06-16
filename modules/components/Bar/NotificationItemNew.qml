import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services

Rectangle {
    id: notif
    property bool isExtended: false

    property real topRadius: 20
    property real bottomRadius: 20

    readonly property var notifData: modelData
    readonly property bool hasActions: modelData.actions.length > 0
    readonly property bool hasBody: (modelData.body ?? "").length > 0
    readonly property bool hasImage: !!modelData.image

    property string relativeTime: notif.computeRelative(modelData.arrivalTimestamp)

    function computeRelative(ts) {
        var diff = Date.now() - ts
        var mins = Math.floor(diff / 60000)
        if (mins < 1)  return "now"
        if (mins < 60) return mins + "m ago"
        var hrs = Math.floor(mins / 60)
        if (hrs < 24)  return hrs + "h ago"
        return Math.floor(hrs / 24) + "d ago"
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: notif.relativeTime = notif.computeRelative(modelData.arrivalTimestamp)
    }

    function resolveSymbol(appIcon, appName) {
        const ic = (appIcon || "").toLowerCase()
        const ap = (appName || "").toLowerCase()
        if (ic.includes("camera-photo") || ap.includes("screenshot")) return "photo_camera"
        if (ic.includes("camera-video") || ap.includes("record"))     return "screen_record"
        if (ic.includes("dialog-error") || ic.includes("error"))      return "error_outline"
        if (ic.includes("bluetooth"))                                  return "bluetooth"
        if (ic.includes("network") || ic.includes("wifi"))            return "wifi"
        if (ic.includes("battery"))                                    return "battery_std"
        if (ic.includes("volume") || ic.includes("audio"))            return "volume_up"
        return ""
    }

    readonly property string symbol: notif.resolveSymbol(modelData.appIcon, modelData.appName)
    readonly property bool usesSymbol: notif.symbol !== ""

    // Height is driven entirely by content — no hardcoded magic numbers
    implicitWidth: parent ? parent.width : 0
    implicitHeight: contentCol.implicitHeight + 20

    topLeftRadius: topRadius
    topRightRadius: topRadius
    bottomLeftRadius: bottomRadius
    bottomRightRadius: bottomRadius
    color: Colors.surfaceContainerHigh
    clip: true
    x: 0

    Behavior on x {
        NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
    }

    // ── Drag to dismiss / expand ─────────────────────────────────────────
    MouseArea {
        property int startY: 0
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        preventStealing: true
        drag.target: parent
        drag.axis: Drag.XAxis

        onPressed: event => {
            startY = event.y
            if (event.button === Qt.MiddleButton)
                ServiceNotification.removeNotification(modelData)
        }
        onReleased: {
            if (Math.abs(notif.x) < notif.width * 0.3)
                notif.x = 0
            else
                ServiceNotification.removeNotification(modelData)
        }
        onPositionChanged: event => {
            if (pressed) {
                const dy = event.y - startY
                if (Math.abs(dy) > 24)
                    notif.isExtended = dy > 0
            }
        }
    }

    // ── Content ──────────────────────────────────────────────────────────
    ColumnLayout {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 10
        spacing: 0

        // ── Header (always visible) ──────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // M3 icon container
            Rectangle {
                width: 40; height: 40
                radius: 12
                color: notif.usesSymbol ? Colors.primaryContainer : Qt.alpha(Colors.primary, 0.12)

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: notif.symbol
                    iconSize: 20
                    customColor: Colors.primaryContainerText
                    visible: notif.usesSymbol
                }

                Image {
                    id: itemIcon
                    anchors.fill: parent
                    anchors.margins: 6
                    source: notif.usesSymbol ? "" : IconUtil.getIconPath(modelData.appIcon)
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectFit
                    visible: !notif.usesSymbol && status === Image.Ready
                }

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: "notifications"
                    iconSize: 18
                    customColor: Colors.primaryContainerText
                    visible: !notif.usesSymbol && itemIcon.status !== Image.Ready
                }
            }

            // App name + summary
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    spacing: 4
                    visible: (modelData.appName ?? "").length > 0

                    CustomText {
                        content: modelData.appName ?? ""
                        size: 11
                        weight: 600
                        customColor: Colors.primary
                    }

                    CustomText {
                        content: "·"
                        size: 10
                        customColor: Colors.outline
                    }

                    CustomText {
                        content: notif.relativeTime
                        size: 10
                        customColor: Colors.outline
                    }
                }

                CustomText {
                    Layout.fillWidth: true
                    content: modelData.summary ?? ""
                    size: 13
                    weight: 600
                    elide: Text.ElideRight
                }
            }

            // Chevron
            Rectangle {
                width: 22; height: 22
                radius: 11
                color: Colors.surfaceContainerHighest

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: "keyboard_arrow_down"
                    iconSize: 16
                    rotation: notif.isExtended ? 180 : 0
                    Behavior on rotation {
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: notif.isExtended = !notif.isExtended
                }
            }
        }

        // ── Body ─────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: (notif.isExtended && notif.hasBody)
                ? bodyText.implicitHeight + 8 : 0
            clip: true
            visible: notif.hasBody

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            CustomText {
                id: bodyText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 50
                anchors.top: parent.top
                anchors.topMargin: 4
                content: modelData.body ?? ""
                size: 12
                weight: 400
                customColor: Colors.outline
                wrapMode: Text.WordWrap
                opacity: notif.isExtended ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                }
            }
        }

        // ── Image ─────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: (notif.isExtended && notif.hasImage) ? 80 : 0
            visible: notif.hasImage
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.top: parent.top
                width: 80
                height: 80
                radius: 12
                clip: true
                color: Colors.surfaceContainerHighest
                opacity: notif.isExtended ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                }

                Image {
                    anchors.fill: parent
                    source: modelData.image ?? ""
                    fillMode: Image.PreserveAspectCrop
                }
            }
        }

        // ── Actions (button group) ────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: notif.hasActions ? 38 : 0
            clip: true
            visible: notif.hasActions

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            ButtonGroup {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                fillWidth: true
                model: notif.notifData.actions.map((a, i) => ({ value: i, label: a.text }))
                activeCheck: function(value) { return false }
                onSegmentClicked: value => {
                    notif.notifData.actions[value].invoke()
                    ServiceNotification.removeNotification(notif.notifData)
                }
            }
        }

        Item { Layout.preferredHeight: 2 }
    }
}
