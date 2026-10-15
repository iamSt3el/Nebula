#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float edgeW;
    int fieldCount;
    int activeMask;
    vec4 fillColor;
    vec4 edgeColor;
    ivec4 counts;
    vec4 frameHole;
    vec4 frameRad;
    vec4 fieldMap[8];
    vec4 fieldInfo[8];
    vec4 pill[192];
    vec4 seg[192];
    vec4 flare[64];
    vec4 tab[168];
    vec4 shadowColor;
    vec4 shadowInfo;
};

const float weld = 2.0;
const float far = 1.0e5;

float sdBox(vec2 p, vec2 c, vec2 h) {
    vec2 q = abs(p - c) - h;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0));
}

float sdRect(vec2 p, vec2 lo, vec2 hi) {
    return sdBox(p, (lo + hi) * 0.5, (hi - lo) * 0.5);
}

float sdCorners(vec2 p, vec2 lo, vec2 hi, vec4 rr) {
    vec2 c = (lo + hi) * 0.5;
    vec2 h = (hi - lo) * 0.5;
    float r = p.x < c.x ? (p.y < c.y ? rr.x : rr.z) : (p.y < c.y ? rr.y : rr.w);
    r = min(r, min(h.x, h.y));
    vec2 e = abs(p - c) - h + r;
    return min(max(e.x, e.y), 0.0) + length(max(e, 0.0)) - r;
}

float smin(float a, float b, float r) {
    if (r < 0.01)
        return min(a, b);
    float h = clamp(0.5 + 0.5 * (b - a) / r, 0.0, 1.0);
    return mix(b, a, h) - r * h * (1.0 - h);
}

float unionRound(float a, float b, float r) {
    if (r <= 0.0)
        return min(a, b);
    vec2 u = max(vec2(r - a, r - b), vec2(0.0));
    return max(r, min(a, b)) - length(u);
}

float segDist(vec4 s, vec2 rad, float top, float stripBot, vec2 p) {
    float bot = s.z;
    if (bot <= stripBot + 0.01 || s.y <= 0.0)
        return far;
    float head = min(stripBot - weld, bot - 2.0 * max(rad.x, rad.y));
    vec2 lo = vec2(s.x, head);
    vec2 hi = vec2(s.x + s.y, bot);
    float d = sdCorners(p, lo, hi, vec4(0.0, 0.0, rad.x, rad.y));
    return max(d, top - p.y);
}

vec2 flareHub(vec4 f, float m) {
    float r = f.z;
    if (m < 1.5)
        return vec2(f.x + r, f.y + r);
    if (m < 2.5)
        return vec2(f.x - r, f.y - r);
    if (m < 3.5)
        return vec2(f.x - r, f.y + r);
    return vec2(f.x + r, f.y - r);
}

float flareDist(vec4 f, float m, vec2 p) {
    float r = f.z;
    vec2 lo, hi;
    if (m < 1.5) {
        lo = vec2(f.x - weld, f.y - weld);
        hi = vec2(f.x + r, f.y + r);
    } else if (m < 2.5) {
        lo = vec2(f.x - r, f.y - r);
        hi = vec2(f.x + weld, f.y);
    } else if (m < 3.5) {
        lo = vec2(f.x - r, f.y - weld);
        hi = vec2(f.x + weld, f.y + r);
    } else {
        lo = vec2(f.x - weld, f.y - r);
        hi = vec2(f.x + r, f.y);
    }
    return sdRect(p, lo, hi);
}

vec2 toFrame(vec2 p, vec4 m) {
    vec2 q = m.x > 0.5 ? p.yx : p;
    q.y = m.y > 0.5 ? m.z - q.y : q.y + m.z;
    return q;
}

bool live(int f) {
    return f < fieldCount && (activeMask & (1 << f)) != 0;
}

float tabDist(int i, vec2 p, bool sunk) {
    vec4 t = tab[i * 7];
    vec4 rr = tab[i * 7 + 1];
    vec4 fl = tab[i * 7 + 2];
    if (sunk) {
        vec4 k = tab[i * 7 + 6];
        if (fl.y > 0.0)
            fl.xy += vec2(-k.y, k.y);
        if (fl.w > 0.0)
            fl.zw += vec2(-k.z, k.z);
    }
    vec4 fx = tab[i * 7 + 3];
    vec4 cn = tab[i * 7 + 4];
    vec4 g = tab[i * 7 + 5];
    float top = t.w;
    float bot = t.z;
    if (g.y > g.x) {
        float hd = sdCorners(p, g.xz, g.yw, vec4(rr.z));
        float bd = sdCorners(p, vec2(t.x, top), vec2(t.x + t.y, bot), vec4(rr.x));
        return smin(hd, bd, rr.y);
    }
    float X = t.x + t.y;
    bool merged = g.x > g.y + 0.5;
    float f = far;
    float c = -far;
    if (fl.y < 0.0) {
        float r = -fl.y;
        float ex = merged ? g.y : t.x;
        f = min(f, sdRect(p, vec2(ex - r, fl.x - r), vec2(ex + weld, fl.x + weld)));
        c = max(c, r - length(p - vec2(ex - r, fl.x - r)));
    }
    if (fl.w < 0.0) {
        float r = -fl.w;
        float ex = merged ? g.x : X;
        f = min(f, sdRect(p, vec2(ex - weld, fl.z - r), vec2(ex + r, fl.z + weld)));
        c = max(c, r - length(p - vec2(ex + r, fl.z - r)));
    }
    if (fl.y > 0.0) {
        f = min(f, sdRect(p, vec2(t.x - fl.y, fl.x - weld), vec2(t.x + weld, fl.x + fl.y)));
        c = max(c, fl.y - length(p - vec2(t.x - fl.y, fl.x + fl.y)));
    }
    if (fl.w > 0.0) {
        f = min(f, sdRect(p, vec2(X - weld, fl.z - weld), vec2(X + fl.w, fl.z + fl.w)));
        c = max(c, fl.w - length(p - vec2(X + fl.w, fl.z + fl.w)));
    }
    if (fx.x > 0.0) {
        vec4 h = vec4(t.x, bot, fx.x, fx.y);
        f = min(f, flareDist(h, fx.y, p));
        c = max(c, fx.x - length(p - flareHub(h, fx.y)));
    }
    if (fx.z > 0.0) {
        vec4 h = vec4(X, bot, fx.z, fx.w);
        f = min(f, flareDist(h, fx.w, p));
        c = max(c, fx.z - length(p - flareHub(h, fx.w)));
    }
    f = max(f, c);
    if (cn.y > 0.5)
        f = min(f, sdRect(p, vec2(cn.x, top), vec2(t.x + weld, fl.x)));
    if (cn.w > 0.5)
        f = min(f, sdRect(p, vec2(X - weld, top), vec2(cn.z, fl.z)));
    float d;
    if (merged) {
        float gap = cn.x;
        float et = max(g.w, 0.0);
        float eb = abs(g.w);
        float fade = max(0.0, eb - (bot - g.z - gap));
        float nbL = fl.y > 0.0 ? eb : fade;
        float nbR = fl.w > 0.0 ? eb : fade;
        float blockD = sdCorners(p, vec2(g.y, top), vec2(g.x, g.z), vec4(et, et, nbL, nbR));
        float stem = sdRect(p, vec2(max(g.y, t.x), g.z - weld), vec2(min(g.x, X), g.z + gap + weld));
        float body = sdCorners(p, vec2(t.x, g.z + gap), vec2(X, bot), rr);
        d = min(min(blockD, stem), min(body, f));
    } else {
        d = min(sdCorners(p, vec2(t.x, top), vec2(X, bot), rr), f);
    }
    return max(d, top - p.y);
}

float combine(float db[8], float df[8]) {
    float d = far;
    float dBase = far;
    float r = 0.0;
    bool first = true;
    for (int f = 0; f < 8; f++) {
        if (!live(f))
            continue;
        if (first) {
            d = df[f];
            dBase = db[f];
            r = fieldInfo[f].z;
            first = false;
            continue;
        }
        float k = fieldInfo[f].z;
        if (fieldMap[f].w < 0.5) {
            r = min(r, k);
            k = r;
        }
        d = min(unionRound(d, db[f], k), unionRound(dBase, df[f], k));
        dBase = unionRound(dBase, db[f], k);
    }
    return d;
}

void main() {
    vec2 p = qt_TexCoord0;
    vec2 pf[8];
    float df[8];
    bool near = false;
    for (int f = 0; f < 8; f++) {
        df[f] = far;
        pf[f] = vec2(0.0);
        if (!live(f))
            continue;
        pf[f] = toFrame(p, fieldMap[f]);
        if (pf[f].y <= fieldInfo[f].w + max(shadowInfo.x, edgeW + 2.0))
            near = true;
    }
    bool frameLive = (activeMask & 256) != 0;
    if (!near && !frameLive) {
        fragColor = vec4(0.0);
        return;
    }

    for (int i = 0; i < counts.z; i++) {
        vec4 c = flare[i];
        int f = int(floor(c.w / 8.0));
        if (!live(f) || c.z <= 0.0)
            continue;
        df[f] = min(df[f], flareDist(c, c.w - 8.0 * float(f), pf[f]));
    }

    for (int i = 0; i < counts.y; i++) {
        vec4 s = seg[i * 3];
        vec4 fl = seg[i * 3 + 1];
        int f = int(seg[i * 3 + 2].z);
        if (!live(f))
            continue;
        vec2 q = pf[f];
        float stripBot = fieldInfo[f].y;
        float d = far;
        if (fl.y > 0.0) {
            float up = fl.x > stripBot + 0.01 ? weld : 0.0;
            d = min(d, sdRect(q, vec2(s.x - fl.y, fl.x - up), vec2(s.x + weld, fl.x + fl.y)));
        }
        if (fl.w > 0.0) {
            float up = fl.z > stripBot + 0.01 ? weld : 0.0;
            d = min(d, sdRect(q, vec2(s.x + s.y - weld, fl.z - up), vec2(s.x + s.y + fl.w, fl.z + fl.w)));
        }
        df[f] = min(df[f], d);
    }

    for (int i = 0; i < counts.z; i++) {
        vec4 c = flare[i];
        int f = int(floor(c.w / 8.0));
        if (!live(f) || c.z <= 0.0)
            continue;
        df[f] = max(df[f], c.z - length(pf[f] - flareHub(c, c.w - 8.0 * float(f))));
    }

    for (int i = 0; i < counts.y; i++) {
        vec4 s = seg[i * 3];
        vec4 fl = seg[i * 3 + 1];
        int f = int(seg[i * 3 + 2].z);
        if (!live(f))
            continue;
        vec2 q = pf[f];
        float d = -far;
        if (fl.y > 0.0)
            d = max(d, fl.y - length(q - vec2(s.x - fl.y, fl.x + fl.y)));
        if (fl.w > 0.0)
            d = max(d, fl.w - length(q - vec2(s.x + s.y + fl.w, fl.z + fl.w)));
        df[f] = max(df[f], d);
    }

    for (int i = 0; i < counts.x; i++) {
        int f = int(pill[i * 3 + 2].x);
        if (!live(f))
            continue;
        vec4 q = pill[i * 3];
        df[f] = min(df[f], sdCorners(pf[f], vec2(q.x, q.w), vec2(q.y, q.z), pill[i * 3 + 1]));
    }

    for (int i = 0; i < counts.y; i++) {
        vec4 s = seg[i * 3];
        vec4 e = seg[i * 3 + 2];
        int f = int(e.z);
        if (!live(f))
            continue;
        df[f] = min(df[f], segDist(s, e.xy, fieldInfo[f].x, fieldInfo[f].y, pf[f]));
    }

    for (int i = 0; i < counts.y; i++) {
        vec4 s = seg[i * 3];
        vec4 fl = seg[i * 3 + 1];
        int f = int(seg[i * 3 + 2].z);
        if (!live(f) || s.w < 0.0)
            continue;
        float top = fieldInfo[f].x;
        float x = s.x + s.y;
        if (fl.z > top + 0.01)
            df[f] = min(df[f], sdRect(pf[f], vec2(x - weld, top), vec2(x + s.w + weld, fl.z)));
    }

    float ds[8];
    float db[8];
    bool sinks = false;
    for (int f = 0; f < 8; f++) {
        ds[f] = df[f];
        db[f] = df[f];
    }
    for (int i = 0; i < counts.w; i++) {
        vec4 t = tab[i * 7];
        vec4 k = tab[i * 7 + 6];
        int f = int(k.x);
        if (!live(f) || t.y <= 0.0)
            continue;
        float td = tabDist(i, pf[f], false);
        df[f] = min(df[f], td);
        if (k.y > 0.0 || k.z > 0.0) {
            sinks = true;
            td = tabDist(i, pf[f], true);
        }
        ds[f] = min(ds[f], td);
    }

    float d = combine(db, df);
    float dShade = sinks ? combine(db, ds) : d;

    if (frameLive) {
        float hole = -sdCorners(p, frameHole.xy, frameHole.zw, frameRad);
        d = min(d, hole);
        dShade = min(dShade, hole);
    }

    float w = clamp(length(vec2(dFdx(d), dFdy(d))), 1.0e-5, 1.0);

    float tintK = 0.0;
    float clearK = 0.0;
    float shadeK = 0.0;
    float lineK = 0.0;
    vec3 tintRgb = vec3(0.0);
    for (int i = 0; i < counts.x; i++) {
        vec4 e = pill[i * 3 + 2];
        if (e.y <= 0.0 && e.w <= 0.0)
            continue;
        int f = int(e.x);
        if (!live(f))
            continue;
        vec4 q = pill[i * 3];
        float dp = sdCorners(pf[f], vec2(q.x, q.w), vec2(q.y, q.z), pill[i * 3 + 1]);
        float m = clamp(0.5 - (dp - 1.0) / w, 0.0, 1.0);
        if (m <= 0.0 && e.y <= 0.0)
            continue;
        if (e.w > 0.0 && m > 0.0) {
            int c = int(e.z + 0.5);
            tintRgb = vec3(float((c >> 16) & 255), float((c >> 8) & 255), float(c & 255)) / 255.0;
            tintK = max(tintK, e.w * m);
        }
        if (e.y > 0.0) {
            clearK = max(clearK, e.y * m);
            float reach = max(shadowInfo.x, 1.0);
            shadeK = max(shadeK, e.y * (1.0 - smoothstep(0.0, reach, dp)));
            lineK = max(lineK, e.y * (1.0 - smoothstep(edgeW + 0.5, edgeW + 2.0, dp)));
        }
    }

    float gooShade = 0.0;
    if (clearK > 0.0 || shadeK > 0.0) {
        float reach = max(shadowInfo.x, 1.0);
        float keep = 0.0;
        for (int i = 0; i < counts.w; i++) {
            vec4 t = tab[i * 7];
            vec4 g = tab[i * 7 + 5];
            int f = int(tab[i * 7 + 6].x);
            if (!live(f) || t.y <= 0.0 || g.y <= g.x)
                continue;
            float td = tabDist(i, pf[f], false);
            float hd = sdCorners(pf[f], g.xz, g.yw, vec4(tab[i * 7 + 1].z));
            float tc = clamp(0.5 - td / w, 0.0, 1.0);
            float hc = clamp(0.5 - hd / w, 0.0, 1.0);
            keep = max(keep, clamp(tc - hc, 0.0, 1.0));
            float fall = 1.0 - smoothstep(0.0, 1.0, clamp(td / reach, 0.0, 1.0));
            gooShade = max(gooShade, fall * smoothstep(0.0, reach, hd));
        }
        clearK *= 1.0 - keep;
    }

    float a = clamp(0.5 - d / w, 0.0, 1.0) * fillColor.a;
    vec3 rgb = fillColor.rgb;
    if (tintK > 0.0)
        rgb = mix(rgb, tintRgb, tintK);
    a *= 1.0 - clearK;
    vec4 col = vec4(rgb * a, a);
    if (edgeW > 0.0) {
        float aa = clamp(fwidth(d), 1.0e-4, 1.0);
        float band = 1.0 - smoothstep(edgeW - 0.5 * aa, edgeW + 0.5 * aa, d);
        float lineA = band * edgeColor.a * (1.0 - lineK);
        col += vec4(edgeColor.rgb * lineA, lineA) * (1.0 - col.a);
    }
    if (shadowInfo.x > 0.0 && shadowInfo.y > 0.0 && col.a < 1.0) {
        float s = 1.0 - smoothstep(0.0, 1.0, clamp(dShade / shadowInfo.x, 0.0, 1.0));
        s = max(s * (1.0 - shadeK), gooShade);
        float sa = s * s * shadowInfo.y * shadowColor.a;
        col += vec4(shadowColor.rgb * sa, sa) * (1.0 - col.a);
    }
    fragColor = col * qt_Opacity;
}
