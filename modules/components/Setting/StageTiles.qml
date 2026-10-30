import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

GridLayout {
    id: grid

    property var tiles: []
    signal tileClicked(var tile)

    function stageView() {
        let p = grid.parent
        while (p && !p.isStageView)
            p = p.parent
        return p
    }

    Layout.fillWidth: true
    columns: 2
    columnSpacing: 8
    rowSpacing: 8

    Repeater {
        model: grid.tiles

        Rectangle {
            id: tile

            required property var modelData
            readonly property bool tonal: tile.modelData.tonal === true

            Layout.fillWidth: true
            Layout.preferredWidth: 1
            implicitHeight: 104
            radius: 24
            color: tile.tonal ? Colors.primaryContainer : Colors.surfaceContainerHigh

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 2

                MaterialIconSymbol {
                    content: tile.modelData.icon ?? ""
                    iconSize: 26
                    fill: 1
                    customColor: tile.tonal ? Colors.primaryContainerText : Colors.primary
                }

                Item { Layout.fillHeight: true }

                CustomText {
                    Layout.fillWidth: true
                    content: tile.modelData.label ?? ""
                    size: 15
                    weight: 600
                    elide: Text.ElideRight
                    customColor: tile.tonal ? Colors.primaryContainerText : Colors.surfaceText
                }

                CustomText {
                    Layout.fillWidth: true
                    visible: (tile.modelData.subtitle ?? "") !== ""
                    content: tile.modelData.subtitle ?? ""
                    size: 12
                    elide: Text.ElideRight
                    customColor: tile.tonal ? Colors.primaryContainerText : Colors.outline
                }
            }

            RippleEffect {
                anchors.fill: parent
                radius: tile.radius
                onClicked: {
                    const target = tile.modelData.target ?? ""
                    if (target !== "") {
                        const v = grid.stageView()
                        if (v)
                            v.push(target)
                    }
                    grid.tileClicked(tile.modelData)
                }
            }
        }
    }
}
