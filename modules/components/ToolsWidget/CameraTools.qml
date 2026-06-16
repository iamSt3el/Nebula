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
    property real _slide:   22
    property real _fade:    0.0

    Component.onCompleted: { slideIn.start(); fadeIn.start() }

    NumberAnimation { id: slideIn; target: root; property: "_slide"; to: 0;   duration: 340; easing.type: Easing.OutCubic }
    NumberAnimation { id: fadeIn;  target: root; property: "_fade";  to: 1.0; duration: 260; easing.type: Easing.OutQuad }

    // ── Header ───────────────────────────────────────────────────────────
    RowLayout {
        id: header
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

        MaterialIconSymbol { content: "photo_camera"; iconSize: 15; color: Colors.primary }

        CustomText { content: "Screenshot"; size: 14; weight: 700; color: Colors.surfaceText }

        Item { Layout.fillWidth: true }
    }

    // ── Cards row ────────────────────────────────────────────────────────
    Row {
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.margins:    12
        anchors.topMargin:  4
        spacing: 10

        // Full Screen
        ModeCard {
            width: (parent.width - 10) / 2
            height: parent.height
            label:    "Full Screen"
            subtitle: "Entire output"
            slideY:   root._slide
            fadeIn:   root._fade
            onTriggered: { root.backClicked(); ServiceTools.takeScreenshot("Screen") }

            illus: Component {
                ScreenIllus { hovered: parent.hovered }
            }
        }

        // Select Area
        ModeCard {
            width: (parent.width - 10) / 2
            height: parent.height
            label:    "Select Area"
            subtitle: "Draw a region"
            slideY:   root._slide * 1.5
            fadeIn:   root._fade
            onTriggered: {
                GlobalStates.toolsWidgetOpen = false
                GlobalStates.areaSelectMode  = "screenshot"
                GlobalStates.areaSelectOpen  = true
            }

            illus: Component {
                AreaIllus { hovered: parent.hovered }
            }
        }
    }

    // ── Shared card component ─────────────────────────────────────────────
    component ModeCard: Rectangle {
        id: card
        radius: 18
        clip:   true
        color:  ma.containsMouse ? Colors.primary : Colors.surfaceContainer
        Behavior on color { ColorAnimation { duration: 160 } }

        required property string label
        required property string subtitle
        required property real   slideY
        required property real   fadeIn
        required property Component illus
        signal triggered()

        readonly property bool hovered: ma.containsMouse

        transform: Translate { y: card.slideY }
        opacity:   card.fadeIn
        scale:     ma.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        // Illustration slot — expose hovered so Components can bind via parent.hovered
        Loader {
            property bool hovered: card.hovered
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: parent.height * 0.60
            sourceComponent: card.illus
        }

        // Labels
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

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked:    card.triggered()
        }
    }

    // ── Monitor illustration ──────────────────────────────────────────────
    component ScreenIllus: Item {
        required property bool hovered
        anchors.fill: parent

        Item {
            anchors.centerIn: parent
            width: 62; height: 50

            // Screen bezel
            Rectangle {
                id: bezel
                anchors.fill: parent
                anchors.bottomMargin: 6
                radius: 5
                color: "transparent"
                border.width: 1.5
                border.color: hovered ? Qt.alpha(Colors.primaryText, 0.55) : Colors.primary
                Behavior on border.color { ColorAnimation { duration: 160 } }

                // Title bar
                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 2 }
                    height: 7; radius: 2.5
                    color: hovered ? Qt.alpha(Colors.primaryText, 0.35) : Qt.alpha(Colors.primary, 0.35)
                    Behavior on color { ColorAnimation { duration: 160 } }

                    // Traffic-light dots
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

                // Content grid
                Grid {
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 4 }
                    columns: 3; rows: 2; spacing: 3
                    Repeater {
                        model: 6
                        Rectangle {
                            width: index === 0 ? 20 : 10
                            height: 5; radius: 1.5
                            color: hovered ? Qt.alpha(Colors.primaryText, 0.18) : Qt.alpha(Colors.primary, 0.18)
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                    }
                }
            }

            // Stand neck
            Rectangle {
                anchors { top: bezel.bottom; horizontalCenter: parent.horizontalCenter }
                width: 8; height: 4; radius: 1
                color: hovered ? Qt.alpha(Colors.primaryText, 0.35) : Qt.alpha(Colors.primary, 0.35)
                Behavior on color { ColorAnimation { duration: 160 } }
            }
            // Stand base
            Rectangle {
                anchors { top: bezel.bottom; horizontalCenter: parent.horizontalCenter; topMargin: 3 }
                width: 22; height: 3; radius: 1.5
                color: hovered ? Qt.alpha(Colors.primaryText, 0.35) : Qt.alpha(Colors.primary, 0.35)
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }
    }

    // ── Area-select illustration ──────────────────────────────────────────
    component AreaIllus: Item {
        required property bool hovered
        anchors.fill: parent

        Item {
            anchors.centerIn: parent
            width: 62; height: 50

            // Faint screen outline
            Rectangle {
                anchors.fill: parent
                radius: 5
                color: "transparent"
                border.width: 1.5
                border.color: hovered ? Qt.alpha(Colors.primaryText, 0.25) : Qt.alpha(Colors.primary, 0.25)
                Behavior on border.color { ColorAnimation { duration: 160 } }
            }

            // Selection rectangle
            Rectangle {
                id: sel
                x: 10; y: 10
                width: 32; height: 24
                radius: 3
                color: hovered ? Qt.alpha(Colors.primaryText, 0.10) : Qt.alpha(Colors.primary, 0.10)
                border.width: 1.5
                border.color: hovered ? Colors.primaryText : Colors.primary
                Behavior on color       { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                // Corner handles
                Repeater {
                    model: 4
                    Rectangle {
                        readonly property bool isRight:  index % 2 === 1
                        readonly property bool isBottom: index >= 2
                        x: isRight  ? sel.width  - 5 : -1
                        y: isBottom ? sel.height - 5 : -1
                        width: 5; height: 5; radius: 1.5
                        color: hovered ? Colors.primaryText : Colors.primary
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                }
            }

            // Cursor dot outside selection
            Rectangle {
                x: sel.x + sel.width + 3
                y: sel.y + sel.height + 3
                width: 5; height: 5; radius: 3
                color: hovered ? Qt.alpha(Colors.primaryText, 0.6) : Qt.alpha(Colors.primary, 0.7)
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }
    }
}
