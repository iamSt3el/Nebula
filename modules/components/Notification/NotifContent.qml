import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

ColumnLayout {
    id: root

    property var notif: null
    property int bodyLines: 2
    property bool showActions: true
    property bool showClose: true
    property int iconBox: 44
    property color chipColor: Colors.surfaceContainerHighest

    readonly property var defaultAction: (root.notif?.notification?.actions ?? []).find(a => a.identifier === "default") ?? null
    readonly property var extraActions: (root.notif?.actions ?? []).slice(0, 3)
    readonly property string imageSrc: IconUtil.imageSource(root.notif?.image)

    spacing: 10

    function dismiss() {
        if (root.notif) root.notif.popup = false
    }

    function openDefault() {
        if (root.defaultAction) root.defaultAction.invoke()
        root.dismiss()
    }

    function symbolFor(appIcon, appName) {
        const ic = (appIcon || "").toLowerCase()
        const ap = (appName || "").toLowerCase()
        if (ic.includes("camera-photo") || ap.includes("screenshot")) return "photo_camera"
        if (ic.includes("camera-video") || ap.includes("record")) return "screen_record"
        if (ic.includes("dialog-error") || ic.includes("error")) return "error_outline"
        if (ic.includes("bluetooth")) return "bluetooth"
        if (ic.includes("network") || ic.includes("wifi")) return "wifi"
        if (ic.includes("battery")) return "battery_std"
        if (ic.includes("volume") || ic.includes("audio")) return "volume_up"
        return ""
    }

    function ago(ts) {
        const mins = Math.floor((Date.now() - (ts ?? Date.now())) / 60000)
        if (mins < 1) return "now"
        if (mins < 60) return mins + "m ago"
        return Math.floor(mins / 60) + "h ago"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle {
            id: iconRect
            Layout.preferredWidth: root.iconBox
            Layout.preferredHeight: root.iconBox
            Layout.alignment: Qt.AlignTop
            radius: root.iconBox * 0.28
            readonly property string symbol: root.symbolFor(root.notif?.appIcon, root.notif?.appName)
            color: iconRect.symbol !== "" ? Colors.primaryContainer : Qt.alpha(Colors.primary, 0.12)

            MaterialIconSymbol {
                anchors.centerIn: parent
                content: iconRect.symbol !== "" ? iconRect.symbol : "notifications"
                iconSize: Math.round(root.iconBox * 0.5)
                customColor: Colors.primaryContainerText
                visible: iconRect.symbol !== "" || appIcon.status !== Image.Ready
            }

            Image {
                id: appIcon
                anchors.fill: parent
                anchors.margins: root.iconBox * 0.16
                source: iconRect.symbol !== "" ? "" : IconUtil.getIconPath(root.notif?.appIcon ?? "")
                sourceSize.width: 88
                sourceSize.height: 88
                fillMode: Image.PreserveAspectFit
                visible: iconRect.symbol === "" && status === Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                CustomText {
                    content: root.notif?.appName ?? ""
                    size: 11
                    weight: 600
                    customColor: Colors.primary
                    visible: (root.notif?.appName ?? "") !== ""
                }
                CustomText {
                    content: "·  " + root.ago(root.notif?.arrivalTimestamp)
                    size: 10
                    customColor: Colors.outline
                }
                Item { Layout.fillWidth: true }
            }

            CustomText {
                Layout.fillWidth: true
                content: root.notif?.summary ?? ""
                size: 14
                weight: 700
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.notif?.body ?? ""
                font.pixelSize: 13
                font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                color: Colors.surfaceVariantText
                wrapMode: Text.WordWrap
                maximumLineCount: root.bodyLines
                elide: Text.ElideRight
                textFormat: Text.PlainText
                visible: (root.notif?.body ?? "") !== ""
            }
        }

        Loader {
            active: root.imageSrc !== "" && !root.imageSrc.startsWith("image://icon/")
            visible: active
            Layout.preferredWidth: 52
            Layout.preferredHeight: 52
            Layout.alignment: Qt.AlignVCenter
            sourceComponent: Rectangle {
                radius: 12
                clip: true
                color: "transparent"
                Image {
                    anchors.fill: parent
                    source: root.imageSrc
                    sourceSize.width: 104
                    sourceSize.height: 104
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: root.imageSrc.startsWith("file:")
                }
            }
        }

        Rectangle {
            visible: root.showClose
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Layout.alignment: Qt.AlignTop
            radius: 14
            color: closeArea.containsMouse ? root.chipColor : "transparent"
            MaterialIconSymbol {
                anchors.centerIn: parent
                content: "close"
                iconSize: 16
                customColor: Colors.outline
            }
            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dismiss()
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        Layout.leftMargin: root.iconBox + 12
        spacing: 6
        visible: root.showActions && root.extraActions.length > 0

        Repeater {
            model: root.showActions ? root.extraActions : []
            delegate: Rectangle {
                id: act
                required property var modelData
                required property int index
                implicitWidth: actText.implicitWidth + 28
                implicitHeight: 32
                radius: 16
                color: act.index === 0 ? Colors.primary : (actArea.containsMouse ? Qt.lighter(root.chipColor, 1.15) : root.chipColor)

                CustomText {
                    id: actText
                    anchors.centerIn: parent
                    content: act.modelData.text ?? ""
                    size: 12
                    weight: 600
                    customColor: act.index === 0 ? Colors.primaryText : Colors.surfaceText
                }

                MouseArea {
                    id: actArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const n = root.notif
                        act.modelData.invoke()
                        if (n) n.popup = false
                    }
                }
            }
        }
    }
}
