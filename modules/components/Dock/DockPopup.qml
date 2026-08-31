import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.components.CustomContextMenu

PopupWindow {
    id: root

    property string appId: ""
    property string mode: "preview"
    property point anchorPoint: Qt.point(0, 0)

    readonly property bool menuMode: root.mode === "menu"

    readonly property var appEntry: {
        if (root.appId === "") return null
        const want = root.appId.toLowerCase()
        return ServiceApps.dockModel.find(e => (e.appId ?? "").toLowerCase() === want) ?? null
    }

    signal hoverEntered
    signal hoverExited
    signal menuDismissed
    signal requestClose

    readonly property int morphDuration: M3Motion.spatialDuration("default")
    readonly property var morphCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]

    property real posT: root.menuMode ? 1 : 0
    Behavior on posT {
        NumberAnimation {
            duration: root.morphDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.morphCurve
        }
    }

    property real timeT: root.menuMode ? 1 : 0
    Behavior on timeT {
        NumberAnimation { duration: root.morphDuration; easing.type: Easing.Linear }
    }

    readonly property real previewOpacity: 1 - Math.min(1, root.timeT / 0.3)
    readonly property real menuOpacity:
        Math.max(0, Math.min(1, (root.timeT - 0.3) / 0.366))

    implicitWidth:  Math.max(previewContent.implicitWidth,  menuContent.implicitWidth)
    implicitHeight: Math.max(previewContent.implicitHeight, menuContent.implicitHeight)

    visible: true
    color: "transparent"

    mask: Region { item: card }

    anchor {
        window: panelWindow
        rect: Qt.rect(root.anchorPoint.x + 22, root.anchorPoint.y - 15, 1, 1)
        gravity: Edges.Top
        edges: Edges.Bottom
    }

    HyprlandFocusGrab {
        active: root.menuMode
        windows: [QsWindow.window]
        onCleared: root.menuDismissed()
    }

    Rectangle {
        id: card

        width:  previewContent.implicitWidth
                + (menuContent.implicitWidth - previewContent.implicitWidth) * root.posT
        height: previewContent.implicitHeight
                + (menuContent.implicitHeight - previewContent.implicitHeight) * root.posT
        x: (parent.width - width) / 2
        anchors.bottom: parent.bottom

        radius: 20
        color: Colors.surfaceContainer
        clip: true

        scale: 0.88
        opacity: 0
        NumberAnimation on scale   { from: 0.88; to: 1; duration: 180; easing.type: Easing.OutQuad; running: true }
        NumberAnimation on opacity { from: 0;    to: 1; duration: 150; running: true }

        HoverHandler {
            onHoveredChanged: hovered ? root.hoverEntered() : root.hoverExited()
        }

        DockPreview {
            id: previewContent
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width:  implicitWidth
            height: implicitHeight
            appEntry: root.appEntry
            capturing: !root.menuMode || previewContent.visible
            opacity: root.previewOpacity
            visible: opacity > 0.01
        }

        CustomContextMenu {
            id: menuContent
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width:  implicitWidth
            height: implicitHeight
            appEntry: root.appEntry
            opacity: root.menuOpacity
            visible: opacity > 0.01
            onClose: root.requestClose()
        }
    }
}
