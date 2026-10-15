import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Scope {
    id: scope

    readonly property var screen: {
        const name = Hyprland.focusedMonitor?.name ?? ""
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0]
    }
    readonly property bool hidden: !!Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen || ServiceGameMode.hideWidgets

    function iconFor(cls) {
        const e = DesktopEntries.heuristicLookup(cls)
        return IconUtil.themeIcon(e?.icon ?? "", true)
    }
    function nameFor(cls) {
        return DesktopEntries.heuristicLookup(cls)?.name ?? (cls || "Window")
    }

    PanelWindow {
        id: win
        property string hoverAddr: ""
        readonly property var hovered: ServiceTuck.tucked.find(e => e.address === win.hoverAddr) ?? null

        screen: scope.screen
        visible: ServiceTuck.tucked.length > 0 && !scope.hidden
        anchors { top: true; bottom: true; right: true }
        implicitWidth: 320
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell:tuck"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {
            Region { item: tabs }
            Region { item: card.visible ? card : none }
        }
        Item { id: none; width: 0; height: 0 }

        Timer {
            id: leave
            interval: 220
            onTriggered: if (!cardHover.hovered) win.hoverAddr = ""
        }

        Column {
            id: tabs
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Repeater {
                model: ServiceTuck.tucked

                Rectangle {
                    id: tab
                    required property var modelData
                    readonly property bool hot: tabArea.containsMouse || win.hoverAddr === tab.modelData.address
                    anchors.right: parent.right
                    width: tab.hot ? 34 : 28
                    height: 66
                    topLeftRadius: 14
                    bottomLeftRadius: 14
                    color: tab.hot ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                    border.width: 1
                    border.color: Colors.surfaceContainerHighest
                    Behavior on width { SpatialAnim { speed: "fast" } }

                    Column {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 1
                        spacing: 7
                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitSize: 18
                            source: scope.iconFor(tab.modelData.cls)
                            visible: source != ""
                        }
                        MaterialIconSymbol {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: scope.iconFor(tab.modelData.cls) === ""
                            content: "web_asset"
                            iconSize: 17
                            customColor: Colors.primary
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 3
                            height: 16
                            radius: 1.5
                            color: Colors.outlineVariant
                        }
                    }

                    MouseArea {
                        id: tabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: {
                            if (containsMouse) {
                                leave.stop()
                                win.hoverAddr = tab.modelData.address
                            } else {
                                leave.restart()
                            }
                        }
                        onClicked: mouse => {
                            win.hoverAddr = ""
                            if (mouse.button === Qt.MiddleButton)
                                ServiceTuck.close(tab.modelData.address)
                            else
                                ServiceTuck.restore(tab.modelData.address)
                        }
                    }
                }
            }
        }

        Rectangle {
            id: card
            readonly property var entry: win.hovered
            visible: !!card.entry
            width: 250
            height: cardCol.implicitHeight + 24
            x: win.width - 46 - width
            y: {
                const i = ServiceTuck.tucked.findIndex(e => e.address === win.hoverAddr)
                const ty = tabs.y + Math.max(0, i) * 74 + 33 - height / 2
                return Math.max(52, Math.min(win.height - height - 12, ty))
            }
            radius: 20
            color: Colors.surfaceContainer
            border.width: 1
            border.color: Colors.surfaceContainerHigh

            HoverHandler {
                id: cardHover
                onHoveredChanged: if (!hovered) leave.restart(); else leave.stop()
            }

            ColumnLayout {
                id: cardCol
                x: 12
                y: 12
                width: parent.width - 24
                spacing: 10

                RowLayout {
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 12
                        color: Colors.surfaceContainerHighest
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 22
                            source: card.entry ? scope.iconFor(card.entry.cls) : ""
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        CustomText {
                            Layout.fillWidth: true
                            content: card.entry?.title ?? ""
                            size: 13
                            weight: 600
                            elide: Text.ElideRight
                        }
                        CustomText {
                            Layout.fillWidth: true
                            content: card.entry ? scope.nameFor(card.entry.cls) + ", tucked from workspace " + card.entry.from : ""
                            size: 11
                            customColor: Colors.outline
                            elide: Text.ElideRight
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 12
                        color: backArea.containsMouse ? Qt.lighter(Colors.primary, 1.08) : Colors.primary
                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            MaterialIconSymbol { content: "left_panel_open"; iconSize: 16; customColor: Colors.primaryText; anchors.verticalCenter: parent.verticalCenter }
                            CustomText { content: "Bring back"; size: 12; weight: 600; customColor: Colors.primaryText; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: backArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const a = win.hoverAddr
                                win.hoverAddr = ""
                                ServiceTuck.restore(a)
                            }
                        }
                    }
                    M3IconButton {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        icon: "close"
                        iconSize: 18
                        onClicked: {
                            const a = win.hoverAddr
                            win.hoverAddr = ""
                            ServiceTuck.close(a)
                        }
                    }
                }
            }
        }
    }
}
