import QtQuick
import qs.modules.customComponents

BarButtonItem {
    id: root

    icon: "power_settings_new"
    label: "Power"
    tip: "Power menu"
    active: !!root.host && root.host.panelKind === "power"
    onActivated: if (root.host) root.host.openPanel("power", root)

    HeroTag { key: "power"; item: root; owner: root }
}
