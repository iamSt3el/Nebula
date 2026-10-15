import QtQuick
import qs.modules.services

Item {
    id: root

    property var closer: null
    readonly property DashActions actions: DashActions { closer: root.closer }
    readonly property bool passwordPrompt: sidebar.passwordPrompt

    implicitWidth: sidebar.implicitWidth
    implicitHeight: sidebar.implicitHeight

    Component.onCompleted: ServiceDashData.retainSystem()
    Component.onDestruction: ServiceDashData.releaseSystem()

    DashSidebar {
        id: sidebar
        anchors.fill: parent
        actions: root.actions
    }
}
