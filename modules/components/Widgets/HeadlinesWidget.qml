import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "headlines"
    tile: WidgetSizes.wide
    resizable: true
    minSpan: Qt.size(3, 2)
    maxSpan: Qt.size(6, 5)
    defaultPos: Qt.point(620, 900)

    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"
    readonly property real pad: WidgetSizes.padFor(root.width)
    readonly property int leadLines: root.height > WidgetSizes.span(2) + 1 ? 3 : 2
    readonly property int follows: Math.max(0, Math.floor((root.height - root.pad * 2 - 22 - 10 - root.leadLines * 21 - 10 + 2) / 38))
    readonly property int pageSize: 1 + root.follows

    readonly property var sampleHeadlines: [
        { title: "Markets close higher as inflation eases for a third month" },
        { title: "Researchers map an ocean current that had gone unrecorded" },
        { title: "City transit plan adds two lines and a night service" },
        { title: "Long-running telescope survey releases its final catalogue" },
        { title: "New standard promises faster charging across devices" },
        { title: "Archive of early radio broadcasts goes online this week" }
    ]

    readonly property var items: root.preview ? root.sampleHeadlines : ServiceNews.headlines

    property int page: 0
    readonly property int pageCount: Math.max(1, Math.ceil(root.items.length / root.pageSize))
    readonly property int pageIndex: root.page % root.pageCount
    readonly property var visibleItems: {
        if (root.items.length === 0) return []
        const start = root.pageIndex * root.pageSize
        return root.items.slice(start, start + root.pageSize)
    }
    readonly property var leadItem: root.visibleItems.length > 0 ? root.visibleItems[0] : null
    readonly property var followItems: root.visibleItems.slice(1)

    readonly property string age: {
        ServiceClock.date
        if (root.preview) return "12 min ago"
        const t = ServiceNews.lastUpdated
        if (!t) return ""
        const m = Math.max(0, Math.round((Date.now() - t.getTime()) / 60000))
        return m < 1 ? "just now" : m < 60 ? m + " min ago" : Math.round(m / 60) + " h ago"
    }

    function open(item) {
        if (!root.preview && item && item.link)
            Qt.openUrlExternally(item.link)
    }

    Component.onCompleted: if (!root.preview) ServiceNews.retain()
    Component.onDestruction: if (!root.preview) ServiceNews.release()

    onItemsChanged: root.page = 0

    Timer {
        interval: 15000
        repeat: true
        running: !root.preview && root.pageCount > 1
        onTriggered: root.page = (root.page + 1) % root.pageCount
    }

    WidgetCard {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.pad
            spacing: 10
            visible: root.items.length > 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    implicitWidth: chipRow.implicitWidth + 16
                    implicitHeight: 22
                    radius: 11
                    color: Colors.tertiaryContainer

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialIconSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            content: "public"
                            iconSize: 13
                            customColor: Colors.tertiaryContainerText
                        }
                        CustomText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, root.width * 0.42)
                            content: (root.preview ? "World News"
                                     : (ServiceNews.channelTitle.length > 0 ? ServiceNews.channelTitle : "Headlines")).toUpperCase()
                            size: 10
                            weight: 800
                            font.letterSpacing: 0.3
                            elide: Text.ElideRight
                            customColor: Colors.tertiaryContainerText
                        }
                    }
                }

                CustomText {
                    content: root.age
                    size: 11
                    weight: 500
                    customColor: Colors.surfaceVariantText
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: 3
                    visible: root.pageCount > 1
                    Repeater {
                        model: root.pageCount
                        delegate: Rectangle {
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: index === root.pageIndex ? 16 : 5
                            height: 5
                            radius: 2.5
                            color: index === root.pageIndex ? Colors.primary : Colors.outlineVariant
                            Behavior on width { SpatialAnim { speed: "fast" } }
                        }
                    }
                }

                Loader {
                    active: !root.preview && ServiceNews.isLoading
                    visible: active
                    sourceComponent: CustomCircularLoader {
                        size: 14; trackWidth: 2
                        waveAmplitude: 0
                        highlightColor: Colors.outline
                    }
                }

                MaterialIconSymbol {
                    visible: !root.preview && !ServiceNews.isLoading
                    content: "refresh"
                    iconSize: 16
                    customColor: Colors.outline
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ServiceNews.refresh()
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: leadText.implicitHeight

                CustomText {
                    id: leadText
                    width: parent.width
                    content: root.leadItem ? root.leadItem.title : ""
                    size: 17
                    weight: 800
                    wrapMode: Text.WordWrap
                    maximumLineCount: root.leadLines
                    elide: Text.ElideRight
                    lineHeight: 1.1
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.preview && !!root.leadItem && !!root.leadItem.link
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.open(root.leadItem)
                }
            }

            Item { Layout.fillHeight: true }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                visible: root.followItems.length > 0

                Repeater {
                    model: root.followItems
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        readonly property bool first: row.index === 0
                        readonly property bool last: row.index === root.followItems.length - 1
                        topLeftRadius: row.first ? 12 : 4
                        topRightRadius: row.first ? 12 : 4
                        bottomLeftRadius: row.last ? 12 : 4
                        bottomRightRadius: row.last ? 12 : 4
                        color: rowArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                        Behavior on color { EffectsColorAnim {} }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8
                            CustomText {
                                content: (row.index + 2).toString()
                                family: root.display
                                size: 13
                                weight: 400
                                customColor: Colors.primary
                            }
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                CustomText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    content: row.modelData.title
                                    size: 11
                                    weight: 600
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.preview && !!row.modelData.link
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.open(row.modelData)
                        }
                    }
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6
            visible: root.items.length === 0

            MaterialIconSymbol {
                Layout.alignment: Qt.AlignHCenter
                content: ServiceNews.hasError ? "cloud_off" : "hourglass_empty"
                iconSize: 20
                customColor: Colors.outline
            }
            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: ServiceNews.hasError ? "Couldn't load feed" : "Loading headlines…"
                size: 12
                customColor: Colors.outline
            }
        }
    }
}
