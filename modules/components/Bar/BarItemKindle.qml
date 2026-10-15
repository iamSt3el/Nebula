import QtQuick
import qs.modules.services

BarButtonItem {
    id: root

    icon: "auto_stories"
    label: "Kindle"
    tip: ServiceKindle.name !== "" ? "Kindle frame: " + ServiceKindle.name : "Kindle frame"
    active: !!root.host && root.host.panelKind === "kindle"
    onActivated: if (root.host) root.host.openPanel("kindle", root)
}
