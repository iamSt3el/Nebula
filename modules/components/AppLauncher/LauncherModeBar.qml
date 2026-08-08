pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

// Two states in one strip, so the row never changes height:
//   apps  → the available prefixes, as a teaching aid
//   mode  → a single chip naming the active mode, plus its usage hint
//
// Clicking a hint chip types its prefix, which makes the modes discoverable by
// mouse as well as by memory.
Item {
    id: root

    signal prefixRequested(string prefix)

    implicitHeight: 26

    // ── Idle: prefix hints ────────────────────────────────────────────────────
    Row {
        id: hints
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        visible: opacity > 0
        opacity: ServiceLauncher.mode === "apps" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        Repeater {
            model: ServiceLauncher.modes

            delegate: Rectangle {
                id: hint
                required property var modelData

                width: hintRow.implicitWidth + 16
                height: 24
                radius: 8
                color: hintArea.containsMouse
                    ? Qt.alpha(Colors.primary, 0.16)
                    : Colors.surfaceContainerHigh
                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    id: hintRow
                    anchors.centerIn: parent
                    spacing: 5

                    CustomText {
                        content: hint.modelData.prefix
                        size: 11; weight: 800
                        customColor: Colors.primary
                    }
                    CustomText {
                        content: hint.modelData.label
                        size: 11; weight: 600
                        customColor: Colors.outline
                    }
                }

                MouseArea {
                    id: hintArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.prefixRequested(
                        hint.modelData.prefix === "w" ? "w " : hint.modelData.prefix)
                }
            }
        }
    }

    // ── Active: mode chip + usage hint ────────────────────────────────────────
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        visible: opacity > 0
        opacity: ServiceLauncher.mode !== "apps" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        Rectangle {
            Layout.preferredWidth: chipRow.implicitWidth + 18
            Layout.preferredHeight: 24
            radius: 8
            color: Colors.primary

            RowLayout {
                id: chipRow
                anchors.centerIn: parent
                spacing: 5

                MaterialIconSymbol {
                    content: ServiceLauncher.activeMode?.icon ?? ""
                    iconSize: 13
                    customColor: Colors.primaryText
                }
                CustomText {
                    content: ServiceLauncher.activeMode?.label ?? ""
                    size: 11; weight: 800
                    customColor: Colors.primaryText
                }
            }
        }

        CustomText {
            Layout.fillWidth: true
            content: ServiceLauncher.activeMode?.hint ?? ""
            size: 11; weight: 500
            customColor: Colors.outline
            elide: Text.ElideRight
        }
    }
}
