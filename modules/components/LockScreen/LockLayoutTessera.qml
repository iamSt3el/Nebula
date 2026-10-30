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
    readonly property string _display: "Fira Sans Condensed"
    readonly property bool _music: root.cfg.showMusic !== false && !root.greeter && ServiceMusic.activePlayer !== null
    readonly property bool _status: root.cfg.showStatus !== false && !root.greeter
    readonly property bool _date: root.cfg.showDate !== false
    readonly property bool _power: root.cfg.showPower !== false

    readonly property real pad: 40 * root.u
    readonly property real gap: 18 * root.u
    readonly property real colW: (root.width - root.pad * 2 - root.gap * 11) / 12
    readonly property real rowH: (root.height - root.pad * 2 - root.gap * 5) / 6
    readonly property real big: 120 * root.u
    readonly property real small: 44 * root.u

    LockStatusModel { id: status }

    function entry(name) {
        return status.entries.find(e => e.name === name) ?? null
    }
    readonly property var weather: root._status ? root.entry("Weather") : null
    readonly property var battery: root._status ? root.entry("Battery") : null
    readonly property var network: root._status ? root.entry("Network") : null
    readonly property var notes: root._status ? root.entry("Notifications") : null

    readonly property bool _row3Split: root.weather !== null
    readonly property bool _row4: root.battery !== null || root.network !== null

    function rect(c0, c1, r0, r1) {
        return {
            x: root.pad + c0 * (root.colW + root.gap),
            y: root.pad + r0 * (root.rowH + root.gap),
            w: (c1 - c0) * root.colW + (c1 - c0 - 1) * root.gap,
            h: (r1 - r0) * root.rowH + (r1 - r0 - 1) * root.gap
        }
    }

    LockTimeline {
        id: tileLine
        animated: root._animated
        exiting: root.exiting
    }

    component Tile: LockTile {
        id: tile
        readonly property real order: tile.r.x / root.width * 6 + tile.r.y / root.height * 4
        line: tileLine
        tl: root.small
        tr: root.small
        bl: root.small
        br: root.small
        dy: 24 * root.u
        preview: root.preview
        at: 80 + Math.round(tile.order * 50)
        outAt: Math.round((10 - tile.order) * 28)
    }

    Tile {
        r: root.rect(0, 7, 0, 4)
        tl: root.small
        bl: root.big
        fill: Colors.surfaceContainerHighest

        Image {
            anchors.fill: parent
            source: WallpaperTheme.wallpaperScreen
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: root.preview ? 480 : 1300
            asynchronous: true
            cache: true
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.5; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0.06, 0.04, 0.05, 0.7) }
            }
        }

        Column {
            x: 38 * root.u
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 34 * root.u
            CustomText {
                content: root.greeter ? "Sign in," : LockSession.greeting + ","
                size: Math.round(24 * root.u)
                weight: 500
                customColor: "#f3e9ec"
            }
            CustomText {
                content: LockSession.user
                size: Math.round(40 * root.u)
                renderType: root.preview ? Text.CurveRendering : Text.NativeRendering
                weight: 700
                customColor: "#ffffff"
            }
        }
    }

    Tile {
        r: root.rect(7, 12, 0, root._date ? 2 : 3)
        tr: root.big
        fill: Colors.primary

        CustomText {
            x: 38 * root.u
            y: 34 * root.u
            content: "LOCAL TIME · " + LockSession.ampm
            size: Math.round(24 * root.u)
            weight: 600
            font.letterSpacing: 3 * root.u
            customColor: Qt.alpha(Colors.primaryText, 0.75)
        }

        LockTimeText {
            x: 30 * root.u
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -34 * root.u
            color: Colors.primaryText
            family: root._display
            pixelSize: Math.round(250 * root.u)
            weight: 800
            letterSpacing: -6 * root.u
            renderType: root.preview ? Text.CurveRendering : Text.NativeRendering
        }
    }

    Tile {
        visible: root._date
        r: root.rect(7, root._row3Split ? 10 : 12, 2, root._row4 ? 3 : 4)
        fill: Colors.secondaryContainer

        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: 38 * root.u
            anchors.verticalCenter: parent.verticalCenter
            spacing: 22 * root.u

            Text {
                text: LockSession.dayNum
                color: Colors.surfaceText
                font.family: root._display
                font.pixelSize: Math.round(108 * root.u)
                font.weight: 800
                renderType: root.preview ? Text.CurveRendering : Text.NativeRendering
            }
            Column {
                CustomText { content: LockSession.weekday; size: Math.round(26 * root.u); weight: 600; customColor: Colors.secondaryContainerText }
                CustomText { content: LockSession.month; size: Math.round(26 * root.u); weight: 600; customColor: Colors.secondaryContainerText }
            }
        }
    }

    Tile {
        visible: root._row3Split
        r: root.rect(root._date ? 10 : 7, 12, 2, root._row4 ? 3 : 4)
        fill: Colors.tertiaryContainer

        MaterialIconSymbol {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 26 * root.u
            content: root.weather?.icon ?? "cloud"
            iconSize: Math.round(46 * root.u)
            customColor: Colors.tertiaryContainerText
        }
        Column {
            x: 34 * root.u
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 26 * root.u
            CustomText { content: root.weather?.value ?? ""; size: Math.round(56 * root.u); renderType: root.preview ? Text.CurveRendering : Text.NativeRendering; weight: 700; customColor: Colors.tertiaryContainerText }
            CustomText {
                width: Math.min(implicitWidth, root.colW * 2 - 60 * root.u)
                content: root.weather?.sub ?? ""
                size: Math.round(19 * root.u)
                weight: 600
                customColor: Colors.tertiaryContainerText
            }
        }
    }

    Tile {
        id: battTile
        visible: root.battery !== null
        r: root.rect(7, root.network !== null ? 9 : 12, 3, 4)

        property real level: 0
        Component.onCompleted: battTile.level = root.preview ? ServiceUPower.powerLevel : 0
        NumberAnimation on level {
            running: root._animated && root.battery !== null
            to: ServiceUPower.powerLevel
            duration: 1400
            easing.type: Easing.OutCubic
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * battTile.level
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Colors.primary, 0.14) }
                GradientStop { position: 1; color: Qt.alpha(Colors.primary, 0.3) }
            }
        }
        MaterialIconSymbol {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 26 * root.u
            content: root.battery?.icon ?? ""
            iconSize: Math.round(40 * root.u)
            customColor: Colors.primary
        }
        Column {
            x: 34 * root.u
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24 * root.u
            CustomText { content: root.battery?.value ?? ""; size: Math.round(52 * root.u); renderType: root.preview ? Text.CurveRendering : Text.NativeRendering; weight: 700 }
            CustomText {
                content: (root.battery?.sub ?? "") !== "" ? "Charging" : "Battery"
                size: Math.round(19 * root.u)
                weight: 400
                customColor: Colors.surfaceVariantText
            }
        }
    }

    Tile {
        visible: root.network !== null
        r: root.rect(root.battery !== null ? 9 : 7, 12, 3, 4)

        Column {
            x: 34 * root.u
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12 * root.u

            Row {
                spacing: 14 * root.u
                MaterialIconSymbol { anchors.verticalCenter: parent.verticalCenter; content: root.network?.icon ?? "wifi"; iconSize: Math.round(32 * root.u); customColor: Colors.primary }
                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, root.colW * 3 - 120 * root.u)
                    content: root.network?.value ?? ""
                    size: Math.round(24 * root.u)
                    weight: 600
                }
            }
            Row {
                visible: root.notes !== null
                spacing: 14 * root.u
                MaterialIconSymbol { anchors.verticalCenter: parent.verticalCenter; content: "notifications"; iconSize: Math.round(32 * root.u); customColor: Colors.primary }
                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: (root.notes?.value ?? "0") + " notifications"
                    size: Math.round(19 * root.u)
                    weight: 400
                    customColor: Colors.surfaceVariantText
                }
            }
        }
    }

    Tile {
        visible: root._music
        r: root.rect(0, 4, 4, 6)
        bl: root.big
        fill: Colors.surfaceContainer

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 34 * root.u
            anchors.rightMargin: 30 * root.u
            spacing: 26 * root.u

            LockShapeImage {
                Layout.preferredWidth: 170 * root.u
                Layout.preferredHeight: 170 * root.u
                source: ServiceMusic.activeTrack?.artUrl ?? ""
                trackKey: (ServiceMusic.activeTrack?.title ?? "") + "|" + (ServiceMusic.activeTrack?.artist ?? "")
                sourceSize: 512
                shapeName: "cookie12"
                fallbackIcon: "music_note"

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ServiceMusic.togglePlaying()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2 * root.u
                CustomText { Layout.fillWidth: true; content: ServiceMusic.activeTrack?.title ?? ""; size: Math.round(34 * root.u); renderType: root.preview ? Text.CurveRendering : Text.NativeRendering; weight: 700 }
                CustomText { Layout.fillWidth: true; content: ServiceMusic.activeTrack?.artist ?? ""; size: Math.round(22 * root.u); weight: 400; customColor: Colors.surfaceVariantText }
                Rectangle {
                    Layout.topMargin: 16 * root.u
                    Layout.fillWidth: true
                    Layout.preferredHeight: 10 * root.u
                    radius: height / 2
                    color: Colors.surfaceContainerHighest
                    Rectangle {
                        height: parent.height
                        radius: height / 2
                        color: Colors.primary
                        width: parent.width * (ServiceMusic.trackLength > 0
                            ? Math.min(1, (ServiceMusic.activePlayer?.position ?? 0) / ServiceMusic.trackLength) : 0)
                        Behavior on width { NumberAnimation { duration: 900 } }
                    }
                }
            }
        }
    }

    Tile {
        r: root.rect(root._music ? 4 : 0, root._power ? 9 : 12, 4, 6)
        bl: root._music ? root.small : root.big
        br: root._power ? root.small : root.big

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 34 * root.u
            anchors.rightMargin: 34 * root.u
            spacing: 26 * root.u

            LockShapeImage {
                Layout.preferredWidth: 150 * root.u
                Layout.preferredHeight: 150 * root.u
                visible: LockSession.cfg.showAvatar !== false
                source: SettingsConfig.general.profile ?? ""
                shapeName: (root.context?.unlockInProgress ?? false) ? "softBurst"
                         : (root.context?.showFailure ?? false) ? "clover4" : "sunny"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 16 * root.u
                CustomText { content: root.greeter ? "Sign in" : "Unlock"; size: Math.round(40 * root.u); renderType: root.preview ? Text.CurveRendering : Text.NativeRendering; weight: 700 }
                LockAuthField {
                    id: auth
                    context: root.context
                    fieldWidth: Math.min(560 * root.u, root.colW * 5 - 280 * root.u)
                    fieldHeight: 76 * root.u
                    fieldColor: Colors.surfaceContainerHighest
                    submitRadius: 18 * root.u
                    placeholder: "Password"
                    placeholderSize: Math.round(23 * root.u)
                    showLockIcon: false
                    submitAlways: true
                    showFailureLine: false
                }
            }
        }
    }

    Tile {
        visible: root._power
        r: root.rect(9, 12, 4, 6)
        br: root.big
        fill: Colors.surfaceContainer

        LockPowerActions {
            anchors.centerIn: parent
            variant: "tile"
            spacing: 14 * root.u
            tileW: (root.colW * 3 + root.gap * 2 - 80 * root.u) / 3
            tileH: 200 * root.u
            tileRadius: 32 * root.u
            plate: Colors.surfaceContainerHigh
            plateHover: Colors.surfaceContainerHighest
        }
    }
}
