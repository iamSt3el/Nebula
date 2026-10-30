import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Widgets
import Quickshell.Services.UPower
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "sysBattery"
    tile: Qt.size(WidgetSizes.span(2), WidgetSizes.span(1))
    defaultPos: Qt.point(1575, 495)
    turnable: true
    backdropRadius: Math.min(root.width, root.height) / 2

    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"
    readonly property var dev: UPower.displayDevice
    readonly property bool present: root.preview || (root.dev?.isPresent ?? false)
    readonly property real level: root.preview ? 0.82 : (root.dev?.percentage ?? 0)
    readonly property bool charging: root.preview || ServiceUPower.isCharging
    readonly property bool full: !root.preview && root.dev?.state === UPowerDeviceState.FullyCharged
    readonly property bool low: !root.charging && root.level <= 0.2
    readonly property real health: root.preview ? 0.53 : ServiceUPower.health
    readonly property real secs: root.preview ? 4800
                               : (root.charging ? root.dev?.timeToFull : root.dev?.timeToEmpty) ?? 0

    function duration(s) {
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }

    readonly property string stateText: !root.present ? "No battery"
        : root.full ? "Fully charged"
        : root.charging ? "Charging"
        : root.low ? "Battery low" : "On battery"
    readonly property string timeText: !root.present || root.full || root.secs <= 0 ? ""
        : root.charging ? root.duration(root.secs) + " to full" : root.duration(root.secs) + " left"
    readonly property string icon: root.charging ? "bolt"
        : root.low ? "battery_alert" : ""

    property real shown: Math.max(0, Math.min(1, root.level))
    Behavior on shown { SpatialAnim {} }

    WidgetCard {
        anchors.fill: parent
        radius: Math.min(width, height) / 2

        GridLayout {
            anchors.fill: parent
            anchors.leftMargin: root.turned ? 10 : 17
            anchors.rightMargin: root.turned ? 10 : 14
            anchors.topMargin: root.turned ? 17 : 0
            anchors.bottomMargin: root.turned ? 18 : 0
            flow: root.turned ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: root.turned ? 2 : 1
            columns: root.turned ? 1 : 2
            rowSpacing: 10
            columnSpacing: 12

            ClippingRectangle {
                id: pill
                Layout.alignment: Qt.AlignCenter
                implicitWidth: root.turned ? 56 : 92
                implicitHeight: root.turned ? 104 : 56
                radius: 28
                color: Colors.surfaceContainerHighest

                readonly property color tone: root.low ? Colors.error : Colors.primary

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: pill.tone
                        PathPolyline {
                            path: {
                                const w = pill.width, h = pill.height
                                if (root.turned) {
                                    const y = h * (1 - root.shown)
                                    const pts = [Qt.point(-4, h + 4), Qt.point(-4, y)]
                                    for (let x = 0; x <= w; x += 2)
                                        pts.push(Qt.point(x, y + 3 * Math.sin(x / w * Math.PI * 3)))
                                    pts.push(Qt.point(w + 4, y), Qt.point(w + 4, h + 4))
                                    return pts
                                }
                                const x = w * root.shown
                                const pts = [Qt.point(-4, -4), Qt.point(x, -4)]
                                for (let y = 0; y <= h; y += 2)
                                    pts.push(Qt.point(x + 3 * Math.sin(y / h * Math.PI * 3), y))
                                pts.push(Qt.point(x, h + 4), Qt.point(-4, h + 4))
                                return pts
                            }
                        }
                    }
                }

                Repeater {
                    model: 2

                    Item {
                        id: layer
                        required property int index
                        readonly property color ink: index === 0 ? Colors.surfaceText
                                                   : root.low ? Colors.errorText : Colors.primaryText
                        readonly property real cut: index === 0 ? 1 : root.shown
                        x: 0
                        y: root.turned ? pill.height - height : 0
                        width: root.turned ? pill.width : Math.round(pill.width * layer.cut)
                        height: root.turned ? Math.round(pill.height * layer.cut) : pill.height
                        clip: index === 1

                        Item {
                            y: -layer.y
                            width: pill.width
                            height: pill.height

                            GridLayout {
                                anchors.centerIn: parent
                                columns: root.turned ? 1 : 2
                                rowSpacing: 0
                                columnSpacing: 1

                                MaterialIconSymbol {
                                    Layout.alignment: Qt.AlignCenter
                                    visible: root.icon !== ""
                                    content: root.icon
                                    iconSize: 17
                                    fill: 1
                                    customColor: layer.ink
                                }
                                CustomText {
                                    Layout.alignment: Qt.AlignCenter
                                    content: root.present ? Math.round(root.level * 100) : "—"
                                    size: 19
                                    family: root.display
                                    customColor: layer.ink
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignCenter
                spacing: 2
                CustomText {
                    Layout.fillWidth: true
                    horizontalAlignment: root.turned ? Text.AlignHCenter : Text.AlignLeft
                    wrapMode: root.turned ? Text.WordWrap : Text.NoWrap
                    maximumLineCount: 2
                    content: root.stateText
                    size: 13
                    weight: 600
                    customColor: root.low ? Colors.error : Colors.surfaceText
                }
                CustomText {
                    Layout.fillWidth: true
                    visible: root.timeText !== ""
                    horizontalAlignment: root.turned ? Text.AlignHCenter : Text.AlignLeft
                    content: root.timeText
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    lineHeight: 0.95
                    size: 11
                    customColor: Colors.surfaceVariantText
                }
                CustomText {
                    Layout.fillWidth: true
                    visible: root.health > 0 && !root.turned
                    horizontalAlignment: root.turned ? Text.AlignHCenter : Text.AlignLeft
                    content: "Health " + Math.round(root.health * 100) + "%"
                    size: 11
                    customColor: Colors.outline
                }
            }
        }
    }
}
