pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

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
    readonly property var digitShapes: ["cookie12", "clover4", "sunny", "flower", "cookie4",
                                        "softBurst", "cookie6", "cookie7", "clover8", "cookie9"]
    readonly property var chipShapes: ["cookie9", "clover4", "sunny", "flower"]
    readonly property string digits: LockSession.hourPad + LockSession.minute

    LockStatusModel { id: status }

    component Digit: MotionEnter {
        id: dg
        required property int index
        readonly property string value: root.digits.charAt(dg.index)
        width: 268 * root.u
        height: 268 * root.u
        dy: 0
        fromScale: 0.3
        fromRotation: -40
        delay: 90 + dg.index * 90
        animated: root._animated
        exiting: root.exiting

        MaterialShapes.ShapeCanvas {
            id: face
            anchors.fill: parent
            roundedPolygon: ShapeLibrary.get(root.digitShapes[parseInt(dg.value) || 0])
            color: dg.index < 2 ? Colors.primary : Colors.primaryContainer

            RotationAnimation on rotation {
                running: root._animated && !root.exiting
                from: dg.index % 2 === 0 ? 0 : 360
                to: dg.index % 2 === 0 ? 360 : 0
                duration: 90000 + dg.index * 7000
                loops: Animation.Infinite
            }
        }

        Text {
            anchors.centerIn: parent
            text: dg.value
            color: dg.index < 2 ? Colors.primaryText : Colors.primaryContainerText
            font.family: root._family
            font.pixelSize: Math.round(176 * root.u)
            font.weight: 700
            renderType: Text.QtRendering
        }
    }

    MotionEnter {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 64 * root.u
        delay: 40
        dy: -24 * root.u
        animated: root._animated
        exiting: root.exiting

        CustomText {
            content: root.greeter ? "Sign in, " + LockSession.user : LockSession.greeting + ", " + LockSession.user
            size: Math.round(30 * root.u)
            renderType: Text.QtRendering
            weight: 500
            customColor: Colors.surfaceVariantText
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 190 * root.u
        spacing: 22 * root.u

        Digit { index: 0 }
        Digit { index: 1 }

        MotionEnter {
            anchors.verticalCenter: parent.verticalCenter
            delay: 260
            dy: 0
            fromScale: 0
            animated: root._animated
            exiting: root.exiting

            Column {
                spacing: 36 * root.u
                leftPadding: 6 * root.u
                rightPadding: 6 * root.u
                Repeater {
                    model: 2
                    Rectangle {
                        width: 30 * root.u
                        height: width
                        radius: width / 2
                        color: Colors.surfaceText
                        opacity: 0.9
                    }
                }
            }
        }

        Digit { index: 2 }
        Digit { index: 3 }
    }

    MotionEnter {
        visible: root.cfg.showDate !== false
        anchors.horizontalCenter: parent.horizontalCenter
        y: 500 * root.u
        delay: 480
        animated: root._animated
        exiting: root.exiting

        CustomText {
            content: LockSession.weekday + ", " + LockSession.month + " " + LockSession.dayNum
            size: Math.round(40 * root.u)
            renderType: Text.QtRendering
            weight: 600
        }
    }

    Row {
        visible: root.cfg.showStatus !== false && !root.greeter
        anchors.horizontalCenter: parent.horizontalCenter
        y: 588 * root.u
        spacing: 40 * root.u

        Repeater {
            model: status.entries

            delegate: MotionEnter {
                id: chip
                required property var modelData
                required property int index
                dy: 0
                fromScale: 0.2
                delay: 560 + chip.index * 70
                animated: root._animated
                exiting: root.exiting

                Column {
                    spacing: 12 * root.u

                    MaterialShapes.ShapeCanvas {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 92 * root.u
                        height: width
                        roundedPolygon: ShapeLibrary.get(root.chipShapes[chip.index % root.chipShapes.length])
                        color: Colors.secondaryContainer

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: chip.modelData.icon
                            iconSize: Math.round(40 * root.u)
                            customColor: Colors.secondaryContainerText
                        }
                    }

                    CustomText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        content: chip.modelData.value
                        size: Math.round(20 * root.u)
                        weight: 500
                        customColor: Colors.surfaceVariantText
                    }
                }
            }
        }
    }

    MotionEnter {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - height - 92 * root.u
        delay: 640
        dy: 40 * root.u
        animated: root._animated
        exiting: root.exiting

        RowLayout {
            spacing: 18 * root.u

            LockShapeImage {
                Layout.preferredWidth: 92 * root.u
                Layout.preferredHeight: 92 * root.u
                Layout.alignment: Qt.AlignTop
                visible: LockSession.cfg.showAvatar !== false
                source: SettingsConfig.general.profile ?? ""
                shapeName: (root.context?.unlockInProgress ?? false) ? "softBurst"
                         : (root.context?.showFailure ?? false) ? "clover4" : "cookie9"
            }

            LockAuthField {
                id: auth
                context: root.context
                fieldWidth: 460 * root.u
                fieldHeight: 80 * root.u
                fieldColor: Colors.surfaceContainerHigh
                submitRadius: 18 * root.u
                placeholder: "Password"
                placeholderSize: Math.round(24 * root.u)
                showLockIcon: false
                submitAlways: true
            }
        }
    }

    MotionEnter {
        visible: root._music
        x: 72 * root.u
        y: root.height - height - 100 * root.u
        delay: 720
        dx: -30 * root.u
        dy: 0
        animated: root._animated
        exiting: root.exiting

        Rectangle {
            width: musicRow.implicitWidth + 34 * root.u
            height: 84 * root.u
            radius: 26 * root.u
            color: Colors.surfaceContainer

            RowLayout {
                id: musicRow
                anchors.left: parent.left
                anchors.leftMargin: 12 * root.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16 * root.u

                LockShapeImage {
                    Layout.preferredWidth: 60 * root.u
                    Layout.preferredHeight: 60 * root.u
                    source: ServiceMusic.activeTrack?.artUrl ?? ""
                    trackKey: (ServiceMusic.activeTrack?.title ?? "") + "|" + (ServiceMusic.activeTrack?.artist ?? "")
                    sourceSize: 512
                    shapeName: "cookie12"
                    fallbackIcon: "music_note"
                }

                ColumnLayout {
                    spacing: 0
                    CustomText {
                        Layout.maximumWidth: 300 * root.u
                        content: ServiceMusic.activeTrack?.title ?? ""
                        size: Math.round(21 * root.u)
                        weight: 600
                    }
                    CustomText {
                        Layout.maximumWidth: 300 * root.u
                        content: ServiceMusic.activeTrack?.artist ?? ""
                        size: Math.round(17 * root.u)
                        weight: 400
                        customColor: Colors.surfaceVariantText
                    }
                }

                M3IconButton {
                    implicitWidth: 48 * root.u
                    implicitHeight: 48 * root.u
                    icon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                    iconSize: Math.round(24 * root.u)
                    onClicked: ServiceMusic.togglePlaying()
                }
            }
        }
    }

    MotionEnter {
        visible: root.cfg.showPower !== false
        x: root.width - width - 72 * root.u
        y: root.height - height - 104 * root.u
        delay: 720
        dx: 30 * root.u
        dy: 0
        animated: root._animated
        exiting: root.exiting

        LockPowerActions {
            variant: "icons"
            box: 64 * root.u
            iconPx: Math.round(28 * root.u)
            spacing: 14 * root.u
            tone: Colors.surfaceVariantText
            plate: Colors.surfaceContainerHigh
            plateHover: Colors.surfaceContainerHighest
        }
    }
}
