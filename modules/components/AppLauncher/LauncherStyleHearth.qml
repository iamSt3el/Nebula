import Quickshell
import Quickshell.Services.UPower
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root

    required property Item launcher
    readonly property Item appView: nav

    readonly property string serif: "Noto Serif Display"
    readonly property int heroH: Math.round(Math.max(150, Math.min(240, root.height * 0.32)))
    readonly property bool resting: root.launcher.isApps && !root.launcher.searching
    readonly property var recentApps: {
        ServiceApps.usage
        const r = ServiceApps.recent(5)
        return r.length > 0 ? r : root.launcher.mostUsed(5)
    }
    readonly property int r: root.resting && root.height >= 520 ? root.recentApps.length : 0

    readonly property string userName: {
        const u = Quickshell.env("USER") ?? ""
        return u.length > 0 ? u : "friend"
    }
    readonly property string greeting: {
        ServiceClock.minute
        const h = new Date().getHours()
        if (h < 5) return "Still up, " + root.userName + "?"
        if (h < 12) return "Good morning, " + root.userName
        if (h < 17) return "Good afternoon, " + root.userName
        if (h < 22) return "Good evening, " + root.userName
        return "Cosy night, " + root.userName
    }
    readonly property string dateLine: {
        ServiceClock.minute
        return Qt.formatDateTime(new Date(), "dddd, d MMMM")
    }

    onRChanged: nav.sync()
    Component.onCompleted: nav.sync()

    function reset() {
        nav.activeIndex = 0
        grid.positionViewAtBeginning()
    }

    Item {
        id: nav
        property int activeIndex: 0
        readonly property int navCount: root.r + grid.count
        readonly property int count: nav.navCount
        readonly property int columns: 1

        onActiveIndexChanged: nav.sync()

        function sync() {
            const g = nav.activeIndex - root.r
            if (grid.activeIndex !== g) grid.activeIndex = g
        }

        function activateIndex(i) {
            if (i < root.r) root.launcher.launch(root.recentApps[i])
            else grid.activateIndex(i - root.r)
        }

        function reveal(i) {
            if (i >= root.r) grid.positionViewAtIndex(i - root.r, GridView.Contain)
        }

        function navigate(key) {
            const i = nav.activeIndex
            const cols = grid.columns
            let next = i
            if (i < root.r) {
                if (key === Qt.Key_Left) next = Math.max(0, i - 1)
                else if (key === Qt.Key_Right) next = Math.min(root.r - 1, i + 1)
                else if (key === Qt.Key_Down) next = grid.count > 0 ? root.r + Math.min(i, cols - 1, grid.count - 1) : i
                else if (key !== Qt.Key_Up) return false
            } else {
                const g = i - root.r
                if (key === Qt.Key_Left) next = root.r + Math.max(0, g - 1)
                else if (key === Qt.Key_Right) next = root.r + Math.min(grid.count - 1, g + 1)
                else if (key === Qt.Key_Up) next = g - cols >= 0 ? i - cols : (root.r > 0 ? Math.min(g, root.r - 1) : i)
                else if (key === Qt.Key_Down) next = g + cols < grid.count ? i + cols : i
                else return false
            }
            nav.activeIndex = next
            nav.reveal(next)
            return true
        }
    }

    Connections {
        target: grid
        function onActiveIndexChanged() {
            if (grid.activeIndex >= 0 && nav.activeIndex !== root.r + grid.activeIndex)
                nav.activeIndex = root.r + grid.activeIndex
        }
    }

    Connections {
        target: root.launcher
        function onFilteredAppsChanged() {
            nav.sync()
            grid.positionViewAtBeginning()
        }
    }

    ClippingRectangle {
        id: hero
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.heroH
        topLeftRadius: root.launcher.innerCorner("tl")
        topRightRadius: root.launcher.innerCorner("tr")
        bottomLeftRadius: root.launcher.innerCorner("tl")
        bottomRightRadius: root.launcher.innerCorner("tr")
        color: Colors.surfaceContainerHigh

        Image {
            anchors.fill: parent
            source: WallpaperTheme.wallpaperScreen
            sourceSize.width: 1280
            sourceSize.height: 720
            fillMode: Image.PreserveAspectCrop
            verticalAlignment: Image.AlignVCenter
            asynchronous: true
            cache: true
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(Settings.layoutColor, 0.05) }
                GradientStop { position: 0.45; color: Qt.alpha(Settings.layoutColor, 0.25) }
                GradientStop { position: 1.0; color: Settings.layoutColor }
            }
        }

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.bottomMargin: 42
            spacing: 8

            CustomText {
                Layout.fillWidth: true
                content: root.greeting
                family: root.serif
                size: root.width > 520 ? 34 : 26
                weight: 600
                elide: Text.ElideRight
                customColor: Colors.surfaceText
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8

                CustomText {
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                    content: root.dateLine
                    size: 13
                    weight: 500
                    customColor: Colors.surfaceText
                }

                HeroChip {
                    visible: Features.weather && ServiceWeather.currentCondition !== null
                    icon: Features.weather ? ServiceWeather.getWeatherIcon(ServiceWeather.weatherCode).icon : ""
                    label: !Features.weather ? "" : ServiceWeather.temperature + " " + ServiceWeather.description.toLowerCase().trim()
                        + (ServiceWeather.cityName !== "Unknown" ? " · " + ServiceWeather.cityName : "")
                }

                HeroChip {
                    visible: UPower.displayDevice?.isLaptopBattery ?? false
                    icon: ServiceUPower.isCharging ? "battery_charging_full"
                        : "battery_" + Math.min(6, Math.floor(ServiceUPower.powerLevel * 7)) + "_bar"
                    label: Math.round(ServiceUPower.powerLevel * 100) + "%"
                }
            }
        }
    }

    LauncherSearch {
        id: search
        launcher: root.launcher
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        y: root.heroH - height / 2
        height: 52
        radius: 26
        color: Colors.surfaceContainerHighest
        placeholder: root.width > 460 ? "What are we opening " + (new Date().getHours() >= 17 || new Date().getHours() < 5 ? "tonight?" : "today?") : ""
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: search.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: 14
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 10

        LauncherModeArea {
            launcher: root.launcher
            visible: !root.launcher.isApps
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        SectionLabel {
            visible: root.r > 0
            label: "Pick up where you left off"
        }

        Row {
            id: recentRow
            visible: root.r > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 108
            spacing: 10
            readonly property real cardW: (recentRow.width - (root.r - 1) * recentRow.spacing) / Math.max(1, root.r)

            Repeater {
                model: root.r > 0 ? root.recentApps.slice(0, root.r) : []
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool active: nav.activeIndex === card.index

                    width: recentRow.cardW
                    height: recentRow.height
                    radius: 22
                    color: card.active ? Colors.primaryContainer
                        : cardArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                    Behavior on color { EffectsColorAnim {} }

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 4

                        LauncherIcon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.bottomMargin: 2
                            app: card.modelData
                            size: 42
                        }
                        CustomText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            content: card.modelData?.name ?? ""
                            size: 12
                            weight: 600
                            elide: Text.ElideRight
                            customColor: card.active ? Colors.primaryContainerText : Colors.surfaceText
                        }
                        CustomText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            content: root.launcher.timeAgo(card.modelData) || "Pinned"
                            size: 10
                            elide: Text.ElideRight
                            customColor: card.active ? Qt.alpha(Colors.primaryContainerText, 0.75) : Colors.outline
                        }
                    }

                    MouseArea {
                        id: cardArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: nav.activeIndex = card.index
                        onClicked: event => {
                            if (event.button === Qt.RightButton)
                                root.launcher.openMenu(cardArea, event.x, event.y, card.modelData)
                            else
                                root.launcher.launch(card.modelData)
                        }
                    }
                }
            }
        }

        SectionLabel {
            visible: root.launcher.isApps
            label: root.launcher.searching
                ? (root.launcher.filteredApps.length === 1 ? "1 match" : root.launcher.filteredApps.length + " matches")
                : "Everything else"
            detail: root.launcher.searching ? "" : (ServiceLauncher.sortMode === "used" ? "most used" : "A–Z")
        }

        LauncherGrid {
            id: grid
            visible: root.launcher.isApps
            launcher: root.launcher
            Layout.fillWidth: true
            Layout.fillHeight: true
            apps: root.r > 0 ? root.launcher.filteredApps.filter(a => root.recentApps.indexOf(a) < 0) : root.launcher.filteredApps
            iconSize: root.launcher.searching ? ServiceLauncher.iconSize + 12 : ServiceLauncher.iconSize + 2
            minCell: grid.iconSize + (root.launcher.searching ? 58 : 50)
            plate: "none"
            labelSize: 11
            opacity: root.launcher.searching ? 1 : 0.86
            Behavior on opacity { EffectsAnim {} }
        }
    }

    component SectionLabel: RowLayout {
        property string label: ""
        property string detail: ""
        Layout.fillWidth: true
        Layout.leftMargin: 10
        spacing: 8

        CustomText {
            content: parent.label.toUpperCase()
            size: 11
            weight: 600
            font.letterSpacing: 1.2
            customColor: Colors.primary
        }
        CustomText {
            visible: parent.detail !== ""
            content: parent.detail
            size: 11
            customColor: Colors.outline
        }
        Item { Layout.fillWidth: true }
    }

    component HeroChip: Rectangle {
        id: chip
        property string icon: ""
        property string label: ""
        height: 26
        width: chipRow.implicitWidth + 20
        radius: 13
        color: Qt.alpha(Colors.surfaceContainerHighest, 0.82)

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5

            MaterialIconSymbol {
                anchors.verticalCenter: parent.verticalCenter
                content: chip.icon
                iconSize: 15
                customColor: Colors.primary
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: chip.label
                size: 12
                customColor: Colors.surfaceText
            }
        }
    }
}
