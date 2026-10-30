import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    signal closeRequested

    property bool inReader: false
    property bool filterWasOn: false
    property bool filterOwned: false

    readonly property bool wantFilter: root.inReader && GlobalStates.booksOpen && (ServiceBooks.cfg.eyeComfort ?? true)

    onWantFilterChanged: {
        if (root.wantFilter) {
            root.filterWasOn = ServiceReading.active
            root.filterOwned = !ServiceReading.active
            if (!ServiceReading.active)
                ServiceReading.setEnabled(true)
        } else if (root.filterOwned) {
            root.filterOwned = false
            if (ServiceReading.active)
                ServiceReading.setEnabled(false)
        }
    }

    Component.onDestruction: {
        if (root.filterOwned && ServiceReading.active)
            ServiceReading.setEnabled(false)
    }

    Connections {
        target: ServiceBooks
        function onBookReady() {
            root.inReader = true
        }
    }

    Connections {
        target: GlobalStates
        function onBooksOpenChanged() {
            if (GlobalStates.booksOpen)
                Qt.callLater(() => root.inReader ? reader.forceActiveFocus() : library.focusSearch())
        }
    }

    function leaveReader() {
        root.inReader = false
        reader.settingsOpen = false
        reader.contentsOpen = false
        library.forceActiveFocus()
    }

    Keys.onEscapePressed: root.closeRequested()

    BooksLibrary {
        id: library
        anchors.fill: parent
        opacity: root.inReader ? 0 : 1
        visible: opacity > 0.01
        enabled: !root.inReader
        Behavior on opacity { EffectsAnim {} }
        focus: !root.inReader
        onCloseRequested: root.closeRequested()
        Keys.onEscapePressed: root.closeRequested()
    }

    BooksReader {
        id: reader
        anchors.fill: parent
        opacity: root.inReader ? 1 : 0
        visible: opacity > 0.01
        enabled: root.inReader
        Behavior on opacity { EffectsAnim {} }
        onLeave: root.leaveReader()
    }
}
