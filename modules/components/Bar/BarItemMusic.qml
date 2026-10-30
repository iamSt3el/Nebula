import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property Item host: null
    property string itemId: ""
    property string fallbackStyle: "pill"

    readonly property var styles: ["pill", "develop", "shape"]
    readonly property string style: {
        const s = BarLayout.opt(root.itemId, "style") ?? root.fallbackStyle
        return root.styles.indexOf(s) >= 0 ? s : "pill"
    }
    readonly property bool hideIdle: BarLayout.opt(root.itemId, "hideIdle") === true

    readonly property bool hasTrack: ServiceMusic.activePlayer !== null
    readonly property bool playing: ServiceMusic.isPlaying
    readonly property string title: ServiceMusic.activeTrack?.title ?? ""
    readonly property string artist: ServiceMusic.activeTrack?.artist ?? ""
    readonly property string artUrl: ServiceMusic.activeTrack?.artUrl ?? ""
    readonly property real elapsed: ServiceMusic.activePlayer?.position ?? 0
    readonly property real progress: {
        const len = ServiceMusic.trackLength
        if (len <= 0)
            return 0
        return Math.max(0, Math.min(1, root.elapsed / len))
    }

    readonly property var panelKinds: ({ pill: "musicPoster", poster: "musicPoster", dial: "musicDial",
                                         sources: "musicSources", beads: "musicBeads",
                                         develop: "musicDevelop", shape: "musicShape" })
    readonly property string panelKind: {
        const p = BarLayout.opt(root.itemId, "panel") ?? "match"
        if (root.panelKinds[p] !== undefined)
            return root.panelKinds[p]
        return root.panelKinds[root.style] ?? "musicPoster"
    }

    readonly property bool inDock: root.host && root.host.iconSize ? true : false
    readonly property real h: root.inDock ? root.host.iconSize + 14 : Appearance.size.barHeight
    readonly property real art: Math.max(20, Math.min(30, root.h - 18))

    readonly property bool shown: root.hasTrack || !root.hideIdle
    readonly property bool vertical: !!root.host && root.host.vertical === true
    readonly property bool verticalReady: false

    implicitWidth: face.item ? face.item.implicitWidth : 0
    implicitHeight: root.h

    Loader {
        id: face
        anchors.centerIn: parent
        sourceComponent: {
            if (!root.hasTrack)
                return idleComp
            switch (root.style) {
            case "develop": return developComp
            case "shape":   return shapeComp
            }
            return pillComp
        }
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered && root.host)
                root.host.hoverOpen(root.panelKind, root)
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: ServiceMusic.togglePlaying()
    }

    component Art: ClippingWrapperRectangle {
        id: artBox
        property real side: root.art
        implicitWidth: artBox.side
        implicitHeight: artBox.side
        radius: 8
        color: Colors.surfaceContainerHighest

        Item {
            MaterialIconSymbol {
                anchors.centerIn: parent
                content: "music_note"
                iconSize: Math.round(artBox.side * 0.55)
                customColor: Colors.outline
                visible: root.artUrl === ""
            }

            Image {
                anchors.fill: parent
                source: root.artUrl
                sourceSize.width: 96
                sourceSize.height: 96
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                visible: root.artUrl !== ""
            }
        }
    }

    component Btn: Rectangle {
        id: btn
        property string icon: ""
        property bool primary: false
        property real side: 26
        signal tapped

        implicitWidth: btn.side
        implicitHeight: btn.side
        radius: btn.side / 2
        color: btn.primary ? (btnArea.containsMouse ? Colors.primary : Colors.primaryContainer)
                           : (btnArea.containsMouse ? Qt.alpha(Colors.primary, 0.14) : "transparent")
        Behavior on color { EffectsColorAnim {} }

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: btn.icon
            iconSize: Math.round(btn.side * 0.62)
            customColor: btn.primary ? (btnArea.containsMouse ? Colors.primaryText : Colors.primaryContainerText)
                                     : (btnArea.containsMouse ? Colors.primary : Colors.outline)
        }

        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.tapped()
        }
    }

    Component {
        id: idleComp
        RowLayout {
            spacing: 8
            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 12
                color: Colors.surfaceContainerHigh
                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: "music_off"
                    iconSize: 14
                    customColor: Colors.outline
                }
            }
            CustomText {
                content: "Nothing playing"
                size: 12
                weight: 500
                customColor: Colors.outline
            }
        }
    }

    Component {
        id: pillComp
        Rectangle {
            implicitWidth: pillRow.implicitWidth + 10
            implicitHeight: root.h - 10
            radius: implicitHeight / 2
            color: Colors.surfaceContainerHigh

            RowLayout {
                id: pillRow
                anchors.verticalCenter: parent.verticalCenter
                x: 5
                spacing: 6
                Art {
                    side: root.h - 18
                    radius: (root.h - 18) / 2
                }
                ColumnLayout {
                    spacing: -1
                    CustomMarqueeText {
                        Layout.preferredWidth: Math.min(implicitWidth, 110)
                        content: root.inDock || root.artist === "" ? root.title : root.title + "  —  " + root.artist
                        size: 12
                        weight: 600
                        customColor: Colors.surfaceText
                        scrolling: root.playing
                    }
                    CustomText {
                        Layout.maximumWidth: 110
                        visible: root.inDock && root.artist !== ""
                        content: root.artist
                        size: 10
                        customColor: Colors.outline
                        elide: Text.ElideRight
                    }
                }
                Btn { icon: "skip_previous"; onTapped: ServiceMusic.previous() }
                Btn {
                    icon: root.playing ? "pause" : "play_arrow"
                    primary: true
                    side: 28
                    onTapped: ServiceMusic.togglePlaying()
                }
                Btn { icon: "skip_next"; onTapped: ServiceMusic.next() }
            }
        }
    }

    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"

    Component {
        id: developComp
        Rectangle {
            implicitWidth: devRow.implicitWidth + 17
            implicitHeight: root.h - 10
            radius: implicitHeight / 2
            color: Colors.surfaceContainerHigh

            RowLayout {
                id: devRow
                anchors.verticalCenter: parent.verticalCenter
                x: 3
                spacing: 9

                MusicDevelopArt {
                    Layout.preferredWidth: Math.round((root.h - 16) * 3)
                    Layout.preferredHeight: root.h - 16
                    cornerRadius: (root.h - 16) / 2
                    progress: root.progress
                    decode: 160
                    opacity: root.playing ? 1 : 0.6
                    Behavior on opacity { EffectsAnim {} }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "pause"
                        iconSize: 16
                        fill: 1
                        customColor: "white"
                        visible: !root.playing
                    }
                }
                CustomText {
                    Layout.maximumWidth: 130
                    content: root.title
                    size: 12
                    weight: 600
                    customColor: root.playing ? Colors.surfaceText : Colors.outline
                }
                CustomText {
                    Layout.maximumWidth: 100
                    visible: !root.inDock && root.artist !== ""
                    content: root.artist
                    size: 12
                    weight: 400
                    customColor: Colors.outline
                }
            }
        }
    }

    Component {
        id: shapeComp
        Item {
            implicitWidth: shapeRow.implicitWidth + 6
            implicitHeight: root.h - 8

            RowLayout {
                id: shapeRow
                anchors.verticalCenter: parent.verticalCenter
                x: 2
                spacing: 9

                MusicShapeArt {
                    Layout.preferredWidth: root.h - 10
                    Layout.preferredHeight: root.h - 10
                    decode: 96
                    round: !root.playing
                    dim: root.playing ? 0 : 1
                }
                CustomText {
                    Layout.maximumWidth: 140
                    content: root.title
                    size: 12
                    weight: 600
                    customColor: root.playing ? Colors.surfaceText : Colors.outline
                }
                CustomText {
                    Layout.maximumWidth: 100
                    visible: !root.inDock && root.artist !== ""
                    content: root.artist
                    size: 12
                    weight: 400
                    customColor: Colors.outline
                }
            }
        }
    }
}
