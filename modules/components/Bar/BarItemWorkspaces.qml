import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import Quickshell.Widgets
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true

    readonly property int wsCount: SettingsConfig.general.workspaceCount ?? 5
    readonly property bool wsNumbers: SettingsConfig.general.showWorkspaceNumbers ?? false
    readonly property bool perMonitorMode: SettingsConfig.general.perMonitorWorkspaces ?? false

    readonly property int otherOccupied: {
        if (!perMonitorMode) return 0
        var count = 0
        var vals = Hyprland.workspaces.values
        for (var i = 0; i < vals.length; i++) {
            if (vals[i].monitor?.name !== layout.screen.name) count++
        }
        return count
    }

    readonly property var thisMonitor: {
        var mons = Hyprland.monitors?.values ?? []
        for (var i = 0; i < mons.length; i++) {
            if (mons[i].name === layout.screen.name) return mons[i]
        }
        return null
    }

    readonly property int activeWsId: thisMonitor?.activeWorkspace?.id ?? -1

    readonly property bool otherFocused: perMonitorMode
        && (Hyprland.focusedMonitor?.name ?? layout.screen.name) !== layout.screen.name

    readonly property int monitorCount: Hyprland.monitors?.values?.length ?? 1
    readonly property bool showOtherIndicator: perMonitorMode && monitorCount > 1

    readonly property string style: BarLayout.opt(root.itemId, "style") ?? "pill"
    readonly property string screenName: layout.screen.name
    readonly property real screenW: layout.screen.width
    readonly property real screenH: layout.screen.height
    readonly property var cozyStyles: ["lanterns", "house", "stars", "map", "dial"]
    readonly property var quietStyles: ["ring", "viewfinder"]
    readonly property var motionStyles: ["goo", "bounce"]
    readonly property var wsIds: Array.from({ length: root.wsCount }, (_, i) => i + 1)
    readonly property var shapeCycle: ["cookie4", "clover4", "sunny", "cookie6", "softBurst", "cookie9", "flower", "cookie7"]

    readonly property real sizePct: BarLayout.opt(root.itemId, "size") ?? 100
    readonly property real room: root.host && root.host.barH > 0 ? (root.host.barH - 4) / 30 : 1
    readonly property real k: Math.max(1, Math.min(root.sizePct / 100, root.room))

    readonly property bool vertical: !!root.host && root.host.vertical === true
    readonly property var turningStyles: ["goo", "bounce", "pill", "shapes", "worm", "ring", "viewfinder"]
    readonly property bool rotatesWithBar: root.vertical && root.turningStyles.indexOf(root.style) >= 0
    readonly property bool verticalReady: root.vertical && !root.rotatesWithBar && root.cozyStyles.indexOf(root.style) < 0

    implicitWidth: face.item ? face.item.implicitWidth : 0
    implicitHeight: root.verticalReady && face.item ? face.item.implicitHeight : 30 * root.k

    function focusWs(id, ws) {
        if (ws)
            ws.activate()
        else
            Hyprland.dispatch(`hl.dsp.focus({ workspace = '${id}' })`)
    }

    component WsState: QtObject {
        required property int wsId
        readonly property var ws: ServiceWorkspaces.getWorkspace(wsId)
        readonly property bool onOther: root.perMonitorMode && !!ws && !!ws.monitor
            && ws.monitor.name !== layout.screen.name
        readonly property bool occupied: !!ws && !onOther
        readonly property bool active: !onOther && (root.perMonitorMode ? wsId === root.activeWsId
                                                                        : (!!ws && ws.active))
    }

    Loader {
        id: face
        anchors.centerIn: parent
        sourceComponent: {
            if (root.verticalReady)
                return columnComp
            if (root.cozyStyles.indexOf(root.style) >= 0)
                return cozyComp
            if (root.quietStyles.indexOf(root.style) >= 0)
                return quietComp
            if (root.motionStyles.indexOf(root.style) >= 0)
                return motionComp
            switch (root.style) {
            case "shapes":  return shapesComp
            case "worm":    return wormComp
            case "numbers": return numbersComp
            case "kanji":   return kanjiComp
            }
            return pillComp
        }
    }

    Component {
        id: columnComp
        Item {
            implicitWidth: 30 * root.k
            implicitHeight: col.implicitHeight

            Column {
                id: col
                anchors.centerIn: parent
                spacing: 4 * root.k

                Repeater {
                    model: root.wsIds
                    delegate: Rectangle {
                        id: wsCell
                        required property int modelData
                        WsState { id: st; wsId: wsCell.modelData }
                        width: 28 * root.k
                        height: st.active ? 42 * root.k : 28 * root.k
                        radius: 14 * root.k
                        color: st.active ? Colors.primary : st.occupied ? Colors.surfaceContainerHighest : "transparent"
                        border.width: st.onOther ? 1 * root.k : 0
                        border.color: Qt.alpha(Colors.outline, 0.35)
                        Behavior on height { SpatialAnim { speed: "fast" } }
                        Behavior on color { EffectsColorAnim {} }

                        Rectangle {
                            visible: !st.active && !st.occupied
                            anchors.centerIn: parent
                            width: 6 * root.k
                            height: 6 * root.k
                            radius: 3 * root.k
                            color: st.onOther ? Qt.alpha(Colors.outline, 0.45) : Colors.outline
                        }

                        CustomText {
                            anchors.centerIn: parent
                            visible: st.active || st.occupied
                            content: wsCell.modelData.toString()
                            size: Math.round(10 * root.k)
                            weight: st.active ? 800 : 600
                            customColor: st.active ? Colors.primaryText : Colors.surfaceText
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.focusWs(wsCell.modelData, st.ws)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cozyComp
        BarWsCozy {
            owner: root
            style: root.style
        }
    }

    Component {
        id: quietComp
        BarWsQuiet {
            owner: root
            style: root.style
        }
    }

    Component {
        id: motionComp
        BarWsMotion {
            owner: root
            style: root.style
        }
    }

    Component {
        id: pillComp

        Item {
            id: wsPill
            implicitWidth: row.implicitWidth
            implicitHeight: 30 * root.k

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: 6 * root.k

                Repeater {
                    model: ScriptModel {
                        values: Array.from({ length: root.wsCount }, (_, i) => i + 1)
                    }

                    delegate: Rectangle {
                        required property var modelData
                        property int workspaceId: modelData
                        property var currentWorkspace: ServiceWorkspaces.getWorkspace(workspaceId)
                        readonly property bool isOccupied: !!currentWorkspace
                        readonly property bool showNumbers: root.wsNumbers

                        readonly property bool onOtherMonitor: root.perMonitorMode
                            && !!currentWorkspace
                            && !!currentWorkspace.monitor
                            && currentWorkspace.monitor.name !== layout.screen.name

                        readonly property bool occupiedHere: isOccupied && !onOtherMonitor

                        readonly property bool isActive: !onOtherMonitor && (root.perMonitorMode
                            ? workspaceId === root.activeWsId
                            : (!!currentWorkspace && currentWorkspace.active))

                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: 30 * root.k
                        Layout.preferredWidth: occupiedHere
                            ? Math.max(30 * root.k, (topLevels.appList?.width ?? 0) + 14 * root.k)
                            : 30 * root.k
                        radius: 15 * root.k
                        color: isActive     ? Colors.primary
                             : occupiedHere ? Colors.surfaceContainerHighest
                                            : "transparent"

                        border.width: (occupiedHere && !isActive) || onOtherMonitor ? 1 * root.k : 0
                        border.color: onOtherMonitor ? Qt.alpha(Colors.outline, 0.35)
                                                     : Qt.alpha(Colors.outline, 0.15)

                        Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on color                 { ColorAnimation  { duration: 200 } }

                        Rectangle {
                            visible: !occupiedHere
                            implicitWidth: 6 * root.k
                            implicitHeight: 6 * root.k
                            color: onOtherMonitor ? Qt.alpha(Colors.outline, 0.45) : Colors.outline
                            radius: width / 2
                            anchors.centerIn: parent
                        }

                        Loader {
                            id: topLevels
                            anchors.fill: parent
                            active: occupiedHere && !showNumbers
                            visible: active
                            sourceComponent: TopLevels { k: root.k }
                            property var appList: item ? item.appList : null
                        }

                        CustomText {
                            anchors.centerIn: parent
                            visible: showNumbers && occupiedHere
                            content: workspaceId.toString()
                            size: Math.round(10 * root.k)
                            weight: isActive ? 800 : 600
                            customColor: isActive ? Colors.primaryText : Colors.surfaceText
                            Behavior on customColor { ColorAnimation { duration: 200 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (currentWorkspace) currentWorkspace.activate()
                                else Hyprland.dispatch(`hl.dsp.focus({ workspace = '${workspaceId}' })`)
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 30 * root.k
                    Layout.preferredWidth: root.showOtherIndicator ? 30 * root.k : 0
                    opacity: root.showOtherIndicator ? 1 : 0
                    visible: Layout.preferredWidth > 0
                    radius: 15 * root.k
                    color: root.otherFocused ? Colors.primary : "transparent"
                    border.width: root.otherFocused ? 0 : 1 * root.k
                    border.color: Qt.alpha(Colors.outline, 0.35)

                    Behavior on color                 { ColorAnimation  { duration: 200 } }
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity               { NumberAnimation { duration: 180 } }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "tv_displays"
                        iconSize: 12 * root.k
                        customColor: root.otherFocused ? Colors.primaryText : Colors.outline
                        Behavior on customColor { ColorAnimation { duration: 200 } }
                    }

                    CustomToolTip {
                        content: root.otherOccupied + " workspace" + (root.otherOccupied !== 1 ? "s" : "") + " on other monitor" + (root.otherFocused ? " — focused" : "")
                        visible: otherMonHov.containsMouse
                    }
                    MouseArea { id: otherMonHov; anchors.fill: parent; hoverEnabled: true }
                }
            }
        }
    }

    Component {
        id: shapesComp
        Row {
            spacing: 4 * root.k
            Repeater {
                model: root.wsIds
                delegate: Item {
                    id: cell
                    required property int modelData
                    required property int index
                    WsState { id: st; wsId: cell.modelData }
                    readonly property real side: (st.active ? 28 : st.occupied ? 17 : 12) * root.k
                    width: 30 * root.k
                    height: 30 * root.k

                    MaterialShapes.ShapeCanvas {
                        id: shape
                        anchors.centerIn: parent
                        width: cell.side
                        height: cell.side
                        roundedPolygon: ShapeLibrary.get(st.active ? "cookie12"
                                                          : root.shapeCycle[cell.index % root.shapeCycle.length])
                        color: st.active ? Colors.primary
                             : st.occupied ? Qt.alpha(Colors.surfaceText, 0.78)
                             : st.onOther ? Qt.alpha(Colors.outlineVariant, 0.5)
                             : Colors.outlineVariant
                        Behavior on width { SpatialAnim { speed: "fast" } }
                        Behavior on height { SpatialAnim { speed: "fast" } }

                        RotationAnimator on rotation {
                            from: 0
                            to: 360
                            duration: 9000
                            loops: Animation.Infinite
                            running: st.active
                        }
                    }

                    Connections {
                        target: st
                        function onActiveChanged() {
                            if (!st.active)
                                shape.rotation = 0
                        }
                    }

                    CustomText {
                        anchors.centerIn: parent
                        visible: st.active
                        content: cell.modelData.toString()
                        size: Math.round(10 * root.k)
                        weight: 800
                        customColor: Colors.primaryText
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.focusWs(cell.modelData, st.ws)
                    }
                }
            }
        }
    }

    Component {
        id: wormComp
        Item {
            id: track
            readonly property real dot: 11 * root.k
            readonly property real pill: 32 * root.k
            readonly property real gap: 11 * root.k
            readonly property int activeIndex: root.wsIds.indexOf(root.activeWsId)
            implicitWidth: (root.wsCount - 1) * (track.dot + track.gap) + track.pill
            implicitHeight: 30 * root.k

            Repeater {
                model: root.wsIds
                delegate: Rectangle {
                    id: dotItem
                    required property int modelData
                    required property int index
                    WsState { id: st; wsId: dotItem.modelData }
                    readonly property bool before: track.activeIndex >= 0 && dotItem.index > track.activeIndex
                    x: dotItem.index * (track.dot + track.gap) + (dotItem.before ? track.pill - track.dot : 0)
                    y: (track.height - height) / 2
                    width: st.active ? track.pill : track.dot
                    height: track.dot
                    radius: track.dot / 2
                    color: st.active ? Colors.primary : st.occupied ? Colors.outline : "transparent"
                    border.width: st.active || st.occupied ? 0 : 1.5 * root.k
                    border.color: Colors.outlineVariant
                    Behavior on x { SpatialAnim { speed: "fast" } }
                    Behavior on width { SpatialAnim { speed: "fast" } }
                    Behavior on color { EffectsColorAnim {} }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5 * root.k
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.focusWs(dotItem.modelData, st.ws)
                    }
                }
            }
        }
    }

    Component {
        id: numbersComp
        Item {
            id: nums
            readonly property real cell: 24 * root.k
            readonly property int activeIndex: root.wsIds.indexOf(root.activeWsId)
            implicitWidth: root.wsCount * nums.cell
            implicitHeight: 30 * root.k

            Row {
                Repeater {
                    model: root.wsIds
                    delegate: Item {
                        id: numItem
                        required property int modelData
                        WsState { id: st; wsId: numItem.modelData }
                        width: nums.cell
                        height: 30 * root.k

                        CustomText {
                            anchors.centerIn: parent
                            content: numItem.modelData.toString()
                            size: Math.round(13 * root.k)
                            weight: st.active ? 800 : 600
                            customColor: st.active ? Colors.primary
                                       : st.occupied ? Colors.surfaceText : Colors.outlineVariant
                            Behavior on customColor { EffectsColorAnim {} }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.focusWs(numItem.modelData, st.ws)
                        }
                    }
                }
            }

            Rectangle {
                visible: nums.activeIndex >= 0
                x: Math.max(0, nums.activeIndex) * nums.cell + (nums.cell - width) / 2
                y: 25 * root.k
                width: 12 * root.k
                height: 3 * root.k
                radius: 1.5 * root.k
                color: Colors.primary
                Behavior on x { SpatialAnim { speed: "fast" } }
            }
        }
    }

    Component {
        id: kanjiComp
        Row {
            spacing: 3 * root.k
            Repeater {
                model: root.wsIds
                delegate: Rectangle {
                    id: kan
                    required property int modelData
                    WsState { id: st; wsId: kan.modelData }
                    width: 26 * root.k
                    height: 26 * root.k
                    radius: 13 * root.k
                    color: st.active ? Colors.primary : "transparent"
                    Behavior on color { EffectsColorAnim {} }

                    CustomText {
                        anchors.centerIn: parent
                        content: ServiceJp.count(kan.modelData)
                        family: ServiceJp.serif
                        size: Math.round((String(ServiceJp.count(kan.modelData)).length > 1 ? 10 : 14) * root.k)
                        weight: 700
                        customColor: st.active ? Colors.primaryText
                                   : st.occupied ? Colors.surfaceText : Colors.outlineVariant
                        Behavior on customColor { EffectsColorAnim {} }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.focusWs(kan.modelData, st.ws)
                    }
                }
            }
        }
    }
}
