import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

WidgetHost {
    id: root
    configKey: "weatherPoster"
    tile: WidgetSizes.tall
    defaultPos: Qt.point(145, 165)

    readonly property bool metric: SettingsConfig.weather.useMetric ?? true
    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"
    readonly property bool ready: root.preview || !!ServiceWeather.currentCondition
    readonly property var today: (ServiceWeather.forecastDays ?? [])[0] ?? null

    readonly property string temp: root.preview ? "30°" : ServiceWeather.temperature
    readonly property string condition: root.preview ? "Sunny" : ServiceWeather.description.trim()
    readonly property string range: {
        if (root.preview) return "31° / 20° · Chirawa"
        const hi = root.today ? (root.metric ? root.today.maxtempC : root.today.maxtempF) : ""
        const lo = root.today ? (root.metric ? root.today.mintempC : root.today.mintempF) : ""
        const city = ServiceWeather.cityName
        return (hi !== "" ? hi + "° / " + lo + "°" : "") + (city && city !== "Unknown" ? " · " + city : "")
    }

    readonly property string shapeName: {
        const code = root.preview ? "113" : ServiceWeather.weatherCode
        const night = !root.preview && ServiceWeather.isNightTime()
        if (code === "113") return night ? "cookie12" : "sunny"
        if (code === "116" || code === "119" || code === "122") return "cookie6"
        if (code === "200" || code === "386" || code === "389" || code === "392" || code === "395") return "burst"
        return "clover8"
    }

    WidgetCard {
        id: card
        anchors.fill: parent
        color: Colors.tertiaryContainer

        ClippingRectangle {
            anchors.fill: parent
            radius: card.radius
            color: "transparent"

            MaterialShapes.ShapeCanvas {
                x: card.width - width * 0.6
                y: -height * 0.4
                width: card.width * 0.9
                height: width
                roundedPolygon: ShapeLibrary.get(root.shapeName)
                color: Qt.alpha(Colors.tertiaryContainerText, 0.08)
            }
        }

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 20
            spacing: 0
            visible: root.ready

            CustomText {
                content: root.temp
                family: root.display
                size: 84
                weight: 400
                lineHeight: 0.9
                customColor: Colors.tertiaryContainerText
            }
            CustomText {
                Layout.fillWidth: true
                Layout.topMargin: 8
                content: root.condition
                size: 20
                weight: 800
                elide: Text.ElideRight
                customColor: Colors.tertiaryContainerText
            }
            CustomText {
                Layout.fillWidth: true
                Layout.topMargin: 2
                visible: root.range !== ""
                content: root.range
                size: 13
                weight: 600
                elide: Text.ElideRight
                customColor: Colors.tertiaryContainerText
            }
        }

        CustomText {
            anchors.centerIn: parent
            visible: !root.ready
            content: ServiceWeather.hasError ? "No weather" : "Loading…"
            size: 13
            weight: 600
            customColor: Colors.tertiaryContainerText
        }
    }
}
