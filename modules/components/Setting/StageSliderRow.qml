import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

StageRow {
    id: row

    property real from: 0
    property real to: 1
    property real current: 0
    property real step: 0
    property var format: v => String(Math.round(v))
    property real peak: 0
    property bool showPeak: false
    signal moved(real value)
    signal committed(real value)

    property real shown: row.current
    onCurrentChanged: row.shown = row.current

    function snap(v) {
        const s = row.step > 0 ? Math.round((v - row.from) / row.step) * row.step + row.from : v
        return Math.max(row.from, Math.min(row.to, s))
    }

    value: row.format(row.shown)

    below: M3Slider {
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        from: row.from
        to: row.to
        showValueLabel: false
        peakLevel: row.peak
        showPeak: row.showPeak
        progress: (row.current - row.from) / Math.max(1e-6, row.to - row.from)
        onMoved: v => {
            row.shown = row.snap(v)
            row.moved(row.shown)
        }
        onCommitted: v => row.committed(row.snap(v))
    }
}
