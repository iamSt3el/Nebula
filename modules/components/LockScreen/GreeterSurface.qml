import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.services

Item {
    id: root
    required property var context
    focus: true

    Keys.onPressed: event => {
        passInput.forceActiveFocus();
    }

    readonly property string _font: SettingsConfig.general.displayFont ?? "Titan One"

    readonly property int _h24: parseInt(ServiceClock.hour)
    readonly property int _h12: {
        let h = _h24 % 12;
        return h === 0 ? 12 : h;
    }
    readonly property string _period: _h24 < 12 ? "AM" : "PM"
    readonly property string h1: Math.floor(_h12 / 10).toString()
    readonly property string h2: (_h12 % 10).toString()
    readonly property string m1: ServiceClock.minute[0] ?? "0"
    readonly property string m2: ServiceClock.minute[1] ?? "0"

    // ── Background ────────────────────────────────────────────────────────────
    Image {
        anchors.fill: parent
        source: WallpaperTheme.wallpaper
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width, height)
        asynchronous: false
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.9
            blurMax: 48
            autoPaddingEnabled: false
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.22)
    }

    // ── Login panel ───────────────────────────────────────────────────────────
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: 500
        height: inner.implicitHeight + 56
        radius: 28
        color: Colors.surfaceContainer
        opacity: 0

        transform: Translate {
            id: entryTx
            y: 60
        }

        NumberAnimation on opacity {
            from: 0
            to: 1
            duration: 480
            easing.type: Easing.OutCubic
            running: true
        }
        NumberAnimation {
            target: entryTx
            property: "y"
            from: 60
            to: 0
            duration: 520
            easing.type: Easing.OutCubic
            running: true
        }

        ColumnLayout {
            id: inner
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 28
                leftMargin: 28
                rightMargin: 28
            }
            spacing: 0

            // ── Avatar ────────────────────────────────────────────────────────
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 80
                implicitHeight: 80

                ClippingWrapperRectangle {
                    anchors.fill: parent
                    radius: parent.height
                    color: Colors.primaryContainer
                    Image {
                        anchors.fill: parent
                        source: SettingsConfig.profileImage
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(width, height)
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: height
                    color: "transparent"
                    border.width: 2.5
                    border.color: Colors.primary
                }
            }

            Item {
                Layout.preferredHeight: 12
            }

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: root.context.currentUser
                size: 19
                weight: 700
            }

            Item {
                Layout.preferredHeight: 3
            }

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: "Hyprland"
                size: 12
                customColor: Colors.outline
            }

            Item {
                Layout.preferredHeight: 24
            }

            // ── AM/PM label ───────────────────────────────────────────────────
            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: root._period
                size: 11
                weight: 700
                customColor: Colors.outline
                font.letterSpacing: 3
            }

            Item {
                Layout.preferredHeight: 8
            }

            // ── Digit-block clock ─────────────────────────────────────────────
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                // Hours (surfaceContainerHighest)
                Row {
                    spacing: 4
                    Repeater {
                        model: [root.h1, root.h2]
                        delegate: Rectangle {
                            required property var modelData
                            width: 72
                            height: 88
                            radius: 16
                            color: Colors.surfaceContainerHighest
                            CustomText {
                                anchors.centerIn: parent
                                content: modelData
                                size: 56
                                weight: 700
                                font.family: root._font
                            }
                        }
                    }
                }

                // Colon dots
                Item {
                    width: 18
                    height: 88

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 26
                        width: 7
                        height: 7
                        radius: 4
                        color: Colors.primary
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: true
                            NumberAnimation {
                                to: 0.2
                                duration: 520
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: 1.0
                                duration: 520
                                easing.type: Easing.InOutSine
                            }
                        }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 55
                        width: 7
                        height: 7
                        radius: 4
                        color: Colors.primary
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: true
                            NumberAnimation {
                                to: 1.0
                                duration: 520
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: 0.2
                                duration: 520
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }

                // Minutes (primary)
                Row {
                    spacing: 4
                    Repeater {
                        model: [root.m1, root.m2]
                        delegate: Rectangle {
                            required property var modelData
                            width: 72
                            height: 88
                            radius: 16
                            color: Colors.primary
                            CustomText {
                                anchors.centerIn: parent
                                content: modelData
                                size: 56
                                weight: 700
                                font.family: root._font
                                customColor: Colors.primaryText
                            }
                        }
                    }
                }
            }

            Item {
                Layout.preferredHeight: 10
            }

            // Date
            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: ServiceClock.day + "  ·  " + ServiceClock.month + " " + ServiceClock.date + ", " + ServiceClock.year
                size: 13
                customColor: Colors.outline
            }

            Item {
                Layout.preferredHeight: 24
            }

            // ── Password input ────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 52
                radius: 16
                color: Colors.surfaceContainerHighest

                transform: Translate {
                    id: shakeTx
                    x: 0
                }
                SequentialAnimation {
                    running: root.context.showFailure
                    NumberAnimation {
                        target: shakeTx
                        property: "x"
                        to: -10
                        duration: 50
                    }
                    NumberAnimation {
                        target: shakeTx
                        property: "x"
                        to: 10
                        duration: 90
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        target: shakeTx
                        property: "x"
                        to: -8
                        duration: 90
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        target: shakeTx
                        property: "x"
                        to: 8
                        duration: 90
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        target: shakeTx
                        property: "x"
                        to: 0
                        duration: 50
                    }
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 14
                        rightMargin: 14
                    }
                    spacing: 10

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 10
                        color: root.context.showFailure ? Qt.alpha(Colors.error, 0.15) : root.context.unlockInProgress ? Qt.alpha(Colors.primary, 0.15) : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: 180
                            }
                        }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: root.context.unlockInProgress ? "lock_open" : "lock"
                            iconSize: 20
                            customColor: root.context.showFailure ? Colors.error : root.context.unlockInProgress ? Colors.primary : Colors.outline
                            Behavior on customColor {
                                ColorAnimation {
                                    duration: 180
                                }
                            }
                        }
                    }

                    CustomShapeInput {
                        id: passInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: root.context.showFailure ? "Wrong password — try again" : "Enter password"
                        placeholderColor: root.context.showFailure ? Colors.error : Colors.outline
                        enabled: !root.context.unlockInProgress

                        onTextChanged: root.context.currentText = text
                        onAccepted: root.context.tryUnlock()

                        Connections {
                            target: root.context
                            function onCurrentTextChanged() {
                                passInput.text = root.context.currentText;
                            }
                        }
                    }
                }
            }

            Item {
                Layout.preferredHeight: 16
            }

            // ── Power buttons ─────────────────────────────────────────────────
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                // Restart
                Item {
                    id: restartBtn
                    width: restartInner.implicitWidth + 28
                    height: 40
                    property bool hovered: false

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: restartBtn.hovered ? Qt.alpha(Colors.primary, 0.14) : Colors.surfaceContainerHighest
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        Row {
                            id: restartInner
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIconSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                content: "restart_alt"
                                iconSize: 18
                                customColor: restartBtn.hovered ? Colors.primary : Colors.outline
                                Behavior on customColor {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                            }
                            CustomText {
                                anchors.verticalCenter: parent.verticalCenter
                                content: "Restart"
                                size: 13
                                weight: 600
                                customColor: restartBtn.hovered ? Colors.primary : Colors.outline
                            }
                        }
                    }

                    CustomMouseArea {
                        anchors.fill: parent
                        radius: 12
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: restartBtn.hovered = true
                        onExited: restartBtn.hovered = false
                        onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                    }
                }

                // Shutdown
                Item {
                    id: shutdownBtn
                    width: shutdownInner.implicitWidth + 28
                    height: 40
                    property bool hovered: false

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: shutdownBtn.hovered ? Qt.alpha(Colors.error, 0.14) : Colors.surfaceContainerHighest
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        Row {
                            id: shutdownInner
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIconSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                content: "power_settings_new"
                                iconSize: 18
                                customColor: shutdownBtn.hovered ? Colors.error : Colors.outline
                                Behavior on customColor {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                            }
                            CustomText {
                                anchors.verticalCenter: parent.verticalCenter
                                content: "Shut Down"
                                size: 13
                                weight: 600
                                customColor: shutdownBtn.hovered ? Colors.error : Colors.outline
                            }
                        }
                    }

                    CustomMouseArea {
                        anchors.fill: parent
                        radius: 12
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: shutdownBtn.hovered = true
                        onExited: shutdownBtn.hovered = false
                        onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                    }
                }
            }

            Item {
                Layout.preferredHeight: 28
            }
        }
    }
}
