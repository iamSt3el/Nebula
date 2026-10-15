import Quickshell
import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Rectangle {
    anchors.fill: parent
    topLeftRadius: Appearance.radius.large
    topRightRadius: Appearance.radius.extraLarge
    color: Colors.surface
    anchors.bottom: parent.bottom

    Behavior on implicitHeight {
        NumberAnimation { duration: Appearance.duration.normal; easing.type: Easing.OutQuad }
    }

    onVisibleChanged: if (visible && !colLoader.active) buildTimer.restart()
    Component.onCompleted: if (visible) buildTimer.restart()

    Timer {
        id: buildTimer
        interval: 0
        onTriggered: colLoader.active = true
    }

    Loader {
        id: colLoader
        active: false
        visible: active
        anchors.fill: parent
        sourceComponent: WallpaperGallery {}
    }
}
