import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents


PanelWindow{
    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true

    WlrLayershell.layer: WlrLayer.Bottom
    color: "transparent"

    // Temperature{
    // } 
    CircularMusicPlayer{

    }


}
