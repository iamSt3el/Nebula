import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.components.Bar

// Thin wrapper so the dashboard's music slot has the same shape as every other
// section: a root that takes `compact` and carries its own layout hints.
MusicPlayer{
    id: root
    property bool compact: false

    implicitHeight: root.compact ? 120 : 150
}
