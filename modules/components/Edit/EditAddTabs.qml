pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Rectangle {
    id: tabs
    property string current: "parts"

    readonly property var kinds: [
        { value: "parts",   label: "Bar parts",       icon: "dock_to_left", layer: "edges" },
        { value: "widgets", label: "Widgets",         icon: "widgets",      layer: "desktop" }
    ]
    readonly property string query: GlobalStates.editAddQuery.trim().toLowerCase()

    function go(kind) {
        if (kind === tabs.current)
            return
        const k = tabs.kinds.find(x => x.value === kind)
        if (!k)
            return
        if (kind === "widgets")
            GlobalStates.widgetOpenAdd = true
        else
            GlobalStates.editOpenAdd = kind
        GlobalStates.editLayer = k.layer
    }

    implicitHeight: 40
    implicitWidth: tabRow.implicitWidth + 6
    radius: 20
    color: Colors.surfaceContainerLow

    Row {
        id: tabRow
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: tabs.kinds

            delegate: Rectangle {
                id: tab
                required property var modelData
                readonly property bool on: tabs.current === tab.modelData.value
                readonly property int hits: tabs.query !== "" ? EditSession.search(tab.modelData.value, tabs.query) : -1
                width: tabInner.implicitWidth + 24
                height: 34
                radius: 17
                color: tab.on ? Colors.secondaryContainer
                    : tabArea.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
                Behavior on color { EffectsColorAnim { speed: "fast" } }

                RowLayout {
                    id: tabInner
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIconSymbol {
                        content: tab.modelData.icon
                        iconSize: 16
                        customColor: tab.on ? Colors.secondaryContainerText : Colors.surfaceVariantText
                    }
                    CustomText {
                        content: tab.modelData.label
                        size: 12
                        weight: tab.on ? 700 : 500
                        customColor: tab.on ? Colors.secondaryContainerText : Colors.surfaceText
                    }
                    Rectangle {
                        visible: tab.hits >= 0
                        implicitWidth: Math.max(20, hitText.implicitWidth + 10)
                        implicitHeight: 18
                        radius: 9
                        color: tab.hits > 0 ? Colors.primary : Colors.surfaceContainerHighest

                        CustomText {
                            id: hitText
                            anchors.centerIn: parent
                            content: String(Math.max(0, tab.hits))
                            size: 10
                            weight: 700
                            customColor: tab.hits > 0 ? Colors.primaryText : Colors.outline
                        }
                    }
                }

                MouseArea {
                    id: tabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tabs.go(tab.modelData.value)
                }
            }
        }
    }
}
