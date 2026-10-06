import Quickshell
import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: root.model.length > 0

    readonly property string showMode: BarLayout.opt(root.itemId, "show") ?? "all"
    readonly property bool dimmed: BarLayout.opt(root.itemId, "dim") === true

    readonly property var model: {
        const all = ServiceApps.dockModel
        if (root.showMode === "pinned")   return all.filter(e => !!e.pinned)
        if (root.showMode === "unpinned") return all.filter(e => !e.pinned)
        if (root.showMode === "idle")     return all.filter(e => !!e.pinned && (e.toplevels?.length ?? 0) === 0)
        return all
    }
    readonly property int entriesVersion: ServiceApps.list.length
    readonly property real icon: root.host && root.host.iconSize ? root.host.iconSize : 32
    readonly property real roundT: root.host && root.host.roundT !== undefined ? root.host.roundT : 0
    readonly property real cell: root.icon + 12
    readonly property real stride: root.cell + 2
    readonly property bool editing: !!root.host && !!root.host.editing
    readonly property bool vertical: !!root.host && root.host.vertical === true
    readonly property bool verticalReady: true
    readonly property string side: root.host && root.host.frame ? root.host.frame.side : "bottom"
    readonly property real across: root.icon + 22
    readonly property real along: root.gripW + Math.max(0, root.model.length * root.stride - 2)
    property real gripW: root.editing ? 22 : 0

    readonly property var appRects: root.model.map((e, i) => ({
        appId: e.appId ?? "",
        pinned: !!e.pinned,
        x: root.gripW + i * root.stride,
        w: root.cell
    }))

    readonly property QtObject editor: root.host && root.host.editor ? root.host.editor : null
    readonly property bool appDrag: !!root.editor && root.editor.mode === "app"
    readonly property int dragFrom: {
        if (!root.appDrag)
            return -1
        const want = root.editor.appId.toLowerCase()
        return root.model.findIndex(e => (e.appId ?? "").toLowerCase() === want)
    }
    readonly property int dropAt: root.appDrag ? root.editor.appDropIndex : -1

    function shiftFor(i) {
        if (root.dropAt < 0 || root.dragFrom < 0 || i === root.dragFrom)
            return 0
        let s = 0
        let j = i
        if (i > root.dragFrom) {
            s -= root.stride
            j = i - 1
        }
        if (j >= root.dropAt)
            s += root.stride
        return s
    }

    implicitWidth: root.vertical ? root.across : root.along
    implicitHeight: root.vertical ? root.along : root.across
    opacity: root.dimmed && !root.editing ? 0.55 : 1
    Behavior on opacity { EffectsAnim { speed: "fast" } }

    Behavior on gripW {
        SpatialAnim { speed: "fast" }
    }

    Rectangle {
        visible: root.gripW > 1
        x: root.vertical ? (parent.width - width) / 2 : 2
        y: root.vertical ? 2 : (parent.height - height) / 2
        width: root.vertical ? root.cell - 8 : Math.max(0, root.gripW - 6)
        height: root.vertical ? Math.max(0, root.gripW - 6) : root.cell - 8
        radius: Math.min(width, height) / 2
        color: Qt.alpha(Colors.outline, 0.14)
        opacity: Math.min(1, root.gripW / 22)

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: "drag_indicator"
            iconSize: 16
            customColor: Colors.surfaceText
        }
    }

    Repeater {
        model: root.model

        delegate: Item {
            id: dockItem
            required property var modelData
            required property int index

            readonly property bool isRunning: dockItem.modelData.toplevels.length > 0
            readonly property bool isActive: dockItem.modelData.toplevels.some(t => t.activated)
            readonly property int winCount: Math.min(dockItem.modelData.toplevels.length, 3)
            readonly property bool pinned: !!dockItem.modelData.pinned
            readonly property bool offer: root.editing && !dockItem.pinned
            readonly property string appKey: (dockItem.modelData.appId ?? "").toLowerCase()
            readonly property bool notifLift: GlobalStates.notifLiftApp !== "" && GlobalStates.notifLiftApp === dockItem.appKey
            readonly property int notifCount: GlobalStates.notifBadges[dockItem.appKey] ?? 0

            Component.onCompleted: GlobalStates.registerDockIcon(dockItem.modelData.appId, dockItem)
            Component.onDestruction: GlobalStates.unregisterDockIcon(dockItem.modelData.appId, dockItem)

            readonly property real pos: root.gripW + dockItem.index * root.stride
            readonly property real lift: dockItem.notifLift ? (root.side === "left" || root.side === "top" ? 10 : -10) : 0
            x: root.vertical ? 0 : dockItem.pos
            y: root.vertical ? dockItem.pos : 0
            width: root.vertical ? root.width : root.cell
            height: root.vertical ? root.cell : root.height
            opacity: root.appDrag && dockItem.index === root.dragFrom ? 0 : 1

            transform: Translate {
                x: root.vertical ? dockItem.lift : root.shiftFor(dockItem.index)
                y: root.vertical ? root.shiftFor(dockItem.index) : dockItem.lift
                Behavior on x {
                    SpatialAnim { speed: "fast" }
                }
                Behavior on y {
                    SpatialAnim { speed: "default" }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: dockIconArea.containsMouse ? Math.round((root.icon + 8) * 1.15) : root.icon + 8
                height: width
                radius: 12 + (width / 2 - 12) * root.roundT
                Behavior on width {
                    NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 0.5 }
                }
                color: dockIconArea.containsMouse
                    ? Colors.primaryContainer
                    : dockItem.isActive
                        ? Qt.alpha(Colors.primaryContainer, 0.45)
                        : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Image {
                anchors.centerIn: parent
                width: dockIconArea.containsMouse ? Math.round(root.icon * 1.12) : root.icon
                height: width
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
                source: root.entriesVersion >= 0
                    ? Quickshell.iconPath(DesktopEntries.heuristicLookup(dockItem.modelData.appId)?.icon, "image-missing")
                    : ""
                sourceSize.width: 96
                sourceSize.height: 96
                smooth: true
                mipmap: true
                fillMode: Image.PreserveAspectFit
                opacity: dockItem.offer ? 0.5 : 1
                Behavior on opacity { EffectsAnim { speed: "fast" } }

            }

            Rectangle {
                visible: dockItem.offer
                x: parent.width / 2 + root.icon / 2 - width + 4
                y: parent.height / 2 - root.icon / 2 - 4
                width: 18
                height: 18
                radius: 9
                color: Colors.primary

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: "push_pin"
                    iconSize: 12
                    customColor: Colors.primaryText
                }
            }

            Rectangle {
                visible: dockItem.notifCount > 0 && !dockItem.offer
                x: parent.width / 2 + root.icon / 2 - width + 6
                y: parent.height / 2 - root.icon / 2 - 6
                width: Math.max(18, badgeText.implicitWidth + 8)
                height: 18
                radius: 9
                color: Colors.error

                CustomText {
                    id: badgeText
                    anchors.centerIn: parent
                    content: dockItem.notifCount
                    size: 11
                    weight: 700
                    customColor: Colors.errorText
                }
            }

            Rectangle {
                readonly property real len: dockItem.winCount === 1 ? 6 : dockItem.winCount === 2 ? 12 : 18
                visible: dockItem.isRunning
                x: !root.vertical ? (parent.width - width) / 2 : root.side === "left" ? 3 : parent.width - width - 3
                y: root.vertical ? (parent.height - height) / 2
                    : root.side === "top" ? 3 : parent.height - height - 3
                width: root.vertical ? 4 : len
                height: root.vertical ? len : 4
                radius: 2
                color: dockItem.isActive ? Colors.primary : Qt.alpha(Colors.primary, 0.45)

                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                id: dockIconArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onEntered: if (root.host && root.host.appEntered) root.host.appEntered(dockItem.modelData, dockItem)
                onExited: if (root.host && root.host.appExited) root.host.appExited()

                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        if (dockItem.modelData.toplevels.length > 0)
                            dockItem.modelData.toplevels[0].activate()
                        else
                            ServiceApps.launch(dockItem.modelData.appId)
                    } else if (root.host && root.host.appMenu) {
                        root.host.appMenu(dockItem.modelData, dockItem)
                    }
                }
            }
        }
    }
}
