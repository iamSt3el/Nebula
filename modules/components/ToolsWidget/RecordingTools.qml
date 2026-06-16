import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Rectangle {
    id: root
    implicitWidth:  300
    implicitHeight: 300
    radius: 24
    color:  Colors.surface
    clip:   true

    signal backClicked()

    // ── Staggered entrance ───────────────────────────────────────────────
    property real _slide: 22
    property real _fade:  0.0

    Component.onCompleted: { slideIn.start(); fadeIn.start() }

    NumberAnimation { id: slideIn; target: root; property: "_slide"; to: 0;   duration: 340; easing.type: Easing.OutCubic }
    NumberAnimation { id: fadeIn;  target: root; property: "_fade";  to: 1.0; duration: 260; easing.type: Easing.OutQuad }

    // ═══════════════════════════════════════════════════════════════════════
    // IDLE VIEW — two mode cards
    // ═══════════════════════════════════════════════════════════════════════
    Item {
        id: idleView
        anchors.fill: parent

        property real _opacity: 1.0
        property real _slideY:  0.0

        Behavior on _opacity { NumberAnimation { duration: 240; easing.type: Easing.InOutQuad } }
        Behavior on _slideY  { NumberAnimation { duration: 240; easing.type: Easing.InOutQuad } }

        Connections {
            target: ServiceTools
            function onIsRecordingChanged() {
                if (ServiceTools.isRecording) {
                    idleView._opacity = 0.0
                    idleView._slideY  = 18
                } else {
                    idleView._opacity = 1.0
                    idleView._slideY  = 0.0
                }
            }
        }

        opacity:   idleView._opacity
        visible:   idleView._opacity > 0.01
        transform: Translate { y: idleView._slideY }

        // ── Header ───────────────────────────────────────────────────────
        RowLayout {
            id: idleHeader
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
            height: 46
            spacing: 6

            Rectangle {
                width: 30; height: 30; radius: 9
                color: backHov.containsMouse ? Colors.surfaceContainer : "transparent"
                Behavior on color { ColorAnimation { duration: 110 } }
                MaterialIconSymbol { anchors.centerIn: parent; content: "arrow_back"; iconSize: 17; color: Colors.surfaceText }
                MouseArea { id: backHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.backClicked() }
            }

            MaterialIconSymbol { content: "screen_record"; iconSize: 15; color: Colors.primary }

            CustomText { content: "Recording"; size: 14; weight: 700; color: Colors.surfaceText }

            Item { Layout.fillWidth: true }
        }

        // ── Cards ─────────────────────────────────────────────────────────
        Row {
            anchors { top: idleHeader.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.margins:   12
            anchors.topMargin: 4
            spacing: 10

            RecCard {
                width: (parent.width - 10) / 2
                height: parent.height
                label:    "Full Screen"
                subtitle: "Entire output"
                slideY:   root._slide
                cardFade: root._fade
                onTriggered: {
                    root.backClicked()
                    ServiceTools.startDelayed("Screen", "")
                }
                illus: Component { ScreenIllus { hovered: parent.hovered } }
            }

            RecCard {
                width: (parent.width - 10) / 2
                height: parent.height
                label:    "Select Area"
                subtitle: "Draw a region"
                slideY:   root._slide * 1.5
                cardFade: root._fade
                onTriggered: {
                    GlobalStates.toolsWidgetOpen = false
                    GlobalStates.areaSelectMode  = "recording"
                    GlobalStates.areaSelectOpen  = true
                }
                illus: Component { AreaIllus { hovered: parent.hovered } }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // RECORDING VIEW — pulsing ring + big timer
    // ═══════════════════════════════════════════════════════════════════════
    Item {
        id: recView
        anchors.fill: parent

        property real _opacity: 0.0
        property real _slideY:  -18.0

        Behavior on _opacity { NumberAnimation { duration: 280; easing.type: Easing.InOutQuad } }
        Behavior on _slideY  { NumberAnimation { duration: 280; easing.type: Easing.InOutQuad } }

        Connections {
            target: ServiceTools
            function onIsRecordingChanged() {
                if (ServiceTools.isRecording) {
                    recView._opacity = 1.0
                    recView._slideY  = 0.0
                } else {
                    recView._opacity = 0.0
                    recView._slideY  = -18.0
                }
            }
        }

        opacity:   recView._opacity
        visible:   recView._opacity > 0.01
        transform: Translate { y: recView._slideY }

        // ── REC badge ────────────────────────────────────────────────────
        Row {
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 24 }
            spacing: 6

            Rectangle {
                width: 8; height: 8; radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.error

                SequentialAnimation on opacity {
                    running: ServiceTools.isRecording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                }
            }

            CustomText { content: "REC"; size: 11; weight: 700; color: Colors.error }

            Rectangle {
                width: 1; height: 12; color: Colors.outline; opacity: 0.4
                anchors.verticalCenter: parent.verticalCenter
            }

            CustomText {
                content: ServiceTools.recordingMode
                size: 11; weight: 500; color: Colors.outline
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── Big elapsed timer ─────────────────────────────────────────────
        CustomText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -20
            content: {
                const s = ServiceTools.recordingSeconds
                return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
            }
            size: 48; weight: 700
            color: Colors.surfaceText
        }

        // ── Stop button + pulsing ring ────────────────────────────────────
        Item {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 32 }
            width: 76; height: 76

            // Outer pulse ring 1
            Rectangle {
                id: ring1
                anchors.centerIn: parent
                width: 76; height: 76; radius: 38
                color: "transparent"
                border.width: 1.5
                border.color: Qt.alpha(Colors.error, 0.30)

                SequentialAnimation on scale {
                    running: ServiceTools.isRecording
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.18; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on opacity {
                    running: ServiceTools.isRecording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            // Outer pulse ring 2 (offset phase)
            Rectangle {
                anchors.centerIn: parent
                width: 76; height: 76; radius: 38
                color: "transparent"
                border.width: 1.5
                border.color: Qt.alpha(Colors.error, 0.18)

                SequentialAnimation on scale {
                    running: ServiceTools.isRecording
                    loops: Animation.Infinite
                    PauseAnimation   { duration: 450 }
                    NumberAnimation { to: 1.22; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                }
            }

            // Stop button
            Rectangle {
                id: stopBtn
                anchors.centerIn: parent
                width: 54; height: 54; radius: 27
                color: stopHov.containsMouse ? Qt.lighter(Colors.error, 1.12) : Colors.error
                Behavior on color { ColorAnimation { duration: 130 } }
                scale: stopHov.pressed ? 0.92 : 1.0
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                // Stop square icon
                Rectangle {
                    anchors.centerIn: parent
                    width: 18; height: 18; radius: 3
                    color: Colors.primaryText
                }

                MouseArea {
                    id: stopHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    ServiceTools.stopRecording()
                }
            }
        }
    }

    // ── Shared card component ─────────────────────────────────────────────
    component RecCard: Rectangle {
        id: card
        radius: 18
        clip:   true
        color:  ma.containsMouse ? Colors.primary : Colors.surfaceContainer
        Behavior on color { ColorAnimation { duration: 160 } }

        required property string    label
        required property string    subtitle
        required property real      slideY
        required property real      cardFade
        required property Component illus
        signal triggered()

        readonly property bool hovered: ma.containsMouse

        transform: Translate { y: card.slideY }
        opacity:   card.cardFade
        scale:     ma.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        Loader {
            property bool hovered: card.hovered
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: parent.height * 0.60
            sourceComponent: card.illus
        }

        Column {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 14 }
            spacing: 3

            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                content: card.label
                size: 12; weight: 700
                color: card.hovered ? Colors.primaryText : Colors.surfaceText
                Behavior on color { ColorAnimation { duration: 160 } }
            }
            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                content: card.subtitle
                size: 10; weight: 400
                color: card.hovered ? Qt.alpha(Colors.primaryText, 0.65) : Colors.outline
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }

        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.triggered() }
    }

    // ── Monitor illustration ──────────────────────────────────────────────
    component ScreenIllus: Item {
        required property bool hovered
        anchors.fill: parent

        Item {
            anchors.centerIn: parent
            width: 62; height: 50

            Rectangle {
                id: bezel2
                anchors.fill: parent; anchors.bottomMargin: 6
                radius: 5; color: "transparent"
                border.width: 1.5
                border.color: hovered ? Qt.alpha(Colors.primaryText, 0.55) : Colors.primary
                Behavior on border.color { ColorAnimation { duration: 160 } }

                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 2 }
                    height: 7; radius: 2.5
                    color: hovered ? Qt.alpha(Colors.primaryText, 0.35) : Qt.alpha(Colors.primary, 0.35)
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Row {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 3 }
                        spacing: 2
                        Repeater {
                            model: 3
                            Rectangle {
                                width: 2.5; height: 2.5; radius: 1.5
                                color: hovered ? Qt.alpha(Colors.primaryText, 0.5) : Qt.alpha(Colors.primary, 0.6)
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }
                        }
                    }
                }

                Grid {
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 4 }
                    columns: 3; rows: 2; spacing: 3
                    Repeater {
                        model: 6
                        Rectangle {
                            width: index === 0 ? 20 : 10; height: 5; radius: 1.5
                            color: hovered ? Qt.alpha(Colors.primaryText, 0.18) : Qt.alpha(Colors.primary, 0.18)
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                    }
                }
            }

            Rectangle {
                anchors { top: bezel2.bottom; horizontalCenter: parent.horizontalCenter }
                width: 8; height: 4; radius: 1
                color: hovered ? Qt.alpha(Colors.primaryText, 0.35) : Qt.alpha(Colors.primary, 0.35)
                Behavior on color { ColorAnimation { duration: 160 } }
            }
            Rectangle {
                anchors { top: bezel2.bottom; horizontalCenter: parent.horizontalCenter; topMargin: 3 }
                width: 22; height: 3; radius: 1.5
                color: hovered ? Qt.alpha(Colors.primaryText, 0.35) : Qt.alpha(Colors.primary, 0.35)
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }
    }

    // ── Area illustration ─────────────────────────────────────────────────
    component AreaIllus: Item {
        required property bool hovered
        anchors.fill: parent

        Item {
            anchors.centerIn: parent
            width: 62; height: 50

            Rectangle {
                anchors.fill: parent; radius: 5; color: "transparent"
                border.width: 1.5
                border.color: hovered ? Qt.alpha(Colors.primaryText, 0.25) : Qt.alpha(Colors.primary, 0.25)
                Behavior on border.color { ColorAnimation { duration: 160 } }
            }

            Rectangle {
                id: asel
                x: 10; y: 10; width: 32; height: 24; radius: 3
                color: hovered ? Qt.alpha(Colors.primaryText, 0.10) : Qt.alpha(Colors.primary, 0.10)
                border.width: 1.5
                border.color: hovered ? Colors.primaryText : Colors.primary
                Behavior on color        { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                Repeater {
                    model: 4
                    Rectangle {
                        readonly property bool isRight:  index % 2 === 1
                        readonly property bool isBottom: index >= 2
                        x: isRight  ? asel.width  - 5 : -1
                        y: isBottom ? asel.height - 5 : -1
                        width: 5; height: 5; radius: 1.5
                        color: hovered ? Colors.primaryText : Colors.primary
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                }
            }

            Rectangle {
                x: asel.x + asel.width + 3; y: asel.y + asel.height + 3
                width: 5; height: 5; radius: 3
                color: hovered ? Qt.alpha(Colors.primaryText, 0.6) : Qt.alpha(Colors.primary, 0.7)
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }
    }
}
