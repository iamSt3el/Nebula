import Quickshell
import QtQuick
import qs.modules.utils

CustomText{
    id: root
    property real iconSize: 16
    property real fill: 0

    font {
        hintingPreference: Font.PreferVerticalHinting
        family: root.fill >= 0.5 ? IconFont.filledFamily : IconFont.family
        pixelSize: Math.round(iconSize)
    }
}
