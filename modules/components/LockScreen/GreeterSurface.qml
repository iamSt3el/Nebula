pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.settings

Item {
    id: root

    required property var context
    property bool ready: false
    property real uiOpacity: 1
    focus: true

    Component.onCompleted: {
        SettingsConfig.greeterMode = true
        LockSession.identity = root.context.currentUser
        root.ready = true
    }

    readonly property var _cfg: SettingsConfig.greeter ?? ({})
    readonly property string variantStyle: LockCatalog.normalize(root._cfg.layout)

    function focusInput() {
        const f = layoutLoader.authField
        if (f && f.input)
            f.input.forceActiveFocus()
    }

    Keys.onPressed: event => root.focusInput()

    Item {
        id: backdropWrap
        anchors.fill: parent
        opacity: 0

        NumberAnimation on opacity {
            from: 0; to: 1; running: true
            duration: 480; easing.type: Easing.OutQuad
        }

        LockBackdrop {
            id: backdrop
            anchors.fill: parent
            style: LockCatalog.backdropFor(root.variantStyle)
        }
    }

    LockLayoutLoader {
        id: layoutLoader
        anchors.fill: parent
        active: root.ready
        visible: active
        variant: root.variantStyle
        opacity: root.uiOpacity
        context: root.context
        greeter: true
        onLoaded: Qt.callLater(root.focusInput)
    }

    Timer {
        interval: 700; running: true
        onTriggered: root.focusInput()
    }
}
