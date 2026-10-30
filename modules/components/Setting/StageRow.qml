import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

CustomCard {
    id: row

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string value: ""
    property string target: ""
    property bool tonal: false
    property bool clickable: row.target !== ""
    property bool danger: false
    property string badge: ""
    property string tag: ""
    property string tagIcon: ""
    property color tagColor: Colors.secondaryContainer
    property color tagInk: Colors.secondaryContainerText
    property real tagWidth: 0
    default property alias trailing: trail.data
    property alias below: belowCol.data

    signal clicked()

    function stageView() {
        let p = row.parent
        while (p && !p.isStageView)
            p = p.parent
        return p
    }

    function activate() {
        if (row.target !== "") {
            const v = row.stageView()
            if (v)
                v.push(row.target)
        }
        row.clicked()
    }

    color: "transparent"

    ColumnLayout {
        id: content
        Layout.fillWidth: true
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumHeight: 40
            spacing: 14

            Rectangle {
                visible: row.icon !== ""
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 14
                color: row.tonal ? Colors.primary : Colors.surfaceContainerHighest

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: row.icon
                    iconSize: 21
                    fill: 1
                    customColor: row.tonal ? Colors.primaryText
                        : row.danger ? Colors.error : Colors.primary
                }

                Rectangle {
                    visible: row.badge !== ""
                    x: parent.width - width + 6
                    y: -6
                    width: 18
                    height: 18
                    radius: 9
                    color: Colors.primary
                    border.width: 2
                    border.color: Colors.surfaceContainerHigh

                    CustomText {
                        anchors.centerIn: parent
                        content: row.badge
                        size: 10
                        weight: 600
                        customColor: Colors.primaryText
                    }
                }
            }

            Rectangle {
                visible: row.tag !== ""
                Layout.preferredWidth: Math.max(row.tagWidth, tagRow.implicitWidth + 16)
                Layout.preferredHeight: 24
                radius: 12
                color: row.tagColor

                Row {
                    id: tagRow
                    anchors.centerIn: parent
                    spacing: 5

                    MaterialIconSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.tagIcon !== ""
                        content: row.tagIcon
                        iconSize: 14
                        fill: 1
                        customColor: row.tagInk
                    }

                    CustomText {
                        anchors.verticalCenter: parent.verticalCenter
                        content: row.tag
                        size: 11
                        weight: 600
                        customColor: row.tagInk
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                CustomText {
                    Layout.fillWidth: true
                    content: row.title
                    size: 14
                    elide: Text.ElideRight
                    customColor: row.danger ? Colors.error
                        : row.tonal ? Colors.primaryContainerText : Colors.surfaceText
                }

                CustomText {
                    Layout.fillWidth: true
                    visible: row.subtitle !== ""
                    content: row.subtitle
                    size: 12
                    wrapMode: Text.WordWrap
                    customColor: row.tonal ? Colors.primaryContainerText : Colors.outline
                }
            }

            CustomText {
                visible: row.value !== ""
                Layout.maximumWidth: 260
                content: row.value
                size: 13
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                customColor: row.tonal ? Colors.primaryContainerText : Colors.outline
            }

            RowLayout {
                id: trail
                spacing: 8
                visible: trail.children.length > 0
            }
        }

        ColumnLayout {
            id: belowCol
            Layout.fillWidth: true
            spacing: 8
            visible: belowCol.children.length > 0
        }
    }

    Rectangle {
        parent: row
        anchors.fill: parent
        z: -2
        color: row.tonal ? Colors.primaryContainer : Colors.surfaceContainerHigh
        topLeftRadius: row.topLeftRadius
        topRightRadius: row.topRightRadius
        bottomLeftRadius: row.bottomLeftRadius
        bottomRightRadius: row.bottomRightRadius
    }

    RippleEffect {
        parent: row
        anchors.fill: parent
        z: -1
        visible: row.clickable
        topLeftRadius: row.topLeftRadius
        topRightRadius: row.topRightRadius
        bottomLeftRadius: row.bottomLeftRadius
        bottomRightRadius: row.bottomRightRadius
        onClicked: row.activate()
    }
}
