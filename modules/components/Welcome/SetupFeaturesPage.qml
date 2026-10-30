import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

SetupScroll {
    id: scroll

    GridLayout {
        width: scroll.contentWidthAvail
        columns: 2
        columnSpacing: 24
        rowSpacing: 18

        Repeater {
            model: Features.groups

            ColumnLayout {
                id: group
                required property string modelData
                readonly property var items: Features.list.filter(f => f.group === group.modelData)

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 4

                    CustomText {
                        Layout.fillWidth: true
                        content: group.modelData.toUpperCase()
                        size: 12
                        weight: 700
                        font.letterSpacing: 0.6
                        customColor: Colors.primary
                    }

                    CustomText {
                        content: group.items.filter(f => Features.on(f.id)).length + " of " + group.items.length
                        size: 12
                        weight: 400
                        customColor: Colors.outline
                    }
                }

                Repeater {
                    model: group.items

                    SetupAppRow {
                        required property var modelData
                        required property int index

                        app: ({
                            name: modelData.name,
                            note: Features.missingTool(modelData.id) ? "Needs " + modelData.pkg : modelData.description,
                            replacesFile: false
                        })
                        tint: index
                        picked: Features.on(modelData.id)
                        onToggled: on => Features.set(modelData.id, on)
                    }
                }
            }
        }
    }
}
