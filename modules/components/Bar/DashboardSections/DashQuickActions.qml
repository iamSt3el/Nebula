import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings

Rectangle{
    id: root
    property bool compact: false
    implicitHeight: root.compact ? 42 : 50
    color: Colors.surfaceContainer
    radius: 20

    ColumnLayout{
        anchors.fill: parent
        anchors.margins: root.compact ? 7 : 10
        spacing: root.compact ? 7 : 10


        RowLayout{
            Layout.fillWidth: true
            Layout.preferredHeight: root.compact ? 32 : 40
            spacing: 4
            Repeater{
                model: Settings.quickIcons
                delegate: Rectangle{
                    id: qBtn
                    required property int index
                    required property var modelData

                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    property bool active: {
                        if (index === 0) return !ServiceNetwork.wifiEnabled
                        if (index === 1) return ServiceNotification.muted
                        if (index === 2) return ServicePipewire.muted
                        if (index === 3) return ServicePipewire.micMuted
                        return false
                    }
                    property bool isFirst: index === 0
                    property bool isLast:  index === Settings.quickIcons.length - 1

                    color: active ? Colors.primary : Colors.surfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 150 } }

                    topLeftRadius:     (active || isFirst) ? height / 2 : 5
                    topRightRadius:    (active || isLast)  ? height / 2 : 5
                    bottomLeftRadius:  (active || isFirst) ? height / 2 : 5
                    bottomRightRadius: (active || isLast)  ? height / 2 : 5
                    Behavior on topLeftRadius     { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    Behavior on topRightRadius    { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    Behavior on bottomLeftRadius  { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    Behavior on bottomRightRadius { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: qBtn.active ? qBtn.modelData.iconActive : qBtn.modelData.icon
                        iconSize: 20
                        color: qBtn.active ? Colors.primaryText : Colors.surfaceText
                        Behavior on color { ColorAnimation { duration: 150 } }
                        layer.enabled: true
                        layer.smooth: true
                        scale: qRipple.pressed ? 0.82 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                    }

                    RippleEffect {
                        id: qRipple
                        anchors.fill: parent
                        topLeftRadius:     qBtn.topLeftRadius
                        topRightRadius:    qBtn.topRightRadius
                        bottomLeftRadius:  qBtn.bottomLeftRadius
                        bottomRightRadius: qBtn.bottomRightRadius
                        hoverColor: Qt.alpha(qBtn.active ? Colors.primaryText : Colors.primary, 0.10)
                        pressColor: Qt.alpha(qBtn.active ? Colors.primaryText : Colors.primary, 0.20)
                        onClicked: {
                            if      (qBtn.index === 0) ServiceNetwork.toggleWifi()
                            else if (qBtn.index === 1) ServiceNotification.toggleMute()
                            else if (qBtn.index === 2) ServicePipewire.toggleMute()
                            else if (qBtn.index === 3) ServicePipewire.toggleMicMute()
                        }
                    }
                }
            }
        }
    }
}

