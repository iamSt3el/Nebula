pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property var context: null
    property bool preview: false
    property bool exiting: false
    property bool greeter: false
    property var cfg: LockSession.cfg

    readonly property Item authField: auth
    readonly property bool _animated: !root.preview
    readonly property real u: Math.min(root.width / 1920, root.height / 1080)
    readonly property string _mono: "Fira Code"
    readonly property bool _music: root.cfg.showMusic !== false && !root.greeter && ServiceMusic.activePlayer !== null

    readonly property real cx: root.width / 2
    readonly property real cy: 440 * root.u
    readonly property real rad: 330 * root.u
    readonly property real orbitR: root.rad + 118 * root.u

    readonly property string dateLine: root.cfg.showDate === false ? ""
        : (LockSession.weekday + " · " + LockSession.dayNum + " " + LockSession.month).toUpperCase()
    readonly property string musicLine: {
        if (!root._music)
            return ""
        const t = ((ServiceMusic.activeTrack?.title ?? "") + " — " + (ServiceMusic.activeTrack?.artist ?? "")).toUpperCase()
        return "♪ " + (t.length > 34 ? t.slice(0, 33) + "…" : t)
    }

    property real sweep: root._animated ? 0 : 360
    NumberAnimation on sweep {
        running: root._animated
        from: 0; to: 360
        duration: 1100
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
    }

    readonly property real secSweep: 6 * (parseInt(ServiceClock.seconds) + 1)

    LockStatusModel { id: status }

    component ArcText: Item {
        id: arc
        property string text: ""
        property real radius: 0
        property bool lower: false
        property color color: Colors.surfaceVariantText
        property real px: 22 * root.u
        readonly property real step: arc.px * 0.6 + arc.px * 0.32

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

    MotionEnter {
        anchors.fill: parent
        dy: 0
        fromScale: 0.88
        delay: 60
        animated: root._animated
        exiting: root.exiting

        Rectangle {
            x: root.cx - root.rad
            y: root.cy - root.rad
            width: root.rad * 2
            height: width
            radius: width / 2
            color: Qt.alpha(Colors.surface, 0.55)
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(Colors.surfaceText, 0.12)
                strokeWidth: 1.5 * root.u
                strokeStyle: ShapePath.DashLine
                dashPattern: [1.5, 7]
                PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: root.orbitR; radiusY: root.orbitR; startAngle: 0; sweepAngle: 360 }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(Colors.surfaceText, 0.08)
                strokeWidth: 10 * root.u
                PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: root.rad + 22 * root.u; radiusY: root.rad + 22 * root.u; startAngle: 0; sweepAngle: 360 }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.primary
                strokeWidth: 10 * root.u
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: root.cx; centerY: root.cy
                    radiusX: root.rad + 22 * root.u; radiusY: root.rad + 22 * root.u
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
                width: 6 * root.u
                height: root.rad * 2
                rotation: tick.index * 6
                opacity: root.sweep >= tick.index * 6 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 14 * root.u
                    width: (tick.hour ? 5 : 3) * root.u
                    height: (tick.hour ? 26 : 12) * root.u
                    radius: width / 2
                    color: tick.hour ? Qt.alpha(Colors.surfaceText, 0.75) : Qt.alpha(Colors.surfaceText, 0.28)
                }
            }
        }

        ArcText { text: root.dateLine; radius: root.rad - 72 * root.u }
        ArcText { text: root.musicLine; radius: root.rad - 62 * root.u; lower: true; color: Colors.primary }

        Column {
            x: root.cx - width / 2
            y: root.cy - 128 * root.u
            spacing: -6 * root.u

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: LockSession.hour + ":" + LockSession.minute
                color: Colors.surfaceText
                font.family: "Fira Sans Condensed"
                font.pixelSize: Math.round(196 * root.u)
                font.weight: 700
                font.letterSpacing: -4 * root.u
                renderType: Text.QtRendering
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: LockSession.ampm
                color: Colors.outline
                font.family: root._mono
                font.pixelSize: Math.round(24 * root.u)
                font.letterSpacing: 7 * root.u
                renderType: Text.QtRendering
            }
        }
    }

    property real shownSec: root.secSweep
    Behavior on shownSec {
        enabled: root.secSweep > 6
        NumberAnimation { duration: 900; easing.type: Easing.Linear }
    }

    Repeater {
        model: root.cfg.showStatus !== false && !root.greeter ? status.entries.slice(0, 4) : []

        delegate: MotionEnter {
            id: sat
            required property var modelData
            required property int index
            readonly property real angle: [300, 240, 60, 120][sat.index] * Math.PI / 180
            readonly property real drift: (1 - Math.min(1, sat.p)) * (sat.index < 2 ? -0.55 : 0.55)

            width: 108 * root.u
            height: width
            x: root.cx + root.orbitR * Math.sin(sat.angle + sat.drift) - width / 2
            y: root.cy - root.orbitR * Math.cos(sat.angle + sat.drift) - height / 2
            dy: 0
            fromScale: 0.4
            delay: 520 + sat.index * 90
            animated: root._animated
            exiting: root.exiting

            Rectangle {
                width: parent.width
                height: width
                radius: width / 2
                color: Colors.surfaceContainerHigh
                border.width: 2 * root.u
                border.color: Qt.alpha(Colors.primary, 0.35)

                Column {
                    anchors.centerIn: parent
                    spacing: 2 * root.u

                    MaterialIconSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        content: sat.modelData.icon
                        iconSize: Math.round(34 * root.u)
                        customColor: Colors.primary
                    }
                    CustomText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(implicitWidth, 90 * root.u)
                        horizontalAlignment: Text.AlignHCenter
                        content: sat.modelData.value
                        size: Math.round(19 * root.u)
                        weight: 600
                    }
                }
            }
        }
    }

    MotionEnter {
        x: 64 * root.u
        y: root.height - height - 76 * root.u
        delay: 700
        dx: -24 * root.u
        dy: 0
        animated: root._animated
        exiting: root.exiting

        Text {
            text: LockSession.user.toUpperCase() + "  ·  " + (root.greeter ? "SIGN IN" : "LOCKED")
            color: Colors.surfaceVariantText
            font.family: root._mono
            font.pixelSize: Math.round(22 * root.u)
            font.letterSpacing: 5 * root.u
            renderType: Text.QtRendering
        }
    }

    MotionEnter {
        x: root.cx - width / 2
        y: root.height - height - 62 * root.u
        delay: 620
        dy: 36 * root.u
        animated: root._animated
        exiting: root.exiting

        Rectangle {
            width: authRow.implicitWidth + 20 * root.u
            height: 84 * root.u
            radius: height / 2
            color: Qt.alpha(Colors.surfaceContainer, 0.85)

            RowLayout {
                id: authRow
                anchors.left: parent.left
                anchors.leftMargin: 10 * root.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14 * root.u

                LockShapeImage {
                    Layout.preferredWidth: 62 * root.u
                    Layout.preferredHeight: 62 * root.u
                    visible: LockSession.cfg.showAvatar !== false
                    source: SettingsConfig.general.profile ?? ""
                }

                LockAuthField {
                    id: auth
                    Layout.topMargin: 0
                    context: root.context
                    fieldWidth: 400 * root.u
                    fieldHeight: 64 * root.u
                    fieldColor: "transparent"
                    placeholder: "PASSWORD"
                    placeholderFamily: root._mono
                    placeholderSize: Math.round(22 * root.u)
                    showLockIcon: false
                    submitAlways: true
                    showFailureLine: false
                }
            }
        }
    }

    MotionEnter {
        visible: root.cfg.showPower !== false
        x: root.width - width - 64 * root.u
        y: root.height - height - 76 * root.u
        delay: 700
        dx: 24 * root.u
        dy: 0
        animated: root._animated
        exiting: root.exiting

        LockPowerActions {
            variant: "icons"
            box: 56 * root.u
            iconPx: Math.round(26 * root.u)
            spacing: 12 * root.u
            tone: Colors.surfaceVariantText
            plate: Qt.alpha(Colors.surfaceContainer, 0.85)
            plateHover: Colors.surfaceContainerHighest
        }
    }
}
