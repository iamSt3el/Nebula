import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "sysMemory"
    tile: Qt.size(WidgetSizes.span(3), WidgetSizes.span(1))
    resizable: true
    minSpan: Qt.size(3, 1)
    maxSpan: Qt.size(6, 1)
    turnable: true
    defaultPos: Qt.point(1245, 495)

    readonly property var si: root.preview ? PreviewData : ServiceSystemInfo
    Component.onCompleted: root.si.retain()
    Component.onDestruction: root.si.release()

    readonly property bool tight: root.si.memUsage > 0.9
    readonly property real used: Math.max(0, root.si.memUsage)
    readonly property real cache: Math.max(0, Math.min(1 - root.used, root.si.memCacheFrac))
    readonly property real buffers: Math.max(0, Math.min(1 - root.used - root.cache, root.si.memBuffersFrac))
    readonly property var parts: [
        { name: "Used", frac: root.used, tone: root.tight ? Colors.error : Colors.primary },
        { name: "Cache", frac: root.cache, tone: Colors.tertiary },
        { name: "Buffers", frac: root.buffers, tone: Colors.secondary },
        { name: "Free", frac: Math.max(0, 1 - root.used - root.cache - root.buffers), tone: Colors.surfaceContainerHighest }
    ]

    WidgetCard {
        id: card
        anchors.fill: parent

        ColumnLayout {
            visible: root.turned
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 0
                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: "RAM"
                    size: 10
                    weight: 600
                    font.letterSpacing: 0.6
                    customColor: Colors.surfaceVariantText
                }
                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: root.si.memUsedGb.toFixed(1)
                    size: 18
                    weight: 600
                    customColor: root.tight ? Colors.error : Colors.primary
                }
                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: "of " + root.si.memTotalGb.toFixed(0) + " GB"
                    size: 10
                    customColor: Colors.outline
                }
            }

            Item {
                id: column
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                implicitWidth: 30

                readonly property real gap: 3
                readonly property real room: height - gap * 3
                readonly property var heights: {
                    const h = root.parts.slice(0, 3).map(p => Math.max(4, column.room * p.frac))
                    h.push(Math.max(4, column.room - h[0] - h[1] - h[2]))
                    return h
                }

                Column {
                    anchors.bottom: parent.bottom
                    spacing: column.gap
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            readonly property int part: 3 - index
                            width: column.width
                            height: column.heights[part]
                            Behavior on height { SpatialAnim {} }
                            color: root.parts[part].tone
                            topLeftRadius: part === 3 ? 15 : 5
                            topRightRadius: part === 3 ? 15 : 5
                            bottomLeftRadius: part === 0 ? 15 : 5
                            bottomRightRadius: part === 0 ? 15 : 5
                        }
                    }
                }
            }
        }

        ColumnLayout {
            visible: !root.turned
            anchors.fill: parent
            anchors.leftMargin: card.pad
            anchors.rightMargin: card.pad
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                CustomText {
                    Layout.alignment: Qt.AlignBaseline
                    content: "Memory"
                    size: 13
                    weight: 600
                }
                Item { Layout.fillWidth: true }
                CustomText {
                    Layout.alignment: Qt.AlignBaseline
                    content: root.si.memUsedGb.toFixed(1) + " GB"
                    size: 15
                    weight: 600
                    customColor: root.tight ? Colors.error : Colors.primary
                }
                CustomText {
                    Layout.alignment: Qt.AlignBaseline
                    content: "/ " + root.si.memTotalGb.toFixed(1) + " GB"
                    size: 12
                    customColor: Colors.outline
                }
            }

            Item {
                id: bar
                Layout.fillWidth: true
                Layout.preferredHeight: 24

                readonly property real gap: 3
                readonly property real room: width - gap * 3
                readonly property var widths: {
                    const w = root.parts.slice(0, 3).map(p => Math.max(4, bar.room * p.frac))
                    w.push(Math.max(4, bar.room - w[0] - w[1] - w[2]))
                    return w
                }

                Row {
                    spacing: bar.gap
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            readonly property var part: root.parts[index]
                            width: bar.widths[index]
                            Behavior on width { SpatialAnim {} }
                            height: 24
                            color: part.tone
                            topLeftRadius: index === 0 ? 12 : 5
                            bottomLeftRadius: index === 0 ? 12 : 5
                            topRightRadius: index === 3 ? 12 : 5
                            bottomRightRadius: index === 3 ? 12 : 5
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Repeater {
                    model: 4
                    RowLayout {
                        required property int index
                        spacing: 4
                        Rectangle {
                            implicitWidth: 7
                            implicitHeight: 7
                            radius: 3.5
                            color: root.parts[index].tone
                            border.width: index === 3 ? 1 : 0
                            border.color: Colors.outlineVariant
                        }
                        CustomText {
                            content: root.parts[index].name
                            size: 10
                            customColor: Colors.surfaceVariantText
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }
    }
}
