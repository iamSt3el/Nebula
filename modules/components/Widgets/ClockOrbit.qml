pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "clock"
    tile: Qt.size(WidgetSizes.span(3), WidgetSizes.span(3))
    defaultPos: Qt.point(100, 100)
    backdrop: false
    outlined: false

    readonly property bool showSeconds: SettingsConfig.widgets.clockSeconds ?? true
    readonly property bool musicRim: SettingsConfig.widgets.clockMusicRim ?? true
    readonly property bool _music: root.musicRim && ServiceMusic.activePlayer !== null
    readonly property string _mono: "Fira Code"

    readonly property real cx: root.width / 2
    readonly property real cy: root.height / 2
    readonly property real rad: Math.min(root.width, root.height) / 2 - 27

    ClockParts { id: t }

    readonly property string dateLine: t.showDate ? (t.weekday + " · " + t.day + " " + t.month).toUpperCase() : ""
    readonly property string musicLine: {
        if (!root._music)
            return ""
        const s = ((ServiceMusic.activeTrack?.title ?? "") + " — " + (ServiceMusic.activeTrack?.artist ?? "")).toUpperCase()
        return "♪ " + (s.length > 24 ? s.slice(0, 23) + "…" : s)
    }

    optionsComponent: Component {
        ClockOptions {
            rows: [{ key: "clockSeconds", label: "Seconds ring", sub: "A ring that sweeps once a minute", def: true },
                   { key: "clockMusicRim", label: "Song on the rim", sub: "Shows what's playing along the lower edge", def: true }]
        }
    }

    property real sweep: root.preview ? 360 : 0
    NumberAnimation on sweep {
        running: !root.preview
        from: 0; to: 360
        duration: 1100
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
    }

    property real shownSec: 6 * (t.second + 1)
    Behavior on shownSec {
        enabled: t.second > 0
        NumberAnimation { duration: 900; easing.type: Easing.Linear }
    }

    component ArcText: Item {
        id: arc
        property string text: ""
        property real radius: 0
        property bool lower: false
        property color color: Colors.surfaceVariantText
        property real px: 11
        readonly property real step: arc.px * 0.6 + arc.px * 0.3

        anchors.fill: parent

        Repeater {
            model: arc.text.length

            delegate: Text {
                id: ch
                required property int index
                readonly property real d: (ch.index - (arc.text.length - 1) / 2) * arc.step
                readonly property real theta: arc.lower ? Math.PI / 2 - ch.d / arc.radius
                                                        : -Math.PI / 2 + ch.d / arc.radius
                text: arc.text.charAt(ch.index)
                color: arc.color
                font.family: root._mono
                font.pixelSize: arc.px
                font.weight: 600
                renderType: Text.QtRendering
                x: root.cx + arc.radius * Math.cos(ch.theta) - width / 2
                y: root.cy + arc.radius * Math.sin(ch.theta) - height / 2
                rotation: ch.theta * 180 / Math.PI + (arc.lower ? -90 : 90)
            }
        }
    }

    ClockLift {
        anchors.fill: parent

        MotionEnter {
            anchors.fill: parent
            dy: 0
            fromScale: 0.86
            animated: !root.preview

            Shape {
                anchors.fill: parent
                visible: root.showSeconds
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.alpha(Colors.surfaceText, 0.14)
                    strokeWidth: 5
                    PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: root.rad + 12; radiusY: root.rad + 12; startAngle: 0; sweepAngle: 360 }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colors.primary
                    strokeWidth: 5
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: root.cx; centerY: root.cy
                        radiusX: root.rad + 12; radiusY: root.rad + 12
                        startAngle: -90
                        sweepAngle: Math.min(root.sweep, root.shownSec)
                    }
                }
            }

            Repeater {
                model: 60

                delegate: Item {
                    id: tick
                    required property int index
                    readonly property bool hour: tick.index % 5 === 0
                    x: root.cx - width / 2
                    y: root.cy - root.rad
                    width: 4
                    height: root.rad * 2
                    rotation: tick.index * 6
                    opacity: root.sweep >= tick.index * 6 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 4
                        width: tick.hour ? 3.5 : 2
                        height: tick.hour ? 12 : 6
                        radius: width / 2
                        color: tick.hour ? Qt.alpha(Colors.surfaceText, 0.9) : Qt.alpha(Colors.surfaceText, 0.4)
                    }
                }
            }

            ArcText { text: root.dateLine; radius: root.rad - 30 }
            ArcText { text: root.musicLine; radius: root.rad - 24; lower: true; color: Colors.primary }

            Column {
                anchors.centerIn: parent
                spacing: 0

                RollText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: t.time
                    family: "Fira Sans Condensed"
                    pixelSize: 80
                    weight: 700
                    letterSpacing: -1
                    animated: !root.preview
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: t.ampm !== ""
                    text: t.ampm
                    color: Colors.surfaceVariantText
                    font.family: root._mono
                    font.pixelSize: 12
                    font.letterSpacing: 3.6
                    renderType: Text.QtRendering
                }
            }
        }
    }
}
