import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true

    readonly property string style: BarLayout.opt(root.itemId, "style") ?? "display"
    readonly property bool use24: BarLayout.opt(root.itemId, "use24") === true
    readonly property bool showDate: BarLayout.opt(root.itemId, "showDate") !== false

    readonly property string hh: {
        const h = parseInt(ServiceClock.hour)
        if (root.use24)
            return String(h).padStart(2, "0")
        const m = h % 12
        return String(m === 0 ? 12 : m)
    }
    readonly property string timeText: root.hh + ":" + ServiceClock.minute
    readonly property string dowText: String(ServiceClock.day).slice(0, 3)
    readonly property string dayMonText: parseInt(ServiceClock.date) + " " + String(ServiceClock.month).slice(0, 3)
    readonly property string dateText: root.dowText + " " + root.dayMonText
    readonly property string mm: ServiceClock.minute
    readonly property int dateNum: parseInt(ServiceClock.date)
    readonly property string monShort: String(ServiceClock.month).slice(0, 3)
    readonly property string meridiem: parseInt(ServiceClock.hour) < 12 ? "AM" : "PM"
    readonly property string clockDigits: root.hh.padStart(2, "0") + root.mm
    readonly property string displayFamily: SettingsConfig.general.displayFont ?? "Titan One"

    readonly property bool live: BarLayout.opt(root.itemId, "live") === true
    readonly property bool dndOn: SettingsConfig.notifications?.doNotDisturb ?? false
    readonly property bool dndBadge: BarLayout.opt(root.itemId, "dndBadge") !== false && root.dndOn

    property string event: ""
    property string notifApp: ""
    property string notifText: ""
    property bool armed: false
    property int seenNotifs: ServiceNotification.allNotifications.length

    readonly property real faceWidth: faceRow.implicitWidth
    readonly property real islandWidth: island.implicitWidth
    readonly property bool islandUp: root.event !== "" && !root.vertical
    readonly property bool vertical: !!root.host && root.host.vertical === true
    readonly property bool verticalReady: true

    implicitWidth: root.islandUp ? root.islandWidth : root.faceWidth
    implicitHeight: root.vertical ? faceRow.implicitHeight + 6 : Appearance.size.clockHeight
    Behavior on implicitWidth {
        enabled: root.live
        SpatialAnim { speed: "fast" }
    }

    function show(kind, ms) {
        if (!root.live || !root.armed || root.vertical)
            return
        root.event = kind
        islandTimer.interval = ms
        islandTimer.restart()
    }

    Timer {
        interval: 3000
        running: true
        onTriggered: root.armed = true
    }

    Binding {
        target: GlobalStates
        property: "liveIsland"
        value: true
        when: root.live && root.host !== null && !root.host.bottomEdge && !root.vertical
    }

    Timer {
        id: islandTimer
        onTriggered: root.event = ""
    }

    Connections {
        target: ServicePipewire
        enabled: root.live
        function onVolumeChanged() { root.show("volume", 1600) }
        function onMutedChanged() { root.show("volume", 1600) }
    }

    Connections {
        target: ServiceUPower
        enabled: root.live
        function onIsChargingChanged() { root.show("charge", 2600) }
    }

    Connections {
        target: ServiceNotification
        function onAllNotificationsChanged() {
            const list = ServiceNotification.allNotifications
            const grew = list.length > root.seenNotifs
            root.seenNotifs = list.length
            if (!grew || !root.live || root.dndOn || ServiceNotification.muted)
                return
            const n = list[list.length - 1]
            root.notifApp = n?.appName || "Notification"
            root.notifText = n?.summary || n?.body || ""
            root.show("notif", 3600)
        }
    }

    Grid {
        id: faceRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        spacing: root.vertical ? 2 : 6
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        opacity: root.islandUp ? 0 : 1
        visible: opacity > 0.01
        Behavior on opacity { EffectsAnim { speed: "fast" } }

        MaterialIconSymbol {
            visible: root.dndBadge
            content: "bedtime"
            iconSize: 15
            customColor: Colors.secondary
        }

        Loader {
            id: face
            sourceComponent: {
                if (root.vertical)
                    return uprightComp
                switch (root.style) {
                case "inline": return inlineComp
                case "stack": return stackComp
                case "datefirst": return dateFirstComp
                case "twotone": return twoToneComp
                case "ampm": return ampmComp
                case "tab": return tabComp
                case "tiles": return tilesComp
                case "side": return sideComp
                case "mono": return monoComp
                case "long": return longComp
                }
                return displayComp
            }
        }
    }

    Component {
        id: uprightComp
        Column {
            spacing: -3

            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                content: root.hh.padStart(2, "0")
                size: 15
                weight: 800
                elide: Text.ElideNone
                font.features: { "tnum": 1 }
            }
            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                content: ServiceClock.minute
                size: 15
                weight: 800
                customColor: Colors.primary
                elide: Text.ElideNone
                font.features: { "tnum": 1 }
            }
        }
    }

    component Tile: Rectangle {
        property string ch: ""
        property bool minute: false
        width: 17
        height: 26
        radius: 6
        color: minute ? Colors.secondaryContainer : Colors.surfaceContainerHigh
        CustomText {
            anchors.centerIn: parent
            content: parent.ch
            size: 15
            weight: 700
            elide: Text.ElideNone
            customColor: parent.minute ? Colors.secondaryContainerText : Colors.surfaceText
        }
    }

    Component {
        id: inlineComp
        Row {
            spacing: 7
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: root.timeText
                size: 15
                weight: 700
                elide: Text.ElideNone
                font.features: { "tnum": 1 }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 4
                height: 4
                radius: 2
                color: Colors.primary
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: root.dowText + " " + root.dateNum
                size: 13
                weight: 500
                elide: Text.ElideNone
                customColor: Colors.surfaceVariantText
            }
        }
    }

    Component {
        id: stackComp
        Column {
            spacing: 0
            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                content: root.timeText
                size: 15
                weight: 700
                elide: Text.ElideNone
                font.features: { "tnum": 1 }
            }
            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                content: (root.dowText + " " + root.dateNum + " " + root.monShort).toUpperCase()
                size: 8
                weight: 600
                elide: Text.ElideNone
                font.letterSpacing: 1
                customColor: Colors.outline
            }
        }
    }

    Component {
        id: dateFirstComp
        Row {
            spacing: 9
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: root.dowText + " " + root.dateNum + " " + root.monShort
                size: 13
                weight: 500
                elide: Text.ElideNone
                customColor: Colors.surfaceVariantText
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: root.timeText
                size: 16
                weight: 700
                elide: Text.ElideNone
                font.features: { "tnum": 1 }
            }
        }
    }

    Component {
        id: twoToneComp
        Row {
            spacing: 6
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: root.hh
                size: 17
                weight: 800
                elide: Text.ElideNone
                font.features: { "tnum": 1 }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 15
                radius: 1
                color: Colors.outlineVariant
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: root.mm
                size: 17
                weight: 800
                elide: Text.ElideNone
                customColor: Colors.primary
                font.features: { "tnum": 1 }
            }
        }
    }

    Component {
        id: ampmComp
        Row {
            spacing: 3
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: root.timeText
                size: 22
                weight: 400
                family: root.displayFamily
                renderType: Text.QtRendering
                elide: Text.ElideNone
            }
            CustomText {
                anchors.top: parent.top
                anchors.topMargin: 2
                visible: !root.use24
                content: root.meridiem
                size: 8
                weight: 700
                elide: Text.ElideNone
                font.letterSpacing: 1
                customColor: Colors.primary
            }
        }
    }

    Component {
        id: tabComp
        Row {
            Rectangle {
                width: tabDay.implicitWidth + 20
                height: 28
                topLeftRadius: 14
                bottomLeftRadius: 14
                color: Colors.primaryContainer
                CustomText {
                    id: tabDay
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 1
                    content: root.dowText.toUpperCase()
                    size: 10
                    weight: 800
                    elide: Text.ElideNone
                    font.letterSpacing: 1
                    customColor: Colors.primaryContainerText
                }
            }
            Rectangle {
                width: tabTime.implicitWidth + 22
                height: 28
                topRightRadius: 14
                bottomRightRadius: 14
                color: Colors.surfaceContainerHigh
                CustomText {
                    id: tabTime
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -1
                    content: root.timeText
                    size: 14
                    weight: 700
                    elide: Text.ElideNone
                    font.features: { "tnum": 1 }
                }
            }
        }
    }

    Component {
        id: tilesComp
        Row {
            spacing: 3
            Tile { visible: root.clockDigits[0] !== "0"; ch: root.clockDigits[0] }
            Tile { ch: root.clockDigits[1] }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: 5
                spacing: 4
                Repeater {
                    model: 2
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 3
                        height: 3
                        radius: 1.5
                        color: Colors.outline
                    }
                }
            }
            Tile { ch: root.clockDigits[2]; minute: true }
            Tile { ch: root.clockDigits[3]; minute: true }
        }
    }

    Component {
        id: sideComp
        Row {
            spacing: 9
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: root.timeText
                size: 22
                weight: 400
                family: root.displayFamily
                renderType: Text.QtRendering
                elide: Text.ElideNone
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 22
                radius: 1
                color: Colors.outlineVariant
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                CustomText {
                    content: root.dowText.toUpperCase()
                    size: 9
                    weight: 700
                    elide: Text.ElideNone
                    font.letterSpacing: 1
                }
                CustomText {
                    content: (root.dateNum + " " + root.monShort).toUpperCase()
                    size: 9
                    weight: 600
                    elide: Text.ElideNone
                    font.letterSpacing: 1
                    customColor: Colors.outline
                }
            }
        }
    }

    Component {
        id: monoComp
        Row {
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: root.hh.padStart(2, "0") + ":" + root.mm
                size: 15
                weight: 700
                elide: Text.ElideNone
                font.features: { "tnum": 1 }
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: ":" + ServiceClock.seconds
                size: 15
                weight: 500
                elide: Text.ElideNone
                customColor: Colors.outline
                font.features: { "tnum": 1 }
            }
        }
    }

    Component {
        id: longComp
        Row {
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: ServiceClock.day + " " + root.dateNum + " " + ServiceClock.month + ", "
                size: 14
                weight: 500
                elide: Text.ElideNone
                customColor: Colors.surfaceVariantText
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: root.timeText
                size: 14
                weight: 700
                elide: Text.ElideNone
                customColor: Colors.primary
                font.features: { "tnum": 1 }
            }
        }
    }

    Component {
        id: displayComp
        Item {
            implicitWidth: clockText.implicitWidth
            implicitHeight: Appearance.size.clockHeight
            CustomClock {
                id: clockText
                use24: root.use24
            }
        }
    }

    Rectangle {
        id: island
        anchors.centerIn: parent
        implicitWidth: islandRow.implicitWidth + 28
        width: Math.min(implicitWidth, root.width)
        height: 30
        radius: 15
        clip: true
        opacity: root.islandUp ? 1 : 0
        visible: opacity > 0.01
        color: root.event === "charge" ? Colors.primaryContainer : Colors.surfaceContainerHigh
        Behavior on opacity { EffectsAnim { speed: "fast" } }
        Behavior on color { EffectsColorAnim {} }

        Row {
            id: islandRow
            anchors.centerIn: parent
            spacing: 8

            MaterialIconSymbol {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.event === "volume"
                content: ServicePipewire.muted ? "volume_off" : "volume_up"
                iconSize: 18
                customColor: Colors.primary
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.event === "volume"
                width: 110
                height: 6
                radius: 3
                color: Colors.surfaceContainerHighest

                Rectangle {
                    width: parent.width * (ServicePipewire.muted ? 0 : Math.max(0, Math.min(1, ServicePipewire.volume)))
                    height: parent.height
                    radius: 3
                    color: Colors.primary
                    Behavior on width { SpatialAnim { speed: "fast" } }
                }
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.event === "volume"
                width: Math.max(implicitWidth, 22)
                font.features: { "tnum": 1 }
                content: ServicePipewire.muted ? "0" : Math.round(ServicePipewire.volume * 100)
                size: 13
                weight: 600
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.event === "notif"
                width: 20
                height: 20
                radius: 10
                color: Colors.tertiaryContainer
                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: "notifications"
                    iconSize: 13
                    customColor: Colors.tertiaryContainerText
                }
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.event === "notif"
                content: root.notifApp
                size: 13
                weight: 700
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 120)
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.event === "notif" && root.notifText !== ""
                content: root.notifText
                size: 13
                weight: 400
                customColor: Colors.surfaceVariantText
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 240)
            }

            MaterialIconSymbol {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.event === "charge"
                content: ServiceUPower.isCharging ? "bolt" : "battery_android_full"
                iconSize: 18
                customColor: Colors.primaryContainerText
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.event === "charge"
                content: (ServiceUPower.isCharging ? "Charging · " : "On battery · ")
                         + Math.round(ServiceUPower.powerLevel * 100) + "%"
                size: 13
                weight: 600
                customColor: Colors.primaryContainerText
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.islandUp
            onClicked: root.event = ""
        }
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered && root.host)
                root.host.hoverOpen("calendar", root)
        }
    }
}
