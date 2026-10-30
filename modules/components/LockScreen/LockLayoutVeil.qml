pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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
    property bool handoff: false
    property real handoffReveal: 1
    property bool handoffDate: false

    readonly property Item authField: auth
    readonly property var handoffTargets: ({
        restyle: true,
        ink: clockText,
        hours: clockText.hourItem,
        colon: clockText.colonItem,
        minutes: clockText.minuteItem,
        date: root.handoffDate && root.cfg.showDate !== false ? dateText : null
    })
    readonly property int _lead: root.handoff ? 580 : 0
    readonly property bool _animated: !root.preview
    readonly property real u: Math.min(root.width / 1920, root.height / 1080)
    readonly property string _family: SettingsConfig.general.defaultFont ?? "Rubik"
    readonly property bool _music: root.cfg.showMusic !== false && !root.greeter && ServiceMusic.activePlayer !== null

    LockStatusModel { id: status }

    LockTimeline {
        id: tl
        animated: root._animated
        exiting: root.exiting
    }

    component Line: Item {
        id: line
        default property alias content: lift.data
        property int at: 0
        property int dur: 600
        property int outDur: 300
        property bool still: false
        implicitWidth: lift.childrenRect.width
        implicitHeight: lift.childrenRect.height

        Item {
            id: win
            x: -line.height * 0.3
            width: line.width + line.height * 0.6
            height: line.height
            clip: !line.still && (tl.t < line.at + line.dur || tl.leaving)

            Item {
                id: lift
                x: -win.x
                width: line.width
                height: line.height
                y: line.still ? 0 : line.height * (1 - tl.span(line.at, line.dur, tl.standard, 0, line.outDur))
            }
        }
    }

    LockPart {
        line: tl
        visible: root._music
        x: root.width - width - 72 * root.u
        y: 64 * root.u
        dy: -16 * root.u
        at: 420 + root._lead
        dur: 440

        Rectangle {
            width: musicRow.implicitWidth + 40 * root.u
            height: 80 * root.u
            radius: height / 2
            color: Qt.alpha(Colors.surface, 0.55)

            RowLayout {
                id: musicRow
                anchors.left: parent.left
                anchors.leftMargin: 12 * root.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16 * root.u

                LockShapeImage {
                    Layout.preferredWidth: 56 * root.u
                    Layout.preferredHeight: 56 * root.u
                    source: ServiceMusic.activeTrack?.artUrl ?? ""
                    trackKey: (ServiceMusic.activeTrack?.title ?? "") + "|" + (ServiceMusic.activeTrack?.artist ?? "")
                    sourceSize: 512
                    shapeName: "cookie12"
                    fallbackIcon: "music_note"
                }

                ColumnLayout {
                    spacing: 0
                    CustomText {
                        Layout.maximumWidth: 320 * root.u
                        content: ServiceMusic.activeTrack?.title ?? ""
                        size: Math.round(22 * root.u)
                        weight: 600
                    }
                    CustomText {
                        Layout.maximumWidth: 320 * root.u
                        content: ServiceMusic.activeTrack?.artist ?? ""
                        size: Math.round(17 * root.u)
                        weight: 400
                        customColor: Colors.surfaceVariantText
                    }
                }

                M3IconButton {
                    implicitWidth: 44 * root.u
                    implicitHeight: 44 * root.u
                    icon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                    iconSize: Math.round(24 * root.u)
                    iconFill: 1
                    iconColor: Colors.primaryText
                    color: Colors.primary
                    onClicked: ServiceMusic.togglePlaying()
                }
            }
        }
    }

    ColumnLayout {
        x: 112 * root.u
        y: root.height - implicitHeight - 104 * root.u
        spacing: 0

        Line {
            visible: root.cfg.showDate !== false
            at: 100
            dur: 540
            outDur: 260
            still: root.handoff && root.handoffDate
            opacity: still ? root.handoffReveal : 1

            CustomText {
                id: dateText
                content: (LockSession.weekday + ", " + LockSession.dayNum + " " + LockSession.month).toUpperCase()
                size: Math.round(30 * root.u)
                renderType: root.preview ? Text.CurveRendering : Text.NativeRendering
                weight: 500
                font.letterSpacing: 4 * root.u
                customColor: Colors.surfaceVariantText
            }
        }

        Line {
            Layout.topMargin: 6 * root.u
            Layout.leftMargin: -10 * root.u
            at: 160
            dur: 660
            outDur: 340
            still: root.handoff
            opacity: still ? root.handoffReveal : 1

            LockTimeText {
                id: clockText
                color: Colors.surfaceText
                family: root._family
                pixelSize: Math.round(300 * root.u)
                weight: 600
                letterSpacing: -13 * root.u
                features: { "tnum": 1 }
                renderType: root.preview ? Text.CurveRendering : Text.NativeRendering
                lineHeight: 0.86
            }
        }

        LockPart {
            line: tl
            visible: root.cfg.showStatus !== false && !root.greeter
            Layout.topMargin: 22 * root.u
            at: 320 + root._lead
            dur: 480
            dy: 20 * root.u

            Row {
                spacing: 34 * root.u

                Repeater {
                    model: status.entries

                    delegate: Row {
                        required property var modelData
                        spacing: 10 * root.u

                        MaterialIconSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            content: parent.modelData.icon
                            iconSize: Math.round(28 * root.u)
                            fill: 1
                            customColor: Colors.primary
                        }
                        CustomText {
                            anchors.verticalCenter: parent.verticalCenter
                            content: parent.modelData.value
                            size: Math.round(24 * root.u)
                            weight: 500
                            customColor: Colors.surfaceVariantText
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        x: root.width - width - 112 * root.u
        y: root.height - implicitHeight - 104 * root.u
        width: 520 * root.u
        spacing: 22 * root.u

        LockPart {
            line: tl
            visible: root.cfg.showPower !== false
            Layout.alignment: Qt.AlignRight
            at: 440 + root._lead
            dur: 460
            dx: 40 * root.u

            LockPowerActions {
                variant: "icons"
                box: 64 * root.u
                iconPx: Math.round(28 * root.u)
                spacing: 14 * root.u
                plate: Qt.alpha(Colors.surface, 0.5)
                plateHover: Qt.alpha(Colors.surfaceContainerHighest, 0.8)
            }
        }

        LockPart {
            line: tl
            Layout.alignment: Qt.AlignRight
            at: 320 + root._lead
            dur: 460
            dx: 48 * root.u

            RowLayout {
                spacing: 18 * root.u

                ColumnLayout {
                    spacing: 0
                    CustomText {
                        Layout.alignment: Qt.AlignRight
                        content: LockSession.user
                        size: Math.round(32 * root.u)
                        renderType: root.preview ? Text.CurveRendering : Text.NativeRendering
                        weight: 600
                    }
                    CustomText {
                        Layout.alignment: Qt.AlignRight
                        content: root.greeter ? "Sign in to continue" : LockSession.greeting
                        size: Math.round(19 * root.u)
                        weight: 400
                        customColor: Colors.surfaceVariantText
                    }
                }

                LockShapeImage {
                    Layout.preferredWidth: 80 * root.u
                    Layout.preferredHeight: 80 * root.u
                    visible: LockSession.cfg.showAvatar !== false
                    source: SettingsConfig.general.profile ?? ""
                    shapeName: "circle"

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4 * root.u
                        radius: width / 2
                        color: "transparent"
                        border.width: 3 * root.u
                        border.color: (root.context?.showFailure ?? false) ? Colors.error : Colors.primary
                        Behavior on border.color { EffectsColorAnim {} }
                    }
                }
            }
        }

        LockPart {
            line: tl
            Layout.fillWidth: true
            at: 400 + root._lead
            dur: 460
            dx: 48 * root.u

            LockAuthField {
                id: auth
                width: 520 * root.u
                context: root.context
                fieldWidth: 520 * root.u
                fieldHeight: 76 * root.u
                fieldColor: Qt.alpha(Colors.surfaceText, 0.12)
                idleBorder: Qt.alpha(Colors.surfaceText, 0.2)
                placeholder: "Password"
                placeholderColor: Qt.alpha(Colors.surfaceText, 0.6)
                placeholderSize: Math.round(24 * root.u)
                showLockIcon: false
                submitAlways: true
            }
        }
    }
}
