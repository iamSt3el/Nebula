pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Rectangle {
    id: card
    property bool open: false
    signal picked

    property real openT: card.open ? 1 : 0
    Behavior on openT { SpatialAnim { speed: "fast" } }
    visible: card.openT > 0.01
    opacity: Math.min(1, card.openT * 1.5)
    transform: Scale {
        origin.x: card.width / 2
        origin.y: 0
        yScale: 0.6 + 0.4 * card.openT
    }

    width: 380
    height: Math.min(440, col.implicitHeight + 20)
    radius: 24
    color: Colors.surfaceContainer
    border.width: 1
    border.color: Qt.alpha(Colors.outline, 0.18)

    property int tick: 0
    Timer {
        interval: 30000
        repeat: true
        running: card.visible
        onTriggered: card.tick++
    }

    function ago(t) {
        card.tick
        const s = Math.max(0, (Date.now() - t) / 1000)
        if (s < 60)
            return "now"
        const m = Math.round(s / 60)
        return m < 60 ? m + " min" : Math.round(m / 60) + " h"
    }

    MouseArea { anchors.fill: parent }

    Flickable {
        anchors.fill: parent
        anchors.margins: 10
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                spacing: 8

                MaterialIconSymbol {
                    content: "history"
                    iconSize: 18
                    customColor: Colors.primary
                }
                CustomText {
                    Layout.fillWidth: true
                    content: "This session"
                    size: 13
                    weight: 600
                    customColor: Colors.primary
                }
                CustomText {
                    content: EditSession.changes === 1 ? "1 change" : EditSession.changes + " changes"
                    size: 12
                    customColor: Colors.surfaceVariantText
                }
            }

            Repeater {
                model: card.visible ? EditSession.history.map((h, i) => ({ h: h, i: i })).reverse() : []

                delegate: Rectangle {
                    id: step
                    required property var modelData
                    readonly property bool here: step.modelData.i === EditSession.index
                    readonly property bool ahead: step.modelData.i > EditSession.index
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 14
                    color: step.here ? Colors.secondaryContainer
                        : stepArea.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        spacing: 10

                        MaterialIconSymbol {
                            content: step.modelData.i === 0 ? "schedule" : step.here ? "radio_button_checked" : "radio_button_unchecked"
                            iconSize: 16
                            customColor: step.here ? Colors.secondaryContainerText : Colors.outline
                        }
                        CustomText {
                            Layout.fillWidth: true
                            content: step.modelData.h.label
                            elide: Text.ElideRight
                            size: 13
                            weight: step.here ? 600 : 400
                            customColor: step.here ? Colors.secondaryContainerText
                                : step.ahead ? Colors.outline : Colors.surfaceText
                        }
                        CustomText {
                            content: card.ago(step.modelData.h.t)
                            size: 11
                            customColor: step.here ? Colors.secondaryContainerText : Colors.outline
                        }
                    }

                    MouseArea {
                        id: stepArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            EditSession.restoreAt(step.modelData.i)
                            card.picked()
                        }
                    }
                }
            }
        }
    }
}
