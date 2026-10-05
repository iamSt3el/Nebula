import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true
    readonly property bool iconSizable: true
    readonly property real box: BarLayout.boxFor(root.itemId, root.host)
    readonly property real iconPx: BarLayout.iconPxFor(root.itemId, root.box, 16)
    readonly property real plate: BarLayout.platePxFor(root.box, root.iconPx, 16, 26)
    readonly property bool clickable: SettingsConfig.general.barWeatherPanel ?? true
    readonly property bool vertical: !!root.host && root.host.vertical === true
    readonly property bool verticalReady: true

    implicitWidth: zone.width
    implicitHeight: zone.height

    Rectangle {
        id: zone
        anchors.verticalCenter: parent.verticalCenter
        width: root.vertical ? Math.max(root.plate, weatherRow.implicitWidth + 8)
            : weatherRow.implicitWidth + BarLayout.scaleFor(root.iconPx, 16, 18, 8)
        height: root.vertical ? weatherRow.implicitHeight + 10 : root.plate
        radius: Math.min(width, height) / 2
        color: weatherHov.containsMouse ? Colors.primaryContainer : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }

        GridLayout {
            id: weatherRow
            anchors.centerIn: parent
            columns: root.vertical ? 1 : -1
            rowSpacing: 2
            columnSpacing: BarLayout.scaleFor(root.iconPx, 16, 7, 4)

            Image {
                visible: BarLayout.opt(root.itemId, "showIcon") !== false
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: root.iconPx
                Layout.preferredHeight: root.iconPx
                sourceSize.width: root.iconPx
                sourceSize.height: root.iconPx
                source: IconUtil.getSystemIcon(ServiceWeather.weatherIconPath.svg)
            }

            CustomText {
                visible: !root.vertical
                Layout.alignment: Qt.AlignHCenter
                content: ServiceWeather.temperature
                size: BarLayout.scaleFor(root.iconPx, 16, root.vertical ? 11 : 13, 8); weight: 700
                customColor: weatherHov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                Behavior on customColor { ColorAnimation { duration: 150 } }
            }
        }

        MouseArea {
            id: weatherHov
            anchors.fill: parent
            hoverEnabled: root.clickable
            cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (root.clickable && root.host) root.host.openPanel("weather", root)
        }
    }
}
