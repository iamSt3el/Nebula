import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "yearAgo"
    tile: WidgetSizes.tall
    defaultPos: Qt.point(145, 385)

    readonly property var pick: root.preview ? null : ServicePersonal.photos.pick
    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"
    readonly property string when: {
        if (root.preview) return "22 Sep 2025"
        if (!root.pick) return ""
        const p = root.pick.date.split("-")
        return Qt.formatDate(new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2])), "d MMM yyyy")
    }
    readonly property int count: root.preview ? 5 : (root.pick ? root.pick.count : 0)

    WidgetCard {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            ClippingRectangle {
                id: frame
                Layout.fillWidth: true
                Layout.fillHeight: true
                topLeftRadius: frame.width / 2
                topRightRadius: frame.width / 2
                bottomLeftRadius: WidgetSizes.radius - 10
                bottomRightRadius: WidgetSizes.radius - 10
                color: Colors.surfaceContainerHigh

                Image {
                    anchors.fill: parent
                    source: root.pick ? "file://" + root.pick.path : (root.preview ? WallpaperTheme.wallpaper : "")
                    sourceSize.width: 480
                    sourceSize.height: 480
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    visible: !root.preview && !root.pick
                    content: "photo_library"
                    iconSize: 34
                    customColor: Colors.outline
                }

                Rectangle {
                    visible: root.when !== ""
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    implicitWidth: dateText.implicitWidth + 20
                    implicitHeight: 24
                    radius: 12
                    color: WidgetSizes.cardColor

                    CustomText {
                        id: dateText
                        anchors.centerIn: parent
                        content: root.when
                        size: 11
                        weight: 700
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.preview && !!root.pick
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ServicePersonal.openFile(root.pick.path)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                Layout.bottomMargin: 6
                spacing: 2

                CustomText {
                    content: "A year ago"
                    family: root.display
                    size: 22
                    weight: 400
                }
                CustomText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    size: 12
                    weight: 600
                    customColor: Colors.surfaceVariantText
                    content: root.preview || root.pick
                        ? (root.count === 1 ? "1 screenshot" : root.count + " screenshots")
                        : "Nothing from this week last year"
                }
                CustomText {
                    Layout.fillWidth: true
                    visible: root.preview || !!root.pick
                    elide: Text.ElideRight
                    size: 11
                    weight: 500
                    customColor: Colors.outline
                    content: (root.preview ? 469 : (ServicePersonal.photos.since ?? 0)) + " since then"
                }
            }
        }
    }
}
