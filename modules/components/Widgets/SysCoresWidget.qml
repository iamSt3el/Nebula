import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes

WidgetHost {
    id: root
    configKey: "sysCores"
    tile: WidgetSizes.small
    resizable: true
    minSpan: Qt.size(2, 2)
    maxSpan: Qt.size(3, 3)
    defaultPos: Qt.point(1685, 55)

    readonly property var si: root.preview ? PreviewData : ServiceSystemInfo
    Component.onCompleted: root.si.retain()
    Component.onDestruction: root.si.release()

    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"
    readonly property var cores: root.si.cpuCores ?? []
    readonly property bool busy: root.si.cpuUsage > 0.85
    readonly property bool hot: root.si.cpuTemp >= 85

    WidgetCard {
        id: card
        anchors.fill: parent

        RowLayout {
            id: head
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: card.pad
            anchors.rightMargin: card.pad - 2
            anchors.topMargin: 14
            spacing: 6

            CustomText {
                Layout.alignment: Qt.AlignBaseline
                content: "CPU"
                size: 12
                weight: 600
                customColor: Colors.surfaceVariantText
            }
            CustomText {
                Layout.alignment: Qt.AlignBaseline
                content: Math.round(root.si.cpuUsage * 100) + "%"
                size: 20
                family: root.display
                customColor: root.busy ? Colors.error : Colors.primary
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                visible: root.si.cpuTemp > 0
                implicitWidth: tempRow.implicitWidth + 12
                implicitHeight: 22
                radius: 11
                color: root.hot ? Colors.errorContainer : Colors.surfaceContainerHighest

                RowLayout {
                    id: tempRow
                    anchors.centerIn: parent
                    spacing: 2
                    MaterialIconSymbol {
                        content: "thermostat"
                        iconSize: 14
                        fill: 1
                        customColor: root.hot ? Colors.errorContainerText : Colors.surfaceVariantText
                    }
                    CustomText {
                        content: Math.round(root.si.cpuTemp) + "°"
                        size: 11
                        weight: 600
                        customColor: root.hot ? Colors.errorContainerText : Colors.surfaceVariantText
                    }
                }
            }
        }

        Item {
            id: garden
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: head.bottom
            anchors.bottom: parent.bottom
            anchors.margins: card.pad - 2
            anchors.topMargin: 10

            readonly property int n: Math.max(1, root.cores.length)
            readonly property int cols: Math.ceil(Math.sqrt(n * width / Math.max(1, height)))
            readonly property int rows: Math.ceil(n / cols)
            readonly property real gap: 6
            readonly property real cell: Math.floor(Math.min((width - (cols - 1) * gap) / cols,
                                                             (height - (rows - 1) * gap) / rows))

            Grid {
                anchors.centerIn: parent
                columns: garden.cols
                spacing: garden.gap

                Repeater {
                    model: root.cores.length

                    MaterialShapes.ShapeCanvas {
                        required property int index
                        readonly property real load: root.cores[index] ?? 0
                        property real shown: load
                        Behavior on shown { SpatialAnim {} }

                        width: garden.cell
                        height: garden.cell
                        roundedPolygon: "cookie4"
                        color: Colors.surfaceContainerHighest
                        fillLevel: Math.max(0, Math.min(1, shown))
                        levelColor: load > 0.85 ? Colors.error : Colors.primary
                    }
                }
            }
        }
    }
}
