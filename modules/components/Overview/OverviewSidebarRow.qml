import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: root

    required property int wsId
    property string label: ""
    property bool selected: false
    property bool dropTarget: false
    property bool moveTarget: false
    property bool dimmed: false

    signal clicked()

    readonly property var workspace: ServiceWorkspaces.getWorkspace(root.wsId)
    readonly property bool isActive: root.workspace?.active ?? false
    readonly property var toplevels: root.workspace?.toplevels?.values ?? []
    readonly property int windowCount: root.toplevels.length
    readonly property string monitorName: root.workspace?.monitor?.name ?? ""

    readonly property bool showMonitor:
        root.monitorName !== "" && (Hyprland.monitors?.values?.length ?? 1) > 1

    readonly property var iconSources: {
        var out = []
        const list = root.toplevels
        for (var i = 0; i < list.length && out.length < 6; i++) {
            const id = list[i]?.wayland?.appId ?? ""
            out.push(IconUtil.themeIcon(DesktopEntries.heuristicLookup(id)?.icon, "image-missing"))
        }
        return out
    }

    implicitHeight: 52
    radius: 18

    color: root.dropTarget || root.moveTarget ? Qt.alpha(Colors.primary, 0.16)
         : root.selected                      ? Colors.secondaryContainer
         : rowMa.containsMouse                ? Qt.alpha(Colors.surfaceText, 0.06)
                                              : "transparent"
    Behavior on color { EffectsColorAnim { speed: "fast" } }

    border.width: root.dropTarget || root.moveTarget ? 2 : 0
    border.color: Colors.primary

    opacity: root.dimmed ? 0.4 : 1
    Behavior on opacity { EffectsAnim { speed: "fast" } }

    RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 10
            color: root.isActive ? Colors.primary : Colors.surfaceContainerHighest
            Behavior on color { EffectsColorAnim { speed: "fast" } }

            CustomText {
                anchors.centerIn: parent
                content: root.wsId.toString()
                size: 13
                weight: 800
                customColor: root.isActive ? Colors.primaryText : Colors.surfaceText
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            CustomText {
                Layout.fillWidth: true
                content: root.label
                size: 14
                weight: 600
                elide: Text.ElideRight
                customColor: root.selected ? Colors.secondaryContainerText
                           : root.windowCount === 0 ? Colors.outline : Colors.surfaceText
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: root.windowCount > 0

                Repeater {
                    model: root.iconSources

                    delegate: Image {
                        required property var modelData
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        source: modelData
                        sourceSize: Qt.size(18, 18)
                        fillMode: Image.PreserveAspectFit
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        Rectangle {
            Layout.preferredHeight: 18
            Layout.preferredWidth: monText.implicitWidth + 14
            radius: 9
            color: Colors.surfaceContainerHighest
            visible: root.showMonitor

            CustomText {
                id: monText
                anchors.centerIn: parent
                content: root.monitorName
                size: 9
                weight: 700
                customColor: Colors.outline
            }
        }

        CustomText {
            content: root.windowCount > 0 ? root.windowCount.toString() : ""
            size: 12
            weight: 500
            customColor: Colors.outline
        }
    }

    MouseArea {
        id: rowMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
