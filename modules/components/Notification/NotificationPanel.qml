import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    implicitHeight: ServiceNotification.popups.length > 0 ? innerItem.height + 20 : 0
    implicitWidth: 380
    anchors.right: parent.right
    anchors.bottom: parent.bottom

    Behavior on implicitHeight {
        NumberAnimation { easing.type: Easing.OutQuad; duration: 300 }
    }

    // property var notifications: ServiceNotification.popups
    //
    Item {
        id: innerItem
        width: 380
        height: list.contentHeight + 20
        anchors.bottom: parent.bottom
        anchors.right: parent.right

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 10
            orientation: Qt.Vertical
            model: ScriptModel { values: [...ServiceNotification.popups.reverse()]}
            spacing: 5
            interactive: false

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; from: list.width + 20; to: 0; duration: 350; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutQuad }
                }
            }


            addDisplaced: Transition{
                NumberAnimation{
                    property: "y,x"
                    duration: 300
                    easing.type: Easing.OutQuad
                }
            }

            move: Transition {
                NumberAnimation {
                    property: "y,x"
                    duration: 350
                    easing.type: Easing.OutQuad
                }
            }

            displaced: Transition {
                NumberAnimation {
                    property: "y,x"
                    duration: 350
                    easing.type: Easing.OutQuad
                }
            }


            delegate: Rectangle {
                id: popup
                required property var modelData
                required property real index
                implicitWidth: list.width
                implicitHeight: row.implicitHeight + 24
                radius: 18

                color: Colors.surfaceContainerHigh



                SequentialAnimation {
                    id: removeAnimation
                    PropertyAction { target: popup; property: "ListView.delayRemove"; value: true }

                    ParallelAnimation{
                        NumberAnimation { target: popup; property: "x"; to: list.width; duration: 350; easing.type: Easing.InCubic }
                        NumberAnimation { target: popup; property: "opacity"; from: 1; to: 0; duration: 250; easing.type: Easing.InQuad }
                    }
                    NumberAnimation { target: popup; property: "implicitHeight"; to: 0; duration: 250; easing.type: Easing.InCubic }

                    PropertyAction { target: popup; property: "ListView.delayRemove"; value: false }
                }
                ListView.onRemove: removeAnimation.start()

                RowLayout {
                    id: row
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: 12
                    spacing: 12

                    // App icon
                    Rectangle {
                        id: iconRect
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        Layout.alignment: Qt.AlignTop
                        radius: 12

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

                        readonly property string symbol: iconRect.resolveSymbol(popup.modelData.appIcon, popup.modelData.appName)
                        readonly property bool usesSymbol: iconRect.symbol !== ""

                        color: iconRect.usesSymbol ? Colors.primaryContainer : Qt.alpha(Colors.primary, 0.12)

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: iconRect.symbol
                            iconSize: 22
                            customColor: Colors.primaryContainerText
                            visible: iconRect.usesSymbol
                        }

                        Image {
                            id: panelIcon
                            anchors.fill: parent
                            anchors.margins: 7
                            source: iconRect.usesSymbol ? "" : IconUtil.getIconPath(popup.modelData.appIcon)
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectFit
                            visible: !iconRect.usesSymbol && status === Image.Ready
                        }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "notifications"
                            iconSize: 20
                            customColor: Colors.primaryContainerText
                            visible: !iconRect.usesSymbol && panelIcon.status !== Image.Ready
                        }
                    }

                    // Text content
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        // App name · time inline
                        RowLayout {
                            spacing: 4
                            visible: (popup.modelData.appName ?? "").length > 0

                            CustomText {
                                content: popup.modelData.appName ?? ""
                                size: 11
                                weight: 600
                                color: Colors.primary
                            }

                            CustomText {
                                content: "·"
                                size: 10
                                color: Colors.outline
                            }

                            CustomText {
                                content: {
                                    var diff = Date.now() - (popup.modelData.arrivalTimestamp ?? Date.now())
                                    var mins = Math.floor(diff / 60000)
                                    if (mins < 1)  return "now"
                                    if (mins < 60) return mins + "m ago"
                                    return Math.floor(mins / 60) + "h ago"
                                }
                                size: 10
                                color: Colors.outline
                            }
                        }

                        // Summary
                        CustomText {
                            Layout.fillWidth: true
                            content: popup.modelData.summary
                            size: 14
                            weight: 700
                            elide: Text.ElideRight
                        }

                        // Body
                        Text {
                            Layout.fillWidth: true
                            text: popup.modelData.body
                            font.pixelSize: 13
                            font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                            color: Colors.outline
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            visible: (popup.modelData.body ?? "").length > 0
                            bottomPadding: 2
                        }
                    }

                    // Optional inline image
                    Loader {
                        active: !!popup.modelData.image
                        visible: active
                        Layout.preferredHeight: 52
                        Layout.preferredWidth: 52
                        Layout.alignment: Qt.AlignVCenter
                        sourceComponent: Rectangle {
                            radius: 10
                            clip: true
                            color: "transparent"
                            Image {
                                anchors.fill: parent
                                source: popup.modelData.image
                                sourceSize: Qt.size(width, height)
                                fillMode: Image.PreserveAspectCrop
                            }
                        }
                    }
                }
            }
        }
    }
}
