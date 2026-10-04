import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "mostOpened"
    tile: WidgetSizes.small
    defaultPos: Qt.point(1135, 165)

    readonly property var ranked: {
        const u = ServiceApps.usage
        const list = ServiceApps.list.filter(a => (u[a.id]?.count ?? 0) > 0)
        list.sort((a, b) => u[b.id].count - u[a.id].count)
        return list.slice(0, 3).map(a => ({ app: a, n: u[a.id].count }))
    }
    readonly property var podium: root.ranked.length >= 3 ? [root.ranked[1], root.ranked[0], root.ranked[2]]
        : root.ranked.length === 2 ? [root.ranked[1], root.ranked[0]] : root.ranked
    readonly property var heights: root.ranked.length >= 3 ? [0.72, 1, 0.56] : root.ranked.length === 2 ? [0.72, 1] : [1]

    WidgetCard {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: parent.pad
            spacing: 6

            WidgetTitle {
                Layout.fillWidth: true
                icon: "rocket_launch"
                title: "Most opened"
            }

            Item {
                id: stage
                Layout.fillWidth: true
                Layout.fillHeight: true

                Row {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Repeater {
                        model: root.podium
                        delegate: Rectangle {
                            id: step
                            required property var modelData
                            required property int index
                            readonly property bool first: step.modelData === root.ranked[0]
                            width: 46
                            height: Math.max(56, stage.height * root.heights[step.index])
                            anchors.bottom: parent.bottom
                            topLeftRadius: 14
                            topRightRadius: 14
                            bottomLeftRadius: 4
                            bottomRightRadius: 4
                            color: step.first ? Colors.primaryContainer : (stepArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh)

                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 8
                                spacing: 4
                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: step.first ? 32 : 26
                                    height: width
                                    source: IconUtil.getDesktopIconPath(step.modelData.app.icon ?? "")
                                    sourceSize.width: 64
                                    sourceSize.height: 64
                                }
                                CustomText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    content: step.modelData.n
                                    size: 12
                                    weight: 600
                                    customColor: step.first ? Colors.primaryContainerText : Colors.surfaceText
                                }
                            }

                            MouseArea {
                                id: stepArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !root.preview
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ServiceApps.run(step.modelData.app)
                            }

                            CustomToolTip {
                                content: step.modelData.app.name
                                visible: stepArea.containsMouse
                            }
                        }
                    }
                }

                CustomText {
                    anchors.centerIn: parent
                    visible: root.ranked.length === 0
                    content: "Open a few apps from\nthe launcher first"
                    horizontalAlignment: Text.AlignHCenter
                    size: 12
                    customColor: Colors.outline
                }
            }

            CustomText {
                Layout.fillWidth: true
                visible: root.ranked.length > 0
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                content: (root.ranked[0]?.app.name ?? "") + " leads"
                size: 11
                customColor: Colors.outline
            }
        }
    }
}
