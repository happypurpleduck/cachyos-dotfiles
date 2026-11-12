pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Weather from wttr.in (location by IP). Refreshes every 30 minutes.
Singleton {
    id: root

    property bool ready: false
    property string location: ""
    property int temp: 0
    property int feels: 0
    property string desc: ""
    property string icon: "cloud"
    property int high: 0
    property int low: 0
    property var forecast: []     // [{day, icon, high, low}]

    function iconFor(code) {
        code = Number(code);
        const hour = new Date().getHours();
        const night = hour < 6 || hour >= 19;
        if (code === 113)
            return night ? "clear_night" : "clear_day";
        if (code === 116)
            return night ? "partly_cloudy_night" : "partly_cloudy_day";
        if (code === 119 || code === 122)
            return "cloud";
        if ([143, 248, 260].includes(code))
            return "foggy";
        if ([200, 386, 389, 392, 395].includes(code))
            return "thunderstorm";
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].includes(code))
            return "weather_snowy";
        if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].includes(code))
            return "weather_mix";
        return "rainy";
    }

    Process {
        id: fetch
        command: ["curl", "-sf", "--max-time", "15", "https://wttr.in/?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    const c = j.current_condition[0];
                    root.temp = Number(c.temp_C);
                    root.feels = Number(c.FeelsLikeC);
                    root.desc = c.weatherDesc[0].value.trim();
                    root.icon = root.iconFor(c.weatherCode);
                    const a = j.nearest_area?.[0];
                    root.location = a ? a.areaName[0].value : "";
                    root.high = Number(j.weather[0].maxtempC);
                    root.low = Number(j.weather[0].mintempC);
                    const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                    root.forecast = j.weather.map(w => ({
                                day: days[new Date(w.date + "T12:00:00").getDay()],
                                icon: root.iconFor(w.hourly[4]?.weatherCode ?? 116),
                                high: Number(w.maxtempC),
                                low: Number(w.mintempC)
                            }));
                    root.ready = true;
                } catch (e) {
                    console.warn("weather: parse failed", e);
                }
            }
        }
    }

    Timer {
        running: true
        interval: 30 * 60 * 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: fetch.running = true
    }
}
