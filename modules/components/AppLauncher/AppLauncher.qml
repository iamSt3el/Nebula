import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Scope{
    id: root

    readonly property bool preview: GlobalStates.launcherPreview && !GlobalStates.appLauncherOpen
    readonly property bool want: !GlobalStates.launcherHosted
        && (GlobalStates.appLauncherOpen || GlobalStates.launcherPreview)

    onWantChanged: {
        if (root.want) {
            animationTimer.stop()
            loader.active = true
        } else if (loader.active) {
            animationTimer.start()
        }
    }

    Loader{
        id: loader
        active: false
        sourceComponent: PanelWindow{
            id: panelWindow

            readonly property bool centered: ServiceLauncher.position === "center"
            property bool shown: false
            property real openT: 0

            onShownChanged: {
                if (panelWindow.shown) {
                    closeAnim.stop()
                    openAnim.restart()
                } else {
                    openAnim.stop()
                    closeAnim.restart()
                }
            }

            NumberAnimation {
                id: openAnim
                target: panelWindow
                property: "openT"
                to: 1
                duration: M3Motion.spatialDuration("default")
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
            }

            NumberAnimation {
                id: closeAnim
                target: panelWindow
                property: "openT"
                to: 0
                duration: Math.min(300, Appearance.duration.large - 60)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.3, 0.0, 0.8, 0.15, 1, 1]
            }

            implicitWidth: ServiceLauncher.panelWidth
            anchors.left: true
            anchors.right: panelWindow.centered
            anchors.top: true
            anchors.bottom: true
            margins.left: panelWindow.centered ? 0
                : (ServiceGaps.barSide === "left" ? ServiceGaps.barReserve : 0) + (ServiceGaps.dockSide === "left" ? ServiceGaps.dockReserve : 0)
            WlrLayershell.namespace: "quickshell:appLauncher"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Normal
            WlrLayershell.keyboardFocus: root.preview ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand
            color: "transparent"

            Component.onCompleted: Qt.callLater(() => panelWindow.shown = Qt.binding(() => root.want))

            property Region inputRegion: Region {
                item: maskRect
                intersection: Intersection.Xor

                Region {
                    item: container
                    intersection: Intersection.Subtract
                }
            }
            property Region noInput: Region {}

            property Region handleInput: Region {
                Region { item: handleLeft }
                Region { item: handleRight }
                Region { item: handleTop }
                Region { item: handleBottom }
            }

            mask: root.preview ? panelWindow.handleInput : panelWindow.inputRegion

            property bool resizing: false
            property real anchorX: 0
            property real anchorY: 0

            readonly property real screenW: panelWindow.screen ? panelWindow.screen.width : panelWindow.width
            readonly property real insetL: root.preview && panelWindow.centered ? GlobalStates.previewInsetLeft : 0
            readonly property real insetR: root.preview && panelWindow.centered ? GlobalStates.previewInsetRight : 0

            function beginResize() {
                panelWindow.resizing = true
                panelWindow.anchorX = container.x + container.width / 2
                panelWindow.anchorY = container.y + container.height / 2
                ServiceLauncher.draft = { w: ServiceLauncher.panelWidth, h: child.height }
            }

            function dragTo(side, p) {
                const d = ServiceLauncher.draft
                if (!d) return
                const cx = panelWindow.anchorX
                const cy = panelWindow.anchorY
                let w = d.w
                let h = d.h
                if (side === "left") w = 2 * (cx - p.x)
                else if (side === "right") w = panelWindow.centered ? 2 * (p.x - cx) : p.x - container.x
                else if (side === "top") h = 2 * (cy - p.y)
                else h = 2 * (p.y - cy)
                ServiceLauncher.draft = {
                    w: ServiceLauncher.clampW(Math.min(w, panelWindow.screenW - panelWindow.insetL - panelWindow.insetR - 32)),
                    h: ServiceLauncher.clampH(Math.min(h, panelWindow.height - 32))
                }
            }

            function endResize() {
                const d = ServiceLauncher.draft
                panelWindow.resizing = false
                if (d) ServiceLauncher.setSize(d.w, d.h)
            }

            Rectangle {
                id: maskRect
                anchors.fill: parent
                color: "transparent"
            }

            HyprlandFocusGrab{
                id: grab
                windows: [panelWindow]
                active: loader.active && GlobalStates.appLauncherOpen
                onCleared: () => {
                    if (!active && !GlobalStates.toolsWidgetOpen && !ServiceTools.screenshotActive) {
                        GlobalStates.appLauncherOpen = false
                    }
                }
            }

            Shape {
                id: bgShape
                z: 1
                preferredRendererType: Shape.CurveRenderer
                visible: !panelWindow.centered && child.width > 0

                readonly property real r: ServiceLauncher.radius

                function buildPath(dX, dY, rX, rY, left, right, top, bottom, w) {
                    const effDX = Math.min(dX, w / 2)
                    function A(sw, ex, ey) { return `A ${rX} ${rY} 0 0 ${sw} ${ex} ${ey} ` }
                    function L(x,  y)      { return `L ${x} ${y} ` }
                    const CW = 1, CCW = 0
                    let p = `M ${left} ${top - dY} `
                    p += A(CCW, left + effDX, top)
                    p += L(right - effDX,     top)
                    p += A(CW,  right, top    + effDX)
                    p += L(right,      bottom - effDX)
                    p += A(CW,  right - effDX, bottom)
                    p += L(left + effDX,       bottom)
                    p += A(CCW, left, bottom  + dY)
                    p += L(left,      top     - dY)
                    return p
                }

                ShapePath {
                    strokeWidth: -1
                    fillColor: Settings.layoutColor
                    PathSvg {
                        path: bgShape.buildPath(
                            bgShape.r, bgShape.r, bgShape.r, bgShape.r,
                            container.x,
                            container.x + child.width,
                            container.y,
                            container.y + container.height,
                            child.width
                        )
                    }
                }
            }

            Item {
                id: container
                z: 10
                width: Math.max(20, child.width)
                height: Math.max(100, child.height)
                x: !panelWindow.centered ? 0
                    : Math.max(16, Math.min(panelWindow.width - container.width - 16,
                        panelWindow.insetL + (panelWindow.width - panelWindow.insetL - panelWindow.insetR - container.width) / 2))
                y: (panelWindow.height - container.height) / 2

                Item {
                    id: card
                    readonly property real t: panelWindow.centered && !panelWindow.resizing ? panelWindow.openT : 1
                    readonly property real pillW: Math.min(container.width, Math.max(240, container.width * 0.6))
                    readonly property real pillH: 56
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: panelWindow.centered ? (1 - card.t) * 36 : 0
                    width: card.pillW + (container.width - card.pillW) * card.t
                    height: card.pillH + (container.height - card.pillH) * card.t
                    opacity: panelWindow.centered ? Math.min(1, card.t * 5) : 1
                    clip: panelWindow.centered && card.t < 1

                    Rectangle {
                        anchors.fill: parent
                        visible: panelWindow.centered
                        radius: Math.min(card.height / 2, card.pillH / 2 + (ServiceLauncher.radius - card.pillH / 2) * card.t)
                        color: Settings.layoutColor
                    }

                    Item {
                        id: child
                        anchors.centerIn: parent
                        width: panelWindow.centered || panelWindow.shown ? ServiceLauncher.panelWidth : 0
                        height: Math.min(ServiceLauncher.panelHeight, panelWindow.height - 32)
                        clip: true

                        Behavior on width {
                            enabled: !panelWindow.centered && !panelWindow.resizing
                            NumberAnimation {
                                duration: Appearance.duration.large
                                easing.type: Easing.OutQuad
                            }
                        }

                        AppLauncherContent{
                            anchors.fill: parent
                            preview: root.preview
                            enabled: !root.preview
                            entranceDelay: panelWindow.centered ? 170 : 300
                            entranceScale: panelWindow.centered ? 1 : 0.92
                            entranceRise: panelWindow.centered ? 14 : 0
                            onClosed:{
                                GlobalStates.appLauncherOpen = false
                            }
                        }
                    }
                }
            }

            SizeHandle {
                id: handleLeft
                win: panelWindow
                side: "left"
                enabled: panelWindow.centered
                visible: root.preview && panelWindow.centered
                x: container.x - width / 2 + 4
                y: container.y + container.height / 2 - height / 2
            }
            SizeHandle {
                id: handleRight
                win: panelWindow
                side: "right"
                x: panelWindow.centered ? container.x + container.width - width / 2 - 4 : container.x + container.width - width
                y: container.y + container.height / 2 - height / 2
            }
            SizeHandle {
                id: handleTop
                win: panelWindow
                side: "top"
                x: container.x + container.width / 2 - width / 2
                y: container.y - height / 2 + 4
            }
            SizeHandle {
                id: handleBottom
                win: panelWindow
                side: "bottom"
                x: container.x + container.width / 2 - width / 2
                y: container.y + container.height - height / 2 - 4
            }

            Rectangle {
                z: 61
                visible: panelWindow.resizing
                x: container.x + (container.width - width) / 2
                y: container.y + (container.height - height) / 2
                width: sizeText.implicitWidth + 24
                height: 32
                radius: 16
                color: Colors.inverseSurface
                CustomText {
                    id: sizeText
                    anchors.centerIn: parent
                    content: ServiceLauncher.panelWidth + " × " + ServiceLauncher.panelHeight
                    size: 13
                    weight: 700
                    customColor: Colors.inverseSurfaceText
                    font.features: { "tnum": 1 }
                }
            }
        }
    }

    component SizeHandle: MouseArea {
        id: handle
        property string side: "right"
        property var win: null
        readonly property bool vertical: handle.side === "left" || handle.side === "right"
        z: 60
        visible: root.preview
        width: handle.vertical ? 18 : 80
        height: handle.vertical ? 80 : 18
        hoverEnabled: true
        preventStealing: true
        cursorShape: handle.vertical ? Qt.SizeHorCursor : Qt.SizeVerCursor
        onPressed: handle.win.beginResize()
        onPositionChanged: mouse => {
            if (handle.pressed)
                handle.win.dragTo(handle.side, handle.mapToItem(null, mouse.x, mouse.y))
        }
        onReleased: handle.win.endResize()
        onCanceled: handle.win.endResize()

        Rectangle {
            anchors.centerIn: parent
            width: handle.vertical ? 5 : (handle.containsMouse || handle.pressed ? 60 : 46)
            height: handle.vertical ? (handle.containsMouse || handle.pressed ? 60 : 46) : 5
            radius: 2.5
            color: handle.pressed ? Colors.primary : handle.containsMouse ? Qt.alpha(Colors.primary, 0.85)
                                                                          : Qt.alpha(Colors.outline, 0.9)
            Behavior on width { SpatialAnim { speed: "fast" } }
            Behavior on height { SpatialAnim { speed: "fast" } }
        }
    }

    Timer{
        id: animationTimer
        interval: Appearance.duration.large
        onTriggered:{
            loader.active = false
        }
    }

    GlobalShortcut{
        name: "appLauncher"
        onPressed:{
            GlobalStates.appLauncherOpen = !GlobalStates.appLauncherOpen
        }
    }

}
