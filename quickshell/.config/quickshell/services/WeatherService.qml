pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

// Current weather + short forecast from Open-Meteo (free, no API key).
// Location comes from state "weather.city"; when empty it is guessed from the IP.
// There is no background polling: data is fetched at startup and refreshed
// on demand (refresh()) when older than maxAge.
Singleton {
    id: root

    readonly property string city: StateService.get("weather.city", "")
    readonly property int maxAge: 15 * 60 * 1000
    readonly property int forecastDays: 5

    property string location: ""
    property bool loading: false
    property string error: ""
    property real lastUpdate: 0

    // { temp, feelsLike, humidity, wind, code, isDay }
    property var current: null
    // [{ date, code, max, min, rain }]
    property var daily: []
    property string sunrise: ""
    property string sunset: ""

    readonly property bool available: current !== null

    // Resolved coordinates, cached per configured city
    property var _coords: null

    function refresh(force) {
        if (loading || StateService.isLoading)
            return;
        if (!force && Date.now() - lastUpdate < maxAge)
            return;

        loading = true;
        error = "";

        if (_coords && _coords.city === city)
            _fetchForecast();
        else if (city !== "")
            _geocode();
        else
            _locateByIp();
    }

    onCityChanged: {
        _coords = null;
        refresh(true);
    }

    Component.onCompleted: refresh(false)

    Connections {
        target: StateService
        function onStateLoaded() {
            root.refresh(false);
        }
    }

    // ========================================================================
    // CONDITIONS (WMO weather codes)
    // ========================================================================

    function icon(code, isDay) {
        if (code === 0)
            return isDay ? "󰖙" : "󰖔";
        if (code <= 2)
            return isDay ? "󰖕" : "󰼱";
        if (code === 3)
            return "󰖐";
        if (code === 45 || code === 48)
            return "󰖑";
        if (code === 65 || code === 82)
            return "󰖖";
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
            return "󰖗";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return "󰖘";
        if (code >= 95)
            return "󰖓";
        return "󰖐";
    }

    function description(code) {
        const map = {
            0: "Clear sky",
            1: "Mainly clear",
            2: "Partly cloudy",
            3: "Overcast",
            45: "Fog",
            48: "Rime fog",
            51: "Light drizzle",
            53: "Drizzle",
            55: "Heavy drizzle",
            56: "Freezing drizzle",
            57: "Freezing drizzle",
            61: "Light rain",
            63: "Rain",
            65: "Heavy rain",
            66: "Freezing rain",
            67: "Freezing rain",
            71: "Light snow",
            73: "Snow",
            75: "Heavy snow",
            77: "Snow grains",
            80: "Light showers",
            81: "Showers",
            82: "Violent showers",
            85: "Snow showers",
            86: "Snow showers",
            95: "Thunderstorm",
            96: "Thunderstorm, hail",
            99: "Thunderstorm, hail"
        };
        return map[code] ?? "Unknown";
    }

    // ========================================================================
    // REQUESTS
    // ========================================================================

    function _get(url, onSuccess) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status !== 200) {
                root._fail(xhr.status === 0 ? "No connection" : "Request failed (" + xhr.status + ")");
                return;
            }
            try {
                onSuccess(JSON.parse(xhr.responseText));
            } catch (e) {
                root._fail("Invalid response");
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function _fail(message) {
        console.warn("[Weather]", message);
        error = message;
        loading = false;
    }

    function _geocode() {
        const configured = city;
        _get("https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&format=json&name=" + encodeURIComponent(configured), data => {
            const r = data.results?.[0];
            if (!r) {
                root._fail("City not found: " + configured);
                return;
            }
            root._coords = {
                city: configured,
                lat: r.latitude,
                lon: r.longitude,
                name: r.name
            };
            root._fetchForecast();
        });
    }

    function _locateByIp() {
        _get("https://ipwho.is/?fields=success,city,latitude,longitude", data => {
            if (!data.success) {
                root._fail("Could not detect location");
                return;
            }
            root._coords = {
                city: "",
                lat: data.latitude,
                lon: data.longitude,
                name: data.city
            };
            root._fetchForecast();
        });
    }

    function _fetchForecast() {
        const c = _coords;
        const url = "https://api.open-meteo.com/v1/forecast?timezone=auto" + "&latitude=" + c.lat + "&longitude=" + c.lon + "&forecast_days=" + forecastDays + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day" + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset";

        _get(url, data => {
            const cur = data.current;
            const d = data.daily;

            root.current = {
                temp: Math.round(cur.temperature_2m),
                feelsLike: Math.round(cur.apparent_temperature),
                humidity: cur.relative_humidity_2m,
                wind: Math.round(cur.wind_speed_10m),
                code: cur.weather_code,
                isDay: cur.is_day === 1
            };

            root.daily = d.time.map((t, i) => ({
                        date: new Date(t + "T12:00:00"),
                        code: d.weather_code[i],
                        max: Math.round(d.temperature_2m_max[i]),
                        min: Math.round(d.temperature_2m_min[i]),
                        rain: d.precipitation_probability_max[i] ?? 0
                    }));

            root.sunrise = d.sunrise[0].slice(11);
            root.sunset = d.sunset[0].slice(11);
            root.location = c.name;
            root.lastUpdate = Date.now();
            root.loading = false;
        });
    }
}
