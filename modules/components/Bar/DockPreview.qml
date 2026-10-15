import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.customComponents
import qs.modules.utils
import qs.modules.settings

Item {
    id: root
    readonly property int rowHeight: 38
    readonly property int rowSpacing: 2
    readonly property int layoutMargins: 8
    readonly property int headerHeight: 28
    readonly property int maxRows: 8

    property var appEntry: null
    property real maxWidth: 100000

    signal activated

    readonly property var tops: root.appEntry?.toplevels ?? []
    readonly property int count: Math.max(1, root.tops.length)
    readonly property int shownRows: Math.min(root.count, root.maxRows)
    readonly property real listHeight: root.shownRows * (root.rowHeight + root.rowSpacing) - root.rowSpacing

    implicitWidth: Math.min(300, root.maxWidth)
    implicitHeight: root.layoutMargins * 2 + root.headerHeight + 6 + root.listHeight

    onAppEntryChanged: list.contentY = 0

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.layoutMargins
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.headerHeight
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 8

            Image {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                source: IconUtil.themeIcon(
                    DesktopEntries.heuristicLookup(root.appEntry?.appId ?? "")?.icon,
                    "image-missing")
                sourceSize.width: 18
                sourceSize.height: 18
                fillMode: Image.PreserveAspectFit
            }

            CustomText {
                Layout.fillWidth: true
                content: DesktopEntries.heuristicLookup(root.appEntry?.appId ?? "")?.name
                         ?? root.appEntry?.appId ?? ""
                size: 12
                weight: 700
                elide: Text.ElideRight
                customColor: Colors.outline
            }

            CustomText {
                visible: root.tops.length > 1
                content: root.tops.length + " windows"
                size: 10
                weight: 600
                customColor: Colors.outline
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.tops
            spacing: root.rowSpacing
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: root.tops.length > root.maxRows

            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool focused: !!row.modelData.activated
                width: ListView.view.width
                height: root.rowHeight
                radius: 12
                color: row.focused ? Colors.surfaceContainerHighest
                     : rowRipple.containsMouse ? Colors.surfaceContainerHigh : "transparent"
                Behavior on color { EffectsColorAnim { speed: "fast" } }

                RippleEffect {
                    id: rowRipple
                    anchors.fill: parent
                    radius: 12
                    onClicked: {
                        row.modelData.activate()
                        root.activated()
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 5
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: Colors.primary
                        visible: row.focused
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: row.modelData.title || (DesktopEntries.heuristicLookup(root.appEntry?.appId ?? "")?.name ?? "")
                        size: 12
                        weight: row.focused ? 600 : 500
                        elide: Text.ElideRight
                        customColor: Colors.surfaceText
                    }

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 14
                        color: closeRipple.containsMouse ? Colors.surfaceContainerHighest : "transparent"
                        opacity: rowRipple.containsMouse || closeRipple.containsMouse || row.focused ? 1 : 0
                        Behavior on opacity { EffectsAnim { speed: "fast" } }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "close"
                            iconSize: 15
                            customColor: closeRipple.containsMouse ? Colors.error : Colors.outline
                        }

                        RippleEffect {
                            id: closeRipple
                            anchors.fill: parent
                            radius: 14
                            onClicked: row.modelData.close()
                        }
                    }
                }
            }
        }
    }
}
