import QtQuick

Item {
    id: view

    readonly property bool isStageView: true
    property var stack: ["front"]
    readonly property string current: view.stack[view.stack.length - 1]

    function push(stageId) {
        if (stageId && stageId !== view.current)
            view.stack = view.stack.concat([stageId])
    }

    function back() {
        if (view.stack.length > 1)
            view.stack = view.stack.slice(0, -1)
    }

    function home() {
        view.stack = ["front"]
    }

    function depthOf(stageId) {
        if (stageId === view.current)
            return 0
        return view.stack.indexOf(stageId) >= 0 ? -1 : 1
    }

    anchors.fill: parent
    clip: true

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.BackButton
        onClicked: view.back()
    }
}
