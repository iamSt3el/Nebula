import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services

Image {
    id: root

    property var app: null
    property int size: 32

    Layout.preferredWidth: root.size
    Layout.preferredHeight: root.size
    width: root.size
    height: root.size
    sourceSize.width: root.size
    sourceSize.height: root.size
    source: IconUtil.getDesktopIconPath(root.app?.icon ?? "")
    fillMode: Image.PreserveAspectFit
    onSizeChanged: ServiceLauncher.noteIconSize(root.size)
    Component.onCompleted: ServiceLauncher.noteIconSize(root.size)
}
