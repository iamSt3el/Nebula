import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

WeatherTileHost {
    id: root
    configKey: "weatherTileMini"
    tile: Qt.size(WidgetSizes.span(2), WidgetSizes.span(1))
    defaultPos: Qt.point(1245, 385)

    readonly property real badgeS: height - pad * 2
    readonly property real colX: pad + badgeS + gap
    readonly property real colW: width - colX - pad
    readonly property real lineH: (height - pad * 2 - gap) / 2

    rows: [
        [pad, pad, badgeS, badgeS, badgeS / 2],
        [colX, pad + 4, colW, height - pad * 2 - 8]
    ]

    WeatherTileBadge {
        x: root.pad
        y: root.pad
        width: root.badgeS
        height: root.badgeS
        wx: root.wx
    }

    Rectangle {
        x: root.colX
        y: root.pad
        width: root.colW
        height: root.lineH
        radius: root.tileRadius
        color: Colors.secondaryContainer

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 6

            CustomText {
                content: root.wx.ready ? root.wx.now + "°" : "--°"
                size: 15
                weight: 700
                customColor: Colors.secondaryContainerText
            }
            CustomText {
                Layout.fillWidth: true
                content: root.wx.desc
                size: 12
                weight: 400
                elide: Text.ElideRight
                customColor: Qt.alpha(Colors.secondaryContainerText, 0.75)
            }
        }
    }

    RowLayout {
        x: root.colX
        y: root.pad + root.lineH + root.gap
        width: root.colW
        height: root.lineH
        spacing: root.gap

        Repeater {
            model: root.wx.hours.slice(1, 3)

            Rectangle {
                id: chip
                required property var modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: root.tileRadius
                color: Colors.surfaceContainerHigh

                Row {
                    anchors.centerIn: parent
                    spacing: 3

                    CustomText {
                        content: chip.modelData.h12
                        size: 11
                        weight: 500
                        customColor: Qt.alpha(Colors.surfaceText, 0.7)
                    }
                    CustomText {
                        content: chip.modelData.temp + "°"
                        size: 11
                        weight: 700
                    }
                }
            }
        }
    }
}
