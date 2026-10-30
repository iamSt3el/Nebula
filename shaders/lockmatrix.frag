#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec2 grid;
    vec4 digitsNew;
    vec4 digitsOld;
    float progress;
    float colon;
    float hide;
    vec4 hourColor;
    vec4 minuteColor;
    vec4 colonColor;
    vec4 dimColor;
};

bool isDigit(float d, float k) {
    return abs(d - k) < 0.5;
}

void glyph(float d, out vec4 a, out vec3 b) {
    a = vec4(0.0);
    b = vec3(0.0);
    if (isDigit(d, 0.0)) { a = vec4(14.0, 17.0, 19.0, 21.0); b = vec3(25.0, 17.0, 14.0); }
    else if (isDigit(d, 1.0)) { a = vec4(4.0, 12.0, 4.0, 4.0); b = vec3(4.0, 4.0, 14.0); }
    else if (isDigit(d, 2.0)) { a = vec4(14.0, 17.0, 1.0, 2.0); b = vec3(4.0, 8.0, 31.0); }
    else if (isDigit(d, 3.0)) { a = vec4(31.0, 2.0, 4.0, 2.0); b = vec3(1.0, 17.0, 14.0); }
    else if (isDigit(d, 4.0)) { a = vec4(2.0, 6.0, 10.0, 18.0); b = vec3(31.0, 2.0, 2.0); }
    else if (isDigit(d, 5.0)) { a = vec4(31.0, 16.0, 30.0, 1.0); b = vec3(1.0, 17.0, 14.0); }
    else if (isDigit(d, 6.0)) { a = vec4(6.0, 8.0, 16.0, 30.0); b = vec3(17.0, 17.0, 14.0); }
    else if (isDigit(d, 7.0)) { a = vec4(31.0, 1.0, 2.0, 4.0); b = vec3(8.0, 8.0, 8.0); }
    else if (isDigit(d, 8.0)) { a = vec4(14.0, 17.0, 17.0, 14.0); b = vec3(17.0, 17.0, 14.0); }
    else if (isDigit(d, 9.0)) { a = vec4(14.0, 17.0, 17.0, 15.0); b = vec3(1.0, 2.0, 12.0); }
}

float glyphBit(float d, float fr, float fc) {
    vec4 a;
    vec3 b;
    glyph(d, a, b);
    vec4 selA = vec4(equal(vec4(fr), vec4(0.0, 1.0, 2.0, 3.0)));
    vec3 selB = vec3(equal(vec3(fr), vec3(4.0, 5.0, 6.0)));
    float rowValue = dot(a, selA) + dot(b, selB);
    return mod(floor(rowValue / exp2(4.0 - fc)), 2.0);
}

float slotDigit(vec4 digits, float slot) {
    return dot(digits, vec4(equal(vec4(slot), vec4(0.0, 1.0, 2.0, 3.0))));
}

float litAt(vec4 digits, float c, float fr, float margin) {
    float rel = c - margin;
    float slot = -1.0;
    float start = 0.0;
    if (rel >= 0.0 && rel < 10.0) { slot = 0.0; start = 0.0; }
    else if (rel >= 11.0 && rel < 21.0) { slot = 1.0; start = 11.0; }
    else if (rel >= 27.0 && rel < 37.0) { slot = 2.0; start = 27.0; }
    else if (rel >= 38.0 && rel < 48.0) { slot = 3.0; start = 38.0; }
    if (slot < 0.0)
        return 0.0;
    float d = slotDigit(digits, slot);
    if (d < -0.5)
        return 0.0;
    float fc = floor((rel - start) / 2.0);
    return glyphBit(d, fr, fc);
}

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    vec2 pitch = itemSize / grid;
    vec2 cell = floor(px / pitch);
    vec2 local = px - (cell + 0.5) * pitch;
    float dist = length(local);
    float m = min(pitch.x, pitch.y);

    float margin = floor((grid.x - 48.0) * 0.5);
    float top = floor((grid.y - 21.0) * 0.5);
    float row = cell.y - top;
    float rel = cell.x - margin;
    float fr = floor(row / 3.0);
    bool inRows = row >= 0.0 && row < 21.0;

    float tcol = cell.x / grid.x;
    float t = clamp((progress - tcol * 0.5 - (cell.y / grid.y) * 0.08) / 0.42, 0.0, 1.0);
    float te = t * t * (3.0 - 2.0 * t);

    float litOld = 0.0;
    float litNew = 0.0;
    vec4 kind = hourColor;
    bool isColon = rel >= 23.0 && rel < 25.0;

    if (inRows) {
        if (isColon) {
            float on = (fr == 2.0 || fr == 4.0) ? 1.0 : 0.0;
            litOld = on * colon;
            litNew = on * colon;
            kind = colonColor;
        } else {
            litOld = litAt(digitsOld, cell.x, fr, margin);
            litNew = litAt(digitsNew, cell.x, fr, margin);
            kind = rel < 23.0 ? hourColor : minuteColor;
        }
    }

    float lit = mix(litOld, litNew, te);
    float pop = 1.0 + 0.3 * sin(3.14159 * t) * abs(litNew - litOld);
    float hcut = clamp((hide - tcol * 0.4) / 0.6, 0.0, 1.0);
    lit *= 1.0 - hcut;

    float radius = mix(0.11, 0.29, lit) * m * pop;
    float cover = 1.0 - smoothstep(radius - 0.8, radius + 0.8, dist);
    float sigma = 0.17 * m;
    float glow = exp(-(dist * dist) / (2.0 * sigma * sigma)) * 0.45 * lit;
    glow *= 1.0 - smoothstep(0.3 * m, 0.5 * m, dist);

    vec4 dotCol = mix(dimColor, vec4(kind.rgb, 1.0), lit);
    float baseFade = 1.0 - hide;
    float a = cover * dotCol.a * baseFade;
    vec3 rgb = dotCol.rgb * a;
    float ga = glow * (1.0 - cover) * baseFade;
    rgb += kind.rgb * ga;
    a += ga;

    fragColor = vec4(rgb, a) * qt_Opacity;
}
