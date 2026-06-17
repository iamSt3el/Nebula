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

    Component.onCompleted: Qt.callLater(function() { root._cs = 1.0; root._co = 1.0 })

    // ── Elevation shadow ──────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        width: 268; height: 246
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
        width: 268; height: 246
        radius: 28
        color: Colors.surfaceContainerLow
        clip: true
        scale: root._cs
        opacity: root._co

        ColumnLayout {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.margins: 16
            anchors.topMargin: 16
            spacing: 12

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

                Rectangle {
                    width: 32; height: 32; radius: 16
                    color: closeHov.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MaterialIconSymbol { anchors.centerIn: parent; content: "close"; iconSize: 17; color: Colors.surfaceVariantText }
                    MouseArea {
                        id: closeHov
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: GlobalStates.toolsWidgetOpen = false
                    }
                }
            }

            // ── Segmented tab switch ───────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 20
                color: Colors.surfaceContainer
                border.color: Colors.outlineVariant
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 3

                    SegBtn { width: (parent.width - 3) / 2; height: parent.height; mode: "camera";     icon: "photo_camera";  label: "Camera" }
                    SegBtn { width: (parent.width - 3) / 2; height: parent.height; mode: "recording";  icon: "screen_record"; label: "Record" }
                }
            }

            // ── Options area (+ recording-active overlay for rec tab) ─────
            Item {
                Layout.fillWidth: true
                height: 108

                // Option cards — hidden only on recording tab while actively recording
                RowLayout {
                    anchors.fill: parent
                    spacing: 8
                    opacity: (ServiceTools.isRecording && root.toolMode === "recording") ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 240 } }

                    OptionCard {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        icon: root.toolMode === "camera" ? "screenshot_monitor" : "monitor"
                        label: "Screen"; delay: 0
                        onTriggered: {
                            if (root.toolMode === "camera") {
                                GlobalStates.toolsWidgetOpen = false
                                ServiceTools.takeScreenshot("Screen")
                            } else {
                                GlobalStates.toolsWidgetOpen = false
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

                // Recording active view — only on recording tab
                Item {
                    anchors.fill: parent
                    opacity: (ServiceTools.isRecording && root.toolMode === "recording") ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.InOutQuad } }
                    visible: opacity > 0.01

                    Row {
                        anchors.centerIn: parent
                        spacing: 22

                        // Timer + REC badge
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            CustomText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                content: {
                                    const s = ServiceTools.recordingSeconds
                                    return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
                                }
                                size: 36; weight: 700; color: Colors.surfaceText
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 5

                                // Pulsing dot (scale-based)
                                Item {
                                    width: 7; height: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 7; height: 7; radius: 3.5
                                        color: Colors.error
                                        SequentialAnimation on scale {
                                            running: ServiceTools.isRecording; loops: Animation.Infinite
                                            NumberAnimation { to: 0.55; duration: 620; easing.type: Easing.InOutSine }
                                            NumberAnimation { to: 1.0;  duration: 620; easing.type: Easing.InOutSine }
                                        }
                                    }
                                }

                                CustomText { content: "REC"; size: 10; weight: 700; color: Colors.error }
                                Rectangle {
                                    width: 1; height: 10; color: Colors.outlineVariant
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                CustomText {
                                    content: ServiceTools.recordingMode; size: 10; weight: 400; color: Colors.outline
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Stop button with pulsing rings
                        Item {
                            width: 66; height: 66
                            anchors.verticalCenter: parent.verticalCenter

                            // Pulse ring 1
                            Rectangle {
                                anchors.centerIn: parent; width: 66; height: 66; radius: 33
                                color: "transparent"
                                border.width: 1.5; border.color: Qt.alpha(Colors.error, 0.30)
                                SequentialAnimation on scale {
                                    running: ServiceTools.isRecording; loops: Animation.Infinite
                                    NumberAnimation { to: 1.22; duration: 900; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                                }
                                SequentialAnimation on opacity {
                                    running: ServiceTools.isRecording; loops: Animation.Infinite
                                    NumberAnimation { to: 0.2; duration: 900; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                                }
                            }

                            // Pulse ring 2 (offset phase)
                            Rectangle {
                                anchors.centerIn: parent; width: 66; height: 66; radius: 33
                                color: "transparent"
                                border.width: 1.5; border.color: Qt.alpha(Colors.error, 0.15)
                                SequentialAnimation on scale {
                                    running: ServiceTools.isRecording; loops: Animation.Infinite
                                    PauseAnimation  { duration: 450 }
                                    NumberAnimation { to: 1.28; duration: 900; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                                }
                            }

                            // Stop button
                            Rectangle {
                                anchors.centerIn: parent
                                width: 48; height: 48; radius: 24
                                color: stopMa.containsMouse ? Colors.errorContainer : Colors.error
                                Behavior on color { ColorAnimation { duration: 130 } }
                                scale: stopMa.pressed ? 0.88 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                                Rectangle {
                                    anchors.centerIn: parent; width: 15; height: 15; radius: 3
                                    color: stopMa.containsMouse ? Colors.errorContainerText : Colors.errorText
                                    Behavior on color { ColorAnimation { duration: 130 } }
                                }
                                MouseArea {
                                    id: stopMa
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: ServiceTools.stopRecording()
                                }
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

    // ── Segmented tab button ───────────────────────────────────────────────
    component SegBtn: Rectangle {
        id: sb
        radius: height / 2

        property string mode:  ""
        property string icon:  ""
        property string label: ""

        readonly property bool active: root.toolMode === sb.mode

        color: active ? Colors.secondaryContainer : "transparent"
        Behavior on color { ColorAnimation { duration: 200 } }

        Row {
            anchors.centerIn: parent
            spacing: 6

            MaterialIconSymbol {
                anchors.verticalCenter: parent.verticalCenter
                content: sb.icon; iconSize: 14
                color: sb.active ? Colors.secondaryContainerText : Colors.surfaceVariantText
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: sb.label; size: 12; weight: 500
                color: sb.active ? Colors.secondaryContainerText : Colors.surfaceVariantText
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: root.toolMode = sb.mode
        }
    }

    // ── Option card ────────────────────────────────────────────────────────
    component OptionCard: Rectangle {
        id: oc
        radius: 16
        color: Colors.surfaceContainer
        clip: true

        property string icon:  ""
        property string label: ""
        property int    delay: 0
        signal triggered()

        // M3 state layer
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: Colors.surfaceText
            opacity: ocMa.pressed ? 0.12 : ocMa.containsMouse ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }

        // Staggered entrance
        property real _ey: 16
        property real _eo: 0.0
        Component.onCompleted: { eyAnim.start(); eoAnim.start() }

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
        scale:     ocMa.pressed ? 0.93 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        Column {
            anchors.centerIn: parent
            spacing: 8

            // Icon with tinted background pill
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 40; height: 40; radius: 14
                color: ocMa.containsMouse ? Qt.alpha(Colors.primary, 0.15) : Qt.alpha(Colors.surfaceText, 0.06)
                Behavior on color { ColorAnimation { duration: 150 } }

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: oc.icon; iconSize: 22
                    color: ocMa.containsMouse ? Colors.primary : Colors.surfaceText
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                content: oc.label; size: 10; weight: 600
                color: ocMa.containsMouse ? Colors.primary : Colors.surfaceVariantText
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        MouseArea {
            id: ocMa
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: oc.triggered()
        }
    }
}
