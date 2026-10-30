pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Widgets

Item {
    id: root

    property var context: null
    property bool preview: false
    property bool exiting: false
    property bool greeter: false
    property var cfg: LockSession.cfg
    property var sources: ({})
    property url desk: ""

    readonly property Item authField: auth
    readonly property bool _animated: !root.preview
    readonly property real u: Math.min(root.width / 1920, root.height / 1080)
    readonly property string _family: SettingsConfig.general.defaultFont ?? "Rubik"
    readonly property bool _busy: root.context?.unlockInProgress ?? false
    readonly property bool _failed: root.context?.showFailure ?? false
    readonly property url _shot: String(root.desk) !== "" ? root.desk
        : (WallpaperTheme.wallpaperScreen !== "" ? "file://" + WallpaperTheme.wallpaperScreen : "")
    readonly property int _windows: root.sources?.windows ?? 0
    property string lockedAt: ""

    readonly property real cardW: 720 * root.u
    readonly property real cardH: root.cardW * root.height / Math.max(1, root.width)
    readonly property real cardX: root.width - root.cardW - 128 * root.u
    readonly property real cardY: (root.height - root.cardH) / 2 - 36 * root.u
    readonly property real s: tl.span(60, 820, tl.standard, 120, 640, tl.inOut)
    readonly property real k: 1 + (root.cardW / Math.max(1, root.width) - 1) * root.s

    ClockParts { id: clock }
    LockStatusModel { id: status }

    LockTimeline {
        id: tl
        animated: root._animated
        exiting: root.exiting
    }

    Component.onCompleted: root.lockedAt = clock.time + (clock.ampm !== "" ? " " + clock.ampm : "")

    readonly property real _thumb: Math.max(0, Math.min(1, (root.s - 0.08) / 0.3))
    readonly property real _cardK: root.k * root.width / Math.max(1, root.cardW)

    Image {
        width: root.width
        height: root.height
        visible: root._thumb < 1
        opacity: 1 - Math.max(0, (root._thumb - 0.6) / 0.4)
        source: root._shot
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
        smooth: true
        transform: [
            Scale { xScale: root.k; yScale: root.k },
            Translate { x: root.cardX * root.s; y: root.cardY * root.s }
        ]
    }

    ClippingRectangle {
        width: root.cardW
        height: root.cardH
        visible: root._thumb > 0
        opacity: root._thumb
        color: "transparent"
        radius: 36 * root.u
        transform: [
            Scale { xScale: root._cardK; yScale: root._cardK },
            Translate { x: root.cardX * root.s; y: root.cardY * root.s }
        ]

        Image {
            anchors.fill: parent
            source: root._shot
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
            smooth: true
            mipmap: true
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: 36 * root.u
            border.width: 2 * root.u
            border.color: Qt.alpha(Colors.outlineVariant, 0.8)
        }
    }

    LockPart {
        line: tl
        x: root.cardX + 8 * root.u
        y: root.cardY + root.cardH + 28 * root.u
        at: 620
        dur: 460
        dy: 18 * root.u

        Column {
            spacing: 4 * root.u

            CustomText {
                content: "Where you left off"
                size: Math.round(26 * root.u)
                weight: 600
                renderType: root.preview ? Text.CurveRendering : Text.NativeRendering
            }
            CustomText {
                content: (root._windows === 1 ? "1 window" : root._windows > 1 ? root._windows + " windows" : "Your desktop")
                    + (root.lockedAt !== "" ? " · locked at " + root.lockedAt : "")
                size: Math.round(20 * root.u)
                weight: 400
                customColor: Colors.surfaceVariantText
            }
        }
    }

    LockPart {
        line: tl
        visible: root.cfg.showStatus !== false && !root.greeter
        x: 128 * root.u
        y: 72 * root.u
        at: 560
        dur: 440
        dy: -16 * root.u

        Row {
            spacing: 30 * root.u

            Repeater {
                model: status.entries

                delegate: Row {
                    required property var modelData
                    spacing: 10 * root.u

                    MaterialIconSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        content: parent.modelData.icon
                        iconSize: Math.round(26 * root.u)
                        fill: 1
                        customColor: Colors.primary
                    }
                    CustomText {
                        anchors.verticalCenter: parent.verticalCenter
                        content: parent.modelData.value
                        size: Math.round(22 * root.u)
                        weight: 500
                        customColor: Colors.surfaceVariantText
                    }
                }
            }
        }
    }

    LockPart {
        line: tl
        visible: root.cfg.showPower !== false
        x: root.width - width - 128 * root.u
        y: 64 * root.u
        at: 600
        dur: 440
        dy: -16 * root.u

        LockPowerActions {
            variant: "icons"
            box: 64 * root.u
            iconPx: Math.round(26 * root.u)
            spacing: 10 * root.u
            plate: Qt.alpha(Colors.surfaceContainerHigh, 0.8)
            plateHover: Colors.surfaceContainerHighest
        }
    }

    ColumnLayout {
        x: 128 * root.u
        y: root.cardY + (root.cardH - implicitHeight) / 2 + 24 * root.u
        spacing: 0

        LockPart {
            line: tl
            visible: root.cfg.showDate !== false
            at: 480
            dur: 520
            dx: -40 * root.u

            CustomText {
                content: (clock.weekday + ", " + clock.day + " " + clock.month).toUpperCase()
                size: Math.round(26 * root.u)
                renderType: root.preview ? Text.CurveRendering : Text.NativeRendering
                weight: 600
                font.letterSpacing: 4 * root.u
                customColor: Colors.surfaceVariantText
            }
        }

        LockPart {
            line: tl
            Layout.topMargin: 2 * root.u
            Layout.leftMargin: -8 * root.u
            at: 520
            dur: 560
            dx: -48 * root.u

            LockTimeText {
                color: Colors.surfaceText
                family: root._family
                pixelSize: Math.round(250 * root.u)
                weight: 600
                letterSpacing: -10 * root.u
                features: { "tnum": 1 }
                renderType: root.preview ? Text.CurveRendering : Text.NativeRendering
                lineHeight: 0.86
            }
        }

        LockPart {
            line: tl
            Layout.topMargin: 36 * root.u
            at: 600
            dur: 520
            dx: -48 * root.u

            LockAuthField {
                id: auth
                context: root.context
                variant: "filled"
                fieldWidth: 600 * root.u
                fieldHeight: 80 * root.u
                fieldRadius: 40 * root.u
                fieldColor: Qt.alpha(Colors.surfaceContainerHigh, 0.9)
                placeholder: root.greeter ? "Sign in as " + LockSession.user : "Password for " + LockSession.user
                placeholderColor: Colors.surfaceVariantText
                placeholderSize: Math.round(23 * root.u)
                submitAlways: true
            }
        }
    }
}
