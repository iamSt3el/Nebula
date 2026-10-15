import QtQuick
import qs.modules.services
import qs.modules.settings

BarButtonItem {
    id: root

    readonly property bool verticalReady: true

    shown: BarLayout.anchorsOnly(root.host)
    icon: ServicePipewire.muted ? "volume_off"
        : ServicePipewire.volume > 0.6 ? "volume_up"
        : ServicePipewire.volume > 0.2 ? "volume_down"
        : "volume_mute"
    active: GlobalStates.osdOpen
    label: "Volume " + Math.round(ServicePipewire.volume * 100) + "%"
    clickable: false

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            if (d > 0)
                ServicePipewire.incrementVolume(0.05)
            else if (d < 0)
                ServicePipewire.decrementVolume(0.05)
        }
    }
}
