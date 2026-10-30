.pragma library

var helpers = {
    luma: "float luma(vec3 c) {\n"
        + "    return dot(c, vec3(0.2126, 0.7152, 0.0722));\n"
        + "}\n",
    kelvin: "vec3 kelvin(float k) {\n"
        + "    float t = k / 100.0;\n"
        + "    float r, g, b;\n"
        + "    if (t <= 66.0) {\n"
        + "        r = 1.0;\n"
        + "        g = clamp((99.4708025861 * log(t) - 161.1195681661) / 255.0, 0.0, 1.0);\n"
        + "    } else {\n"
        + "        r = clamp(329.698727446 * pow(t - 60.0, -0.1332047592) / 255.0, 0.0, 1.0);\n"
        + "        g = clamp(288.1221695283 * pow(t - 60.0, -0.0755148492) / 255.0, 0.0, 1.0);\n"
        + "    }\n"
        + "    if (t >= 66.0) b = 1.0;\n"
        + "    else if (t <= 19.0) b = 0.0;\n"
        + "    else b = clamp((138.5177312231 * log(t - 10.0) - 305.0447927307) / 255.0, 0.0, 1.0);\n"
        + "    return vec3(r, g, b);\n"
        + "}\n\n"
        + "vec3 warmth(float k) {\n"
        + "    return kelvin(k) / kelvin(6500.0);\n"
        + "}\n"
}

var filters = [
    {
        id: "warm",
        name: "Warm Paper",
        blurb: "Keeps every colour, pulls blue out and caps the brightest whites",
        swatch: ["#fbe9cf", "#1d1a15", "#3d6fb8"],
        uses: ["luma", "kelvin"],
        params: [
            { key: "warmTemp", glsl: "TEMP", label: "Colour temperature", min: 3400, max: 6500, step: 100, def: 4600, unit: "k" },
            { key: "warmCap", glsl: "CAP", label: "Brightest white", min: 0.7, max: 1, step: 0.01, def: 0.88, unit: "pct" }
        ],
        body: "vec3 filt(vec3 c) {\n"
            + "    c *= warmth(TEMP);\n"
            + "    float l = luma(c);\n"
            + "    float knee = 0.55;\n"
            + "    float nl = l < knee ? l : knee + (l - knee) * (CAP - knee) / (1.0 - knee);\n"
            + "    return c * nl / max(l, 1e-4);\n"
            + "}\n"
    },
    {
        id: "sepia",
        name: "Sepia Page",
        blurb: "Brown ink on paper, colour fades to a hint",
        swatch: ["#efe3cb", "#2e241b", "#b79a76"],
        uses: ["luma"],
        params: [
            { key: "sepiaTone", glsl: "TONE", label: "Paper tone", min: 0, max: 1, step: 0.01, def: 0.35, unit: "pct" },
            { key: "sepiaKeep", glsl: "KEEP", label: "Colour kept", min: 0, max: 0.5, step: 0.01, def: 0.15, unit: "pct" }
        ],
        body: "vec3 filt(vec3 c) {\n"
            + "    vec3 paper = mix(vec3(0.961, 0.929, 0.859), vec3(0.878, 0.792, 0.643), TONE);\n"
            + "    vec3 ink = vec3(0.180, 0.141, 0.106);\n"
            + "    vec3 duo = mix(ink, paper, luma(c));\n"
            + "    vec3 hint = mix(ink, paper, c);\n"
            + "    return mix(duo, hint, KEEP);\n"
            + "}\n"
    },
    {
        id: "eink",
        name: "E-ink",
        blurb: "Greys only, firmer contrast and a fixed set of grey levels",
        swatch: ["#ecebe4", "#1c1c1c", "#8a8a86"],
        uses: ["luma"],
        params: [
            { key: "einkContrast", glsl: "CONTRAST", label: "Contrast", min: 1, max: 1.6, step: 0.01, def: 1.2, unit: "x" },
            { key: "einkLevels", glsl: "LEVELS", label: "Grey levels", min: 4, max: 32, step: 4, def: 16, unit: "int" },
            { key: "einkGrain", glsl: "GRAIN", label: "Paper grain", min: 0, max: 0.08, step: 0.005, def: 0.025, unit: "pct1" }
        ],
        body: "vec3 filt(vec3 c) {\n"
            + "    float l = clamp((luma(c) - 0.5) * CONTRAST + 0.5, 0.0, 1.0);\n"
            + "    float n = fract(sin(dot(floor(gl_FragCoord.xy), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;\n"
            + "    l = clamp(l + n * GRAIN, 0.0, 1.0);\n"
            + "    l = floor(l * (LEVELS - 1.0) + 0.5) / (LEVELS - 1.0);\n"
            + "    return mix(vec3(0.110), vec3(0.925, 0.918, 0.894), l);\n"
            + "}\n"
    }
]

function byId(id) {
    for (var i = 0; i < filters.length; i++)
        if (filters[i].id === id) return filters[i]
    return null
}

function param(key) {
    for (var i = 0; i < filters.length; i++)
        for (var j = 0; j < filters[i].params.length; j++)
            if (filters[i].params[j].key === key) return filters[i].params[j]
    return null
}

function snap(p, v) {
    var s = Math.round((v - p.min) / p.step) * p.step + p.min
    return Math.min(p.max, Math.max(p.min, Number(s.toFixed(4))))
}

function valueOf(p, cfg) {
    var v = Number(cfg ? cfg[p.key] : undefined)
    return isFinite(v) ? Math.min(p.max, Math.max(p.min, v)) : p.def
}

function format(p, v) {
    switch (p.unit) {
    case "k": return Math.round(v) + " K"
    case "pct": return Math.round(v * 100) + "%"
    case "pct1": return (v * 100).toFixed(1) + "%"
    case "x": return v.toFixed(2) + "×"
    default: return String(Math.round(v))
    }
}

function literal(v) {
    var s = Number(v).toFixed(4).replace(/0+$/, "")
    return s.charAt(s.length - 1) === "." ? s + "0" : s
}

function source(id, cfg) {
    var f = byId(id) || filters[0]
    var out = "#version 300 es\n"
        + "precision highp float;\n\n"
        + "in vec2 v_texcoord;\n"
        + "uniform sampler2D tex;\n"
        + "layout(location = 0) out vec4 fragColor;\n\n"
    for (var i = 0; i < f.params.length; i++)
        out += "const float " + f.params[i].glsl + " = " + literal(valueOf(f.params[i], cfg)) + ";\n"
    out += "\n"
    for (var j = 0; j < f.uses.length; j++)
        out += helpers[f.uses[j]] + "\n"
    out += f.body + "\n"
        + "void main() {\n"
        + "    vec4 s = texture(tex, v_texcoord);\n"
        + "    fragColor = vec4(clamp(filt(s.rgb), 0.0, 1.0), s.a);\n"
        + "}\n"
    return out
}
