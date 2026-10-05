import QtQuick
import qs.modules.settings

BarButtonItem {
    id: root

    readonly property bool paging: GlobalStates.barEditMode && !!root.host && !!root.host.frame
    icon: root.paging && root.host.frame.editPage === 1 ? "first_page" : "more_horiz"
    label: "More"
    tip: root.paging ? "Show the other blocks" : "More items"
    active: !!root.host && (root.host.panelKind !== "" || (root.paging && root.host.frame.editPage === 1))
    onActivated: if (root.host) root.host.openPanel("more", root)
}
