import QtQuick
import qs.modules.utils
import qs.modules.customComponents

Item {
    id: root

    property string face: "display"
    property bool awake: false

    signal wakeRequested()

    readonly property real dim: root.face === "matrix" ? 0.84 : root.face === "display" ? 0.6 : 0

    Item {
        anchors.fill: parent
        opacity: root.awake ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: root.awake ? 520 : 560
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
        }

        Image {
            anchors.fill: parent
            source: WallpaperTheme.wallpaperScreen
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 1920
            sourceSize.height: 1080
            asynchronous: true
            cache: true
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.063, 0.055, 0.055, root.dim)
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.face === "stencil" ? cStencil : root.face === "matrix" ? cMatrix : cDisplay
    }

    Component { id: cDisplay; LockClockDisplay { awake: root.awake } }
    Component { id: cStencil; LockClockStencil { awake: root.awake } }
    Component { id: cMatrix; LockClockMatrix { awake: root.awake } }

    MouseArea {
        anchors.fill: parent
        enabled: !root.awake
        acceptedButtons: Qt.AllButtons
        onPressed: root.wakeRequested()
        onWheel: root.wakeRequested()
    }
}
