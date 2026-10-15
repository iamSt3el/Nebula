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

    readonly property Item authField: auth
    readonly property bool _animated: !root.preview
    readonly property real u: Math.min(root.width / 1920, root.height / 1080)
    readonly property string _family: SettingsConfig.general.defaultFont ?? "Rubik"
    readonly property bool _music: root.cfg.showMusic !== false && !root.greeter && ServiceMusic.activePlayer !== null

    LockStatusModel { id: status }

    MotionEnter {
        visible: root._music
        x: root.width - width - 72 * root.u
        y: 64 * root.u
        dy: -30 * root.u
        delay: 520
        animated: root._animated
        exiting: root.exiting

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

        MotionEnter {
            visible: root.cfg.showDate !== false
            delay: 260
            dy: 26 * root.u
            animated: root._animated
            exiting: root.exiting

            CustomText {
                content: (LockSession.weekday + ", " + LockSession.dayNum + " " + LockSession.month).toUpperCase()
                size: Math.round(30 * root.u)
                renderType: Text.QtRendering
                weight: 500
                font.letterSpacing: 4 * root.u
                customColor: Colors.surfaceVariantText
            }
        }

        MotionEnter {
            Layout.topMargin: 6 * root.u
            Layout.leftMargin: -10 * root.u
            delay: 120
            dy: 60 * root.u
            fromScale: 0.96
            animated: root._animated
            exiting: root.exiting

            Text {
                text: LockSession.hour + ":" + LockSession.minute
                color: Colors.surfaceText
                font.family: root._family
                font.pixelSize: Math.round(300 * root.u)
                font.weight: 600
                font.letterSpacing: -13 * root.u
                font.features: { "tnum": 1 }
                renderType: Text.QtRendering
                lineHeight: 0.86
            }
        }

        MotionEnter {
            visible: root.cfg.showStatus !== false && !root.greeter
            Layout.topMargin: 22 * root.u
            delay: 380
            dy: 26 * root.u
            animated: root._animated
            exiting: root.exiting

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

        MotionEnter {
            visible: root.cfg.showPower !== false
            Layout.alignment: Qt.AlignRight
            delay: 560
            dx: 30 * root.u
            dy: 0
            animated: root._animated
            exiting: root.exiting

            LockPowerActions {
                variant: "icons"
                box: 64 * root.u
                iconPx: Math.round(28 * root.u)
                spacing: 14 * root.u
                plate: Qt.alpha(Colors.surface, 0.5)
                plateHover: Qt.alpha(Colors.surfaceContainerHighest, 0.8)
            }
        }

        MotionEnter {
            Layout.alignment: Qt.AlignRight
            delay: 420
            dx: 40 * root.u
            dy: 0
            animated: root._animated
            exiting: root.exiting

            RowLayout {
                spacing: 18 * root.u

                ColumnLayout {
                    spacing: 0
                    CustomText {
                        Layout.alignment: Qt.AlignRight
                        content: LockSession.user
                        size: Math.round(32 * root.u)
                        renderType: Text.QtRendering
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

        MotionEnter {
            Layout.fillWidth: true
            delay: 480
            dx: 40 * root.u
            dy: 0
            animated: root._animated
            exiting: root.exiting

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
