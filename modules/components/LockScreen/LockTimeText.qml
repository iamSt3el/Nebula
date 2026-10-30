import QtQuick

Row {
    id: root

    property string hour: LockSession.hour
    property string minute: LockSession.minute
    property string suffix: ""
    property color color: "white"
    property string family: "Rubik"
    property int pixelSize: 100
    property int weight: 400
    property real letterSpacing: 0
    property var features: ({})
    property int renderType: Text.NativeRendering
    property real lineHeight: 1

    readonly property rect zeroBox: { fm.font; return fm.tightBoundingRect("0") }
    readonly property rect colonBox: { fm.font; return fm.tightBoundingRect(":") }
    readonly property real colonShift: Math.round((root.zeroBox.y + root.zeroBox.height / 2) - (root.colonBox.y + root.colonBox.height / 2))

    readonly property Item hourItem: hourText
    readonly property Item colonItem: colonText
    readonly property Item minuteItem: minuteText

    function inkOf(item) {
        return Qt.rect(0, item.baselineOffset + root.zeroBox.y, item.width, root.zeroBox.height)
    }

    baselineOffset: hourText.baselineOffset
    spacing: 0

    FontMetrics {
        id: fm
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.weight: root.weight
    }

    component Part: Text {
        color: root.color
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        font.letterSpacing: root.letterSpacing
        font.features: root.features
        renderType: root.renderType
        lineHeight: root.lineHeight
    }

    Part { id: hourText; text: root.hour }
    Part { id: colonText; text: ":"; y: root.colonShift }
    Part { id: minuteText; text: root.minute }
    Part { visible: root.suffix !== ""; text: " " + root.suffix }
}
