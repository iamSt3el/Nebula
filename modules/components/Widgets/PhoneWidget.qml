import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "phone"
    tile: WidgetSizes.small
    defaultPos: Qt.point(365, 385)

    readonly property bool near: root.preview || ServicePhone.ready
    readonly property int battery: root.preview ? 64 : ServicePhone.battery
    readonly property bool paired: root.preview || ServicePhone.paired
    readonly property string name: root.preview ? "Phone" : (ServicePhone.name || "Phone")

    component PhoneButton: Rectangle {
        id: pb
        property string icon: ""
        property string tip: ""
        signal activated
        width: 36
        height: 36
        radius: 12
        color: pbArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
        opacity: root.near ? 1 : 0.45
        MaterialIconSymbol {
            anchors.centerIn: parent
            content: pb.icon
            iconSize: 18
            customColor: Colors.primary
        }
        MouseArea {
            id: pbArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.near && !root.preview
            cursorShape: Qt.PointingHandCursor
            onClicked: pb.activated()
        }
        CustomToolTip { content: pb.tip; visible: pbArea.containsMouse }
    }

    WidgetCard {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: parent.pad
            spacing: 6

            WidgetTitle {
                Layout.fillWidth: true
                icon: "smartphone"
                title: root.name
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Item {
                    id: ring
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height, 84)
                    height: width
                    visible: root.near && root.battery >= 0
                    readonly property real frac: Math.max(0, Math.min(1, root.battery / 100))

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: Colors.surfaceContainerHighest
                            strokeWidth: 8
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.width / 2 - 5; radiusY: ring.height / 2 - 5; startAngle: 0; sweepAngle: 360 }
                        }
                        ShapePath {
                            strokeColor: root.battery <= 15 ? Colors.error : Colors.tertiary
                            strokeWidth: 8
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.width / 2 - 5; radiusY: ring.height / 2 - 5; startAngle: -90; sweepAngle: 360 * ring.frac }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        CustomText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            content: root.battery + "%"
                            size: 16
                            weight: 600
                        }
                        MaterialIconSymbol {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: ServicePhone.charging && !root.preview
                            content: "bolt"
                            iconSize: 14
                            customColor: Colors.tertiary
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    visible: !ring.visible
                    spacing: 4
                    MaterialIconSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        content: root.paired ? "phonelink_off" : "phonelink_setup"
                        iconSize: 30
                        customColor: Colors.outline
                    }
                    CustomText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        content: !root.paired ? "Pair with KDE Connect" : root.near ? "Battery unknown" : "Not nearby"
                        size: 12
                        customColor: Colors.outline
                    }
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                PhoneButton { icon: "volume_up"; tip: "Ring phone"; onActivated: ServicePhone.ring() }
                PhoneButton { icon: "upload_file"; tip: "Send a file"; onActivated: GlobalStates.phoneOpen = true }
                PhoneButton { icon: "content_paste"; tip: "Send clipboard"; onActivated: ServicePhone.sendClipboard() }
            }

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                visible: root.near && (root.preview || ServicePhone.notifs > 0)
                content: (root.preview ? 3 : ServicePhone.notifs) + " notifications"
                size: 11
                customColor: Colors.outline
            }
        }
    }
}
