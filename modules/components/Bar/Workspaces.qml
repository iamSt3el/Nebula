import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.modules.components.Ai

Item{
    id: root

    readonly property bool active: ServiceAi.open && layout.isPrimary

    readonly property bool isPill: ServiceGaps.isPill

    readonly property bool showArc: !isPill && height > Appearance.size.barHeight + 2

    readonly property real pillPanelTop: Appearance.size.barHeight + 8

    property bool contentShown: false

    onActiveChanged: {
        if (active) {
            revealDelay.restart()
        } else {
            revealDelay.stop()
            root.contentShown = false
        }
    }

    Timer {
        id: revealDelay
        interval: Appearance.duration.normal
        onTriggered: {
            root.contentShown = true
            chat.takeFocus()
        }
    }

    readonly property real collapsedWidth: outerRow.implicitWidth + 20
    readonly property real panelWidth: 500

    readonly property int wsCount:    SettingsConfig.general.workspaceCount ?? 5
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
    // The Hyprland monitor this particular bar is drawn on
    readonly property var thisMonitor: {
        var mons = Hyprland.monitors?.values ?? []
        for (var i = 0; i < mons.length; i++) {
            if (mons[i].name === layout.screen.name) return mons[i]
        }
        return null
    }

    // What this monitor is currently showing. HyprlandWorkspace.active is the
    // *globally* focused workspace, so relying on it made every bar react to a
    // switch on any monitor. Each monitor tracks its own activeWorkspace.
    readonly property int activeWsId: thisMonitor?.activeWorkspace?.id ?? -1

    // Keyboard focus sits on some other monitor
    readonly property bool otherFocused: perMonitorMode
        && (Hyprland.focusedMonitor?.name ?? layout.screen.name) !== layout.screen.name

    // Stable while monitors stay plugged in — unlike a workspace count, which
    // churns as Hyprland creates and reaps empty workspaces
    readonly property int monitorCount: Hyprland.monitors?.values?.length ?? 1
    readonly property bool showOtherIndicator: perMonitorMode && monitorCount > 1
    readonly property real panelBottomInset: ServiceGaps.isPill
        ? ServiceGaps.pillMargin * 2
        : 0

    // Size the chat targets once, off the *open* geometry rather than the
    // animating one — binding the card to root.width/height relaid out every
    // line of the transcript at every width the animation passed through.
    readonly property real openHeight: layout.height - panelBottomInset

    // The bottom-right corner only flares once the block has actually landed on
    // the screen bottom — mid-animation that curve has nothing to merge into and
    // just reads as a notch hanging in the air.
    readonly property bool atScreenBottom: showArc && height >= openHeight - 2
    readonly property real chatWidth:  panelWidth - (isPill ? 0 : 20)
    readonly property real chatHeight: Math.max(0, openHeight
        - (isPill ? pillPanelTop : 10) - (isPill ? 0 : 10))

    implicitWidth:  active ? panelWidth : collapsedWidth
    implicitHeight: active ? openHeight : 40

    Behavior on implicitWidth {
        NumberAnimation {
            duration: root.active ? Appearance.duration.normal : Appearance.duration.large
            easing.type: root.active ? Easing.OutQuad : Easing.InOutCubic
        }
    }
    Behavior on implicitHeight {
        NumberAnimation {
            duration: root.active ? Appearance.duration.normal : Appearance.duration.large
            easing.type: root.active ? Easing.OutQuad : Easing.InOutCubic
        }
    }

    AiChat {
        id: chat
        elevated: root.isPill

        x: root.isPill ? 0 : 10
        y: root.isPill ? root.pillPanelTop : 10
        width:  root.chatWidth
        height: root.chatHeight

        visible: root.contentShown
        opacity: root.contentShown ? 1 : 0

        property real slideX: root.contentShown ? 0 : (root.isPill ? -40 : 0)
        transform: Translate { x: chat.slideX }

        Behavior on opacity {
            NumberAnimation {
                duration: root.contentShown ? Appearance.duration.normal : Appearance.duration.small
                easing.type: Easing.OutQuad
            }
        }
        Behavior on slideX {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        onClosed: ServiceAi.hide()
    }

    RowLayout{
        id: outerRow
        anchors.left: parent.left
        anchors.leftMargin: 10
        y: (40 - height) / 2
        spacing: 5

        opacity: root.active && !root.isPill ? 0 : 1
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: Appearance.duration.normal; easing.type: Easing.OutQuad }
        }
        Rectangle{
            Layout.preferredWidth: row.implicitWidth + 6
            Layout.preferredHeight: 30
            radius: 15
            color: Colors.surfaceContainer
            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: ScriptModel {
                        values: Array.from({ length: root.wsCount }, (_, i) => i + 1)
                    }

                    delegate: Rectangle {
                        property int workspaceId: modelData
                        property var currentWorkspace: ServiceWorkspaces.getWorkspace(workspaceId)
                        readonly property bool isOccupied: !!currentWorkspace
                        readonly property bool showNumbers: root.wsNumbers

                        // Requires a *known* monitor that isn't ours. During a switch
                        // Hyprland briefly reports a workspace with no monitor yet;
                        // treating that as "elsewhere" made the pill vanish and
                        // reappear, which is what made the row jump.
                        readonly property bool onOtherMonitor: root.perMonitorMode
                            && !!currentWorkspace
                            && !!currentWorkspace.monitor
                            && currentWorkspace.monitor.name !== layout.screen.name

                        readonly property bool occupiedHere: isOccupied && !onOtherMonitor

                        // Per-monitor: ask this monitor what it's showing. Otherwise
                        // fall back to the global focused workspace, which is what
                        // mirrored bars want.
                        readonly property bool isActive: !onOtherMonitor && (root.perMonitorMode
                            ? workspaceId === root.activeWsId
                            : (!!currentWorkspace && currentWorkspace.active))

                        // The slot is always kept. Collapsing it to zero width made
                        // the row resize on every switch, and since the bar centres
                        // its contents that shifted everything either side.
                        visible: true
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: 25
                        Layout.preferredWidth: occupiedHere
                            ? Math.max(25, (topLevels.appList?.width ?? 0) + 12)
                            : 25
                        radius: 15
                        color: isActive     ? Colors.primary
                             : occupiedHere ? Colors.surfaceContainerHighest
                                            : "transparent"

                        border.width: (occupiedHere && !isActive) || onOtherMonitor ? 1 : 0
                        border.color: onOtherMonitor ? Qt.alpha(Colors.outline, 0.35)
                                                     : Qt.alpha(Colors.outline, 0.15)

                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on Layout.preferredWidth  { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on color                  { ColorAnimation  { duration: 200 } }

                        Rectangle{
                            visible: !occupiedHere
                            implicitWidth: 5
                            implicitHeight: 5
                            // Dimmer when the workspace exists but lives elsewhere,
                            // so an empty slot still reads differently from a busy one
                            color: onOtherMonitor ? Qt.alpha(Colors.outline, 0.45) : Colors.outline
                            radius: width / 2
                            anchors.centerIn: parent
                        }

                        Loader {
                            id: topLevels
                            anchors.fill: parent
                            active: occupiedHere && !showNumbers
                            visible: active
                            sourceComponent: TopLevels {}
                            property var appList: item ? item.appList : null
                        }

                        CustomText {
                            anchors.centerIn: parent
                            visible: showNumbers && occupiedHere
                            content: workspaceId.toString()
                            size: 10
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

                // Other-monitors indicator. Presence is keyed off the monitor count,
                // not the other monitor's workspace count: Hyprland destroys a
                // workspace as soon as you leave it empty, so counting workspaces
                // made this pill appear and vanish — resizing the centred row on
                // this bar every time the *other* monitor changed workspace.
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 25
                    Layout.preferredWidth: root.showOtherIndicator ? 25 : 0
                    opacity: root.showOtherIndicator ? 1 : 0
                    visible: Layout.preferredWidth > 0
                    radius: 12
                    color: root.otherFocused ? Colors.primary : "transparent"
                    border.width: root.otherFocused ? 0 : 1
                    border.color: Qt.alpha(Colors.outline, 0.35)

                    Behavior on color                 { ColorAnimation  { duration: 200 } }
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity               { NumberAnimation { duration: 180 } }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "tv_displays"
                        iconSize: 12
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
        Rectangle {
            Layout.leftMargin: 10
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: Colors.surfaceContainer

            MaterialIconSymbol {
                anchors.centerIn: parent
                content: Hyprland.activeToplevel ? "ad" : "desktop_windows"
                iconSize: 18
                customColor: Colors.surfaceText
                Behavior on customColor { ColorAnimation { duration: 150 } }
            }
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth:  titleCol.implicitWidth
            Layout.preferredHeight: titleCol.implicitHeight

            Item {
                clip: true
                height: parent.height
                width: Math.max(0, parent.width
                    - Math.max(0, root.collapsedWidth - root.implicitWidth))

                ColumnLayout {
                    id: titleCol
                    width: implicitWidth
                    spacing: 0

                    CustomText {
                        Layout.maximumWidth: 200
                        content: ToplevelManager.activeToplevel
                                 ? (ToplevelManager.activeToplevel.appId ?? "")
                                 : "Desktop"
                        size: 10
                        weight: 700
                        customColor: Colors.outline
                        elide: Text.ElideRight
                    }
                    CustomText {
                        Layout.maximumWidth: 200
                        content: ToplevelManager.activeToplevel
                                 ? (ToplevelManager.activeToplevel.title ?? "")
                                 : "Workspace " + (Hyprland.focusedMonitor?.activeWorkspace?.id ?? "")

                        size: 13
                        weight: 800
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

}
