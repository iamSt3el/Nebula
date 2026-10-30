import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes

WidgetHost {
    id: root
    configKey: "sysQuad"
    tile: Qt.size(WidgetSizes.span(4), WidgetSizes.span(1))
    turnable: true
    defaultPos: Qt.point(1245, 385)

    readonly property var si: root.preview ? PreviewData : ServiceSystemInfo
    Component.onCompleted: root.si.retain()
    Component.onDestruction: root.si.release()

    readonly property var meters: [
        { name: "CPU", icon: "developer_board", shape: "cookie9", value: root.si.cpuUsage },
        { name: "RAM", icon: "memory_alt", shape: "clover4", value: root.si.memUsage },
        { name: "GPU", icon: "stadia_controller", shape: "sunny", value: root.si.gpuUsage },
        { name: "DISK", icon: "hard_drive", shape: "cookie4", value: root.si.diskUsage }
    ]

    WidgetCard {
        id: card
        anchors.fill: parent

        GridLayout {
            anchors.fill: parent
            anchors.leftMargin: root.turned ? 0 : card.pad
            anchors.rightMargin: root.turned ? 0 : card.pad
            anchors.topMargin: root.turned ? card.pad : 0
            anchors.bottomMargin: root.turned ? card.pad : 0
            flow: root.turned ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: root.turned ? 4 : 1
            columns: root.turned ? 1 : 4
            rowSpacing: 0
            columnSpacing: 0

            Repeater {
                model: 4

                GridLayout {
                    id: cell
                    required property int index
                    readonly property var meter: root.meters[index]
                    readonly property bool hot: cell.meter.value > 0.9
                    property real shown: Math.max(0, Math.min(1, cell.meter.value))
                    Behavior on shown { SpatialAnim {} }

                    Layout.fillWidth: true
                    Layout.fillHeight: root.turned
                    Layout.alignment: Qt.AlignCenter
                    columns: root.turned ? 1 : 2
                    columnSpacing: 6
                    rowSpacing: 4

                    Item {
                        Layout.alignment: Qt.AlignCenter
                        implicitWidth: 50
                        implicitHeight: 50

                        MaterialShapes.ShapeCanvas {
                            anchors.fill: parent
                            roundedPolygon: cell.meter.shape
                            color: Colors.surfaceContainerHighest
                            sweepLevel: cell.shown
                            levelColor: cell.hot ? Colors.error : Colors.primary
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 28
                            height: 28
                            radius: 14
                            color: Colors.surfaceContainerLow
                        }
                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: cell.meter.icon
                            iconSize: 16
                            fill: 1
                            customColor: Colors.surfaceText
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: root.turned ? -1 : 40
                        Layout.alignment: root.turned ? Qt.AlignHCenter : Qt.AlignVCenter
                        spacing: 0
                        CustomText {
                            Layout.alignment: root.turned ? Qt.AlignHCenter : Qt.AlignLeft
                            content: cell.meter.name
                            size: 10
                            weight: 600
                            font.letterSpacing: 0.6
                            customColor: Colors.surfaceVariantText
                        }
                        CustomText {
                            Layout.alignment: root.turned ? Qt.AlignHCenter : Qt.AlignLeft
                            content: Math.round(cell.meter.value * 100) + "%"
                            size: 15
                            weight: 600
                            customColor: cell.hot ? Colors.error : Colors.surfaceText
                        }
                    }
                }
            }
        }
    }
}
