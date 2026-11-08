import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

RowLayout {
    id: root

    required property var wx
    property string trailing: ""
    property string trailingIcon: ""
    property bool showBadge: true

    spacing: 6

    WeatherTileBadge {
        visible: root.showBadge
        wx: root.wx
        Layout.preferredWidth: root.height
        Layout.preferredHeight: root.height
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 16
        color: Colors.secondaryContainer

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 8

            CustomText {
                content: root.wx.ready ? root.wx.now + "°" : "--°"
                size: root.height >= 40 ? 16 : 14
                weight: 700
                customColor: Colors.secondaryContainerText
            }

            CustomText {
                Layout.fillWidth: true
                content: root.wx.ready ? root.wx.desc : "Loading"
                size: 13
                weight: 400
                elide: Text.ElideRight
                customColor: Qt.alpha(Colors.secondaryContainerText, 0.75)
            }

            MaterialIconSymbol {
                visible: root.trailingIcon !== ""
                content: root.trailingIcon
                iconSize: 14
                fill: 1
                customColor: Qt.alpha(Colors.secondaryContainerText, 0.75)
            }

            CustomText {
                visible: root.trailing !== ""
                content: root.trailing
                size: 12
                weight: 500
                customColor: Qt.alpha(Colors.secondaryContainerText, 0.75)
            }
        }
    }
}
