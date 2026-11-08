import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.services

Item {
    id: row

    property var notifData: null
    property bool showIcon: true
    property bool reserveIconColumn: false
    property bool showAppName: true
    property bool isExtended: false
    property bool interactive: true

    readonly property bool hasBody: (row.notifData?.body ?? "").length > 0
    readonly property string imageSrc: IconUtil.imageSource(row.notifData?.image)
    readonly property bool hasImage: row.imageSrc !== "" && !row.imageSrc.startsWith("image://icon/")
    readonly property bool bigImage: row.hasImage && row.showIcon
    readonly property var defaultAction: (row.notifData?.notification?.actions ?? []).find(a => a.identifier === "default") ?? null
    readonly property var acts: {
        const out = []
        if (row.defaultAction)
            out.push({ label: "Open", act: row.defaultAction })
        for (const a of (row.notifData?.actions ?? []))
            out.push({ label: a.text ?? "", act: a })
        out.push({ label: "Copy", icon: "content_copy", kind: "copy" })
        out.push({ label: "Dismiss", icon: "close", kind: "dismiss" })
        return out
    }
    readonly property bool hasActions: row.acts.length > 2
    readonly property string clock: {
        const d = new Date(row.notifData?.arrivalTimestamp ?? Date.now())
        return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0")
    }

    function runAction(entry) {
        const item = row.notifData
        if (entry.kind === "copy") {
            Quickshell.clipboardText = [item?.summary ?? "", item?.body ?? ""].filter(t => t !== "").join("\n")
            row.copied = true
            copiedTimer.restart()
            return
        }
        if (entry.kind !== "dismiss") {
            if (Features.genie) ServiceGenie.armNotif(row, item)
            entry.act.invoke()
        }
        ServiceNotification.removeNotification(item)
    }

    property bool copied: false
    Timer {
        id: copiedTimer
        interval: 1400
        onTriggered: row.copied = false
    }

    onIsExtendedChanged: if (row.isExtended) extraFx.restart()

    SequentialAnimation {
        id: extraFx
        ScriptAction { script: { extraCol.opacity = 0; extraLift.y = 8 } }
        PauseAnimation { duration: 60 }
        ParallelAnimation {
            NumberAnimation { target: extraCol; property: "opacity"; to: 1; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { target: extraLift; property: "y"; to: 0; duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: M3Motion.panel.openCurve }
        }
    }

    property string relativeTime: row.computeRelative(row.notifData?.arrivalTimestamp ?? Date.now())

    function computeRelative(ts) {
        var diff = Date.now() - ts
        var mins = Math.floor(diff / 60000)
        if (mins < 1)  return "now"
        if (mins < 60) return mins + "m"
        var hrs = Math.floor(mins / 60)
        if (hrs < 24)  return hrs + "h"
        return Math.floor(hrs / 24) + "d"
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: row.relativeTime = row.computeRelative(row.notifData?.arrivalTimestamp ?? Date.now())
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

    readonly property string symbol: row.resolveSymbol(row.notifData?.appIcon, row.notifData?.appName)
    readonly property bool usesSymbol: row.symbol !== ""

    readonly property bool headerShowsAppName: row.isExtended && row.showAppName

    implicitHeight: col.implicitHeight
    Behavior on implicitHeight {
        NumberAnimation {
            duration: M3Motion.container.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: M3Motion.container.curve
        }
    }

    Item {
        id: swipe
        y: 0
        width: row.width
        height: row.height
        clip: true

        MouseArea {
            id: swipeArea
            anchors.fill: parent
            enabled: row.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            drag.target: swipe
            drag.axis: Drag.XAxis

            onPressed: event => {
                if (event.button === Qt.MiddleButton)
                    ServiceNotification.removeNotification(row.notifData)
            }
            onReleased: {
                if (Math.abs(swipe.x) < row.width * 0.35)
                    swipe.x = 0
                else
                    ServiceNotification.removeNotification(row.notifData)
            }
            onClicked: event => {
                if (event.button === Qt.LeftButton && Math.abs(swipe.x) < 4)
                    row.isExtended = !row.isExtended
            }
        }

        Behavior on x {
            enabled: !swipeArea.drag.active
            SpringAnimation {
                spring: Appearance.motion.swipeSpring
                damping: Appearance.motion.swipeDamping
                mass: Appearance.motion.swipeMass
                epsilon: 0.4
            }
        }

        opacity: 1 - Math.min(1, Math.abs(swipe.x) / (row.width || 1))

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item {
                    visible: row.showIcon || row.reserveIconColumn
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignTop

                    Rectangle {
                        anchors.fill: parent
                        visible: row.showIcon
                        radius: 18
                        color: row.usesSymbol ? Colors.primaryContainer
                                              : Qt.alpha(Colors.primary, 0.12)

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: row.symbol
                            iconSize: 19
                            customColor: Colors.primaryContainerText
                            visible: row.usesSymbol
                        }

                        Image {
                            id: appIconImage
                            anchors.fill: parent
                            anchors.margins: 6
                            source: row.usesSymbol ? "" : IconUtil.getIconPath(row.notifData?.appIcon ?? "")
                            sourceSize: Qt.size(24, 24)
                            fillMode: Image.PreserveAspectFit
                            visible: !row.usesSymbol && status === Image.Ready
                        }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "notifications"
                            iconSize: 17
                            customColor: Colors.primaryContainerText
                            visible: !row.usesSymbol && appIconImage.status !== Image.Ready
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        active: !row.showIcon && row.hasImage
                        visible: active

                        sourceComponent: ClippingRectangle {
                            radius: 18
                            color: Colors.surfaceContainerHighest

                            Image {
                                anchors.fill: parent
                                source: row.hasImage ? row.imageSrc : ""
                                sourceSize: Qt.size(72, 72)
                                asynchronous: row.imageSrc.startsWith("file:")
                                fillMode: Image.PreserveAspectCrop
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        CustomText {
                            Layout.fillWidth: !row.headerShowsAppName
                            content: row.headerShowsAppName
                                ? (row.notifData?.appName ?? "")
                                : (row.notifData?.summary ?? "")
                            size: row.headerShowsAppName ? 11 : 13
                            weight: row.headerShowsAppName ? 500 : 700
                            customColor: row.headerShowsAppName ? Colors.outline : Colors.surfaceText
                            elide: Text.ElideRight
                            wrapMode: row.isExtended && !row.headerShowsAppName ? Text.Wrap : Text.NoWrap
                            maximumLineCount: 3
                        }

                        CustomText {
                            content: "·"
                            size: 11
                            customColor: Colors.outline
                        }

                        CustomText {
                            content: row.isExtended ? row.clock : row.relativeTime
                            size: 11
                            customColor: Colors.outline
                        }

                        Item { Layout.fillWidth: row.headerShowsAppName }
                    }

                    CustomText {
                        Layout.fillWidth: true
                        visible: row.headerShowsAppName
                        content: row.notifData?.summary ?? ""
                        size: 13
                        weight: 700
                        wrapMode: Text.WordWrap
                    }

                    CustomText {
                        Layout.fillWidth: true
                        visible: row.hasBody
                        content: row.isExtended
                            ? (row.notifData?.body ?? "")
                            : (row.notifData?.body ?? "").replace(/\s+/g, " ")
                        size: 12
                        customColor: Colors.outline
                        wrapMode: row.isExtended ? Text.WordWrap : Text.NoWrap
                        elide: Text.ElideRight
                    }
                }

                Loader {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    active: row.bigImage && !row.isExtended
                    visible: active

                    sourceComponent: ClippingRectangle {
                        radius: 10
                        color: Colors.surfaceContainerHighest

                        Image {
                            anchors.fill: parent
                            source: row.imageSrc
                            sourceSize: Qt.size(80, 80)
                            asynchronous: row.imageSrc.startsWith("file:")
                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: row.showIcon ? 6 : 0
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 12
                    color: Colors.surfaceContainerHighest

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "keyboard_arrow_down"
                        iconSize: 16
                        customColor: Colors.surfaceVariantText
                        rotation: row.isExtended ? 180 : 0
                        Behavior on rotation {
                            NumberAnimation {
                                duration: M3Motion.container.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: M3Motion.container.curve
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: row.isExtended = !row.isExtended
                    }
                }
            }

            ColumnLayout {
                id: extraCol
                visible: row.isExtended
                Layout.fillWidth: true
                Layout.leftMargin: row.showIcon || row.reserveIconColumn ? 46 : 0
                Layout.topMargin: 8
                Layout.bottomMargin: 2
                spacing: 10
                transform: Translate { id: extraLift }

                ClippingRectangle {
                    visible: row.bigImage
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(170, Math.round(extraCol.width * 0.56))
                    radius: 14
                    color: Colors.surfaceContainerHighest

                    Image {
                        anchors.fill: parent
                        source: row.isExtended && row.bigImage ? row.imageSrc : ""
                        sourceSize: Qt.size(640, 360)
                        asynchronous: row.imageSrc.startsWith("file:")
                        fillMode: Image.PreserveAspectCrop
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: row.acts

                        delegate: Rectangle {
                            id: actionBtn
                            required property var modelData
                            required property int index
                            readonly property bool builtIn: !!actionBtn.modelData.kind
                            readonly property bool primary: actionBtn.index === 0 && !actionBtn.builtIn
                            width: actionInner.implicitWidth + (actionBtn.builtIn ? 24 : 28)
                            height: 32
                            radius: 16
                            color: actionBtn.primary
                                ? (actionHover.containsMouse ? Qt.lighter(Colors.primary, 1.08) : Colors.primary)
                                : actionHover.containsMouse ? Qt.alpha(Colors.primary, 0.10) : "transparent"
                            border.width: actionBtn.primary ? 0 : 1
                            border.color: Colors.outlineVariant
                            Behavior on color { EffectsColorAnim {} }

                            RowLayout {
                                id: actionInner
                                anchors.centerIn: parent
                                spacing: 5

                                MaterialIconSymbol {
                                    visible: actionBtn.builtIn
                                    content: actionBtn.modelData.kind === "copy" && row.copied ? "check" : (actionBtn.modelData.icon ?? "")
                                    iconSize: 15
                                    customColor: Colors.surfaceVariantText
                                }

                                CustomText {
                                    content: actionBtn.modelData.kind === "copy" && row.copied ? "Copied" : actionBtn.modelData.label
                                    size: 12
                                    weight: 600
                                    customColor: actionBtn.primary ? Colors.primaryText
                                               : actionBtn.builtIn ? Colors.surfaceVariantText : Colors.surfaceText
                                }
                            }

                            MouseArea {
                                id: actionHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: row.runAction(actionBtn.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
