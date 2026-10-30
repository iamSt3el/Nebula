import QtQuick

Loader {
    id: lazy

    property string stageId: ""
    default property Component page
    readonly property bool isStageLazy: true
    readonly property Item view: lazy.parent && lazy.parent.isStageView ? lazy.parent : null
    readonly property bool wanted: lazy.view !== null && lazy.view.stack.indexOf(lazy.stageId) >= 0
    property bool keep: false

    anchors.fill: parent
    active: lazy.wanted || lazy.keep
    sourceComponent: lazy.page

    onWantedChanged: if (lazy.wanted) lazy.keep = true

    Connections {
        target: lazy.item
        function onVisibleChanged() {
            if (!lazy.wanted && lazy.item && !lazy.item.visible)
                lazy.keep = false
        }
    }
}
