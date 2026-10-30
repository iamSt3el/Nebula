import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "sysNet"
    tile: Qt.size(WidgetSizes.span(3), WidgetSizes.span(1))
    resizable: true
    minSpan: Qt.size(3, 1)
    maxSpan: Qt.size(6, 1)
    turnable: true
    defaultPos: Qt.point(1245, 605)

    readonly property var si: root.preview ? PreviewData : ServiceSystemInfo
    Component.onCompleted: if (!root.preview) ServiceDashData.retainSystem()
    Component.onDestruction: if (!root.preview) ServiceDashData.releaseSystem()

    readonly property var downHist: root.preview
        ? [0.2, 0.35, 0.3, 0.55, 0.8, 0.95, 0.85, 1, 0.9, 0.7, 0.85, 0.95, 0.8, 0.88].map(v => v * 2e6)
        : ServiceDashData.netDownHist
    readonly property var upHist: root.preview
        ? [0.1, 0.2, 0.15, 0.3, 0.25, 0.4, 0.3, 0.35, 0.5, 0.3, 0.2, 0.35, 0.3, 0.25].map(v => v * 4e5)
        : ServiceDashData.netUpHist

    readonly property string iface: root.preview ? "wlan0" : root.si.netInterface ?? ""
    readonly property string kind: root.iface.startsWith("wl") ? "Wi-Fi"
        : root.iface.startsWith("en") || root.iface.startsWith("eth") ? "Ethernet"
        : root.iface === "" ? "Offline" : "Network"

    function speed(bps) {
        if (!root.turned) return root.si.formatNetSpeed(bps)
        if (bps >= 1024 * 1024) return (bps / (1024 * 1024)).toFixed(1) + "M/s"
        if (bps >= 1024) return Math.round(bps / 1024) + "K/s"
        return Math.round(bps) + "B/s"
    }

    function calm(vals) {
        const step = Math.max(1, Math.ceil(vals.length / 20))
        const out = []
        for (let i = 0; i < vals.length; i += step) {
            const chunk = vals.slice(i, i + step)
            out.push(chunk.reduce((a, b) => a + b, 0) / chunk.length)
        }
        return out.map((v, i) => 0.25 * (out[i - 1] ?? v) + 0.5 * v + 0.25 * (out[i + 1] ?? v))
    }

    function area(raw, w, base, h, dir) {
        const vals = root.calm(raw)
        const n = vals.length
        const floor = 1.5
        if (n < 2 || w <= 0)
            return "M0 " + base + " L0 " + (base + dir * floor) + " L" + w + " " + (base + dir * floor) + " L" + w + " " + base + " Z"
        const peak = Math.sqrt(Math.max(256 * 1024, ...vals))
        const pts = vals.map((v, i) => [i / (n - 1) * w,
                                        base + dir * Math.max(floor, Math.sqrt(v) / peak * h)])
        let d = "M0 " + base + " L0 " + pts[0][1].toFixed(1)
        for (let i = 1; i < n; i++) {
            const mx = ((pts[i - 1][0] + pts[i][0]) / 2).toFixed(1)
            d += " C" + mx + " " + pts[i - 1][1].toFixed(1) + " " + mx + " " + pts[i][1].toFixed(1)
               + " " + pts[i][0].toFixed(1) + " " + pts[i][1].toFixed(1)
        }
        return d + " L" + w + " " + base + " Z"
    }

    WidgetCard {
        id: card
        anchors.fill: parent

        GridLayout {
            anchors.fill: parent
            anchors.leftMargin: root.turned ? 12 : card.pad
            anchors.rightMargin: root.turned ? 12 : 14
            anchors.topMargin: root.turned ? 14 : 12
            anchors.bottomMargin: root.turned ? 12 : 12
            flow: root.turned ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: root.turned ? 2 : 1
            columns: root.turned ? 1 : 2
            rowSpacing: 10
            columnSpacing: 12

            ColumnLayout {
                Layout.preferredWidth: root.turned ? -1 : 104
                Layout.fillWidth: false
                Layout.fillHeight: false
                Layout.alignment: root.turned ? Qt.AlignHCenter : Qt.AlignVCenter
                spacing: root.turned ? 3 : 6

                RowLayout {
                    Layout.alignment: root.turned ? Qt.AlignHCenter : Qt.AlignLeft
                    spacing: 4
                    MaterialIconSymbol { content: "south"; iconSize: root.turned ? 15 : 17; customColor: Colors.primary }
                    CustomText {
                        content: root.speed(root.si.netDownloadBps)
                        size: root.turned ? 13 : 15
                        weight: 600
                        customColor: Colors.primary
                    }
                }
                RowLayout {
                    Layout.alignment: root.turned ? Qt.AlignHCenter : Qt.AlignLeft
                    spacing: 4
                    MaterialIconSymbol { content: "north"; iconSize: root.turned ? 14 : 15; customColor: Colors.tertiary }
                    CustomText {
                        content: root.speed(root.si.netUploadBps)
                        size: root.turned ? 12 : 13
                        weight: 600
                        customColor: Colors.tertiary
                    }
                }
                CustomText {
                    Layout.fillWidth: true
                    horizontalAlignment: root.turned ? Text.AlignHCenter : Text.AlignLeft
                    content: root.iface === "" || root.turned ? root.kind : root.kind + " · " + root.iface
                    size: 10
                    customColor: Colors.outline
                }
            }

            ClippingRectangle {
                id: tide
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: Colors.surfaceContainerHigh

                Item {
                    id: plot
                    anchors.centerIn: parent
                    width: root.turned ? tide.height : tide.width
                    height: root.turned ? tide.width : tide.height
                    rotation: root.turned ? 90 : 0
                    readonly property real base: Math.round(height * 0.6)

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: Colors.primary
                            PathSvg { path: root.area(root.downHist, plot.width, plot.base - 1, plot.base - 7, -1) }
                        }
                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: Qt.alpha(Colors.tertiary, 0.85)
                            PathSvg { path: root.area(root.upHist, plot.width, plot.base + 1, plot.height - plot.base - 7, 1) }
                        }
                    }
                }
            }
        }
    }
}
