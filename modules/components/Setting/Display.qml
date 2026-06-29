import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    property var monitorList: ServiceDisplay.monitorList
    property string selectedMonitor: monitorList.length > 0 ? monitorList[0].name : ""

    property var selectedMonitorData: {
        if (!monitorList || monitorList.length === 0) return null
        return monitorList.find(m => m.name === selectedMonitor) ?? null
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        contentWidth:  width
        clip: true

        ColumnLayout {
            id: column
            width: parent.width
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    parent.top
            anchors.leftMargin:  5
            anchors.rightMargin: 5
            anchors.topMargin:   5
            spacing: 0

            // ── Page header ──────────────────────────────────────────────
            RowLayout {
                spacing: 10
                MaterialIconSymbol { content: "monitor"; iconSize: 20 }
                CustomText { content: "Display"; size: 20; customColor: Colors.primary }
            }

            // ── Arrangement ──────────────────────────────────────────────
            CustomText { Layout.topMargin: 24; content: "Arrangement"; size: 13; customColor: Colors.primary }

            // Monitor map
            CustomCard {
                Layout.topMargin: 6
                autoRadius: false; topRadius: 20; bottomRadius: 20

                Item {
                    id: monitorMap
                    Layout.fillWidth: true
                    Layout.preferredHeight: 130

                    property var monitors: root.monitorList || []
                    property real minX: monitors.length > 0 ? Math.min(...monitors.map(m => m.x)) : 0
                    property real minY: monitors.length > 0 ? Math.min(...monitors.map(m => m.y)) : 0
                    property real maxX: monitors.length > 0 ? Math.max(...monitors.map(m => m.x + m.width))  : 1920
                    property real maxY: monitors.length > 0 ? Math.max(...monitors.map(m => m.y + m.height)) : 1080
                    property real totalW: maxX - minX
                    property real totalH: maxY - minY
                    property real scl: Math.min(
                        totalW > 0 ? width  / totalW : 1,
                        totalH > 0 ? height / totalH : 1
                    ) * 0.88
                    property real offX: (width  - totalW * scl) / 2
                    property real offY: (height - totalH * scl) / 2

                    Repeater {
                        model: monitorMap.monitors

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool isSelected: modelData.name === root.selectedMonitor
                            readonly property bool isPrimary:
                                (SettingsConfig.general.primaryMonitor ?? "") === modelData.name

                            x:      (modelData.x - monitorMap.minX) * monitorMap.scl + monitorMap.offX
                            y:      (modelData.y - monitorMap.minY) * monitorMap.scl + monitorMap.offY
                            width:  modelData.width  * monitorMap.scl
                            height: modelData.height * monitorMap.scl

                            radius: 10
                            color: isSelected ? Colors.primary : Colors.surfaceContainerHighest
                            border.width: isPrimary && !isSelected ? 2 : 0
                            border.color: Colors.primary

                            Behavior on color { ColorAnimation { duration: 180 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3

                                CustomText {
                                    Layout.alignment: Qt.AlignHCenter
                                    content: modelData.name
                                    size: 11; weight: 700
                                    customColor: parent.parent.isSelected
                                                 ? Colors.primaryText : Colors.surfaceText
                                    Behavior on customColor { ColorAnimation { duration: 180 } }
                                }
                                CustomText {
                                    Layout.alignment: Qt.AlignHCenter
                                    content: modelData.resolution ?? ""
                                    size: 9; weight: 400
                                    customColor: parent.parent.isSelected
                                                 ? Qt.alpha(Colors.primaryText, 0.75) : Colors.outline
                                    Behavior on customColor { ColorAnimation { duration: 180 } }
                                }
                            }

                            // Primary star badge
                            Rectangle {
                                visible: isPrimary
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: 4
                                anchors.rightMargin: 4
                                width: 16; height: 16; radius: 8
                                color: isSelected ? Qt.alpha(Colors.primaryText, 0.25) : Colors.primaryContainer

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: "star"; iconSize: 10
                                    customColor: isSelected ? Colors.primaryText : Colors.primaryContainerText
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: root.selectedMonitor = modelData.name
                            }
                        }
                    }
                }
            }

            // Display mode group buttons
            RowLayout {
                Layout.topMargin: 10
                Layout.fillWidth: true
                spacing: 0

                Item { Layout.fillWidth: true }

                ButtonGroup {
                    height: 32
                    model: [
                        { value: "Extended", label: "Extended", icon: "pan_zoom" },
                        { value: "Mirror",   label: "Mirror",   icon: "tv_displays" },
                        { value: "Single",   label: "Single",   icon: "monitor" }
                    ]
                    activeCheck: function(v) { return Settings.currentDisplayMode === v }
                    onSegmentClicked: v => Settings.currentDisplayMode = v
                    inactiveColor: Colors.surfaceContainerHighest
                    textSize: 12; iconSize: 16
                }

                Item { Layout.fillWidth: true }
            }

            // ── Monitor configuration ─────────────────────────────────────
            RowLayout {
                Layout.topMargin: 20
                Layout.fillWidth: true

                CustomText {
                    content: "Monitor"
                    size: 13; customColor: Colors.primary
                }

                Item { Layout.fillWidth: true }

                // Per-monitor selector (shown only when >1 monitor)
                ButtonGroup {
                    visible: root.monitorList.length > 1
                    height: 28
                    model: root.monitorList.map(m => ({ value: m.name, label: m.name }))
                    activeCheck: function(v) { return root.selectedMonitor === v }
                    onSegmentClicked: v => root.selectedMonitor = v
                    inactiveColor: Colors.surfaceContainerHighest
                    textSize: 11
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Resolution"; size: 14 }
                            CustomText {
                                content: "Active resolution for " + (root.selectedMonitor || "monitor")
                                size: 12; customColor: Colors.outline
                            }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            id: resList
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 170
                            color: Colors.surfaceContainerHighest
                            currentVal: root.selectedMonitorData?.resolution ?? ""
                            list: root.selectedMonitorData?.availableResolutions ?? []
                            onIsListClickedChanged: {
                                if (isListClicked) grab.active = false
                                else grab.active = true
                            }
                        }
                    }
                }

                CustomCard {
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Refresh Rate"; size: 14 }
                            CustomText {
                                content: "Hz for " + (root.selectedMonitor || "monitor")
                                size: 12; customColor: Colors.outline
                            }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            id: rateList
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 120
                            color: Colors.surfaceContainerHighest
                            currentVal: root.selectedMonitorData?.refreshRate ?? ""
                            list: root.selectedMonitorData?.availableRefreshRates ?? []
                            onIsListClickedChanged: {
                                if (isListClicked) grab.active = false
                                else grab.active = true
                            }
                        }
                    }
                }

                CustomCard {
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Variable Refresh Rate"; size: 14 }
                            CustomText {
                                content: "Adaptive sync (G-Sync / FreeSync)"
                                size: 12; customColor: Colors.outline
                            }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: root.selectedMonitorData?.vrr ?? false
                        }
                    }
                }
            }

            // ── Bar ───────────────────────────────────────────────────────
            CustomText { Layout.topMargin: 20; content: "Bar"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Primary monitor"; size: 14 }
                            CustomText {
                                content: {
                                    const pm = SettingsConfig.general.primaryMonitor ?? ""
                                    return pm === ""
                                        ? "All monitors show the full bar"
                                        : pm + " shows full bar · others show minimal bar"
                                }
                                size: 12; customColor: Colors.outline
                            }
                        }
                        Item { Layout.fillWidth: true }

                        ButtonGroup {
                            height: 30
                            model: {
                                const all = [{ value: "", label: "All", icon: "devices" }]
                                return all.concat(root.monitorList.map(m => ({
                                    value: m.name, label: m.name
                                })))
                            }
                            activeCheck: function(v) {
                                return (SettingsConfig.general.primaryMonitor ?? "") === v
                            }
                            onSegmentClicked: v => {
                                SettingsConfig.general = Object.assign(
                                    {}, SettingsConfig.general, { primaryMonitor: v })
                            }
                            inactiveColor: Colors.surfaceContainerHighest
                            textSize: 11; iconSize: 14
                        }
                    }
                }
            }

            // ── Workspaces ────────────────────────────────────────────────
            CustomText { Layout.topMargin: 20; content: "Workspaces"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Per-monitor workspaces"; size: 14 }
                            CustomText {
                                content: SettingsConfig.general.perMonitorWorkspaces
                                    ? "Each monitor shows only its own workspaces"
                                    : "All workspaces visible on every monitor"
                                size: 12; customColor: Colors.outline
                            }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.general.perMonitorWorkspaces ?? false
                            onToggled: state => {
                                SettingsConfig.general = Object.assign(
                                    {}, SettingsConfig.general, { perMonitorWorkspaces: state })
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
