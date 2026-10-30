import QtQuick
import qs.modules.services

BarButtonItem {
    id: root

    icon: ServiceWiz.on ? "lightbulb" : "light_off"
    label: ServiceWiz.on ? Math.round(ServiceWiz.dimming * 100) + "%" : "Light"
    tip: !ServiceWiz.ready ? "Light: " + (ServiceWiz.status === "notfound" ? "not found" : "searching")
        : ServiceWiz.on ? "Light on, " + Math.round(ServiceWiz.dimming * 100) + "%" : "Light off"
    active: ServiceWiz.on
    onActivated: if (root.host) root.host.openPanel("wiz", root)

    Component.onCompleted: ServiceWiz.retain()
    Component.onDestruction: ServiceWiz.release()
}
