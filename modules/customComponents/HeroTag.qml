import QtQuick
import qs.modules.settings

QtObject {
    id: tag

    property string key: ""
    property Item item: null
    property Item owner: null
    property bool target: false
    property Item clip: null
    property real clipRadius: 0

    Component.onCompleted: GlobalStates.registerHero(tag)
    Component.onDestruction: GlobalStates.unregisterHero(tag)
}
