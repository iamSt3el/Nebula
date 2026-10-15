import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

RowLayout {
    id: root

    property string kind: "volume"
    property bool showIcon: false
    readonly property var monitor: (ServiceBrightness.monitors ?? [])[0] ?? null
    readonly property real level: root.kind === "volume" ? ServicePipewire.volume : (root.monitor?.brightness ?? 0)
    readonly property bool off: root.kind === "volume" && ServicePipewire.muted

    function set(v) {
        if (root.kind === "volume") ServicePipewire.setVolume(v)
        else if (root.monitor) root.monitor.setBrightness(v)
    }

    spacing: 10

    MaterialIconSymbol {
        visible: root.showIcon
        content: root.kind === "volume" ? (root.off ? "volume_off" : "volume_up") : "light_mode"
        iconSize: 20
        customColor: Colors.surfaceVariantText
    }

    M3Slider {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        progress: root.level
        onMoved: root.set(progress)
    }

    Rectangle {
        implicitWidth: 48
        implicitHeight: 30
        radius: 10
        color: Colors.surfaceContainerHighest

        CustomText {
            anchors.centerIn: parent
            content: root.off ? "Off" : Math.round(root.level * 100) + "%"
            size: 12
            weight: 800
        }
    }
}
