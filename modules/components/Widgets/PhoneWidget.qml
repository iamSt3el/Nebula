import QtQuick
import QtQuick.Layouts
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
    readonly property bool charging: root.preview || ServicePhone.charging
    readonly property int notifs: root.preview ? 3 : ServicePhone.notifs
    readonly property string name: root.preview ? "POCO M3 Pro" : (ServicePhone.name || "Phone")
    readonly property bool known: root.near && root.battery >= 0
    readonly property bool low: root.known && root.battery <= 15
    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"

    component GroupButton: Rectangle {
        id: gb
        property string icon: ""
        property string tip: ""
        property real startR: 6
        property real endR: 6
        signal activated
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        topLeftRadius: gb.startR
        bottomLeftRadius: gb.startR
        topRightRadius: gb.endR
        bottomRightRadius: gb.endR
        color: gbArea.containsMouse && root.near ? Colors.surfaceContainerHighest : Colors.secondaryContainer
        opacity: root.near ? 1 : 0.45
        Behavior on color { EffectsColorAnim {} }
        MaterialIconSymbol {
            anchors.centerIn: parent
            content: gb.icon
            iconSize: 20
            customColor: Colors.secondaryContainerText
        }
        MouseArea {
            id: gbArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.near && !root.preview
            cursorShape: Qt.PointingHandCursor
            onClicked: gb.activated()
        }
        CustomToolTip { content: gb.tip; visible: gbArea.containsMouse }
    }

    WidgetCard {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: parent.pad
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                Rectangle {
                    id: body
                    Layout.preferredWidth: 58
                    Layout.preferredHeight: Math.min(100, parent.height)
                    Layout.alignment: Qt.AlignVCenter
                    radius: 18
                    color: Colors.surfaceContainerHighest

                    readonly property real inset: 4
                    readonly property real innerH: body.height - body.inset * 2
                    readonly property real level: root.known ? Math.max(0, Math.min(1, root.battery / 100)) : 0

                    Rectangle {
                        x: body.inset
                        width: body.width - body.inset * 2
                        height: body.innerH * body.level
                        y: body.height - body.inset - height
                        visible: height > 0.5
                        readonly property real r: body.radius - body.inset
                        bottomLeftRadius: r
                        bottomRightRadius: r
                        topLeftRadius: Math.max(0, Math.min(r, r - (body.innerH - height)))
                        topRightRadius: topLeftRadius
                        color: root.low ? Colors.error : Colors.primary
                        Behavior on height { SpatialAnim { speed: "slow" } }
                        Behavior on color { EffectsColorAnim {} }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 7
                        width: 16
                        height: 4
                        radius: 2
                        color: Colors.outlineVariant
                    }

                    MaterialIconSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        visible: !root.known || root.charging
                        content: !root.known ? (root.paired ? "phonelink_off" : "phonelink_setup") : "bolt"
                        iconSize: 18
                        customColor: !root.known ? Colors.outline : (root.low ? Colors.errorText : Colors.primaryText)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    CustomText {
                        Layout.fillWidth: true
                        content: root.known ? root.battery + "%" : "—"
                        family: root.display
                        size: 30
                        weight: 400
                        customColor: root.low ? Colors.error : Colors.surfaceText
                    }
                    CustomText {
                        Layout.fillWidth: true
                        content: root.name
                        size: 12
                        weight: 700
                    }
                    CustomText {
                        Layout.fillWidth: true
                        content: !root.paired ? "Pair with KDE Connect"
                               : !root.near ? "Not nearby"
                               : root.charging ? "Charging · nearby" : "Nearby"
                        size: 11
                        weight: 500
                        customColor: Colors.surfaceVariantText
                    }
                    Rectangle {
                        Layout.topMargin: 4
                        visible: root.near && root.notifs > 0
                        implicitWidth: notifRow.implicitWidth + 16
                        implicitHeight: 22
                        radius: 11
                        color: Colors.tertiaryContainer
                        Row {
                            id: notifRow
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialIconSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                content: "notifications"
                                iconSize: 14
                                customColor: Colors.tertiaryContainerText
                            }
                            CustomText {
                                anchors.verticalCenter: parent.verticalCenter
                                content: root.notifs.toString()
                                size: 11
                                weight: 700
                                customColor: Colors.tertiaryContainerText
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 2
                GroupButton { icon: "ring_volume"; tip: "Ring phone"; startR: 20; onActivated: ServicePhone.ring() }
                GroupButton { icon: "upload_file"; tip: "Send a file"; onActivated: GlobalStates.phoneOpen = true }
                GroupButton { icon: "content_paste_go"; tip: "Send clipboard"; endR: 20; onActivated: ServicePhone.sendClipboard() }
            }
        }
    }
}
