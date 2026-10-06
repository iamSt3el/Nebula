import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

CustomCard {
    id: row

    property string title: ""
    property string subtitle: ""
    property string path: ""
    property bool isNew: false
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    property real displayScale: 1
    property string unit: ""
    property string zeroLabel: ""

    readonly property real current: Number(ServiceHyprConfig.value(row.path, row.from))
    property real shown: row.current
    onCurrentChanged: {
        row.shown = row.current
        slider.progress = row._progressOf(row.current)
    }

    function _progressOf(v) {
        return Math.max(0, Math.min(1, (v - row.from) / Math.max(1e-6, row.to - row.from)))
    }

    function snap(v) {
        const s = Math.round(v / row.step) * row.step
        return Math.round(Math.max(row.from, Math.min(row.to, s)) * 1000) / 1000
    }

    function label(v) {
        if (row.zeroLabel !== "" && v === 0) return row.zeroLabel
        return (v * row.displayScale).toFixed(row.decimals) + row.unit
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                CustomText { content: row.title; size: 14 }
                HyprNewBadge { visible: row.isNew }
            }

            CustomText {
                visible: row.subtitle !== ""
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                content: row.subtitle
                size: 12
                customColor: Colors.outline
            }
        }

        Item { Layout.fillWidth: true }

        M3Slider {
            id: slider
            Layout.preferredWidth: 210
            Layout.preferredHeight: 30
            from: row.from
            to: row.to
            showValueLabel: false
            Component.onCompleted: progress = row._progressOf(row.current)
            onMoved: v => {
                row.shown = row.snap(v)
                ServiceHyprConfig.preview(row.path, row.shown)
            }
            onCommitted: v => ServiceHyprConfig.set(row.path, row.snap(v))
        }

        Rectangle {
            Layout.preferredWidth: 64
            Layout.preferredHeight: 34
            radius: 10
            color: Colors.surfaceContainerHighest

            CustomText {
                anchors.centerIn: parent
                content: row.label(row.shown)
                size: 13
                weight: 600
            }
        }
    }
}
