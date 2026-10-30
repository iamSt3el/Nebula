.pragma library

var scenes = [
    { id: 1,  name: "Ocean",        moving: true,  a: "#3bd6e8", b: "#3b6bff", shape: "clover4" },
    { id: 2,  name: "Romance",      moving: true,  a: "#ff7ba8", b: "#c43b6a", shape: "heart" },
    { id: 3,  name: "Sunset",       moving: true,  a: "#ffb43b", b: "#ff5c3b", shape: "sunny" },
    { id: 4,  name: "Party",        moving: true,  a: "#ff3bd2", b: "#7b3bff", shape: "gem" },
    { id: 5,  name: "Fireplace",    moving: true,  a: "#ffcf5c", b: "#ff6a2b", shape: "drop" },
    { id: 6,  name: "Cozy",         moving: true,  a: "#ffb87b", b: "#ff8a4c", shape: "cookie9" },
    { id: 7,  name: "Forest",       moving: true,  a: "#7bd66b", b: "#2e8b57", shape: "leaf" },
    { id: 8,  name: "Pastel",       moving: true,  a: "#ffc8e6", b: "#b8d8ff", shape: "puffy" },
    { id: 9,  name: "Wake up",      moving: true,  a: "#ffe4ce", b: "#ffb87b", shape: "verySunny" },
    { id: 10, name: "Bedtime",      moving: true,  a: "#ffb05c", b: "#8a4a2b", shape: "moon" },
    { id: 11, name: "Warm white",   moving: false, a: "#ffa757", b: "#ff9227", shape: "circle" },
    { id: 12, name: "Daylight",     moving: false, a: "#fffefa", b: "#ffe4ce", shape: "squircle" },
    { id: 13, name: "Cool white",   moving: false, a: "#eef3ff", b: "#d6e2ff", shape: "square" },
    { id: 14, name: "Night light",  moving: false, a: "#ff9a3c", b: "#a8622b", shape: "semiCircle" },
    { id: 15, name: "Focus",        moving: false, a: "#f4f7ff", b: "#c8d8ff", shape: "diamond" },
    { id: 16, name: "Relax",        moving: false, a: "#ffd7a8", b: "#ffb87b", shape: "pebble" },
    { id: 17, name: "True colours", moving: false, a: "#ffffff", b: "#ffe9d6", shape: "hexagon" },
    { id: 18, name: "TV time",      moving: false, a: "#b8c8ff", b: "#6b7bff", shape: "oval" },
    { id: 19, name: "Plant growth", moving: false, a: "#ff5cc8", b: "#7b3bff", shape: "flower" },
    { id: 20, name: "Spring",       moving: true,  a: "#b8ff9a", b: "#ffd0e8", shape: "clover8" },
    { id: 21, name: "Summer",       moving: true,  a: "#ffe14d", b: "#ff9a3c", shape: "softBurst" },
    { id: 22, name: "Fall",         moving: true,  a: "#ffa03b", b: "#b34a1e", shape: "cookie6" },
    { id: 23, name: "Deep dive",    moving: true,  a: "#3b7bff", b: "#1e2e8b", shape: "blob" },
    { id: 24, name: "Jungle",       moving: true,  a: "#3bd67b", b: "#b8ff3b", shape: "clover3" },
    { id: 25, name: "Mojito",       moving: true,  a: "#9aff7b", b: "#3bd6c8", shape: "cookie5" },
    { id: 26, name: "Club",         moving: true,  a: "#ff3b9a", b: "#3b3bff", shape: "burst" },
    { id: 27, name: "Christmas",    moving: true,  a: "#ff3b3b", b: "#3bd66b", shape: "star5" },
    { id: 28, name: "Halloween",    moving: true,  a: "#ff8a1e", b: "#7b3bff", shape: "ghostish" },
    { id: 29, name: "Candlelight",  moving: true,  a: "#ffb03b", b: "#ff7a1e", shape: "cookie4" },
    { id: 30, name: "Golden white", moving: false, a: "#ffd9a0", b: "#ffc070", shape: "cookie12" },
    { id: 31, name: "Pulse",        moving: true,  a: "#ffffff", b: "#ffa757", shape: "sparkle" },
    { id: 32, name: "Steampunk",    moving: true,  a: "#d9a05c", b: "#8a5a2b", shape: "octagon" },
    { id: 33, name: "Diwali",       moving: true,  a: "#ffd23b", b: "#ff5c3b", shape: "cookie8" },
    { id: 34, name: "White",        moving: false, a: "#ffffff", b: "#f2f2f2", shape: "cookie10" },
    { id: 35, name: "Alarm",        moving: true,  a: "#ff3b3b", b: "#ffffff", shape: "bolt" },
    { id: 36, name: "Snowy sky",    moving: true,  a: "#e6f2ff", b: "#9ac8ff", shape: "scallop" }
]

var picks = [3, 5, 1, 4, 6, 2, 14, 15]

function byId(id) {
    for (var i = 0; i < scenes.length; i++)
        if (scenes[i].id === id)
            return scenes[i]
    return null
}

function kelvin(k) {
    var t = k / 100
    var r = t <= 66 ? 255 : 329.698727446 * Math.pow(t - 60, -0.1332047592)
    var g = t <= 66 ? 99.4708025861 * Math.log(t) - 161.1195681661 : 288.1221695283 * Math.pow(t - 60, -0.0755148492)
    var b = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307
    function c(v) { return Math.max(0, Math.min(255, v)) / 255 }
    return Qt.rgba(c(r), c(g), c(b), 1)
}
