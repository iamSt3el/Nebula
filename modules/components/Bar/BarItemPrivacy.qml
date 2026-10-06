import QtQuick
import qs.modules.utils
import qs.modules.customComponents

Rectangle {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: dots.active

    implicitWidth: dots.implicitWidth + root.implicitHeight - dots.iconPx
    implicitHeight: 24
    radius: height / 2
    color: Colors.surfaceContainer

    BarPrivacyDots {
        id: dots
        anchors.centerIn: parent
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
    }

    CustomToolTip {
        content: dots.tip
        visible: hov.containsMouse && dots.tip !== ""
    }
}
