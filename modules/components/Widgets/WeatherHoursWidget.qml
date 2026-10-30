import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "weatherHours"
    tile: Qt.size(WidgetSizes.span(4), WidgetSizes.span(2))
    resizable: true
    minSpan: Qt.size(3, 2)
    maxSpan: Qt.size(6, 2)
    defaultPos: Qt.point(365, 165)

    readonly property bool metric: SettingsConfig.weather.useMetric ?? true
    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"
    readonly property real pad: 16
    readonly property real gap: 6
    readonly property real nowWidth: 140

    function minutesOf(str) {
        const m = String(str ?? "").match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i)
        if (!m) return -1
        let h = parseInt(m[1])
        if (m[3].toUpperCase() === "PM" && h !== 12) h += 12
        if (m[3].toUpperCase() === "AM" && h === 12) h = 0
        return h * 60 + parseInt(m[2])
    }

    function hourOf(label) {
        const m = String(label).match(/(\d{1,2})\s*(AM|PM)/i)
        if (!m) return -1
        let h = parseInt(m[1]) % 12
        if (m[2].toUpperCase() === "PM") h += 12
        return h
    }

    readonly property int riseMin: root.minutesOf(ServiceWeather.astronomy?.sunrise)
    readonly property int setMin: root.minutesOf(ServiceWeather.astronomy?.sunset)

    function nightAt(hour) {
        if (root.riseMin < 0 || root.setMin < 0) return hour < 6 || hour >= 18
        const m = hour * 60
        return m < root.riseMin || m >= root.setMin
    }

    readonly property var slots: {
        if (root.preview) return [
            { time: "Now", temp: "30°", desc: "Sunny", icon: "clear_day", rain: 0 },
            { time: "12 PM", temp: "31°", icon: "clear_day", rain: 19 },
            { time: "3 PM", temp: "30°", icon: "rainy", rain: 52 },
            { time: "6 PM", temp: "23°", icon: "clear_night", rain: 26 },
            { time: "9 PM", temp: "22°", icon: "clear_night", rain: 0 },
            { time: "12 AM", temp: "22°", icon: "clear_night", rain: 0 }
        ]
        const list = ServiceWeather.todayHourly ?? []
        return list.map((h, i) => {
            const hour = i === 0 ? new Date().getHours() : root.hourOf(h.time)
            const rain = parseInt(h.chanceofrain ?? 0, 10) || 0
            return {
                time: h.time,
                temp: root.metric ? h.tempC : h.tempF,
                desc: h.description,
                rain: rain,
                icon: rain >= 40 ? "rainy" : ServiceWeather.getWeatherIcon(h.weatherCode, root.nightAt(hour)).icon
            }
        })
    }
    readonly property var current: root.slots.length > 0 ? root.slots[0] : null
    readonly property var later: root.slots.slice(1)

    readonly property real laterRoom: root.width - root.pad * 2 - root.nowWidth
    readonly property var widths: {
        const out = []
        let w = 76
        let used = 0
        for (let i = 0; i < root.later.length; i++) {
            const next = Math.max(22, w)
            if (used + root.gap + next > root.laterRoom + 0.5) break
            out.push(next)
            used += root.gap + next
            w = w * 0.82
        }
        if (out.length > 0) {
            const spare = root.laterRoom - used
            const total = out.reduce((a, b) => a + b, 0)
            for (let i = 0; i < out.length; i++) out[i] += spare * out[i] / total
        }
        return out
    }

    WidgetCard {
        anchors.fill: parent

        RowLayout {
            anchors.fill: parent
            anchors.margins: root.pad
            spacing: root.gap
            visible: !!root.current

            Rectangle {
                Layout.preferredWidth: root.nowWidth
                Layout.fillHeight: true
                radius: 18
                color: Colors.tertiaryContainer

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 0
                    CustomText {
                        content: "Now"
                        size: 12
                        weight: 800
                        customColor: Colors.tertiaryContainerText
                    }
                    Item { Layout.fillHeight: true }
                    CustomText {
                        content: root.current ? root.current.temp : ""
                        family: root.display
                        size: 44
                        weight: 400
                        customColor: Colors.tertiaryContainerText
                    }
                    CustomText {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        content: root.current ? (root.current.desc ?? "") : ""
                        size: 13
                        weight: 700
                        elide: Text.ElideRight
                        customColor: Colors.tertiaryContainerText
                    }
                }
            }

            Repeater {
                model: root.widths.length
                delegate: Rectangle {
                    id: hourCard
                    required property int index
                    readonly property var slot: root.later[hourCard.index]
                    readonly property bool roomy: width >= 48
                    Layout.preferredWidth: root.widths[hourCard.index] ?? 0
                    Layout.fillHeight: true
                    radius: 18
                    color: Colors.surfaceContainerHigh

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: 16
                        anchors.bottomMargin: 16
                        spacing: 0
                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            content: hourCard.slot ? hourCard.slot.time : ""
                            size: 12
                            weight: 600
                            opacity: hourCard.roomy ? 1 : 0
                            customColor: Colors.surfaceVariantText
                        }
                        Item { Layout.fillHeight: true }
                        MaterialIconSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            content: hourCard.slot ? hourCard.slot.icon : ""
                            iconSize: 22
                            opacity: hourCard.width >= 34 ? 1 : 0
                            customColor: hourCard.slot && hourCard.slot.rain >= 40 ? Colors.tertiary : Colors.primary
                        }
                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 8
                            content: hourCard.slot ? hourCard.slot.temp : ""
                            size: hourCard.width >= 34 ? 15 : 12
                            weight: 800
                        }
                    }
                }
            }
        }

        CustomText {
            anchors.centerIn: parent
            visible: !root.current
            content: ServiceWeather.hasError ? "No weather" : "Loading…"
            size: 13
            weight: 600
            customColor: Colors.outline
        }
    }
}
