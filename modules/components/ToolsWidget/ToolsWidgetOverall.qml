import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    implicitWidth:  300
    implicitHeight: 300

    // "camera" | "recording"
    property string toolMode: "camera"

    // ── Card entrance ─────────────────────────────────────────────────────
    property real _cs: 0.88
    property real _co: 0.0

    Behavior on _cs { NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 0.4 } }
    Behavior on _co { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

    Component.onCompleted: Qt.callLater(function() {
        root._cs = 1.0
        root._co = 1.0
    })

    // ── Elevation shadow ──────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        width: 268; height: 232
        radius: 30
        color: Colors.shadow
        opacity: root._co * 0.08
        scale: root._cs
        transform: Translate { y: 4 }
    }

    // ── Card ──────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 268; height: 228
        radius: 28
        color: Colors.surfaceContainerLow
        clip: true
        scale: root._cs
        opacity: root._co

        ColumnLayout {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.margins: 20
            anchors.topMargin: 20
            spacing: 14

            // ── Header ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 32; height: 32; radius: 16
                    color: Colors.primaryContainer

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content:  root.toolMode === "camera" ? "photo_camera" : "screen_record"
                        iconSize: 16
                        color:    Colors.primaryContainerText
                    }
                }

                CustomText {
                    Layout.fillWidth: true
                    content: root.toolMode === "camera" ? "Screenshot" : "Recording"
                    size: 15; weight: 600; color: Colors.surfaceText
                }

                // M3 IconButton — close
                Rectangle {
                    width: 32; height: 32; radius: 16
                    color: closeHov.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "close"; iconSize: 17
                        color: Colors.surfaceVariantText
                    }
                    MouseArea {
                        id: closeHov
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: GlobalStates.toolsWidgetOpen = false
                    }
                }
            }

            // ── Segmented button ───────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 21
                color: Colors.surfaceContainer
                border.color: Colors.outlineVariant
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 3

                    SegBtn {
                        width: (parent.width - 3) / 2; height: parent.height
                        mode: "camera"; icon: "photo_camera"; label: "Camera"
                    }
                    SegBtn {
                        width: (parent.width - 3) / 2; height: parent.height
                        mode: "recording"; icon: "screen_record"; label: "Record"
                    }
                }
            }

            // ── Options + Recording active ──────────────────────────────────
            Item {
                Layout.fillWidth: true
                height: 86

                // Three option cards (idle state)
                RowLayout {
                    anchors.fill: parent
                    spacing: 8
                    opacity: ServiceTools.isRecording ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 240 } }

                    OptionCard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: "screenshot_monitor"; label: "Screen"; delay: 0
                        onTriggered: {
                            if (root.toolMode === "camera") {
                                GlobalStates.toolsWidgetOpen = false
                                ServiceTools.takeScreenshot("Screen")
                            } else {
                                ServiceTools.startDelayed("Screen", "")
                            }
                        }
                    }
                    OptionCard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: "window"; label: "Window"; delay: 55
                        onTriggered: {
                            GlobalStates.toolsWidgetOpen = false
                            GlobalStates.areaSelectMode  = root.toolMode === "camera" ? "window-screenshot" : "window-recording"
                            GlobalStates.areaSelectOpen  = true
                        }
                    }
                    OptionCard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: "select"; label: "Area"; delay: 110
                        onTriggered: {
                            GlobalStates.toolsWidgetOpen = false
                            GlobalStates.areaSelectMode  = root.toolMode === "camera" ? "screenshot" : "recording"
                            GlobalStates.areaSelectOpen  = true
                        }
                    }
                }

                // Recording active view
                Item {
                    anchors.fill: parent
                    opacity: ServiceTools.isRecording ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.InOutQuad } }
                    visible: opacity > 0.01

                    Row {
                        anchors.centerIn: parent
                        spacing: 20

                        // Timer + REC badge
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5

                            CustomText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                content: {
                                    const s = ServiceTools.recordingSeconds
                                    return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
                                }
                                size: 34; weight: 700; color: Colors.surfaceText
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 5

                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.error
                                    SequentialAnimation on opacity {
                                        running: ServiceTools.isRecording; loops: Animation.Infinite
                                        NumberAnimation { to: 0.15; duration: 600; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutSine }
                                    }
                                }
                                CustomText { content: "REC"; size: 10; weight: 700; color: Colors.error }
                                Rectangle { width: 1; height: 10; color: Colors.outlineVariant; anchors.verticalCenter: parent.verticalCenter }
                                CustomText {
                                    content: ServiceTools.recordingMode; size: 10; weight: 400; color: Colors.outline
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Stop button
                        Rectangle {
                            width: 52; height: 52; radius: 26
                            anchors.verticalCenter: parent.verticalCenter
                            color: stopHov.containsMouse ? Colors.errorContainer : Colors.error
                            Behavior on color { ColorAnimation { duration: 130 } }
                            scale: stopHov.pressed ? 0.88 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 16; height: 16; radius: 3
                                color: stopHov.containsMouse ? Colors.errorContainerText : Colors.errorText
                                Behavior on color { ColorAnimation { duration: 130 } }
                            }
                            MouseArea {
                                id: stopHov
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: ServiceTools.stopRecording()
                            }
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // INLINE COMPONENTS
    // ════════════════════════════════════════════════════════════════════════

    // ── M3 Segmented button segment ────────────────────────────────────────
    component SegBtn: Rectangle {
        id: sb
        radius: height / 2

        property string mode:  ""
        property string icon:  ""
        property string label: ""

        color: root.toolMode === sb.mode ? Colors.secondaryContainer : "transparent"
        Behavior on color { ColorAnimation { duration: 200 } }

        Row {
            anchors.centerIn: parent
            spacing: 6

            MaterialIconSymbol {
                anchors.verticalCenter: parent.verticalCenter
                content:  sb.icon; iconSize: 14
                color: root.toolMode === sb.mode ? Colors.secondaryContainerText : Colors.surfaceVariantText
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: sb.label; size: 12; weight: 500
                color: root.toolMode === sb.mode ? Colors.secondaryContainerText : Colors.surfaceVariantText
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: root.toolMode = sb.mode
        }
    }

    // ── M3 Filled tonal option card ────────────────────────────────────────
    component OptionCard: Rectangle {
        id: oc
        radius: 14
        color: Colors.surfaceContainer
        clip: true

        property string icon:  ""
        property string label: ""
        property int    delay: 0
        signal triggered()

        // M3 state layer (hover 8%, press 12%)
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: Colors.surfaceText
            opacity: ocMa.pressed ? 0.12 : ocMa.containsMouse ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }

        // Staggered entrance
        property real _ey: 14
        property real _eo: 0.0

        Component.onCompleted: {
            eyAnim.start()
            eoAnim.start()
        }

        SequentialAnimation {
            id: eyAnim
            PauseAnimation  { duration: oc.delay }
            NumberAnimation { target: oc; property: "_ey"; to: 0; duration: 300; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            id: eoAnim
            PauseAnimation  { duration: oc.delay }
            NumberAnimation { target: oc; property: "_eo"; to: 1; duration: 220; easing.type: Easing.OutQuad }
        }

        transform: Translate { y: oc._ey }
        opacity:   oc._eo

        Column {
            anchors.centerIn: parent
            spacing: 7

            MaterialIconSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                content:  oc.icon; iconSize: 24
                color: ocMa.containsMouse ? Colors.primary : Colors.surfaceText
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                content: oc.label; size: 10; weight: 500
                color: ocMa.containsMouse ? Colors.primary : Colors.surfaceVariantText
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        scale: ocMa.pressed ? 0.93 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        MouseArea {
            id: ocMa
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: oc.triggered()
        }
    }
}
