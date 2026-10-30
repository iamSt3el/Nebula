import QtQuick
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.customComponents

Item {
    id: cover

    property string source: ""
    property string title: ""
    property string author: ""
    property real radius: 10

    readonly property var palettes: [
        ["#26404f", "#f1e6d2", "#33576b"], ["#5a2323", "#f4d9c6", "#7a3434"], ["#1f3b33", "#d8ead9", "#2c5246"],
        ["#3a2f4f", "#e6dcf2", "#4d3f68"], ["#8a6a3b", "#fff5e6", "#a5834f"], ["#284634", "#f0e7cf", "#36604a"],
        ["#2b3d5e", "#e3e9f6", "#3b527a"], ["#6b3a2a", "#f3e1cf", "#86503c"], ["#43302a", "#f0dfcc", "#5a4238"]
    ]
    readonly property var pal: {
        let h = 0
        for (let i = 0; i < cover.title.length; i++)
            h = (h * 31 + cover.title.charCodeAt(i)) >>> 0
        return cover.palettes[h % cover.palettes.length]
    }
    readonly property bool hasImage: rimg.status === Image.Ready

    implicitWidth: 150
    implicitHeight: Math.round(cover.width * 1.5)

    Rectangle {
        anchors.fill: parent
        radius: cover.radius
        color: cover.pal[0]
        visible: !cover.hasImage
        clip: true

        Rectangle {
            width: parent.width * 1.1
            height: width
            radius: width / 2
            x: parent.width * 0.45
            y: parent.height * 0.42
            color: cover.pal[2]
        }

        CustomText {
            x: Math.round(parent.width * 0.09)
            y: Math.round(parent.width * 0.1)
            width: parent.width * 0.82
            content: cover.author.toUpperCase()
            size: Math.max(7, Math.round(parent.width * 0.065))
            elide: Text.ElideRight
            customColor: cover.pal[1]
        }

        Text {
            x: Math.round(parent.width * 0.09)
            width: parent.width * 0.82
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(parent.width * 0.12)
            text: cover.title
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            font.family: "Literata"
            font.weight: Font.DemiBold
            font.pixelSize: Math.max(9, Math.round(parent.width * 0.13))
            lineHeight: 1.05
            color: cover.pal[1]
            renderType: Text.QtRendering
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        visible: cover.hasImage
        radius: cover.radius
        color: "transparent"

        Image {
            id: rimg
            anchors.fill: parent
            source: cover.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            sourceSize.height: 480
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: cover.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.25)
        Rectangle {
            width: 3
            height: parent.height - cover.radius * 2
            y: cover.radius
            color: Qt.rgba(0, 0, 0, 0.18)
        }
    }
}
