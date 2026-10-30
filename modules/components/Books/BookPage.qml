import QtQuick
import qs.modules.utils

Rectangle {
    id: page

    required property Item host
    property string side: "right"
    property int chapter: -1
    property int page: 0
    property real shade: 0
    property bool bend: false
    property bool blank: false

    readonly property Item flow: page.blank ? null : page.host.flowFor(page.chapter)
    readonly property bool has: page.flow !== null && page.page >= 0 && page.page < page.flow.pages
    readonly property var pc: page.host.pc
    readonly property bool isLeft: page.side === "left"
    readonly property var ch: page.has && page.host.book ? page.host.book.chapters[page.chapter] : null

    width: page.host.pageW
    height: page.host.pageH
    color: page.pc.paper
    topLeftRadius: page.side === "right" ? 0 : 6
    bottomLeftRadius: page.side === "right" ? 0 : 6
    topRightRadius: page.isLeft ? 0 : 6
    bottomRightRadius: page.isLeft ? 0 : 6
    antialiasing: true

    Text {
        visible: page.has && !(page.page === 0)
        x: page.host.padX
        y: 26
        width: page.host.textW
        horizontalAlignment: page.isLeft ? Text.AlignLeft : Text.AlignRight
        text: page.isLeft ? (page.host.book ? page.host.book.title.toUpperCase() : "") : (page.ch ? page.ch.title.toUpperCase() : "")
        elide: Text.ElideRight
        font.family: "Rubik"
        font.pixelSize: 10
        font.letterSpacing: 1.6
        color: page.pc.muted
    }

    Column {
        visible: page.has && page.page === 0
        x: page.host.padX
        y: page.host.padTop + 6
        width: page.host.textW
        spacing: 12

        Text {
            width: parent.width
            text: page.ch ? page.ch.title : ""
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.family: page.host.fontFamily
            font.italic: true
            font.pixelSize: Math.round(page.host.fontSize * 1.35)
            color: page.pc.muted
        }
        Rectangle {
            width: 42
            height: 1.5
            color: Qt.alpha(page.pc.muted, 0.7)
        }
    }

    ShaderEffectSource {
        x: page.host.padX
        y: page.host.padTop
        width: page.host.textW
        height: page.host.textH
        visible: page.has
        sourceItem: page.has ? page.flow : null
        sourceRect: Qt.rect(page.page * (page.host.textW + page.host.gapX), 0, page.host.textW, page.host.textH)
        hideSource: true
        smooth: true
    }

    Text {
        visible: page.has
        x: page.host.padX
        y: page.height - 34
        width: page.host.textW
        horizontalAlignment: page.side === "single" ? Text.AlignHCenter : page.isLeft ? Text.AlignLeft : Text.AlignRight
        text: page.has ? String(Math.round(page.host.cum[page.chapter] / page.host.wordsPerPage) + page.page + 1) : ""
        font.family: "Rubik"
        font.pixelSize: 11
        color: page.pc.muted
    }

    Rectangle {
        anchors.fill: parent
        visible: page.shade > 0.002
        radius: 6
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(0.16, 0.1, 0.04, page.bend ? (page.isLeft ? 0 : page.shade) : (page.isLeft ? 0 : page.shade)) }
            GradientStop { position: 1; color: Qt.rgba(0.16, 0.1, 0.04, page.bend ? (page.isLeft ? page.shade : 0) : (page.isLeft ? page.shade : 0)) }
        }
    }
}
