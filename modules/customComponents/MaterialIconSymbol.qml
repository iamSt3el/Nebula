import Quickshell
import QtQuick

CustomText{
    id: root
    property real iconSize: 16
    property real fill: 0

    font {
        hintingPreference: Font.PreferFullHinting
        family: "Material Symbols Rounded"
        pixelSize: Math.round(iconSize)
    }
}
