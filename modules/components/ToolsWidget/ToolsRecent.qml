import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

ColumnLayout {
    id: root
    spacing: 6

    readonly property var entries: (ServiceCaptures.items ?? []).slice(0, 3)

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 8

        CustomText {
            content: "RECENT"
            size: 10; weight: 700
            color: Colors.outline
        }

        Item { Layout.fillWidth: true }

        CustomText {
            content: "Open folder"
            size: 11; weight: 500
            color: folderMa.containsMouse ? Colors.primary : Colors.surfaceVariantText

            MouseArea {
                id: folderMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["xdg-open",
                    String(SettingsConfig.screenshot.outputPath).replace("~", Quickshell.env("HOME"))])
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 76
        visible: root.entries.length === 0
        radius: 14
        color: "transparent"
        border.width: 1
        border.color: Colors.outlineVariant

        CustomText {
            anchors.centerIn: parent
            content: ServiceCaptures.scanning ? "Looking for captures…" : "Captures show up here"
            size: 11; weight: 500
            color: Colors.outline
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.entries.length > 0
        spacing: 8

        Repeater {
            model: root.entries

            delegate: ColumnLayout {
                id: cell
                required property var modelData

                Layout.fillWidth: true
                spacing: 4

                readonly property bool isVideo: cell.modelData.kind === "video"

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 76
                    radius: 14
                    color: Colors.surfaceContainerHigh
                    clip: true
                    border.width: 1
                    border.color: tileHover.hovered ? Colors.primary : Colors.outlineVariant
                    Behavior on border.color { EffectsColorAnim { speed: "fast" } }

                    Image {
                        id: thumb
                        anchors.fill: parent
                        source: cell.modelData.thumb !== "" ? "file://" + cell.modelData.thumb : ""
                        sourceSize: Qt.size(320, 180)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width:  thumb.width
                                height: thumb.height
                                radius: 14
                            }
                        }
                    }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        visible: thumb.status !== Image.Ready
                        content: cell.isVideo ? "movie" : "image"
                        iconSize: 22
                        color: Colors.outline
                    }

                    Rectangle {
                        anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
                        visible: cell.isVideo && cell.modelData.duration > 0 && !tileHover.hovered
                        implicitWidth: durText.implicitWidth + 10
                        implicitHeight: 16
                        radius: 6
                        color: Qt.alpha(Colors.surfaceContainerLowest, 0.8)

                        CustomText {
                            id: durText
                            anchors.centerIn: parent
                            content: ServiceCaptures.clock(cell.modelData.duration)
                            size: 9; weight: 600
                            color: Colors.surfaceText
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Qt.alpha(Colors.surfaceContainerLowest, 0.82)
                        opacity: tileHover.hovered ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { EffectsAnim { speed: "fast" } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            TileAction {
                                icon: cell.isVideo ? "play_arrow" : "content_copy"
                                tip:  cell.isVideo ? "Play" : "Copy"
                                onActivated: {
                                    if (cell.isVideo) Quickshell.execDetached(["xdg-open", cell.modelData.path])
                                    else              ServiceTools.copyScreenshot(cell.modelData.path)
                                    GlobalStates.toolsWidgetOpen = false
                                }
                            }
                            TileAction {
                                visible: !cell.isVideo
                                icon: "edit"; tip: "Edit"
                                onActivated: {
                                    ServiceTools.editScreenshot(cell.modelData.path)
                                    GlobalStates.toolsWidgetOpen = false
                                }
                            }
                            TileAction {
                                icon: "smartphone"; tip: "Send to phone"
                                onActivated: {
                                    ServicePhone.share([cell.modelData.path])
                                    GlobalStates.toolsWidgetOpen = false
                                    GlobalStates.phoneOpen = true
                                }
                            }
                            TileAction {
                                icon: "delete"; tip: "Delete"; danger: true
                                onActivated: {
                                    ServiceTools.deleteScreenshot(cell.modelData.path)
                                    ServiceCaptures.forget(cell.modelData.path)
                                }
                            }
                        }
                    }

                    HoverHandler {
                        id: tileHover
                    }
                }

                CustomText {
                    Layout.fillWidth: true
                    content: ServiceCaptures.humanAge(cell.modelData.mtime) + " · " + ServiceCaptures.humanSize(cell.modelData.size)
                    size: 9; weight: 500
                    color: Colors.outline
                    elide: Text.ElideRight
                }
            }
        }
    }

    component TileAction: Rectangle {
        id: ta
        implicitWidth: 28; implicitHeight: 28
        radius: 14
        color: taMa.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerLow

        property string icon: ""
        property string tip: ""
        property bool   danger: false
        signal activated()

        Behavior on color { EffectsColorAnim { speed: "fast" } }

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: ta.icon
            iconSize: 15
            color: ta.danger ? Colors.error : Colors.surfaceText
        }

        CustomToolTip {
            visible: taMa.containsMouse
            content: ta.tip
        }

        MouseArea {
            id: taMa
            anchors.fill: parent
            hoverEnabled: ta.visible
            cursorShape: Qt.PointingHandCursor
            onClicked: ta.activated()
        }
    }
}
