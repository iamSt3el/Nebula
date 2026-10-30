import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    readonly property int onCount: Features.list.filter(f => Features.on(f.id)).length

    function subtitleOf(f) {
        if (Features.missingTool(f.id))
            return "Needs " + f.pkg + " — install it to use this"
        return f.description
    }

    StageView {
        StagePage {
            stageId: "front"

            StageNote {
                content: root.onCount + " of " + Features.list.length + " features on. A feature that is off never starts: "
                    + "no background work, and its bar items, widgets and panels are hidden but keep their place. "
                    + "Turning one off reloads the shell once you close settings."
            }

            Repeater {
                model: Features.groups

                ColumnLayout {
                    id: group
                    required property string modelData
                    Layout.fillWidth: true
                    spacing: 3

                    StageHeading { text: group.modelData }

                    Repeater {
                        model: Features.list.filter(f => f.group === group.modelData)

                        StageSwitchRow {
                            required property var modelData
                            icon: modelData.icon
                            title: modelData.name
                            subtitle: root.subtitleOf(modelData)
                            tonal: Features.on(modelData.id)
                            checked: Features.on(modelData.id)
                            onToggled: on => Features.set(modelData.id, on)
                        }
                    }
                }
            }
        }
    }
}
