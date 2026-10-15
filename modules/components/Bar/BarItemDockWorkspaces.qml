import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: root.groups.length > 0

    readonly property real icon: root.host && root.host.appIconSize ? root.host.appIconSize : 32
    readonly property real across: Math.min(root.icon + 22, root.host && root.host.barH ? root.host.barH : root.icon + 22)
    readonly property bool vertical: !!root.host && root.host.vertical === true
    readonly property bool verticalReady: true
    readonly property int entriesVersion: ServiceApps.list.length
    readonly property bool showEmpty: BarLayout.opt(root.itemId, "showEmpty") === true
    readonly property int slotCount: parseInt(SettingsConfig.general?.workspaceCount ?? 10) || 10

    readonly property var groups: {
        const byWs = new Map()
        const tops = Hyprland.toplevels?.values ?? []

        for (var i = 0; i < tops.length; i++) {
            const t = tops[i]
            const ws = t?.workspace?.id ?? -1
            if (ws < 1) continue
            if (!byWs.has(ws)) byWs.set(ws, new Map())

            const apps = byWs.get(ws)
            const id = t?.wayland?.appId ?? ""
            const key = id.toLowerCase()
            if (!apps.has(key)) apps.set(key, { appId: id, toplevels: [] })
            apps.get(key).toplevels.push(t)
        }

        if (root.showEmpty) {
            for (var n = 1; n <= root.slotCount; n++)
                if (!byWs.has(n)) byWs.set(n, new Map())
        }

        const out = []
        byWs.forEach((apps, ws) => out.push({ ws: ws, apps: Array.from(apps.values()) }))
        out.sort((a, b) => a.ws - b.ws)
        return out
    }

    implicitWidth: root.vertical ? root.across : row.implicitWidth
    implicitHeight: root.vertical ? row.implicitHeight : root.across

    Grid {
        id: row
        anchors.centerIn: parent
        spacing: 8
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1

        Repeater {
            model: root.groups

            delegate: Rectangle {
                id: group
                required property var modelData

                readonly property int wsId: group.modelData.ws
                readonly property var apps: group.modelData.apps
                readonly property bool isActive:
                    (ServiceWorkspaces.getWorkspace(group.wsId)?.active) ?? false

                width: root.vertical ? root.icon + 14 : groupRow.implicitWidth + 18
                height: root.vertical ? groupRow.implicitHeight + 18 : root.icon + 14
                radius: Math.min(width, height) / 2
                color: group.isActive ? Colors.secondaryContainer : Colors.surfaceContainer
                Behavior on color { EffectsColorAnim { speed: "fast" } }

                Grid {
                    id: groupRow
                    x: root.vertical ? (parent.width - width) / 2 : 6
                    y: root.vertical ? 6 : (parent.height - height) / 2
                    spacing: 8
                    rows: root.vertical ? -1 : 1
                    columns: root.vertical ? 1 : -1
                    horizontalItemAlignment: Grid.AlignHCenter
                    verticalItemAlignment: Grid.AlignVCenter

                    Rectangle {
                        width: 26; height: 26
                        radius: 13
                        color: group.isActive ? Colors.primary : Colors.surfaceContainerHighest
                        Behavior on color { EffectsColorAnim { speed: "fast" } }

                        CustomText {
                            anchors.centerIn: parent
                            content: group.wsId.toString()
                            size: 12
                            weight: 800
                            customColor: group.isActive ? Colors.primaryText : Colors.surfaceText
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ServiceWorkspaces.activateWorkspaceId(group.wsId)
                        }
                    }

                    Repeater {
                        model: group.apps

                        delegate: Item {
                            id: app
                            required property var modelData

                            readonly property var tops: app.modelData.toplevels
                            readonly property bool isActive: app.tops.some(t => t?.activated === true)
                            readonly property int winCount: Math.min(app.tops.length, 3)

                            width: root.icon
                            height: root.icon + 8

                            Rectangle {
                                anchors.centerIn: appIcon
                                width: root.icon + 4
                                height: width
                                radius: root.host && root.host.isPill ? Math.max(0, root.host.pillRadius - (root.host.barH - width) / 2) : 8
                                color: appMa.containsMouse ? Colors.primaryContainer : Qt.alpha(Colors.primaryContainer, 0)
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Image {
                                id: appIcon
                                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: (root.icon - 2 - height) / 2 }
                                width: root.icon - 2
                                height: width
                                smooth: true
                                mipmap: true
                                source: root.entriesVersion >= 0
                                    ? IconUtil.themeIcon(
                                        DesktopEntries.heuristicLookup(app.modelData.appId)?.icon, "image-missing")
                                    : ""
                                sourceSize.width: 96
                                sourceSize.height: 96
                                fillMode: Image.PreserveAspectFit

                            }

                            Rectangle {
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                                width: app.winCount === 1 ? 6 : app.winCount === 2 ? 12 : 18
                                height: 4
                                radius: 2
                                color: app.isActive ? Colors.primary : Qt.alpha(Colors.primary, 0.45)
                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            }

                            CustomToolTip {
                                visible: appMa.containsMouse
                                content: app.tops.length > 0 && app.tops[0].title ? app.tops[0].title : app.modelData.appId
                            }

                            MouseArea {
                                id: appMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (app.tops.length === 0) return
                                    app.tops[0].wayland?.activate()
                                }
                            }
                        }
                    }

                    CustomText {
                        visible: group.apps.length === 0 && !root.vertical
                        content: "empty"
                        size: 11
                        weight: 500
                        customColor: Colors.outline
                    }
                }
            }
        }
    }
}
