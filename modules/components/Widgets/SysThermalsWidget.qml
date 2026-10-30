import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "sysThermals"
    tile: WidgetSizes.small
    defaultPos: Qt.point(1685, 275)

    readonly property var si: root.preview ? PreviewData : ServiceSystemInfo
    Component.onCompleted: root.si.retain()
    Component.onDestruction: root.si.release()

    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"
    readonly property bool hot: root.si.cpuTemp >= 85
    readonly property bool hasGpu: root.si.gpuTemp > 0
    readonly property int rpm: (root.si.fanRpms ?? [])[0] ?? 0

    function frac(t) { return Math.max(0, Math.min(1, (t - 30) / 70)) }

    WidgetCard {
        id: card
        anchors.fill: parent

        Item {
            id: dial
            anchors.fill: parent
            readonly property real k: width / 200

            SysArc {
                anchors.fill: parent
                value: root.frac(root.si.cpuTemp)
                radius: 78 * dial.k
                from: Math.PI * 0.75
                span: Math.PI * 1.5
                gap: 0.14
                thickness: 6
                wave: root.hot ? 4.5 : 2.5
                waves: root.hot ? 30 : 20
                color: root.hot ? Colors.error : Colors.primary
            }

            SysArc {
                anchors.fill: parent
                visible: root.hasGpu
                value: root.frac(root.si.gpuTemp)
                radius: 62 * dial.k
                from: Math.PI * 0.75
                span: Math.PI * 1.5
                gap: 0.12
                thickness: 4
                color: Colors.tertiary
                trackColor: Colors.surfaceContainerHigh
            }

            ColumnLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(62 * dial.k)
                spacing: 4

                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: Math.round(root.si.cpuTemp) + "°"
                    size: 40
                    family: root.display
                    customColor: root.hot ? Colors.error : Colors.primary
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 0
                    CustomText {
                        content: "CPU"
                        size: 11
                        weight: 600
                        customColor: Colors.surfaceVariantText
                    }
                    CustomText {
                        visible: root.hasGpu
                        content: " · GPU " + Math.round(root.si.gpuTemp) + "°"
                        size: 11
                        weight: 600
                        customColor: Colors.tertiary
                    }
                }
            }

            Rectangle {
                visible: root.rpm > 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(160 * dial.k)
                implicitWidth: fanRow.implicitWidth + 20
                implicitHeight: 26
                radius: 13
                color: Colors.surfaceContainerHigh

                RowLayout {
                    id: fanRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialIconSymbol {
                        content: "mode_fan"
                        iconSize: 15
                        fill: 1
                        customColor: Colors.surfaceVariantText
                    }
                    CustomText {
                        content: root.rpm + " rpm"
                        size: 11
                        weight: 600
                        customColor: Colors.surfaceVariantText
                    }
                }
            }
        }
    }
}
