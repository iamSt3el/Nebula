import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    property real topLeftRadius: 28
    property real topRightRadius: 28
    property real bottomLeftRadius: 28
    property real bottomRightRadius: 28

    readonly property bool hasTrack: ServiceMusic.activePlayer !== null
    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"
    readonly property color ink: Colors.primaryContainerText
    readonly property string album: {
        const a = ServiceMusic.activeTrack?.album ?? ""
        return a === "Unknown Album" ? "" : a
    }
    readonly property real volume: ServiceMusic.activePlayer?.volume ?? 0
    property real lastVolume: 0.5

    function setVolume(v) {
        if (!ServiceMusic.canChangeVolume || !ServiceMusic.activePlayer)
            return
        ServiceMusic.activePlayer.volume = Math.max(0, Math.min(1, v))
    }

    MusicEmptyState {
        anchors.fill: parent
        visible: !root.hasTrack
    }

    ClippingRectangle {
        id: card
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: Colors.primaryContainer
        visible: root.hasTrack

        Loader {
            anchors.fill: parent
            active: card.Window.window !== null && (ServiceMusic.activeTrack?.artUrl ?? "") !== ""
            sourceComponent: Item {
                Image {
                    anchors.fill: parent
                    anchors.margins: -32
                    source: ServiceMusic.activeTrack?.artUrl ?? ""
                    sourceSize.width: 96
                    sourceSize.height: 96
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1
                        blurMax: 48
                        saturation: 0.15
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    color: Qt.alpha(Colors.primaryContainer, 0.66)
                }
            }
        }

        HeroTag { key: "art"; item: art; target: true; clip: card; clipRadius: Math.max(root.bottomRightRadius, root.topRightRadius) }
        HeroTag { key: "title"; item: posterTitle; target: true }

        MusicShapeArt {
            id: art
            x: card.width - 236
            y: card.height - 214
            width: 276
            height: 276
            decode: 400
            round: !ServiceMusic.isPlaying
            dim: ServiceMusic.isPlaying ? 0 : 1

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: ServiceMusic.canTogglePlaying
                onClicked: ServiceMusic.togglePlaying()
            }
        }

        RowLayout {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 16
            anchors.rightMargin: 16
            spacing: 4

            MusicIconToggle {
                kind: "shuffle"
                side: 32
                visible: ServiceMusic.shuffleSupported
                accent: root.ink
                idle: Qt.alpha(root.ink, 0.7)
                hoverInk: root.ink
                hoverFill: Qt.alpha(root.ink, 0.14)
            }
            MusicIconToggle {
                kind: "repeat"
                side: 32
                visible: ServiceMusic.loopSupported
                accent: root.ink
                idle: Qt.alpha(root.ink, 0.7)
                hoverInk: root.ink
                hoverFill: Qt.alpha(root.ink, 0.14)
            }
            Rectangle {
                visible: ServiceMusic.canChangeVolume
                implicitWidth: volRow.implicitWidth + 20
                implicitHeight: 32
                radius: 16
                color: volArea.containsMouse ? Qt.alpha(root.ink, 0.22) : Qt.alpha(root.ink, 0.14)
                Behavior on color { EffectsColorAnim { speed: "fast" } }

                RowLayout {
                    id: volRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialIconSymbol {
                        content: root.volume <= 0.001 ? "volume_off" : root.volume < 0.5 ? "volume_down" : "volume_up"
                        iconSize: 17
                        fill: 1
                        customColor: root.ink
                    }
                    CustomText {
                        content: Math.round(root.volume * 100) + "%"
                        size: 11
                        weight: 600
                        customColor: root.ink
                    }
                }

                MouseArea {
                    id: volArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onWheel: wheel => root.setVolume(root.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                    onClicked: {
                        if (root.volume > 0.001) {
                            root.lastVolume = root.volume
                            root.setVolume(0)
                        } else {
                            root.setVolume(root.lastVolume)
                        }
                    }
                }
            }
        }

        ColumnLayout {
            x: 26
            y: 22
            width: 228
            spacing: 0

            CustomText {
                Layout.fillWidth: true
                content: ("Now playing" + (ServiceMusic.activeTrack?.identity ? " · " + ServiceMusic.activeTrack.identity : "")).toUpperCase()
                size: 10
                weight: 600
                font.letterSpacing: 1.4
                customColor: Qt.alpha(root.ink, 0.72)
            }
            Text {
                id: posterTitle
                Layout.fillWidth: true
                Layout.topMargin: 8
                text: ServiceMusic.activeTrack?.title ?? ""
                font.family: root.displayFamily
                font.pixelSize: 36
                lineHeight: 0.92
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                renderType: Text.QtRendering
                color: root.ink
            }
            CustomText {
                Layout.fillWidth: true
                Layout.topMargin: 6
                content: ServiceMusic.activeTrack?.artist ?? ""
                size: 14
                weight: 500
                customColor: root.ink
            }
            CustomText {
                Layout.fillWidth: true
                Layout.topMargin: 2
                visible: root.album !== ""
                content: root.album
                size: 12
                customColor: Qt.alpha(root.ink, 0.72)
            }
        }

        ColumnLayout {
            x: 26
            y: card.height - 130
            width: 200
            spacing: 6

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 6

                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: Qt.alpha(root.ink, 0.18)
                }
                Rectangle {
                    width: Math.max(6, parent.width * seek.shown)
                    height: parent.height
                    radius: 3
                    color: root.ink
                }
                MusicSeekArea {
                    id: seek
                    anchors.fill: parent
                    anchors.margins: -8
                }
            }

            RowLayout {
                Layout.fillWidth: true
                CustomText {
                    content: ServiceMusic.formatTime(seek.shown * ServiceMusic.trackLength)
                    size: 11
                    weight: 500
                    customColor: Qt.alpha(root.ink, 0.72)
                }
                Item { Layout.fillWidth: true }
                CustomText {
                    content: ServiceMusic.formatTime(ServiceMusic.trackLength)
                    size: 11
                    weight: 500
                    customColor: Qt.alpha(root.ink, 0.72)
                }
            }
        }

        RowLayout {
            x: 18
            y: card.height - 86
            spacing: 4

            MusicShapeButton {
                icon: "skip_previous"
                shape: "clover4"
                side: 52
                tone: Qt.alpha(root.ink, 0.14)
                iconColor: root.ink
                usable: ServiceMusic.canGoPrevious
                onTapped: ServiceMusic.previous()
            }
            MusicShapeButton {
                icon: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                shape: "sunny"
                pressShape: "cookie9"
                side: 74
                iconSize: 32
                tone: Colors.primary
                iconColor: Colors.primaryText
                usable: ServiceMusic.canTogglePlaying
                onTapped: ServiceMusic.togglePlaying()
            }
            MusicShapeButton {
                icon: "skip_next"
                shape: "clover4"
                side: 52
                tone: Qt.alpha(root.ink, 0.14)
                iconColor: root.ink
                usable: ServiceMusic.canGoNext
                onTapped: ServiceMusic.next()
            }
        }
    }
}
