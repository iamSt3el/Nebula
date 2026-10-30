import QtQuick
import qs.modules.settings
import qs.modules.utils
import QtQuick.Effects

Text {
    id: root
    property alias content: root.text
    property int size: 12
    verticalAlignment: Text.AlignVCenter
    property int weight: _baseWeight
    property string customColor: Colors.surfaceText
    property string family: Appearance.fontFamily
    renderType: Text.NativeRendering
    elide: Text.ElideRight
    color: customColor
    font.pixelSize: Math.round(size * _sizeScale)
    font.weight: weight
    font.family: family
    font.hintingPreference: Font.PreferDefaultHinting

    readonly property real _sizeScale: Appearance.fontScale
    readonly property int _baseWeight: Appearance.fontWeight

    Behavior on color {
        ColorAnimation { duration: 200 }
    }
}
