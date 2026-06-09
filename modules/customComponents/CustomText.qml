import QtQuick
import qs.modules.settings
import qs.modules.utils
import QtQuick.Effects


Text{
    id: root
    property alias content: root.text
    property int size: 12
    verticalAlignment: Text.AlignVCenter
    property int weight: 800
    property string customColor: Colors.surfaceText
    property string family: SettingsConfig.general.defaultFont ?? "Rubik"
    renderType: Text.NativeRendering
    elide: Text.ElideRight
    color: customColor
    font.pixelSize: size
    font.weight: weight
    font.family: family


    Behavior on color{
        ColorAnimation{
            duration: 200
        }
    }
}
