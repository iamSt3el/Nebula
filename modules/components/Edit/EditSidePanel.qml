pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Rectangle {
    id: side

    property bool open: false
    property string title: ""
    property bool canReset: false
    property string resetLabel: "Reset"
    property real maxHeight: 520
    property bool fromLeft: false
    default property alias content: body.data
    signal back
    signal reset

    width: 300
    height: Math.min(side.maxHeight, body.implicitHeight + head.height + 40)
    radius: 26
    color: Colors.surfaceContainer
    border.width: 1
    border.color: Qt.alpha(Colors.outline, 0.18)

    property real showT: side.open ? 1 : 0
    Behavior on showT { SpatialAnim { speed: side.open ? "move" : "fast" } }
    visible: side.showT > 0.01
    opacity: Math.min(1, side.showT * 1.4)
    transform: Translate { x: side.open ? (1 - side.showT) * (side.fromLeft ? 14 : -14) : 0 }

    MouseArea { anchors.fill: parent }

    RowLayout {
        id: head
        x: 12
        y: 12
        width: side.width - 24
        height: 32
        spacing: 4

        EditPill {
            box: 32
            icon: "arrow_back"
            tip: "Back · Esc"
            onClicked: side.back()
        }
        CustomText {
            Layout.fillWidth: true
            content: side.title
            size: 14
            weight: 600
            elide: Text.ElideRight
        }
        EditPill {
            visible: side.canReset
            box: 32
            icon: "restart_alt"
            label: side.resetLabel
            tip: "Put just this group back"
            onClicked: side.reset()
        }
    }

    Flickable {
        id: flick
        x: 14
        y: head.y + head.height + 10
        width: side.width - 28
        height: side.height - y - 14
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ColumnLayout {
            id: body
            width: flick.width
            spacing: 8
        }
    }

    ScrollFade {
        x: flick.x
        y: flick.y
        width: flick.width
        height: flick.height
        flickable: flick
        color: Colors.surfaceContainer
    }
}
