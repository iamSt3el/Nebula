import QtQuick
import qs.modules.services

BarButtonItem {
    id: root

    icon: "space_dashboard"
    label: "Dashboard"
    tip: "Dashboard"
    active: !!root.host && root.host.panelKind === "dashboard"
    onActivated: if (root.host) root.host.openPanel("dashboard", root)
}
