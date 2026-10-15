import QtQuick
import qs.modules.utils
import qs.modules.customComponents

CustomText {
    id: num

    property string value: ""
    property real maxWidth: 32
    property color ink: Colors.surfaceText

    content: num.value
    size: 12
    weight: 700
    customColor: num.ink
    elide: Text.ElideNone
    horizontalAlignment: Text.AlignHCenter
    fontSizeMode: Text.HorizontalFit
    minimumPixelSize: 8
    width: Math.min(implicitWidth, num.maxWidth)
    font.features: { "tnum": 1 }
}
