pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.services

Item {
    id: root
    required property LockContext context
    focus: true

    Keys.onPressed: event => { passInput.forceActiveFocus() }

    // ── Clock digit helpers (NewClock style) ──────────────────────────────────
    readonly property string _font:  SettingsConfig.general.displayFont ?? "Titan One"
    readonly property real   _sz:    160
    readonly property real   _fX:    26    // overlap offset (scaled from NewClock 40/250 * 160)

    readonly property string h1: {
        let h = parseInt(ServiceClock.hour)
        if (h > 12) h -= 12; if (h === 0) h = 12
        return Math.floor(h / 10).toString()
    }
    readonly property string h2: {
        let h = parseInt(ServiceClock.hour)
        if (h > 12) h -= 12; if (h === 0) h = 12
        return (h % 10).toString()
    }
    readonly property string m1: ServiceClock.minute[0] ?? "0"
    readonly property string m2: ServiceClock.minute[1] ?? "0"

    // ── Blurred wallpaper ─────────────────────────────────────────────────────
    Image {
        anchors.fill: parent
        source: WallpaperTheme.wallpaper
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width, height)
        asynchronous: false
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true; blur: 0.8; blurMax: 40; autoPaddingEnabled: false
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.32)
    }

    // ── Clock (centered in upper area) ────────────────────────────────────────
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.1
        spacing: 0

        // HH:MM with overlapping digit masking — exact NewClock technique
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: -20

            // H1 (surfaceText, masked by H2)
            Item {
                width: _th1.width; height: _th1.height
                CustomText {
                    id: _th1; content: root.h1; size: root._sz; weight: 600
                    font.family: root._font; color: Colors.surfaceText
                    style: Text.Raised; styleColor: Colors.outline
                    layer.enabled: true; visible: false
                }
                Item {
                    id: _mh1; width: parent.width; height: parent.height
                    layer.enabled: true; visible: false
                    CustomText {
                        content: root.h2; size: root._sz; weight: 600
                        font.family: root._font; color: "white"
                        x: _th1.width - root._fX
                    }
                }
                MultiEffect {
                    source: _th1; anchors.fill: _th1
                    maskEnabled: true; maskSource: _mh1
                    maskInverted: true; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0
                }
            }

            // H2 (primary)
            CustomText {
                content: root.h2; size: root._sz; weight: 600
                font.family: root._font; color: Colors.primary
                style: Text.Raised; styleColor: Colors.outline
            }

            // Colon
            CustomText {
                Layout.leftMargin: 20; Layout.rightMargin: 20
                content: ":"; size: root._sz; weight: 600; bottomPadding: 18
                font.family: root._font; color: Colors.primary
                style: Text.Raised; styleColor: Colors.outline
            }

            // M1 (surfaceText, masked by M2)
            Item {
                width: _tm1.width; height: _tm1.height
                CustomText {
                    id: _tm1; content: root.m1; size: root._sz; weight: 600
                    font.family: root._font; color: Colors.surfaceText
                    style: Text.Raised; styleColor: Colors.outline
                    layer.enabled: true; visible: false
                }
                Item {
                    id: _mm1; width: parent.width; height: parent.height
                    layer.enabled: true; visible: false
                    CustomText {
                        content: root.m2; size: root._sz; weight: 600
                        font.family: root._font; color: "white"
                        x: _tm1.width - root._fX
                    }
                }
                MultiEffect {
                    source: _tm1; anchors.fill: _tm1
                    maskEnabled: true; maskSource: _mm1
                    maskInverted: true; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0
                }
            }

            // M2 (primary)
            CustomText {
                content: root.m2; size: root._sz; weight: 600
                font.family: root._font; color: Colors.primary
                style: Text.Raised; styleColor: Colors.outline
            }
        }

        // Day name — two-color split (same as NewClock)
        RowLayout {
            Layout.alignment: Qt.AlignHCenter; spacing: 0
            CustomText {
                content: ServiceClock.day.slice(0, -3); size: 56; weight: 600
                font.family: root._font; color: Colors.surfaceText
                style: Text.Raised; styleColor: Colors.outline
            }
            CustomText {
                content: ServiceClock.day.slice(-3); size: 56; weight: 600
                font.family: root._font; color: Colors.primary
                style: Text.Raised; styleColor: Colors.outline
            }
        }

        // Date · Month · Year
        RowLayout {
            Layout.alignment: Qt.AlignHCenter; spacing: 10
            CustomText {
                content: ServiceClock.date; size: 26; weight: 600
                font.family: root._font; style: Text.Raised; styleColor: Colors.outline
            }
            CustomText {
                content: ServiceClock.month; size: 26; weight: 600; color: Colors.primary
                font.family: root._font; style: Text.Raised; styleColor: Colors.outline
            }
            CustomText {
                content: ServiceClock.year; size: 26; weight: 600
                font.family: root._font; style: Text.Raised; styleColor: Colors.outline
            }
        }
    }

    // ── Bottom dock (original shape + improved cards) ─────────────────────────
    Item {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: 900
        implicitHeight: 110

        // Dock flare shape (unchanged from original)
        Shape {
            id: bgShape
            z: 1
            preferredRendererType: Shape.CurveRenderer

            readonly property real w:          container.width
            readonly property real h:          container.height
            readonly property real bodyLeft:   container.x
            readonly property real bodyRight:  container.x + w
            readonly property real bodyBottom: container.y + container.height
            readonly property real bodyTop:    bodyBottom - h
            readonly property real rounding:   Math.min(h / 3, w / 3)
            readonly property real flareX:     w / 18
            readonly property bool flattenFlare: h < flareX * 2
            readonly property real flareY:     flattenFlare ? Math.max(0, h / 2) : flareX
            readonly property real flareRadiusY: Math.min(flareX, Math.max(0, h))

            ShapePath {
                strokeWidth: -1
                fillColor: Settings.layoutColor

                startX: bgShape.bodyLeft - bgShape.flareX
                startY: bgShape.bodyBottom

                PathArc {
                    x: bgShape.bodyLeft
                    y: bgShape.bodyBottom - bgShape.flareY
                    radiusX: bgShape.flareX
                    radiusY: bgShape.flareRadiusY
                    direction: PathArc.Counterclockwise
                }
                PathLine {
                    x: bgShape.bodyLeft
                    y: bgShape.bodyTop + bgShape.rounding
                }
                PathArc {
                    x: bgShape.bodyLeft + bgShape.rounding
                    y: bgShape.bodyTop
                    radiusX: bgShape.rounding
                    radiusY: Math.min(bgShape.rounding, bgShape.h)
                }
                PathLine {
                    x: bgShape.bodyRight - bgShape.rounding
                    y: bgShape.bodyTop
                }
                PathArc {
                    x: bgShape.bodyRight
                    y: bgShape.bodyTop + bgShape.rounding
                    radiusX: bgShape.rounding
                    radiusY: Math.min(bgShape.rounding, bgShape.h)
                }
                PathLine {
                    x: bgShape.bodyRight
                    y: bgShape.bodyBottom - bgShape.flareY
                }
                PathArc {
                    x: bgShape.bodyRight + bgShape.flareX
                    y: bgShape.bodyBottom
                    radiusX: bgShape.flareX
                    radiusY: bgShape.flareRadiusY
                    direction: PathArc.Counterclockwise
                }
                PathLine {
                    x: bgShape.bodyLeft - bgShape.flareX
                    y: bgShape.bodyBottom
                }
            }
        }

        // Container (slides up via implicitHeight)
        Item {
            id: container
            z: 10
            implicitWidth: 800
            implicitHeight: 0
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter

            Behavior on implicitHeight {
                NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
            }

            Connections {
                target: root.context
                function onUnlocked() {
                    container.implicitHeight = 0
                    row.visible = false
                }
            }

            Timer {
                interval: 600; running: true
                onTriggered: container.implicitHeight = 90
            }
            Timer {
                interval: 900; running: true
                onTriggered: row.visible = true
            }

            // ── Three cards ───────────────────────────────────────────────────
            RowLayout {
                id: row
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                visible: false

                // ── User card ─────────────────────────────────────────────────
                Rectangle {
                    Layout.preferredWidth: 150
                    Layout.fillHeight: true
                    radius: 20
                    color: Colors.surfaceContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        // Avatar
                        ClippingWrapperRectangle {
                            width: 44; height: 44; radius: 14
                            color: Colors.primary
                            Image {
                                anchors.fill: parent
                                source: SettingsConfig.general.profile
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(width, height)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 2

                            CustomText {
                                content: Quickshell.env("USER") || "user"
                                size: 14; weight: 700
                            }
                            CustomText {
                                content: "Hyprland"
                                size: 11; customColor: Colors.outline
                            }
                        }
                    }
                }

                // ── Password card ─────────────────────────────────────────────
                Rectangle {
                    Layout.preferredWidth: 390
                    Layout.fillHeight: true
                    radius: 20
                    color: Colors.surfaceContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        // Lock icon with state tinting
                        Rectangle {
                            width: 38; height: 38; radius: 12
                            color: root.context.showFailure
                                ? Qt.alpha(Colors.error, 0.15)
                                : root.context.unlockInProgress
                                    ? Qt.alpha(Colors.primary, 0.15)
                                    : "transparent"
                            Behavior on color { ColorAnimation { duration: 200 } }

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: root.context.unlockInProgress ? "lock_open" : "lock"
                                iconSize: 22
                                customColor: root.context.showFailure
                                    ? Colors.error
                                    : root.context.unlockInProgress ? Colors.primary : Colors.outline
                            }
                        }

                        CustomShapeInput {
                            id: passInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            placeholderText: root.context.showFailure
                                ? "Wrong password — try again"
                                : "Enter password"
                            placeholderColor: root.context.showFailure ? Colors.error : Colors.outline
                            enabled: !root.context.unlockInProgress

                            onTextChanged: root.context.currentText = text
                            onAccepted:    root.context.tryUnlock()

                            Connections {
                                target: root.context
                                function onCurrentTextChanged() {
                                    passInput.text = root.context.currentText
                                }
                            }
                        }
                    }
                }

                // ── Music card ────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 20
                    color: Colors.surfaceContainer

                    LockScreenMusicPlayer {
                        anchors.fill: parent
                    }
                }
            }
        }
    }
}
