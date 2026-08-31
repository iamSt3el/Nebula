import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.customComponents
import qs.modules.utils
import qs.modules.settings

Item {
    id: root
    readonly property int cardWidth:     180
    readonly property int cardSpacing:   6
    readonly property int layoutMargins: 8
    readonly property int maxCards:      4
    readonly property int overflowWidth: 84

    property var appEntry: null
    property bool capturing: true

    readonly property var tops: root.appEntry?.toplevels ?? []
    readonly property var shownTops: root.tops.slice(0, root.maxCards)
    readonly property int overflowCount: Math.max(0, root.tops.length - root.maxCards)

    implicitWidth: layoutMargins * 2
        + Math.max(1, root.shownTops.length) * (cardWidth + cardSpacing)
        + (root.overflowCount > 0 ? overflowWidth + cardSpacing : 0)
        - cardSpacing
    implicitHeight: 180

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.layoutMargins
        spacing: 6

        // ── App name chip ────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Image {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                source: Quickshell.iconPath(
                    DesktopEntries.heuristicLookup(root.appEntry?.appId ?? "")?.icon,
                    "image-missing")
                sourceSize.width: 18
                sourceSize.height: 18
                fillMode: Image.PreserveAspectFit
            }

            CustomText {
                Layout.fillWidth: true
                content: DesktopEntries.heuristicLookup(root.appEntry?.appId ?? "")?.name
                         ?? root.appEntry?.appId ?? ""
                size: 12
                weight: 700
                elide: Text.ElideRight
                customColor: Colors.outline
            }
        }

        // ── Window cards ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.cardSpacing

            Repeater {
                model: root.shownTops

                delegate: Rectangle {
                    id: card
                    required property var modelData
                    Layout.fillHeight: true
                    Layout.preferredWidth: root.cardWidth
                    color: Colors.surfaceContainerHigh
                    radius: 14
                    clip: true

                    RippleEffect {
                        anchors.fill: parent
                        radius: 14
                        onClicked: card.modelData.activate()
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        // Title row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            CustomText {
                                Layout.fillWidth: true
                                content: card.modelData.title ?? ""
                                size: 10
                                weight: 600
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                radius: 11
                                color: closeRipple.containsMouse
                                       ? Colors.surfaceContainerHighest : "transparent"

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: "close"
                                    iconSize: 13
                                    customColor: closeRipple.containsMouse ? Colors.error : Colors.outline
                                }

                                RippleEffect {
                                    id: closeRipple
                                    anchors.fill: parent
                                    radius: 11
                                    onClicked: card.modelData.close()
                                }
                            }
                        }

                        // Preview
                        ScreencopyView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            captureSource: root.capturing ? card.modelData : null
                            live: true
                            paintCursor: false
                            constraintSize: Qt.size(root.cardWidth, 120)
                        }
                    }
                }
            }

            Rectangle {
                visible: root.overflowCount > 0
                Layout.fillHeight: true
                Layout.preferredWidth: root.overflowWidth
                color: Colors.surfaceContainerHigh
                radius: 14

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: "+" + root.overflowCount
                        size: 22
                        weight: 800
                        customColor: Colors.primary
                    }

                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: root.overflowCount === 1 ? "more window" : "more windows"
                        size: 10
                        weight: 600
                        customColor: Colors.outline
                    }
                }
            }
        }
    }
}
