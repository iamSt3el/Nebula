import QtQuick
import qs.modules.utils
import qs.modules.settings

Item {
    id: digit

    property string ch: ""
    property color tint: Colors.surfaceText
    property color cutColor: Colors.surface
    property bool cut: false
    property real px: 24
    property real cutW: 2
    property real baseY: 0
    property string family: SettingsConfig.general.displayFont ?? "Titan One"

    y: Math.round(digit.baseY - glyph.baselineOffset)
    width: glyph.implicitWidth
    height: glyph.implicitHeight

    Repeater {
        model: digit.cut ? 12 : 0
        Text {
            required property int index
            x: digit.cutW * Math.cos(index * Math.PI / 6)
            y: digit.cutW * Math.sin(index * Math.PI / 6)
            text: digit.ch
            color: digit.cutColor
            renderType: Text.QtRendering
            font: glyph.font
        }
    }

    Text {
        id: glyph
        text: digit.ch
        color: digit.tint
        renderType: Text.QtRendering
        font.family: digit.family
        font.pixelSize: digit.px
        font.weight: 600
        Behavior on color { ColorAnimation { duration: 150 } }
    }
}
