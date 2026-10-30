import QtQuick
import QtQuick.Effects

Item {
    id: root

    property real strength: 1

    property bool _placed: false
    readonly property bool _inWindow: root.Window.window !== null
    on_InWindowChanged: if (root._inWindow) root._placed = true
    Component.onCompleted: if (root._inWindow) root._placed = true

    layer.enabled: root._placed
    layer.smooth: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0.03, 0.015, 0.02, 0.62 * root.strength)
        shadowBlur: 0.75
        shadowVerticalOffset: 2
        shadowScale: 1.0
        autoPaddingEnabled: true
    }
}
