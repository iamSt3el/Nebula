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

    readonly property var styles: ["pill", "develop", "drop", "buttons", "shelf", "counter", "shape"]
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

    readonly property var panelKinds: ({ side: "music", develop: "musicDevelop", drop: "musicDrop",
                                         buttons: "musicButtons", shelf: "musicShelf",
                                         counter: "musicCounter", shape: "musicShape" })
    readonly property string panelKind: {
        const p = BarLayout.opt(root.itemId, "panel") ?? "match"
        if (root.panelKinds[p] !== undefined)
            return root.panelKinds[p]
        return root.panelKinds[root.style] ?? "music"
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
            case "drop":    return dropComp
            case "buttons": return buttonsComp
            case "shelf":   return shelfComp
            case "counter": return counterComp
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

    component Seg: Rectangle {
        id: seg
        property string icon: ""
        property bool first: false
        property bool last: false
        property bool accent: false
        property bool round: false
        property bool usable: true
        signal tapped

        readonly property real hh: root.h - 10
        readonly property bool down: segArea.pressed
        readonly property real inner: seg.down || seg.round ? seg.hh / 2 : 6

        implicitWidth: (seg.accent || seg.round ? 34 : 30) + (seg.down ? 10 : 0)
        implicitHeight: seg.hh
        topLeftRadius: seg.first ? seg.hh / 2 : seg.inner
        bottomLeftRadius: seg.first ? seg.hh / 2 : seg.inner
        topRightRadius: seg.last ? seg.hh / 2 : seg.inner
        bottomRightRadius: seg.last ? seg.hh / 2 : seg.inner
        opacity: seg.usable ? 1 : 0.4
        color: seg.accent ? (segArea.containsMouse ? Qt.lighter(Colors.primary, 1.08) : Colors.primary)
             : seg.round ? Colors.surfaceContainerHighest
             : segArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh

        Behavior on implicitWidth { SpatialAnim { speed: "fast" } }
        Behavior on topLeftRadius { SpatialAnim { speed: "fast" } }
        Behavior on bottomLeftRadius { SpatialAnim { speed: "fast" } }
        Behavior on topRightRadius { SpatialAnim { speed: "fast" } }
        Behavior on bottomRightRadius { SpatialAnim { speed: "fast" } }
        Behavior on color { EffectsColorAnim {} }

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: seg.icon
            iconSize: Math.round(seg.hh * 0.6)
            fill: 1
            customColor: seg.accent ? Colors.primaryText : seg.round ? Colors.primary : Colors.surfaceText
        }

        MouseArea {
            id: segArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: seg.usable
            cursorShape: Qt.PointingHandCursor
            onClicked: seg.tapped()
        }
    }

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
        id: dropComp
        RowLayout {
            id: dropRow
            spacing: 8
            readonly property bool hosted: !root.inDock && !!root.host && typeof root.host.registerDrop === "function"
            property Item hostRef: null

            Item {
                id: dropSlot
                Layout.preferredWidth: root.h - 18
                Layout.preferredHeight: root.h - 18

                Art {
                    anchors.fill: parent
                    side: root.h - 18
                    radius: (root.h - 18) / 2
                    visible: !dropRow.hosted || (!!root.host && root.host.editing === true)
                }
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
                visible: !root.inDock && root.artist !== "" && root.playing
                content: root.artist
                size: 12
                weight: 400
                customColor: Colors.outline
            }
            MaterialIconSymbol {
                visible: !root.playing
                content: "pause"
                iconSize: 14
                fill: 1
                customColor: Colors.outline
            }

            Component.onCompleted: {
                if (!dropRow.hosted)
                    return
                dropRow.hostRef = root.host
                root.host.registerDrop(dropSlot, root)
            }
            Component.onDestruction: {
                const h = dropRow.hostRef
                if (h && h.dropSource === dropSlot)
                    h.releaseDrop(dropSlot)
            }
        }
    }

    Component {
        id: buttonsComp
        RowLayout {
            spacing: 2

            Seg {
                icon: "skip_previous"
                first: true
                usable: ServiceMusic.canGoPrevious
                onTapped: ServiceMusic.previous()
            }
            Seg {
                icon: root.playing ? "pause" : "play_arrow"
                accent: root.playing
                round: !root.playing
                onTapped: ServiceMusic.togglePlaying()
            }
            Rectangle {
                implicitWidth: midRow.implicitWidth + 16
                implicitHeight: root.h - 10
                radius: 6
                color: root.playing ? Colors.secondaryContainer : Colors.surfaceContainer
                Behavior on color { EffectsColorAnim {} }

                RowLayout {
                    id: midRow
                    anchors.verticalCenter: parent.verticalCenter
                    x: 4
                    spacing: 8

                    Art {
                        side: root.h - 18
                        radius: 5
                    }
                    CustomText {
                        Layout.maximumWidth: 130
                        content: root.title
                        size: 12
                        weight: 600
                        customColor: root.playing ? Colors.secondaryContainerText : Colors.outline
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
            Seg {
                icon: "skip_next"
                last: true
                usable: ServiceMusic.canGoNext
                onTapped: ServiceMusic.next()
            }
        }
    }

    Component {
        id: shelfComp
        Rectangle {
            implicitWidth: shelfRow.implicitWidth + 18
            implicitHeight: root.h - 8
            radius: implicitHeight / 2
            color: Colors.surfaceContainer

            RowLayout {
                id: shelfRow
                anchors.verticalCenter: parent.verticalCenter
                x: 4
                spacing: 9

                Rectangle {
                    Layout.preferredWidth: root.h - 16
                    Layout.preferredHeight: root.h - 16
                    radius: width / 2
                    color: root.playing ? Colors.primary : "transparent"
                    border.width: root.playing ? 0 : 1.5
                    border.color: Colors.outline
                    Behavior on color { EffectsColorAnim {} }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: root.playing ? "pause" : "play_arrow"
                        iconSize: Math.round(parent.width * 0.62)
                        fill: 1
                        customColor: root.playing ? Colors.primaryText : Colors.surfaceText
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ServiceMusic.togglePlaying()
                    }
                }
                ColumnLayout {
                    spacing: -1
                    CustomText {
                        Layout.maximumWidth: 140
                        content: root.title
                        size: 11
                        weight: 600
                        customColor: root.playing ? Colors.surfaceText : Colors.surfaceVariantText
                    }
                    CustomText {
                        Layout.maximumWidth: 140
                        content: root.playing ? root.artist : "Paused at " + ServiceMusic.formatTime(root.elapsed)
                        visible: content !== ""
                        size: 10
                        weight: 400
                        customColor: Colors.outline
                    }
                }
            }
        }
    }

    Component {
        id: counterComp
        Rectangle {
            id: counter
            implicitWidth: counterRow.implicitWidth + 18
            implicitHeight: root.h - 10
            radius: implicitHeight / 2
            color: Colors.surfaceContainerHigh

            HoverHandler { id: counterHover }

            RowLayout {
                id: counterRow
                anchors.verticalCenter: parent.verticalCenter
                x: 4
                spacing: 8

                Art {
                    side: root.h - 18
                    radius: (root.h - 18) / 2
                    opacity: root.playing ? 1 : 0.6
                }
                Text {
                    id: counterTime
                    Layout.preferredWidth: Math.ceil(counterSlot.advanceWidth) + 2
                    text: counterHover.hovered
                        ? "−" + ServiceMusic.formatTime(Math.max(0, ServiceMusic.trackLength - root.elapsed))
                        : ServiceMusic.formatTime(root.elapsed)
                    font.family: root.displayFamily
                    font.pixelSize: 15
                    font.features: { "tnum": 1 }
                    renderType: Text.QtRendering
                    color: !root.playing ? Colors.outline : counterHover.hovered ? Colors.surfaceText : Colors.primary
                    Behavior on color { EffectsColorAnim {} }

                    TextMetrics {
                        id: counterSlot
                        font: counterTime.font
                        text: "−" + ServiceMusic.formatTime(ServiceMusic.trackLength).replace(/[0-9]/g, "0")
                    }
                }
                CustomText {
                    Layout.maximumWidth: 130
                    content: root.title
                    size: 12
                    weight: 500
                    customColor: root.playing ? Colors.surfaceVariantText : Colors.outline
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
