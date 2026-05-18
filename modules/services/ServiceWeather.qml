pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.utils
import qs.modules.settings

Singleton {
    id: root

    property string location: SettingsConfig.weather.location
    property bool useMetric: true
    property int refreshInterval: 900000 // 15 minutes
    property bool isLoading: false
    property bool hasError: false

    // Weather data properties
    property var currentCondition: null
    property var locationData: null
    property var astronomy: null

    // Aqi data
    property var currentAqi: null

    // Convenient properties
    readonly property string temperature: currentCondition ?
    (useMetric ? currentCondition.temp_C + "°C" : currentCondition.temp_F + "°F") : "0°C"
    readonly property string feelsLike: currentCondition ?
    (useMetric ? currentCondition.FeelsLikeC + "°C" : currentCondition.FeelsLikeF + "°F") : "N/A"
    readonly property string humidity: currentCondition ? currentCondition.humidity + "%" : "N/A"
    readonly property string description: currentCondition ? currentCondition.weatherDesc[0].value : "No data"
    readonly property string weatherCode: currentCondition ? currentCondition.weatherCode : "113"
    readonly property string cityName: locationData ? locationData.areaName[0].value : "Unknown"
    readonly property string windSpeed: currentCondition ? currentCondition.windspeedKmph + " km/h" : "N/A"
    readonly property string cloudcover: currentCondition ? currentCondition.cloudcover + "%" : "N/A"
    readonly property string uvindex: currentCondition ? currentCondition.uvIndex : "N/A";
    readonly property string visibility: currentCondition ? currentCondition.visibility + " km" : "N/A";
    readonly property real aqi: currentAqi ? calculateAQI(currentAqi) : 0 ;

    Timer {
        id: refreshTimer
        interval: root.refreshInterval
        running: true
        repeat: true
        onTriggered: {
            root.fetchWeather()
            root.fetchAqi()
        }
        Component.onCompleted:{
            root.fetchWeather()
            root.fetchAqi()

        }
    }

    function fetchWeather() {
        root.isLoading = true
        root.hasError = false

        let command = `curl -s wttr.in/${location}?format=j1`

        weatherProcess.command[2] = command
        weatherProcess.running = true
    }

    function fetchAqi() {
        root.isLoading = true
        root.hasError = false

        let command = `curl -s 'http://api.openweathermap.org/data/2.5/air_pollution?lat=31.2206734&lon=75.7696463&appid=30cf8519d65a1be0f9fa1ba838a4eac2'`

        aqiProcess.command[2] = command
        aqiProcess.running = true
    }


    Process{
        id: aqiProcess
        command: ["bash", "-c", ""]

        stdout: StdioCollector {
            onStreamFinished: {
                root.isLoading = false
                if (text.length === 0) {
                    //root.hasError = true
                    return
                }

                try {
                    const data = JSON.parse(text)


                    if (data.list) {
                        root.currentAqi = data.list[0].components
                    }

                    //root.hasError = false
                } catch (e) {
                    //root.hasError = true
                    console.error("Weather data parse error:", e.message)
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    //root.hasError = true
                }
            }
        }

    }

    Process {
        id: weatherProcess
        command: ["bash", "-c", ""]

        stdout: StdioCollector {
            onStreamFinished: {
                root.isLoading = false
                if (text.length === 0) {
                    root.hasError = true
                    return
                }

                try {
                    const data = JSON.parse(text)

                    if (data.current_condition && data.current_condition.length > 0) {
                        root.currentCondition = data.current_condition[0]
                    }
                    if (data.nearest_area && data.nearest_area.length > 0) {
                        root.locationData = data.nearest_area[0]
                    }
                    if (data.weather && data.weather.length > 0 && data.weather[0].astronomy) {
                        root.astronomy = data.weather[0].astronomy[0]
                    }

                    root.hasError = false
                } catch (e) {
                    root.hasError = true
                    console.error("Weather data parse error:", e.message)
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    root.hasError = true
                }
            }
        }
    }

    function isNightTime() {
        if (!astronomy || !astronomy.sunrise || !astronomy.sunset) {
            // Fallback to simple time check if no astronomy data
            const now = new Date()
            const hour = now.getHours()
            return hour < 6 || hour >= 18
        }

        const now = new Date()
        const currentHour = now.getHours()
        const currentMinute = now.getMinutes()
        const currentTime = currentHour * 60 + currentMinute // Convert to minutes

        // Parse sunrise time (format: "06:30 AM")
        const sunriseStr = astronomy.sunrise
        const sunriseMatch = sunriseStr.match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i)
        if (!sunriseMatch) return currentHour < 6 || currentHour >= 18

        let sunriseHour = parseInt(sunriseMatch[1])
        const sunriseMinute = parseInt(sunriseMatch[2])
        const sunriseAMPM = sunriseMatch[3].toUpperCase()

        if (sunriseAMPM === "PM" && sunriseHour !== 12) sunriseHour += 12
        if (sunriseAMPM === "AM" && sunriseHour === 12) sunriseHour = 0
        const sunriseTime = sunriseHour * 60 + sunriseMinute

        // Parse sunset time (format: "07:45 PM")
        const sunsetStr = astronomy.sunset
        const sunsetMatch = sunsetStr.match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i)
        if (!sunsetMatch) return currentHour < 6 || currentHour >= 18

        let sunsetHour = parseInt(sunsetMatch[1])
        const sunsetMinute = parseInt(sunsetMatch[2])
        const sunsetAMPM = sunsetMatch[3].toUpperCase()

        if (sunsetAMPM === "PM" && sunsetHour !== 12) sunsetHour += 12
        if (sunsetAMPM === "AM" && sunsetHour === 12) sunsetHour = 0
        const sunsetTime = sunsetHour * 60 + sunsetMinute

        // It's night if current time is before sunrise or after sunset
        return currentTime < sunriseTime || currentTime >= sunsetTime
    }

    function getWeatherIcon(code) {
        const isNight = isNightTime()

        const dayIconMap = {
            "113": "clear_day", // Sunny
            "116": "partly_cloudy_day", // Partly cloudy
            "119": "cloud", // Cloudy
            "122": "cloud", // Overcast
            "143": "foggy", // Mist
            "176": "rainy_light", // Patchy rain possible
            "179": "weather_snowy", // Patchy snow possible
            "182": "cloudy_snowing", // Patchy sleet possible
            "185": "cloudy_snowing", // Patchy freezing drizzle possible
            "200": "thunderstorm", // Thundery outbreaks possible
            "227": "weather_snowy", // Blowing snow
            "230": "weather_snowy", // Blizzard
            "248": "foggy", // Fog
            "260": "foggy", // Freezing fog
            "263": "grain", // Patchy light drizzle
            "266": "grain", // Light drizzle
            "281": "grain", // Freezing drizzle
            "284": "rainy", // Heavy freezing drizzle
            "293": "rainy_light", // Patchy light rain
            "296": "rainy_light", // Light rain
            "299": "rainy", // Moderate rain at times
            "302": "rainy", // Moderate rain
            "305": "rainy_heavy", // Heavy rain at times
            "308": "rainy_heavy", // Heavy rain
            "311": "cloudy_snowing", // Light freezing rain
            "314": "cloudy_snowing", // Moderate or heavy freezing rain
            "317": "cloudy_snowing", // Light sleet
            "320": "cloudy_snowing", // Moderate or heavy sleet
            "323": "weather_snowy", // Patchy light snow
            "326": "weather_snowy", // Light snow
            "329": "weather_snowy", // Patchy moderate snow
            "332": "weather_snowy", // Moderate snow
            "335": "ac_unit", // Patchy heavy snow
            "338": "ac_unit", // Heavy snow
            "350": "ac_unit", // Ice pellets
            "353": "rainy_light", // Light rain shower
            "356": "rainy", // Moderate or heavy rain shower
            "359": "rainy_heavy", // Torrential rain shower
            "362": "cloudy_snowing", // Light sleet showers
            "365": "cloudy_snowing", // Moderate or heavy sleet showers
            "368": "weather_snowy", // Light snow showers
            "371": "ac_unit", // Moderate or heavy snow showers
            "374": "ac_unit", // Light showers of ice pellets
            "377": "ac_unit", // Moderate or heavy showers of ice pellets
            "386": "thunderstorm", // Patchy light rain with thunder
            "389": "thunderstorm", // Moderate or heavy rain with thunder
            "392": "thunderstorm", // Patchy light snow with thunder
            "395": "thunderstorm"  // Moderate or heavy snow with thunder
        }

        const nightIconMap = {
            "113": "clear_night", // Clear night
            "116": "partly_cloudy_night", // Partly cloudy night
            "119": "cloud", // Cloudy night
            "122": "cloud", // Overcast night
            "143": "foggy", // Mist
            "176": "rainy_light", // Patchy rain possible
            "179": "weather_snowy", // Patchy snow possible
            "182": "cloudy_snowing", // Patchy sleet possible
            "185": "cloudy_snowing", // Patchy freezing drizzle possible
            "200": "thunderstorm", // Thundery outbreaks possible
            "227": "weather_snowy", // Blowing snow
            "230": "weather_snowy", // Blizzard
            "248": "foggy", // Fog
            "260": "foggy", // Freezing fog
            "263": "grain", // Patchy light drizzle
            "266": "grain", // Light drizzle
            "281": "grain", // Freezing drizzle
            "284": "rainy", // Heavy freezing drizzle
            "293": "rainy_light", // Patchy light rain
            "296": "rainy_light", // Light rain
            "299": "rainy", // Moderate rain at times
            "302": "rainy", // Moderate rain
            "305": "rainy_heavy", // Heavy rain at times
            "308": "rainy_heavy", // Heavy rain
            "311": "cloudy_snowing", // Light freezing rain
            "314": "cloudy_snowing", // Moderate or heavy freezing rain
            "317": "cloudy_snowing", // Light sleet
            "320": "cloudy_snowing", // Moderate or heavy sleet
            "323": "weather_snowy", // Patchy light snow
            "326": "weather_snowy", // Light snow
            "329": "weather_snowy", // Patchy moderate snow
            "332": "weather_snowy", // Moderate snow
            "335": "ac_unit", // Patchy heavy snow
            "338": "ac_unit", // Heavy snow
            "350": "ac_unit", // Ice pellets
            "353": "rainy_light", // Light rain shower
            "356": "rainy", // Moderate or heavy rain shower
            "359": "rainy_heavy", // Torrential rain shower
            "362": "cloudy_snowing", // Light sleet showers
            "365": "cloudy_snowing", // Moderate or heavy sleet showers
            "368": "weather_snowy", // Light snow showers
            "371": "ac_unit", // Moderate or heavy snow showers
            "374": "ac_unit", // Light showers of ice pellets
            "377": "ac_unit", // Moderate or heavy showers of ice pellets
            "386": "thunderstorm", // Patchy light rain with thunder
            "389": "thunderstorm", // Moderate or heavy rain with thunder
            "392": "thunderstorm", // Patchy light snow with thunder
            "395": "thunderstorm"  // Moderate or heavy snow with thunder
        }

        const iconMap = isNight ? nightIconMap : dayIconMap
        return iconMap[code] || (isNight ? "clear_night" : "clear_day")
    }
    function calculateAQI(c) {
        var r = {
            "pm2_5": [[0,30,0,50],[30.1,60,51,100],[60.1,90,101,200],[90.1,120,201,300],[120.1,250,301,400],[250.1,380,401,500]],
            "pm10": [[0,50,0,50],[51,100,51,100],[101,250,101,200],[251,350,201,300],[351,430,301,400],[431,550,401,500]],
            "no2": [[0,40,0,50],[41,80,51,100],[81,180,101,200],[181,280,201,300],[281,400,301,400],[401,800,401,500]],
            "o3": [[0,50,0,50],[51,100,51,100],[101,168,101,200],[169,208,201,300],[209,748,301,400],[749,1000,401,500]],
            "co": [[0,1000,0,50],[1001,2000,51,100],[2001,10000,101,200],[10001,17000,201,300],[17001,34000,301,400],[34001,50000,401,500]],
            "so2": [[0,40,0,50],[41,80,51,100],[81,380,101,200],[381,800,201,300],[801,1600,301,400],[1601,2400,401,500]],
            "nh3": [[0,200,0,50],[201,400,51,100],[401,800,101,200],[801,1200,201,300],[1201,1800,301,400],[1801,2400,401,500]]
        };
        var max = 0;
        for (var p in r) {
            if (!c[p]) continue;
            for (var i = 0; i < r[p].length; i++) {
                var b = r[p][i];
                if (c[p] >= b[0] && c[p] <= b[1]) {
                    var aqi = Math.round(((b[3] - b[2]) / (b[1] - b[0])) * (c[p] - b[0]) + b[2]);
                    if (aqi > max) max = aqi;
                    break;
                }
            }
        }
        return max;
    }



    readonly property string weatherIconPath: {
        return getWeatherIcon(weatherCode)
    }
}

