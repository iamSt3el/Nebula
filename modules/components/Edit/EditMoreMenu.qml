pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Rectangle {
    id: menu
    property bool open: false
    property var entries: []
    property string armed: ""
    signal picked(string key)

    property real openT: menu.open ? 1 : 0
    Behavior on openT { SpatialAnim { speed: "fast" } }
    visible: menu.openT > 0.01
    opacity: Math.min(1, menu.openT * 1.5)
    transform: Scale {
        origin.x: menu.width / 2
        origin.y: menu.height
        yScale: 0.6 + 0.4 * menu.openT
    }

    width: 300
    height: col.implicitHeight + 12
    radius: 22
    color: Colors.surfaceContainerHigh
    border.width: 1
    border.color: Qt.alpha(Colors.outline, 0.18)

    MouseArea { anchors.fill: parent }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        spacing: 2

        Repeater {
            model: menu.entries

            delegate: ColumnLayout {
                id: entry
                required property var modelData
                readonly property bool isArmed: menu.armed !== "" && menu.armed === entry.modelData.key
                Layout.fillWidth: true
                spacing: 2

                Rectangle {
                    visible: entry.modelData.divider === true
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.topMargin: 3
                    Layout.bottomMargin: 3
                    implicitHeight: 1
                    color: Colors.outlineVariant
                }

                Rectangle {
                    id: rowBox
                    Layout.fillWidth: true
                    implicitHeight: sub.visible ? 52 : 44
                    radius: rowArea.pressed ? 10 : 14
                    color: entry.isArmed ? Colors.errorContainer
                        : rowArea.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
                    Behavior on color { EffectsColorAnim { speed: "fast" } }
                    Behavior on radius { SpatialAnim { speed: "fast" } }

                    readonly property color ink: entry.isArmed ? Colors.errorContainerText
                        : entry.modelData.danger ? Colors.error : Colors.surfaceText

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 12

                        MaterialIconSymbol {
                            content: entry.isArmed ? "warning" : entry.modelData.icon
                            iconSize: 18
                            customColor: rowBox.ink
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            CustomText {
                                Layout.fillWidth: true
                                content: entry.isArmed ? (entry.modelData.armedLabel ?? entry.modelData.label) : entry.modelData.label
                                elide: Text.ElideRight
                                size: 13
                                weight: 500
                                customColor: rowBox.ink
                            }
                            CustomText {
                                id: sub
                                visible: (entry.modelData.sub ?? "") !== "" && !entry.isArmed
                                Layout.fillWidth: true
                                content: entry.modelData.sub ?? ""
                                elide: Text.ElideRight
                                size: 11
                                customColor: Colors.surfaceVariantText
                            }
                        }

                        Rectangle {
                            visible: (entry.modelData.keys ?? "") !== ""
                            implicitHeight: 22
                            implicitWidth: keyText.implicitWidth + 14
                            radius: 6
                            color: Colors.surfaceContainerHighest

                            CustomText {
                                id: keyText
                                anchors.centerIn: parent
                                content: entry.modelData.keys ?? ""
                                size: 11
                                weight: 600
                                customColor: Colors.surfaceVariantText
                            }
                        }

                        MaterialIconSymbol {
                            visible: entry.modelData.external === true
                            content: "open_in_new"
                            iconSize: 16
                            customColor: Colors.surfaceVariantText
                        }
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressedChanged: if (entry.modelData.hold === true) EditSession.peek = rowArea.pressed
                        onClicked: if (entry.modelData.hold !== true) menu.picked(entry.modelData.key)
                    }
                }
            }
        }
    }
}
