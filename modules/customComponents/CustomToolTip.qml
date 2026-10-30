import QtQuick

Item {
    id: root

    property string content
    property string detail: ""
    property var popup: null
    property bool ready: false

    visible: false
    width: 0
    height: 0

    function arm() {
        if (root.popup || !root.visible)
            return
        const host = root.parent ?? root
        root.popup = popupComponent.createObject(host, { parent: host })
        readyTimer.start()
    }

    onVisibleChanged: root.arm()
    Component.onCompleted: root.arm()
    Component.onDestruction: if (root.popup) root.popup.destroy()

    Timer {
        id: readyTimer
        interval: 0
        onTriggered: root.ready = true
    }

    Component {
        id: popupComponent

        CustomToolTipPopup {
            content: root.content
            detail: root.detail
            visible: root.ready && root.visible
        }
    }
}
