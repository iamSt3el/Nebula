pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings

Item {
    id: root

    readonly property bool usbIn: ServiceKindle.usb !== "none"
    readonly property string pendingLabel: {
        if (ServiceKindle.pending === "image") return "Preparing the image"
        if (ServiceKindle.pending === "fit") return "Re-fitting"
        if (ServiceKindle.pending === "push") return "Copying to the Kindle"
        if (ServiceKindle.pending === "clear") return "Removing"
        return ""
    }
    readonly property string delivery: {
        if (!ServiceKindle.hasFrame) return "Pick an image, then plug in the Kindle or turn on Wi-Fi"
        if (ServiceKindle.onKindle) return "On the Kindle. It shows on the Frame tab and when idle"
        if (root.usbIn) return "Kindle plugged in. Send it over USB"
        if (ServiceKindle.serving) return "The Kindle picks it up the next time it rests"
        return "Plug in the Kindle, or turn on Wi-Fi sending"
    }

    Component.onCompleted: ServiceKindle.retain()
    Component.onDestruction: ServiceKindle.release()

    implicitWidth: 400
    implicitHeight: col.implicitHeight + 32

    ColumnLayout {
        id: col
        x: 16
        y: 16
        width: root.width - 32
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 14
                color: Colors.primaryContainer
                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: "auto_stories"
                    iconSize: 22
                    customColor: Colors.primaryContainerText
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                CustomText {
                    content: "Kindle frame"
                    size: 16
                    weight: 600
                }
                CustomText {
                    Layout.fillWidth: true
                    content: ServiceKindle.name !== "" ? ServiceKindle.name : "No image yet"
                    size: 12
                    weight: 400
                    customColor: Colors.surfaceVariantText
                    elide: Text.ElideMiddle
                    maximumLineCount: 1
                }
            }

            Rectangle {
                implicitWidth: chipRow.implicitWidth + 20
                implicitHeight: 28
                radius: 14
                color: root.usbIn ? Colors.secondaryContainer : Colors.surfaceContainerHigh
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialIconSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        content: root.usbIn ? "usb" : ServiceKindle.serving ? "wifi" : "link_off"
                        iconSize: 15
                        customColor: root.usbIn ? Colors.secondaryContainerText : Colors.surfaceVariantText
                    }
                    CustomText {
                        anchors.verticalCenter: parent.verticalCenter
                        content: root.usbIn ? "USB" : ServiceKindle.serving ? "Wi-Fi" : "Offline"
                        size: 12
                        weight: 500
                        customColor: root.usbIn ? Colors.secondaryContainerText : Colors.surfaceVariantText
                    }
                }
            }
        }

        Rectangle {
            id: stage
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(width * 3 / 4)
            radius: 20
            color: Colors.surfaceContainerHigh
            clip: true
            border.width: drop.containsDrag ? 2 : 0
            border.color: Colors.primary

            Image {
                id: shot
                anchors.fill: parent
                anchors.margins: 6
                visible: ServiceKindle.preview !== ""
                source: ServiceKindle.preview !== "" ? "file://" + ServiceKindle.preview + "?" + ServiceKindle.updated : ""
                sourceSize: Qt.size(800, 600)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                smooth: true
                mipmap: true
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: ServiceKindle.preview === "" && !ServiceKindle.busy
                spacing: 6
                MaterialIconSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    content: "add_photo_alternate"
                    iconSize: 36
                    customColor: Colors.outline
                }
                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: "Drop an image here"
                    size: 13
                    weight: 500
                    customColor: Colors.surfaceVariantText
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: ServiceKindle.busy || drop.containsDrag
                color: Qt.alpha(Colors.surfaceContainerHigh, 0.82)
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    CustomCircularLoader {
                        Layout.alignment: Qt.AlignHCenter
                        visible: ServiceKindle.busy
                        size: 44
                    }
                    MaterialIconSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        visible: !ServiceKindle.busy
                        content: "download"
                        iconSize: 32
                        customColor: Colors.primary
                    }
                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: ServiceKindle.busy ? root.pendingLabel : "Drop to use on the Kindle"
                        size: 13
                        weight: 500
                    }
                }
            }

            DropArea {
                id: drop
                anchors.fill: parent
                keys: ["text/uri-list"]
                onDropped: e => {
                    if (e.hasUrls && e.urls.length > 0)
                        ServiceKindle.setImage(decodeURIComponent(e.urls[0].toString().replace(/^file:\/\//, "")))
                }
            }
        }

        M3ButtonGroup {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            fillWidth: true
            textSize: 13
            iconSize: 16
            enabled: !ServiceKindle.busy
            model: [{ value: "cover", label: "Fill screen", icon: "crop" },
                    { value: "contain", label: "Whole image", icon: "fit_screen" }]
            activeCheck: v => ServiceKindle.fit === v
            onSegmentClicked: v => ServiceKindle.setFit(v)
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: ServiceWallpaper.wallpapers.length > 0
            spacing: 6

            CustomText {
                Layout.leftMargin: 2
                content: "Wallpapers"
                size: 12
                weight: 600
                customColor: Colors.primary
            }

            ListView {
                id: strip
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                orientation: ListView.Horizontal
                spacing: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: ServiceWallpaper.wallpapers
                interactive: !ServiceKindle.busy

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: e => strip.contentX = Math.max(0, Math.min(strip.contentWidth - strip.width,
                        strip.contentX - (e.angleDelta.y !== 0 ? e.angleDelta.y : e.angleDelta.x)))
                }

                delegate: Rectangle {
                    id: thumb
                    required property string modelData
                    readonly property string original: ServiceWallpaper.getOriginalPath(thumb.modelData) ?? ""
                    readonly property bool chosen: ServiceKindle.name !== "" && thumb.original.endsWith("/" + ServiceKindle.name)
                    width: 80
                    height: 60
                    radius: thumbArea.pressed ? 8 : 12
                    color: Colors.surfaceContainerHighest
                    border.width: thumb.chosen ? 3 : 0
                    border.color: Colors.primary
                    Behavior on radius { SpatialAnim { speed: "fast" } }

                    RoundedImage {
                        anchors.fill: parent
                        anchors.margins: thumb.chosen ? 4 : 0
                        source: "file://" + thumb.modelData
                        sourceSize: Qt.size(160, 120)
                        radius: thumb.chosen ? 8 : thumb.radius
                    }

                    MouseArea {
                        id: thumbArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !ServiceKindle.busy && thumb.original !== ""
                        onClicked: ServiceKindle.setImage(thumb.original)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            M3Button {
                Layout.fillWidth: true
                size: "small"
                variant: "tonal"
                icon: "folder_open"
                label: "Browse"
                enabledButton: !ServiceKindle.busy
                onClicked: ServiceKindle.browse()
            }

            M3Button {
                Layout.fillWidth: true
                size: "small"
                variant: ServiceKindle.onKindle ? "tonal" : "filled"
                icon: ServiceKindle.onKindle ? "check" : "usb"
                label: ServiceKindle.onKindle ? "On the Kindle" : "Send over USB"
                enabledButton: root.usbIn && ServiceKindle.hasFrame && !ServiceKindle.onKindle && !ServiceKindle.busy
                onClicked: ServiceKindle.push()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: wifiRow.implicitHeight + 20
            radius: 16
            color: Colors.surfaceContainerHigh

            RowLayout {
                id: wifiRow
                x: 14
                width: parent.width - 28
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                MaterialIconSymbol {
                    content: "wifi"
                    iconSize: 20
                    customColor: ServiceKindle.serving ? Colors.primary : Colors.surfaceVariantText
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    CustomText {
                        content: "Send over Wi-Fi"
                        size: 14
                        weight: 500
                    }
                    CustomText {
                        Layout.fillWidth: true
                        content: ServiceKindle.serving ? "Serving from this laptop" : "Off. The Kindle can't fetch new images"
                        size: 12
                        weight: 400
                        customColor: Colors.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }
                }

                CustomToogle {
                    isToggleOn: ServiceKindle.serving
                    onToggled: state => ServiceKindle.setWifi(state)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 2
            spacing: 8

            MaterialIconSymbol {
                content: ServiceKindle.message !== "" && !ServiceKindle.messageOk ? "error" : "info"
                iconSize: 16
                customColor: ServiceKindle.message !== "" && !ServiceKindle.messageOk ? Colors.error : Colors.surfaceVariantText
            }
            CustomText {
                Layout.fillWidth: true
                content: ServiceKindle.message !== "" && !ServiceKindle.messageOk ? ServiceKindle.message : root.delivery
                size: 12
                weight: 400
                customColor: ServiceKindle.message !== "" && !ServiceKindle.messageOk ? Colors.error : Colors.surfaceVariantText
                wrapMode: Text.WordWrap
            }
        }
    }
}
