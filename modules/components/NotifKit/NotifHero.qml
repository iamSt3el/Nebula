import QtQuick
import Quickshell.Io
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.customComponents

ClippingRectangle {
    id: hero

    property var notif: null
    property real minRatio: 0.42
    property real maxRatio: 0.62

    readonly property string src: {
        const s = IconUtil.imageSource(hero.notif?.image)
        return s.startsWith("file://") ? s : ""
    }
    property int realW: 0
    property int realH: 0
    readonly property bool big: Math.max(hero.realW, hero.realH) >= 320
    readonly property bool ok: hero.big && img.status === Image.Ready
    readonly property real ratio: hero.realW > 0
        ? Math.max(hero.minRatio, Math.min(hero.maxRatio, hero.realH / hero.realW)) : hero.maxRatio

    visible: hero.ok
    implicitHeight: hero.ok ? Math.round(hero.width * hero.ratio) : 0
    radius: 16
    color: Colors.surfaceContainerHighest

    onSrcChanged: hero.probe()
    Component.onCompleted: hero.probe()

    function probe() {
        hero.realW = 0
        hero.realH = 0
        if (hero.src === "")
            return
        const path = decodeURIComponent(hero.src.slice(7))
        dims.target = hero.src
        dims.command = ["magick", "identify", "-ping", "-format", "%w %h", path + "[0]"]
        dims.running = true
    }

    Process {
        id: dims
        property string target: ""
        stdout: StdioCollector { id: dimsOut }
        onExited: code => {
            if (code !== 0 || dims.target !== hero.src)
                return
            const p = dimsOut.text.trim().split(" ")
            hero.realW = parseInt(p[0]) || 0
            hero.realH = parseInt(p[1]) || 0
        }
    }

    Image {
        id: img
        anchors.fill: parent
        source: hero.big ? hero.src : ""
        sourceSize: Qt.size(720, 720)
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 10
        width: dimsText.implicitWidth + 18
        height: 24
        radius: 12
        color: Qt.alpha(Colors.surfaceContainerLowest, 0.78)

        CustomText {
            id: dimsText
            anchors.centerIn: parent
            content: hero.realW + " × " + hero.realH
            size: 11
            weight: 500
            customColor: Colors.surfaceText
        }
    }
}
