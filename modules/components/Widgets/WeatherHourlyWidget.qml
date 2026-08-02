import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

// Today's temperature curve with rain chance underneath.
//
// ServiceWeather already fetches the hourly forecast and nothing displayed it —
// the other weather widgets all show a single moment. Temperatures arrive as
// strings with the degree sign attached, so they have to be stripped before
// anything can be plotted.
WidgetHost {
    id: root
    configKey: "weatherHourly"
    tile: WidgetSizes.wide
    defaultPos: Qt.point(420, 200)

    readonly property bool metric: SettingsConfig.weather.useMetric ?? true

    readonly property var hours: {
        const h = ServiceWeather.todayHourly ?? []
        var out = []
        for (var i = 0; i < h.length; i++) {
            const raw = root.metric ? h[i].tempC : h[i].tempF
            const t = parseInt(String(raw).replace("°", ""), 10)
            if (isNaN(t)) continue
            out.push({
                time: h[i].time,
                temp: t,
                rain: parseInt(h[i].chanceofrain ?? 0, 10) || 0
            })
        }
        return out
    }

    readonly property bool hasData: root.hours.length >= 2

    // Horizontal inset of the plot area, shared by the canvas and the hour
    // labels so a label sits under the point it names.
    readonly property int chartPadX: 7

    readonly property int minTemp: {
        if (!root.hasData) return 0
        var m = root.hours[0].temp
        for (var i = 1; i < root.hours.length; i++) m = Math.min(m, root.hours[i].temp)
        return m
    }
    readonly property int maxTemp: {
        if (!root.hasData) return 0
        var m = root.hours[0].temp
        for (var i = 1; i < root.hours.length; i++) m = Math.max(m, root.hours[i].temp)
        return m
    }

    Rectangle {
        anchors.fill: parent
        radius: WidgetSizes.radius
        color: Colors.surface

        // ── Header ────────────────────────────────────────────────────
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            y: 14
            spacing: 6

            CustomText { content: "Today"; size: 13; customColor: Colors.primary }

            Item { Layout.fillWidth: true }

            CustomText {
                content: root.hasData ? root.maxTemp + "° / " + root.minTemp + "°" : "—"
                size: 12
                customColor: Colors.outline
            }
        }

        // ── Curve ─────────────────────────────────────────────────────
        Canvas {
            id: chart
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            y: 42
            height: 108
            antialiasing: true

            property color lineColor: Colors.primary
            property color rainColor: Colors.tertiary
            property color dotColor:  Colors.surface
            property var   data:      root.hours
            property int   lo:        root.minTemp
            property int   hi:        root.maxTemp

            onLineColorChanged: requestPaint()
            onRainColorChanged: requestPaint()
            onDataChanged:      requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()

                const d = chart.data
                const n = d.length
                if (n < 2) return

                // Keep the curve off the edges: rain bars own the bottom strip
                const padTop = 18
                const rainBand = 26
                const usable = height - padTop - rainBand
                const span = Math.max(1, chart.hi - chart.lo)

                // Horizontal inset so the first and last markers aren't sliced
                // in half by the canvas edge — a point drawn at x=0 loses its
                // left side, and so does its label.
                const padX = root.chartPadX
                const plotW = width - padX * 2

                const xAt = i => padX + (plotW / (n - 1)) * i
                const yAt = t => padTop + usable - ((t - chart.lo) / span) * usable

                // Rain chance as columns along the bottom
                ctx.fillStyle = chart.rainColor
                ctx.globalAlpha = 0.28
                const bw = Math.max(4, width / n * 0.45)
                for (var i = 0; i < n; i++) {
                    const h = (d[i].rain / 100) * rainBand
                    if (h <= 0) continue
                    ctx.fillRect(xAt(i) - bw / 2, height - h, bw, h)
                }
                ctx.globalAlpha = 1

                // Area under the temperature curve
                ctx.beginPath()
                ctx.moveTo(xAt(0), yAt(d[0].temp))
                for (var j = 1; j < n; j++) ctx.lineTo(xAt(j), yAt(d[j].temp))
                ctx.lineTo(xAt(n - 1), padTop + usable)
                ctx.lineTo(xAt(0), padTop + usable)
                ctx.closePath()
                ctx.fillStyle = Qt.rgba(chart.lineColor.r, chart.lineColor.g, chart.lineColor.b, 0.14)
                ctx.fill()

                // Curve
                ctx.beginPath()
                ctx.moveTo(xAt(0), yAt(d[0].temp))
                for (var k = 1; k < n; k++) ctx.lineTo(xAt(k), yAt(d[k].temp))
                ctx.strokeStyle = chart.lineColor
                ctx.lineWidth = 2
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                ctx.stroke()

                // Point markers, punched out so the line reads through them
                for (var m = 0; m < n; m++) {
                    ctx.beginPath()
                    ctx.arc(xAt(m), yAt(d[m].temp), 3, 0, Math.PI * 2)
                    ctx.fillStyle = chart.dotColor
                    ctx.fill()
                    ctx.strokeStyle = chart.lineColor
                    ctx.lineWidth = 2
                    ctx.stroke()
                }

                // Value labels on the coldest and warmest points only —
                // labelling all eight turns the curve into a table.
                ctx.fillStyle = chart.lineColor
                ctx.font = "600 11px sans-serif"

                var didHi = false, didLo = false
                for (var p = 0; p < n; p++) {
                    const isHi = !didHi && d[p].temp === chart.hi
                    const isLo = !didLo && d[p].temp === chart.lo
                    // Several hours can share the min or max; label the first
                    // of each so the same number isn't printed twice.
                    if (!isHi && !isLo) continue
                    if (isHi) didHi = true
                    if (isLo) didLo = true

                    const lx = xAt(p)
                    // The end points sit on x=0 and x=width, where a centred
                    // label spills half outside the canvas and gets clipped.
                    ctx.textAlign = lx < 16 ? "left"
                                  : lx > width - 16 ? "right"
                                                    : "center"
                    // Keep the text off the top edge when the peak is at the
                    // very top of the plot area
                    ctx.fillText(d[p].temp + "°", lx, Math.max(11, yAt(d[p].temp) - 9))
                }
            }
        }

        // ── Hour labels ───────────────────────────────────────────────
        // Positioned per point rather than evenly distributed: a RowLayout
        // spreads eight labels across the full width, which does not match the
        // inset plot spacing, so labels drifted away from their data points.
        Item {
            id: hourLabels
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            y: 154
            height: 14
            visible: root.hasData

            readonly property real plotW: width - root.chartPadX * 2
            readonly property int steps: Math.max(1, root.hours.length - 1)

            Repeater {
                model: root.hours

                delegate: CustomText {
                    required property var modelData
                    required property int index

                    // Every other label — eight timestamps in 280px collide
                    content: index % 2 === 0 ? modelData.time.replace(" ", "") : ""
                    size: 10
                    customColor: Colors.outline

                    x: Math.max(0, Math.min(hourLabels.width - width,
                         root.chartPadX + hourLabels.plotW / hourLabels.steps * index - width / 2))
                }
            }
        }

        // ── Empty state ───────────────────────────────────────────────
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8
            visible: !root.hasData

            MaterialIconSymbol {
                Layout.alignment: Qt.AlignHCenter
                content: "cloud_off"
                iconSize: 26
                customColor: Colors.outline
            }
            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: "No hourly forecast"
                size: 12
                customColor: Colors.outline
            }
        }
    }
}
