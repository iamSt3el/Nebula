pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Setting
import "../../MatrialShapes/" as MaterialShapes

Item {
    id: root

    property real maxHeight: 720
    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"
    readonly property string mode: ServiceWiz.mode
    readonly property bool live: ServiceWiz.ready
    property bool showInfo: false
    property bool allScenes: false

    readonly property var modes: [
        { key: "white", icon: "wb_incandescent", label: "White" },
        { key: "colour", icon: "palette", label: "Colour" },
        { key: "scenes", icon: "auto_awesome", label: "Scenes" },
        { key: "theme", icon: "format_paint", label: "Theme" },
        { key: "music", icon: "music_note", label: "Music" }
    ]

    readonly property var sceneList: root.allScenes ? ServiceWiz.scenes
        : ServiceWiz.scenePicks.map(id => ServiceWiz.sceneById(id))

    readonly property real hue: Math.max(0, ServiceWiz.rgb.hsvHue)
    readonly property real sat: ServiceWiz.rgb.hsvSaturation
    readonly property string signalWord: ServiceWiz.rssi >= -55 ? "strong" : ServiceWiz.rssi >= -70 ? "good" : "weak"

    readonly property var hero: {
        if (!root.live)
            return { label: ServiceWiz.status === "notfound" ? "No light found" : "Searching",
                     sub: ServiceWiz.status === "notfound" ? "Check that it is powered and on Wi-Fi" : "Looking on your network", icon: "search" }
        if (!ServiceWiz.on)
            return { label: "Off", sub: "Use the switch to turn it on", icon: "light_off" }
        switch (root.mode) {
        case "colour":
            return { label: "Colour", sub: "Hue " + Math.round(root.hue * 360) + "°, saturation " + Math.round(root.sat * 100) + "%", icon: "palette" }
        case "scenes": {
            const s = ServiceWiz.scene
            return { label: s ? s.name : "Scene", sub: s && s.moving ? "Moving scene, speed " + ServiceWiz.speed + "%" : "Still scene", icon: "auto_awesome" }
        }
        case "theme":
            return { label: "Theme " + ServiceWiz.liveRole, sub: Qt.color(Colors[ServiceWiz.liveRole]).toString() + (ServiceWiz.boost ? ", boosted for the bulb" : ""), icon: "format_paint" }
        case "music":
            return { label: "Music sync", sub: root.styleName(ServiceWiz.musicStyle) + ", follows what's playing", icon: "graphic_eq" }
        }
        const k = ServiceWiz.temp
        return { label: k < 3200 ? "Warm white" : k < 4500 ? "Neutral white" : k < 6000 ? "Daylight" : "Cool white",
                 sub: k + " K", icon: "wb_incandescent" }
    }

    function styleName(s) {
        return s === "spectrum" ? "Spectrum" : s === "theme" ? "Theme beat" : "Pulse"
    }

    implicitWidth: 380
    implicitHeight: Math.min(root.maxHeight, col.implicitHeight + 24)

    SmoothFlickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 12
        contentWidth: width
        contentHeight: col.implicitHeight
        interactive: contentHeight > height
        fadeEdges: false
        ScrollBar.vertical: CustomScrollBar {}

        ColumnLayout {
            id: col
            width: flick.width
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                StageSwitchRow {
                    icon: "lightbulb"
                    title: "WiZ light"
                    subtitle: root.live ? ServiceWiz.ip + ", " + root.signalWord + " signal"
                        : ServiceWiz.status === "lost" ? "Lost the light, looking again"
                        : ServiceWiz.status === "notfound" ? "Not found on your network" : "Searching your network"
                    tonal: ServiceWiz.on && root.live
                    enabled: root.live
                    checked: ServiceWiz.on
                    onToggled: v => ServiceWiz.setPower(v)
                }

                StageRow {
                    visible: ServiceWiz.locked
                    icon: "lock"
                    danger: true
                    title: "The light is refusing changes"
                    subtitle: "In the WiZ app open Settings, Security, Allow local, and pick Allow all controls."
                }

                StageRow {
                    visible: !root.live && ServiceWiz.status !== "scanning"
                    icon: "search"
                    title: "Search again"
                    subtitle: "Looks at every address on your network"
                    clickable: true
                    onClicked: ServiceWiz.rescan()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                spacing: 16

                Item {
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 140

                    Shape {
                        anchors.centerIn: parent
                        width: 200
                        height: 200
                        opacity: ServiceWiz.on && root.live ? 1 : 0
                        Behavior on opacity { EffectsAnim {} }
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeWidth: 0
                            strokeColor: "transparent"
                            fillGradient: RadialGradient {
                                centerX: 100; centerY: 100; centerRadius: 100
                                focalX: 100; focalY: 100
                                GradientStop { position: 0.45; color: Qt.alpha(ServiceWiz.lightColor, 0.38) }
                                GradientStop { position: 1; color: Qt.alpha(ServiceWiz.lightColor, 0) }
                            }
                            PathAngleArc { centerX: 100; centerY: 100; radiusX: 100; radiusY: 100; startAngle: 0; sweepAngle: 360 }
                        }
                    }

                    MaterialShapes.ShapeCanvas {
                        anchors.fill: parent
                        roundedPolygon: "cookie12"
                        color: ServiceWiz.lightColor
                        Behavior on color { EffectsColorAnim {} }
                    }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: root.hero.icon
                        iconSize: 44
                        fill: 1
                        customColor: ServiceWiz.on && root.live ? Qt.alpha("#100e0d", 0.55) : Colors.surfaceVariantText
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        spacing: 2
                        CustomText {
                            Layout.alignment: Qt.AlignBaseline
                            content: ServiceWiz.on && root.live ? Math.round(ServiceWiz.dimming * 100) : "0"
                            family: root.displayFamily
                            size: 60
                            weight: 400
                        }
                        CustomText {
                            Layout.alignment: Qt.AlignBaseline
                            content: "%"
                            family: root.displayFamily
                            size: 24
                            weight: 400
                            customColor: Colors.outline
                        }
                    }
                    CustomText {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        content: root.hero.label
                        size: 15
                        weight: 500
                        elide: Text.ElideRight
                    }
                    CustomText {
                        Layout.fillWidth: true
                        content: root.hero.sub
                        size: 12
                        wrapMode: Text.WordWrap
                        customColor: Colors.outline
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                enabled: root.live
                opacity: root.live ? 1 : 0.45
                Behavior on opacity { EffectsAnim {} }

                M3Slider {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    icon: ServiceWiz.dimming > 0.66 ? "brightness_7" : ServiceWiz.dimming > 0.33 ? "brightness_6" : "brightness_5"
                    showStopIndicator: false
                    trackOuterCorner: 14
                    trackHeight: 40
                    handleHeight: 52
                    handleWidth: 4
                    pressedHandleWidth: 2
                    handleGap: 4
                    progress: ServiceWiz.on ? ServiceWiz.dimming : 0
                    onMoved: v => ServiceWiz.setBrightness(Math.max(0.01, v))
                }

                ExpressiveIconRow {
                    Layout.fillWidth: true
                    model: root.modes
                    labelActive: true
                    rowHeight: 44
                    activeCheck: i => !root.showInfo && ServiceWiz.on && root.modes[i].key === root.mode
                    onTriggered: i => {
                        root.showInfo = false
                        ServiceWiz.setMode(root.modes[i].key)
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    Layout.preferredHeight: item ? item.implicitHeight : 0
                    sourceComponent: root.showInfo ? infoComp
                        : root.mode === "colour" ? colourComp
                        : root.mode === "scenes" ? scenesComp
                        : root.mode === "theme" ? themeComp
                        : root.mode === "music" ? musicComp : whiteComp
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                M3ButtonGroup {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    fillWidth: true
                    iconSize: 16
                    textSize: 12
                    enabled: root.live
                    model: [{ value: 11, icon: "wb_incandescent", label: "Warm white" },
                            { value: 12, icon: "light_mode", label: "Daylight" },
                            { value: 0, icon: "bedtime", label: ServiceWiz.sleepLeft > 0 ? ServiceWiz.sleepLeft + " min" : "Sleep" }]
                    activeCheck: v => v === 0 ? ServiceWiz.sleepEnd > 0
                        : root.mode === "scenes" && ServiceWiz.sceneId === v && ServiceWiz.on
                    onSegmentClicked: v => {
                        if (v === 0)
                            ServiceWiz.cycleSleep()
                        else
                            ServiceWiz.setScene(v)
                    }
                }
                M3IconButton {
                    icon: root.showInfo ? "close" : "info"
                    tip: root.showInfo ? "Back to the light" : "Light details"
                    onClicked: root.showInfo = !root.showInfo
                }
            }
        }
    }

    Component {
        id: whiteComp
        ColumnLayout {
            spacing: 3
            StageSliderRow {
                icon: "thermostat"
                title: "Colour temperature"
                from: ServiceWiz.cctMin
                to: ServiceWiz.cctMax
                step: 50
                current: ServiceWiz.temp
                format: v => Math.round(v) + " K"
                onMoved: v => ServiceWiz.setTemp(v)
            }
            CustomCard {
                M3ButtonGroup {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    fillWidth: true
                    textSize: 12
                    model: [{ value: 2200, label: "Candle" }, { value: 2700, label: "Warm" },
                            { value: 4000, label: "Neutral" }, { value: 6500, label: "Daylight" }]
                    activeCheck: v => root.mode === "white" && Math.abs(ServiceWiz.temp - v) < 150
                    onSegmentClicked: v => ServiceWiz.setTemp(v)
                }
            }
        }
    }

    Component {
        id: colourComp
        ColumnLayout {
            spacing: 3
            StageSliderRow {
                icon: "palette"
                title: "Hue"
                from: 0
                to: 359
                current: root.hue * 360
                format: v => Math.round(v) + "°"
                onMoved: v => ServiceWiz.setColor(Qt.hsva(v / 360, Math.max(0.05, root.sat), 1, 1))
                onCommitted: ServiceWiz.rememberColor(ServiceWiz.rgb)
            }
            StageSliderRow {
                icon: "opacity"
                title: "Saturation"
                from: 5
                to: 100
                current: root.sat * 100
                format: v => Math.round(v) + "%"
                onMoved: v => ServiceWiz.setColor(Qt.hsva(root.hue, v / 100, 1, 1))
                onCommitted: ServiceWiz.rememberColor(ServiceWiz.rgb)
            }
            StageRow {
                icon: "history"
                title: "Recent"
                Repeater {
                    model: ServiceWiz.recent
                    delegate: Rectangle {
                        id: sw
                        required property var modelData
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 13
                        color: sw.modelData
                        border.width: Qt.colorEqual(sw.modelData, ServiceWiz.rgb) ? 2 : 0
                        border.color: Colors.surfaceText
                        RippleEffect {
                            anchors.fill: parent
                            radius: 13
                            onClicked: ServiceWiz.setColor(sw.modelData)
                        }
                    }
                }
                M3IconButton {
                    icon: "add"
                    tip: "Save this colour"
                    onClicked: ServiceWiz.rememberColor(ServiceWiz.rgb)
                }
            }
        }
    }

    Component {
        id: scenesComp
        ColumnLayout {
            spacing: 3
            CustomCard {
                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    rowSpacing: 6
                    columnSpacing: 6
                    Repeater {
                        model: root.sceneList
                        delegate: Rectangle {
                            id: st
                            required property var modelData
                            readonly property bool on: root.mode === "scenes" && ServiceWiz.sceneId === st.modelData.id && ServiceWiz.on
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 66
                            radius: st.on ? 20 : 14
                            color: st.on ? Colors.primaryContainer : Colors.surfaceContainerHighest
                            Behavior on radius { SpatialAnim { speed: "fast" } }
                            Behavior on color { EffectsColorAnim {} }

                            Column {
                                anchors.centerIn: parent
                                spacing: 5
                                Item {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 26
                                    height: 26
                                    MaterialShapes.ShapeCanvas {
                                        anchors.fill: parent
                                        roundedPolygon: st.modelData.shape
                                        color: st.modelData.a
                                    }
                                    Item {
                                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                        height: 13
                                        clip: true
                                        MaterialShapes.ShapeCanvas {
                                            y: -13
                                            width: 26
                                            height: 26
                                            roundedPolygon: st.modelData.shape
                                            color: st.modelData.b
                                        }
                                    }
                                }
                                CustomText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    content: st.modelData.name
                                    size: 11
                                    weight: st.on ? 600 : 400
                                    customColor: st.on ? Colors.primaryContainerText : Colors.surfaceText
                                }
                            }

                            RippleEffect {
                                anchors.fill: parent
                                radius: st.radius
                                onClicked: ServiceWiz.setScene(st.modelData.id)
                            }
                        }
                    }
                }
                M3Button {
                    Layout.fillWidth: true
                    variant: "tonal"
                    icon: root.allScenes ? "expand_less" : "expand_more"
                    label: root.allScenes ? "Show fewer" : "See all " + ServiceWiz.scenes.length + " scenes"
                    onClicked: root.allScenes = !root.allScenes
                }
            }
            StageSliderRow {
                visible: !!ServiceWiz.scene && ServiceWiz.scene.moving
                icon: "speed"
                title: "Speed"
                from: 10
                to: 200
                step: 10
                current: ServiceWiz.speed
                format: v => Math.round(v) + "%"
                onCommitted: v => {
                    ServiceWiz.setSpeed(v)
                    ServiceWiz.saveWiz({ speed: ServiceWiz.speed })
                }
            }
        }
    }

    Component {
        id: themeComp
        ColumnLayout {
            spacing: 3
            StageRow {
                icon: "format_paint"
                title: "Light follows"
                subtitle: Qt.color(Colors[ServiceWiz.liveRole]).toString() + " becomes " + ServiceWiz.themeColor.toString()
                Rectangle {
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 13
                    color: Colors[ServiceWiz.liveRole]
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12
                        height: 12
                        radius: 6
                        color: ServiceWiz.themeColor
                    }
                }
                below: M3ButtonGroup {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    fillWidth: true
                    textSize: 12
                    model: [{ value: "primary", label: "Primary" }, { value: "secondary", label: "Secondary" },
                            { value: "tertiary", label: "Tertiary" }, { value: "cycle", label: "Cycle", icon: "autorenew" }]
                    activeCheck: v => root.mode === "theme" && ServiceWiz.themeRole === v
                    onSegmentClicked: v => ServiceWiz.setThemeRole(v)
                }
            }
            StageSwitchRow {
                icon: "auto_fix_high"
                title: "Boost colour"
                subtitle: "Theme colours are soft and look almost white on a bulb"
                checked: ServiceWiz.boost
                onToggled: v => ServiceWiz.saveWiz({ boost: v })
            }
            StageSwitchRow {
                icon: "wallpaper"
                title: "Change with the wallpaper"
                subtitle: "Sends the new colour when the palette changes"
                checked: ServiceWiz.follow
                onToggled: v => ServiceWiz.saveWiz({ follow: v })
            }
        }
    }

    Component {
        id: musicComp
        ColumnLayout {
            spacing: 3
            CustomCard {
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 52
                    Row {
                        anchors.fill: parent
                        spacing: 3
                        Repeater {
                            model: 28
                            delegate: Rectangle {
                                id: bar
                                required property int index
                                readonly property var bins: ServiceCava.cavaData ?? []
                                readonly property real v: {
                                    const n = bar.bins.length
                                    if (n === 0)
                                        return 0
                                    const a = Math.floor(bar.index * n / 28), b = Math.max(a + 1, Math.floor((bar.index + 1) * n / 28))
                                    let s = 0
                                    for (let i = a; i < b; i++) s += bar.bins[i]
                                    return s / (b - a)
                                }
                                anchors.bottom: parent.bottom
                                width: (parent.width - 27 * 3) / 28
                                height: Math.max(4, Math.min(1, bar.v) * 52)
                                radius: 3
                                color: ServiceWiz.lightColor
                                opacity: 0.45 + Math.min(1, bar.v) * 0.55
                            }
                        }
                    }
                }
                M3ButtonGroup {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    fillWidth: true
                    textSize: 12
                    model: [{ value: "pulse", label: "Pulse" }, { value: "spectrum", label: "Spectrum" }, { value: "theme", label: "Theme beat" }]
                    activeCheck: v => v === ServiceWiz.musicStyle
                    onSegmentClicked: v => ServiceWiz.saveWiz({ musicStyle: v })
                }
            }
            StageSliderRow {
                icon: "tune"
                title: "Sensitivity"
                current: ServiceWiz.sensitivity
                format: v => Math.round(v * 100) + "%"
                onCommitted: v => ServiceWiz.saveWiz({ sensitivity: v })
            }
            StageInfoRow {
                title: "Listening to"
                value: ServicePipewire.sink?.description || "Default output"
            }
        }
    }

    Component {
        id: infoComp
        ColumnLayout {
            spacing: 3
            StageInfoRow { title: "Address"; value: ServiceWiz.ip || "—" }
            StageInfoRow { title: "Signal"; value: ServiceWiz.rssi !== 0 ? ServiceWiz.rssi + " dBm, " + root.signalWord : "—" }
            StageInfoRow { title: "MAC"; value: ServiceWiz.mac ? ServiceWiz.mac.match(/../g).join(":") : "—" }
            StageInfoRow { title: "Firmware"; value: ServiceWiz.firmware || "—" }
            StageInfoRow { title: "Module"; value: ServiceWiz.moduleName || "—" }
            StageInfoRow { title: "White range"; value: ServiceWiz.cctMin + "–" + ServiceWiz.cctMax + " K" }
            StageRow {
                icon: "search"
                title: "Search the network again"
                clickable: true
                onClicked: ServiceWiz.rescan()
            }
        }
    }
}
