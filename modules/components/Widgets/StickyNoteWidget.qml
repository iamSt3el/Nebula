import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

WidgetHost {
    id: root
    configKey: "stickyNote"
    tile: WidgetSizes.small
    resizable: true
    minSpan: Qt.size(2, 2)
    maxSpan: Qt.size(5, 5)
    defaultPos: Qt.point(620, 660)

    readonly property string savedText: SettingsConfig.widgets.stickyNoteText ?? ""
    readonly property real fold: 44

    onSavedTextChanged: if (!area.activeFocus && area.text !== savedText) area.text = savedText

    Component.onCompleted: {
        area.text = root.preview
            ? "Pick up keys\nCall the landlord\nRent — friday"
            : root.savedText
    }

    Timer {
        id: saveTimer
        interval: 600
        onTriggered: {
            if (root.preview) return
            if (area.text === root.savedText) return
            SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, {
                stickyNoteText: area.text
            })
        }
    }

    WidgetCard {
        id: paper
        anchors.fill: parent
        color: Colors.tertiaryContainer
        bottomRightRadius: root.fold + 12

        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: root.fold
            height: root.fold
            topLeftRadius: root.fold / 2
            bottomRightRadius: paper.bottomRightRadius
            color: Qt.alpha(Colors.tertiaryContainerText, 0.12)
        }

        RowLayout {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: parent.pad
            spacing: 8

            MaterialShapes.ShapeCanvas {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                roundedPolygon: ShapeLibrary.get("sunny")
                color: Colors.tertiaryContainerText
            }
            CustomText {
                content: "NOTE"
                size: 12
                weight: 800
                font.letterSpacing: 0.5
                customColor: Colors.tertiaryContainerText
            }

            Item { Layout.fillWidth: true }

            MaterialIconSymbol {
                content: "close"
                iconSize: 16
                customColor: Colors.tertiaryContainerText
                visible: area.text.length > 0 && !root.preview
                opacity: clearArea.containsMouse ? 1 : 0.6

                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { area.text = ""; saveTimer.restart() }
                }
            }
        }

        ScrollView {
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: 4
            anchors.leftMargin: paper.pad - 6
            anchors.rightMargin: 10
            anchors.bottomMargin: root.fold * 0.5
            clip: true

            TextArea {
                id: area
                readOnly: root.preview
                background: null
                wrapMode: TextArea.Wrap
                font.pixelSize: 16
                font.weight: 600
                font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                color: Colors.tertiaryContainerText
                selectionColor: Qt.alpha(Colors.tertiaryContainerText, 0.25)
                selectedTextColor: Colors.tertiaryContainerText
                placeholderText: "Jot something down…"
                placeholderTextColor: Qt.alpha(Colors.tertiaryContainerText, 0.55)

                onTextChanged: if (!root.preview) saveTimer.restart()

                onActiveFocusChanged: {
                    if (!root.preview) GlobalStates.widgetTextFocus = activeFocus
                    if (!activeFocus) saveTimer.restart()
                }

                Keys.onEscapePressed: focus = false
            }
        }
    }
}
