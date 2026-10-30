pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property var closer: null
    property real room: 900
    property real fixedH: -1
    property string page: "home"

    readonly property DashActions actions: DashActions { closer: root.closer }
    readonly property bool passwordPrompt: sub.item ? (sub.item.passwordPrompt ?? false) : false

    readonly property real availH: root.fixedH > 0 ? Math.min(root.fixedH, root.room) : root.room
    property string mode: ""
    readonly property string wideStyle: SettingsConfig.general.dashWideStyle ?? "rail"
    readonly property real homeH: content.item ? content.item.implicitHeight : 600

    readonly property bool inPage: root.page !== "home"
    readonly property real pageW: 380
    readonly property real pageH: 600
    property real homeW: 0
    property real homeHt: 0

    implicitWidth: root.inPage ? root.pageW : 460
    implicitHeight: root.inPage ? root.pageH : root.homeH
    readonly property real maxContentH: root.fixedH > 0 || root.mode !== "sidebar" ? root.room : root.implicitHeight

    function settle() {
        if (root.inPage || root.width <= 0)
            return
        root.homeW = root.width
        root.homeHt = root.height
        root.mode = root.width >= 720 ? "wide" : root.availH < 640 ? "quick" : "sidebar"
    }

    onWidthChanged: Qt.callLater(root.settle)
    onHeightChanged: Qt.callLater(root.settle)
    onAvailHChanged: Qt.callLater(root.settle)
    onPageChanged: Qt.callLater(root.settle)

    Component.onCompleted: {
        ServiceDashData.retainSystem()
        ServiceEvents.retain()
        root.settle()
        root.remember()
    }
    onImplicitHeightChanged: root.remember()

    function remember() {
        if (root.page === "home" && content.item)
            GlobalStates.dashboardHeight = root.implicitHeight
    }
    Component.onDestruction: {
        ServiceDashData.releaseSystem()
        ServiceEvents.release()
    }

    Item {
        id: home
        x: Math.round((root.width - width) / 2)
        width: root.inPage && root.homeW > 0 ? root.homeW : root.width
        height: root.inPage && root.homeHt > 0 ? root.homeHt : root.height
        opacity: root.page === "home" ? 1 : 0
        visible: opacity > 0.01
        transform: Translate { x: root.page === "home" ? 0 : -40; Behavior on x { SpatialAnim {} } }
        Behavior on opacity { EffectsAnim {} }

        Loader {
            id: content
            anchors.fill: parent
            sourceComponent: root.mode === "wide" ? root.wideComp : root.mode === "quick" ? quickComp : root.mode === "sidebar" ? sidebarComp : null
        }
    }

    Loader {
        id: sub
        anchors.fill: parent
        active: root.page !== "home"
        opacity: active ? 1 : 0
        Behavior on opacity { EffectsAnim {} }
        transform: Translate { x: sub.active ? 0 : 40; Behavior on x { SpatialAnim {} } }
        sourceComponent: root.page === "wifi" ? wifiComp : root.page === "bluetooth" ? btComp
            : root.page === "reading" ? readingComp : null
    }

    Component {
        id: sidebarComp
        DashSidebar {
            actions: root.actions
            onOpened: key => root.page = key
        }
    }

    Component {
        id: quickComp
        DashQuick {
            actions: root.actions
            onOpened: key => root.page = key
        }
    }

    readonly property Component wideComp: root.wideStyle === "ribbon" ? ribbonComp
        : root.wideStyle === "instruments" ? instrumentsComp
        : root.wideStyle === "poster" ? posterComp
        : root.wideStyle === "stage" ? stageComp
        : root.wideStyle === "planner" ? plannerComp : railComp

    Component {
        id: railComp
        DashRail {
            actions: root.actions
            onOpened: key => root.page = key
        }
    }

    Component {
        id: ribbonComp
        DashRibbon {
            actions: root.actions
            onOpened: key => root.page = key
        }
    }

    Component {
        id: instrumentsComp
        DashInstruments {
            actions: root.actions
            onOpened: key => root.page = key
        }
    }

    Component {
        id: posterComp
        DashPoster {
            actions: root.actions
            onOpened: key => root.page = key
        }
    }

    Component {
        id: stageComp
        DashStage {
            actions: root.actions
            onOpened: key => root.page = key
        }
    }

    Component {
        id: plannerComp
        DashPlanner {
            actions: root.actions
            onOpened: key => root.page = key
        }
    }

    Component {
        id: wifiComp
        Wifi {
            showBack: true
            onBackClicked: root.page = "home"
        }
    }

    Component {
        id: btComp
        Bluetooth {
            showBack: true
            onBackClicked: root.page = "home"
        }
    }

    Component {
        id: readingComp
        DashReading {
            onBackClicked: root.page = "home"
        }
    }
}
