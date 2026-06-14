import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal

    mask: Region { item: card }

    visible: _alive
    property bool _alive: false

    Connections {
        target: ServiceScreenshot
        function onHasNewChanged() {
            if (ServiceScreenshot.hasNew) {
                root._alive = true
                enterDelay.restart()
            }
        }
    }

    Timer {
        id: enterDelay
        interval: 16
        onTriggered: card.entering = true
    }

    // ── Card ─────────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.right:        parent.right
        anchors.bottom:       parent.bottom
        anchors.rightMargin:  20
        anchors.bottomMargin: 24

        width: 320
        implicitHeight: inner.implicitHeight + 24
        radius: 22
        color: Colors.surfaceContainer

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled:           true
            shadowColor:             "#50000000"
            shadowBlur:              0.55
            shadowVerticalOffset:    5
            shadowHorizontalOffset:  0
        }

        // ── Entrance / exit ───────────────────────────────────────────────
        property bool entering: false
        property real _dx:  card.width + 40
        property real _opa: 0.0

        transform: Translate { x: card._dx }
        opacity:   card._opa

        onEnteringChanged: {
            if (entering) {
                slideIn.start()
                fadeIn.start()
            }
        }

        NumberAnimation { id: slideIn; target: card; property: "_dx";  to: 0;   duration: 380; easing.type: Easing.OutCubic }
        NumberAnimation { id: fadeIn;  target: card; property: "_opa"; to: 1.0; duration: 260; easing.type: Easing.OutQuad }

        Connections {
            target: ServiceScreenshot
            function onHasNewChanged() {
                if (!ServiceScreenshot.hasNew) {
                    slideOut.start()
                    fadeOut.start()
                    hideTimer.restart()
                }
            }
        }

        NumberAnimation { id: slideOut; target: card; property: "_dx";  to: card.width + 40; duration: 300; easing.type: Easing.InCubic }
        NumberAnimation { id: fadeOut;  target: card; property: "_opa"; to: 0;               duration: 200; easing.type: Easing.InQuad }
        Timer {
            id: hideTimer; interval: 320
            onTriggered: { root._alive = false; card._dx = card.width + 40; card._opa = 0.0; card.entering = false }
        }

        // ── Hover detection (pauses auto-dismiss) ─────────────────────────
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onContainsMouseChanged: ServiceScreenshot.hovered = containsMouse
        }

        // ── Content ───────────────────────────────────────────────────────
        ColumnLayout {
            id: inner
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 12

            // Header: thumbnail + info
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth:  118
                    Layout.preferredHeight: 80
                    radius: 14; clip: true
                    color: Colors.surfaceContainerHigh

                    Image {
                        id: thumbImg
                        anchors.fill: parent
                        source: ServiceScreenshot.latestPath !== ""
                            ? "file://" + ServiceScreenshot.latestPath : ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true; asynchronous: true
                    }
                    Rectangle {
                        anchors.fill: parent; radius: parent.radius
                        color: Colors.surfaceContainerHighest
                        visible: thumbImg.status !== Image.Ready
                        MaterialIconSymbol { anchors.centerIn: parent; content: "image"; iconSize: 28; color: Colors.outline }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 6

                    RowLayout {
                        spacing: 6
                        MaterialIconSymbol { content: "photo_camera"; iconSize: 14; color: Colors.primary }
                        CustomText { content: "Screenshot"; size: 14; weight: 700; color: Colors.surfaceText }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: 22; Layout.preferredHeight: 22
                            radius: 7
                            color: xArea.containsMouse ? Colors.surfaceContainerHigh : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            MaterialIconSymbol { anchors.centerIn: parent; content: "close"; iconSize: 13; color: Colors.outline }
                            MouseArea {
                                id: xArea; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: ServiceScreenshot.dismiss()
                            }
                        }
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: ServiceScreenshot.latestPath.split("/").pop()
                        size: 10; color: Colors.outline; elide: Text.ElideMiddle
                    }

                    Rectangle {
                        Layout.preferredHeight: 20
                        Layout.preferredWidth: savedRow.implicitWidth + 14
                        radius: 10; color: Qt.alpha(Colors.primary, 0.14)
                        RowLayout {
                            id: savedRow; anchors.centerIn: parent; spacing: 4
                            MaterialIconSymbol { content: "check_circle"; iconSize: 11; color: Colors.primary }
                            CustomText { content: "Saved"; size: 10; weight: 600; color: Colors.primary }
                        }
                    }
                }
            }

            // Auto-dismiss progress bar
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 2
                radius: 1; color: Colors.surfaceContainerHigh
                Rectangle {
                    width: parent.width * (1.0 - ServiceScreenshot.dismissProgress)
                    height: parent.height; radius: parent.radius; color: Colors.primary
                }
            }

            // Action buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                SsButton { icon: "content_copy"; label: "Copy";   onClicked: ServiceScreenshot.copyToClipboard() }
                SsButton { icon: "edit";          label: "Edit";   onClicked: ServiceScreenshot.editWithSwappy() }
                SsButton { icon: "open_in_new";   label: "Open";   onClicked: ServiceScreenshot.openFile() }
                SsButton {
                    icon: "delete_outline"; label: "Delete"
                    btnColor:      Qt.alpha(Colors.error, 0.12)
                    btnHoverColor: Qt.alpha(Colors.error, 0.22)
                    textColor:     Colors.error
                    onClicked: ServiceScreenshot.deleteFile()
                }
            }
        }
    }

    // ── Inline action button ──────────────────────────────────────────────────
    component SsButton: Rectangle {
        id: btn
        required property string icon
        required property string label
        property color btnColor:       Colors.surfaceContainerHigh
        property color btnHoverColor:  Colors.surfaceContainerHighest
        property color textColor:      Colors.surfaceText
        signal clicked()

        Layout.preferredHeight: 32
        Layout.preferredWidth:  _row.implicitWidth + 18
        radius: 16
        color: _ma.containsMouse ? btnHoverColor : btnColor
        Behavior on color { ColorAnimation { duration: 120 } }
        scale: _ma.pressed ? 0.90 : 1.0
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

        Row {
            id: _row; anchors.centerIn: parent; spacing: 5
            MaterialIconSymbol {
                anchors.verticalCenter: parent.verticalCenter
                content: btn.icon; iconSize: 13; customColor: btn.textColor
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: btn.label; size: 11; weight: 600; customColor: btn.textColor
            }
        }
        MouseArea {
            id: _ma; anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
