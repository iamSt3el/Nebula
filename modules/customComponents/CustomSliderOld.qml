import Quickshell
import QtQuick
import Quickshell.Widgets
import qs.modules.utils
import QtQuick.Effects
import qs.modules.customComponents

Item {
    id: root
    property alias progress: wrapper.progress
    property string icon
    property bool isDragging: false
    property bool horizontal: false
    signal change

    // The track is inset at each end so the handle can sit centred at 0% and
    // 100% without overhanging. Every position calculation works in that inset
    // space rather than the full length.
    readonly property int inset: 7
    readonly property int endPad: 14

    function applyFraction(f) {
        wrapper.progress = Math.max(0, Math.min(1, f))
        // Emitted after the write so a handler reading `progress` sees the new
        // value. It used to fire first, which left brightness one event behind.
        root.change()
    }

    // vertical
    Column {
        visible: !root.horizontal
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        spacing: 10

        Rectangle {
            id: wrapper
            implicitWidth: 40
            implicitHeight: parent.height
            color: "transparent"
            radius: 8
            anchors.horizontalCenter: parent.horizontalCenter
            property var progress: 1

            Rectangle {
                implicitWidth: parent.width
                anchors.top: parent.top
                implicitHeight: (parent.height - root.endPad) * (1 - wrapper.progress)
                color: Colors.surfaceContainerHigh
                topLeftRadius: 12
                topRightRadius: 12

                MaterialIconSymbol{
                    visible: lower.height < height + 5
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    content: root.icon
                    iconSize: 24
                    color: Colors.surfaceText
                }
            }
            Rectangle {
                id: lower
                implicitHeight: (parent.height - root.endPad) * wrapper.progress
                implicitWidth: parent.width
                anchors.bottom: parent.bottom
                color: Colors.primary
                bottomLeftRadius: 12
                bottomRightRadius: 12


                MaterialIconSymbol{
                    visible: parent.height > height + 5
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    content: root.icon
                    iconSize: 24
                    color: Colors.primaryText
                }
            }

            // Marker only. This used to own the sole MouseArea and be moved by
            // drag.target, which is why the track ignored clicks — and why the
            // y binding was destroyed the first time you dragged it.
            Rectangle {
                id: handler
                implicitHeight: 6
                implicitWidth: 48
                color: Colors.primary
                radius: 2
                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - root.endPad) * (1 - wrapper.progress) + root.inset - (height / 2)
            }

            // Whole track responds: press or drag anywhere sets the value.
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function applyAt(my) {
                    const usable = wrapper.height - root.endPad
                    if (usable <= 0) return
                    root.applyFraction(1 - ((my - root.inset) / usable))
                }

                onPressed:         event => { root.isDragging = true; applyAt(event.y) }
                onPositionChanged: event => { if (pressed) applyAt(event.y) }
                onReleased:        root.isDragging = false
            }
        }
    }



    // horizontal — width plays the role height had, height plays the role width had
    Item {
        visible: root.horizontal
        width: parent.width
        height: parent.height
        anchors.centerIn: parent

        Rectangle {
            id: wrapperH
            implicitHeight: 40          // thin dimension (was implicitWidth: 40)
            implicitWidth: parent.width // long dimension (was implicitHeight: parent.height)
            color: "transparent"
            radius: 8
            anchors.centerIn: parent
            property var progress: wrapper.progress

            // inactive = right portion
            Rectangle {
                implicitHeight: parent.height
                anchors.right: parent.right
                implicitWidth: (parent.width - root.endPad) * (1 - wrapperH.progress)
                color: Qt.alpha(Colors.primary, 0.5)
                topRightRadius: 8
                bottomRightRadius: 8
            }
            // active = left portion
            Rectangle {
                implicitWidth: (parent.width - root.endPad) * wrapperH.progress
                implicitHeight: parent.height
                anchors.left: parent.left
                color: Colors.primary
                topLeftRadius: 8
                bottomLeftRadius: 8
            }
            // handler — tall and thin (inverted from vertical), marker only
            Rectangle {
                id: handlerH
                implicitWidth: 6        // was implicitHeight: 6
                implicitHeight: 48      // was implicitWidth: 48
                color: Colors.primary
                radius: 2
                anchors.verticalCenter: parent.verticalCenter
                x: (parent.width - root.endPad) * wrapperH.progress + root.inset - (width / 2)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                // Writes wrapper.progress rather than wrapperH's: wrapperH.progress
                // is bound to it, so assigning there would sever the binding and
                // leave the two orientations disagreeing.
                function applyAt(mx) {
                    const usable = wrapperH.width - root.endPad
                    if (usable <= 0) return
                    root.applyFraction((mx - root.inset) / usable)
                }

                onPressed:         event => { root.isDragging = true; applyAt(event.x) }
                onPositionChanged: event => { if (pressed) applyAt(event.x) }
                onReleased:        root.isDragging = false
            }
        }
    }
}
