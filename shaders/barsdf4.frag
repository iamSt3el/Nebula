#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float pillCount;
    float segCount;
    float flareCount;
    float topA;
    float rMaxA;
    float botA;
    float topB;
    float rMaxB;
    float botB;
    float cutA;
    float cutB;
    float blend;
    vec2 itemSize;
    vec2 origin;
    vec4 mapA;
    vec4 mapB;
    vec4 fillColor;
    vec4 strokeColor;
    float strokeW;
    vec4 pil0;
    vec4 pil1;
    vec4 pil2;
    vec4 pil3;
    vec4 pil4;
    vec4 pil5;
    vec4 pil6;
    vec4 pil7;
    vec4 pir0;
    vec4 pir1;
    vec4 pir2;
    vec4 pir3;
    vec4 pir4;
    vec4 pir5;
    vec4 pir6;
    vec4 pir7;
    vec4 seg0;
    vec4 seg1;
    vec4 seg2;
    vec4 seg3;
    vec4 seg4;
    vec4 seg5;
    vec4 seg6;
    vec4 seg7;
    vec4 seg8;
    vec4 seg9;
    vec4 seg10;
    vec4 seg11;
    vec4 seg12;
    vec4 seg13;
    vec4 seg14;
    vec4 seg15;
    vec4 seg16;
    vec4 seg17;
    vec4 seg18;
    vec4 seg19;
    vec4 seg20;
    vec4 seg21;
    vec4 seg22;
    vec4 seg23;
    vec4 fil0;
    vec4 fil1;
    vec4 fil2;
    vec4 fil3;
    vec4 fil4;
    vec4 fil5;
    vec4 fil6;
    vec4 fil7;
    vec4 fil8;
    vec4 fil9;
    vec4 fil10;
    vec4 fil11;
    vec4 fil12;
    vec4 fil13;
    vec4 fil14;
    vec4 fil15;
    vec4 fil16;
    vec4 fil17;
    vec4 fil18;
    vec4 fil19;
    vec4 fil20;
    vec4 fil21;
    vec4 fil22;
    vec4 fil23;
    vec4 rad0;
    vec4 rad1;
    vec4 rad2;
    vec4 rad3;
    vec4 rad4;
    vec4 rad5;
    vec4 rad6;
    vec4 rad7;
    vec4 rad8;
    vec4 rad9;
    vec4 rad10;
    vec4 rad11;
    vec4 fc0;
    vec4 fc1;
    vec4 fc2;
    vec4 fc3;
    vec4 fc4;
    vec4 fc5;
    vec4 fc6;
    vec4 fc7;
    vec4 fc8;
    vec4 fc9;
    vec4 fc10;
    vec4 fc11;
    float tabCount;
    vec4 tb0;
    vec4 tbr0;
    vec4 tbf0;
    vec4 tbx0;
    vec4 tbc0;
    vec4 tb1;
    vec4 tbr1;
    vec4 tbf1;
    vec4 tbx1;
    vec4 tbc1;
    vec4 tb2;
    vec4 tbr2;
    vec4 tbf2;
    vec4 tbx2;
    vec4 tbc2;
    vec4 tb3;
    vec4 tbr3;
    vec4 tbf3;
    vec4 tbx3;
    vec4 tbc3;
};

const float weld = 2.0;

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

float unionRound(float a, float b, float r) {
    if (r <= 0.0)
        return min(a, b);
    vec2 u = max(vec2(r - a, r - b), vec2(0.0));
    return max(r, min(a, b)) - length(u);
}

float segDist(vec4 s, vec2 rad, float top, float stripBot, vec2 p) {
    float bot = abs(s.z);
    if (bot <= stripBot + 0.01 || s.y <= 0.0)
        return 1.0e5;
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
        lo = vec2(f.x, f.y - weld);
        hi = vec2(f.x + r, f.y + r);
    } else if (m < 2.5) {
        lo = vec2(f.x - r, f.y - r);
        hi = vec2(f.x + weld, f.y);
    } else if (m < 3.5) {
        lo = vec2(f.x - r, f.y - weld);
        hi = vec2(f.x, f.y + r);
    } else {
        lo = vec2(f.x - weld, f.y - r);
        hi = vec2(f.x + r, f.y);
    }
    return sdRect(p, lo, hi);
}

void addPill(inout float dA, inout float dB, vec4 q, vec4 rr, float idx, vec2 pa, vec2 pb) {
    if (idx >= pillCount)
        return;
    if (q.w < 0.5)
        dA = min(dA, sdCorners(pa, vec2(q.x, topA), vec2(q.y, q.z), rr));
    else
        dB = min(dB, sdCorners(pb, vec2(q.x, topB), vec2(q.y, q.z), rr));
}

void addFlareFill(inout float dA, inout float dB, vec4 f, float idx, vec2 pa, vec2 pb) {
    if (idx >= flareCount || f.z <= 0.0)
        return;
    if (f.w < 8.0)
        dA = min(dA, flareDist(f, f.w, pa));
    else
        dB = min(dB, flareDist(f, f.w - 8.0, pb));
}

void addFlareCarve(inout float dA, inout float dB, vec4 f, float idx, vec2 pa, vec2 pb) {
    if (idx >= flareCount || f.z <= 0.0)
        return;
    if (f.w < 8.0)
        dA = max(dA, f.z - length(pa - flareHub(f, f.w)));
    else
        dB = max(dB, f.z - length(pb - flareHub(f, f.w - 8.0)));
}

void addFilFill(inout float dA, inout float dB, vec4 s, vec4 f, float idx, vec2 pa, vec2 pb) {
    if (idx >= segCount)
        return;
    vec2 p = s.z < 0.0 ? pb : pa;
    float stripBot = s.z < 0.0 ? botB : botA;
    float d = 1.0e5;
    if (f.y > 0.0) {
        float up = f.x > stripBot + 0.01 ? weld : 0.0;
        d = min(d, sdRect(p, vec2(s.x - f.y, f.x - up), vec2(s.x + weld, f.x + f.y)));
    }
    if (f.w > 0.0) {
        float up = f.z > stripBot + 0.01 ? weld : 0.0;
        d = min(d, sdRect(p, vec2(s.x + s.y - weld, f.z - up), vec2(s.x + s.y + f.w, f.z + f.w)));
    }
    if (s.z < 0.0)
        dB = min(dB, d);
    else
        dA = min(dA, d);
}

void addFilCarve(inout float dA, inout float dB, vec4 s, vec4 f, float idx, vec2 pa, vec2 pb) {
    if (idx >= segCount)
        return;
    vec2 p = s.z < 0.0 ? pb : pa;
    float d = -1.0e5;
    if (f.y > 0.0)
        d = max(d, f.y - length(p - vec2(s.x - f.y, f.x + f.y)));
    if (f.w > 0.0)
        d = max(d, f.w - length(p - vec2(s.x + s.y + f.w, f.z + f.w)));
    if (s.z < 0.0)
        dB = max(dB, d);
    else
        dA = max(dA, d);
}

void addSeg(inout float dA, inout float dB, vec4 s, vec2 rad, float idx, vec2 pa, vec2 pb) {
    if (idx >= segCount)
        return;
    if (s.z < 0.0)
        dB = min(dB, segDist(s, rad, topB, botB, pb));
    else
        dA = min(dA, segDist(s, rad, topA, botA, pa));
}

void addCon(inout float dA, inout float dB, vec4 s, vec4 f, float idx, vec2 pa, vec2 pb) {
    if (idx >= segCount || s.w < 0.0)
        return;
    float x = s.x + s.y;
    if (s.z < 0.0) {
        if (f.z > topB + 0.01)
            dB = min(dB, sdRect(pb, vec2(x - weld, topB), vec2(x + s.w + weld, f.z)));
    } else {
        if (f.z > topA + 0.01)
            dA = min(dA, sdRect(pa, vec2(x - weld, topA), vec2(x + s.w + weld, f.z)));
    }
}

void addTab(inout float dA, inout float dB, vec4 t, vec4 rr, vec4 fl, vec4 fx, vec4 cn, float idx, vec2 pa, vec2 pb) {
    if (idx >= tabCount || t.y <= 0.0)
        return;
    bool dock = t.w > 0.5;
    vec2 p = dock ? pb : pa;
    float top = dock ? topB : topA;
    float X = t.x + t.y;
    float f = 1.0e5;
    float c = -1.0e5;
    if (fl.y > 0.0) {
        f = min(f, sdRect(p, vec2(t.x - fl.y, fl.x - weld), vec2(t.x + weld, fl.x + fl.y)));
        c = max(c, fl.y - length(p - vec2(t.x - fl.y, fl.x + fl.y)));
    }
    if (fl.w > 0.0) {
        f = min(f, sdRect(p, vec2(X - weld, fl.z - weld), vec2(X + fl.w, fl.z + fl.w)));
        c = max(c, fl.w - length(p - vec2(X + fl.w, fl.z + fl.w)));
    }
    if (fx.x > 0.0) {
        vec4 g = vec4(t.x, t.z, fx.x, fx.y);
        f = min(f, flareDist(g, fx.y, p));
        c = max(c, fx.x - length(p - flareHub(g, fx.y)));
    }
    if (fx.z > 0.0) {
        vec4 g = vec4(X, t.z, fx.z, fx.w);
        f = min(f, flareDist(g, fx.w, p));
        c = max(c, fx.z - length(p - flareHub(g, fx.w)));
    }
    f = max(f, c);
    if (cn.y > 0.5)
        f = min(f, sdRect(p, vec2(cn.x, top), vec2(t.x + weld, fl.x)));
    if (cn.w > 0.5)
        f = min(f, sdRect(p, vec2(X - weld, top), vec2(cn.z, fl.z)));
    float d = min(sdCorners(p, vec2(t.x, top), vec2(X, t.z), rr), f);
    d = max(d, top - p.y);
    if (dock)
        dB = min(dB, d);
    else
        dA = min(dA, d);
}

vec2 toFrame(vec2 p, vec4 m) {
    vec2 q = m.x > 0.5 ? p.yx : p;
    q.y = m.y > 0.5 ? m.z - q.y : q.y + m.z;
    return q;
}

void main() {
    vec2 p = origin + qt_TexCoord0 * itemSize;
    vec2 pa = toFrame(p, mapA);
    vec2 pb = toFrame(p, mapB);

    if (pa.y > cutA && pb.y > cutB) {
        fragColor = vec4(0.0);
        return;
    }
    float dA = 1.0e5;
    float dB = 1.0e5;

    addPill(dA, dB, pil0, pir0, 0.0, pa, pb);
    addPill(dA, dB, pil1, pir1, 1.0, pa, pb);
    addPill(dA, dB, pil2, pir2, 2.0, pa, pb);
    addPill(dA, dB, pil3, pir3, 3.0, pa, pb);
    addPill(dA, dB, pil4, pir4, 4.0, pa, pb);
    addPill(dA, dB, pil5, pir5, 5.0, pa, pb);
    addPill(dA, dB, pil6, pir6, 6.0, pa, pb);
    addPill(dA, dB, pil7, pir7, 7.0, pa, pb);

    addFlareFill(dA, dB, fc0, 0.0, pa, pb);
    addFlareFill(dA, dB, fc1, 1.0, pa, pb);
    addFlareFill(dA, dB, fc2, 2.0, pa, pb);
    addFlareFill(dA, dB, fc3, 3.0, pa, pb);
    addFlareFill(dA, dB, fc4, 4.0, pa, pb);
    addFlareFill(dA, dB, fc5, 5.0, pa, pb);
    addFlareFill(dA, dB, fc6, 6.0, pa, pb);
    addFlareFill(dA, dB, fc7, 7.0, pa, pb);
    addFlareFill(dA, dB, fc8, 8.0, pa, pb);
    addFlareFill(dA, dB, fc9, 9.0, pa, pb);
    addFlareFill(dA, dB, fc10, 10.0, pa, pb);
    addFlareFill(dA, dB, fc11, 11.0, pa, pb);

    addFilFill(dA, dB, seg0, fil0, 0.0, pa, pb);
    addFilFill(dA, dB, seg1, fil1, 1.0, pa, pb);
    addFilFill(dA, dB, seg2, fil2, 2.0, pa, pb);
    addFilFill(dA, dB, seg3, fil3, 3.0, pa, pb);
    addFilFill(dA, dB, seg4, fil4, 4.0, pa, pb);
    addFilFill(dA, dB, seg5, fil5, 5.0, pa, pb);
    addFilFill(dA, dB, seg6, fil6, 6.0, pa, pb);
    addFilFill(dA, dB, seg7, fil7, 7.0, pa, pb);
    addFilFill(dA, dB, seg8, fil8, 8.0, pa, pb);
    addFilFill(dA, dB, seg9, fil9, 9.0, pa, pb);
    addFilFill(dA, dB, seg10, fil10, 10.0, pa, pb);
    addFilFill(dA, dB, seg11, fil11, 11.0, pa, pb);
    addFilFill(dA, dB, seg12, fil12, 12.0, pa, pb);
    addFilFill(dA, dB, seg13, fil13, 13.0, pa, pb);
    addFilFill(dA, dB, seg14, fil14, 14.0, pa, pb);
    addFilFill(dA, dB, seg15, fil15, 15.0, pa, pb);
    addFilFill(dA, dB, seg16, fil16, 16.0, pa, pb);
    addFilFill(dA, dB, seg17, fil17, 17.0, pa, pb);
    addFilFill(dA, dB, seg18, fil18, 18.0, pa, pb);
    addFilFill(dA, dB, seg19, fil19, 19.0, pa, pb);
    addFilFill(dA, dB, seg20, fil20, 20.0, pa, pb);
    addFilFill(dA, dB, seg21, fil21, 21.0, pa, pb);
    addFilFill(dA, dB, seg22, fil22, 22.0, pa, pb);
    addFilFill(dA, dB, seg23, fil23, 23.0, pa, pb);

    addFlareCarve(dA, dB, fc0, 0.0, pa, pb);
    addFlareCarve(dA, dB, fc1, 1.0, pa, pb);
    addFlareCarve(dA, dB, fc2, 2.0, pa, pb);
    addFlareCarve(dA, dB, fc3, 3.0, pa, pb);
    addFlareCarve(dA, dB, fc4, 4.0, pa, pb);
    addFlareCarve(dA, dB, fc5, 5.0, pa, pb);
    addFlareCarve(dA, dB, fc6, 6.0, pa, pb);
    addFlareCarve(dA, dB, fc7, 7.0, pa, pb);
    addFlareCarve(dA, dB, fc8, 8.0, pa, pb);
    addFlareCarve(dA, dB, fc9, 9.0, pa, pb);
    addFlareCarve(dA, dB, fc10, 10.0, pa, pb);
    addFlareCarve(dA, dB, fc11, 11.0, pa, pb);

    addFilCarve(dA, dB, seg0, fil0, 0.0, pa, pb);
    addFilCarve(dA, dB, seg1, fil1, 1.0, pa, pb);
    addFilCarve(dA, dB, seg2, fil2, 2.0, pa, pb);
    addFilCarve(dA, dB, seg3, fil3, 3.0, pa, pb);
    addFilCarve(dA, dB, seg4, fil4, 4.0, pa, pb);
    addFilCarve(dA, dB, seg5, fil5, 5.0, pa, pb);
    addFilCarve(dA, dB, seg6, fil6, 6.0, pa, pb);
    addFilCarve(dA, dB, seg7, fil7, 7.0, pa, pb);
    addFilCarve(dA, dB, seg8, fil8, 8.0, pa, pb);
    addFilCarve(dA, dB, seg9, fil9, 9.0, pa, pb);
    addFilCarve(dA, dB, seg10, fil10, 10.0, pa, pb);
    addFilCarve(dA, dB, seg11, fil11, 11.0, pa, pb);
    addFilCarve(dA, dB, seg12, fil12, 12.0, pa, pb);
    addFilCarve(dA, dB, seg13, fil13, 13.0, pa, pb);
    addFilCarve(dA, dB, seg14, fil14, 14.0, pa, pb);
    addFilCarve(dA, dB, seg15, fil15, 15.0, pa, pb);
    addFilCarve(dA, dB, seg16, fil16, 16.0, pa, pb);
    addFilCarve(dA, dB, seg17, fil17, 17.0, pa, pb);
    addFilCarve(dA, dB, seg18, fil18, 18.0, pa, pb);
    addFilCarve(dA, dB, seg19, fil19, 19.0, pa, pb);
    addFilCarve(dA, dB, seg20, fil20, 20.0, pa, pb);
    addFilCarve(dA, dB, seg21, fil21, 21.0, pa, pb);
    addFilCarve(dA, dB, seg22, fil22, 22.0, pa, pb);
    addFilCarve(dA, dB, seg23, fil23, 23.0, pa, pb);

    addSeg(dA, dB, seg0, rad0.xy, 0.0, pa, pb);
    addSeg(dA, dB, seg1, rad0.zw, 1.0, pa, pb);
    addSeg(dA, dB, seg2, rad1.xy, 2.0, pa, pb);
    addSeg(dA, dB, seg3, rad1.zw, 3.0, pa, pb);
    addSeg(dA, dB, seg4, rad2.xy, 4.0, pa, pb);
    addSeg(dA, dB, seg5, rad2.zw, 5.0, pa, pb);
    addSeg(dA, dB, seg6, rad3.xy, 6.0, pa, pb);
    addSeg(dA, dB, seg7, rad3.zw, 7.0, pa, pb);
    addSeg(dA, dB, seg8, rad4.xy, 8.0, pa, pb);
    addSeg(dA, dB, seg9, rad4.zw, 9.0, pa, pb);
    addSeg(dA, dB, seg10, rad5.xy, 10.0, pa, pb);
    addSeg(dA, dB, seg11, rad5.zw, 11.0, pa, pb);
    addSeg(dA, dB, seg12, rad6.xy, 12.0, pa, pb);
    addSeg(dA, dB, seg13, rad6.zw, 13.0, pa, pb);
    addSeg(dA, dB, seg14, rad7.xy, 14.0, pa, pb);
    addSeg(dA, dB, seg15, rad7.zw, 15.0, pa, pb);
    addSeg(dA, dB, seg16, rad8.xy, 16.0, pa, pb);
    addSeg(dA, dB, seg17, rad8.zw, 17.0, pa, pb);
    addSeg(dA, dB, seg18, rad9.xy, 18.0, pa, pb);
    addSeg(dA, dB, seg19, rad9.zw, 19.0, pa, pb);
    addSeg(dA, dB, seg20, rad10.xy, 20.0, pa, pb);
    addSeg(dA, dB, seg21, rad10.zw, 21.0, pa, pb);
    addSeg(dA, dB, seg22, rad11.xy, 22.0, pa, pb);
    addSeg(dA, dB, seg23, rad11.zw, 23.0, pa, pb);

    addCon(dA, dB, seg0, fil0, 0.0, pa, pb);
    addCon(dA, dB, seg1, fil1, 1.0, pa, pb);
    addCon(dA, dB, seg2, fil2, 2.0, pa, pb);
    addCon(dA, dB, seg3, fil3, 3.0, pa, pb);
    addCon(dA, dB, seg4, fil4, 4.0, pa, pb);
    addCon(dA, dB, seg5, fil5, 5.0, pa, pb);
    addCon(dA, dB, seg6, fil6, 6.0, pa, pb);
    addCon(dA, dB, seg7, fil7, 7.0, pa, pb);
    addCon(dA, dB, seg8, fil8, 8.0, pa, pb);
    addCon(dA, dB, seg9, fil9, 9.0, pa, pb);
    addCon(dA, dB, seg10, fil10, 10.0, pa, pb);
    addCon(dA, dB, seg11, fil11, 11.0, pa, pb);
    addCon(dA, dB, seg12, fil12, 12.0, pa, pb);
    addCon(dA, dB, seg13, fil13, 13.0, pa, pb);
    addCon(dA, dB, seg14, fil14, 14.0, pa, pb);
    addCon(dA, dB, seg15, fil15, 15.0, pa, pb);
    addCon(dA, dB, seg16, fil16, 16.0, pa, pb);
    addCon(dA, dB, seg17, fil17, 17.0, pa, pb);
    addCon(dA, dB, seg18, fil18, 18.0, pa, pb);
    addCon(dA, dB, seg19, fil19, 19.0, pa, pb);
    addCon(dA, dB, seg20, fil20, 20.0, pa, pb);
    addCon(dA, dB, seg21, fil21, 21.0, pa, pb);
    addCon(dA, dB, seg22, fil22, 22.0, pa, pb);
    addCon(dA, dB, seg23, fil23, 23.0, pa, pb);
    addTab(dA, dB, tb0, tbr0, tbf0, tbx0, tbc0, 0.0, pa, pb);
    addTab(dA, dB, tb1, tbr1, tbf1, tbx1, tbc1, 1.0, pa, pb);
    addTab(dA, dB, tb2, tbr2, tbf2, tbx2, tbc2, 2.0, pa, pb);
    addTab(dA, dB, tb3, tbr3, tbf3, tbx3, tbc3, 3.0, pa, pb);
    if (strokeW > 0.0) {
        float ws = clamp(length(vec2(dFdx(dA), dFdy(dA))), 1.0e-5, 1.0);
        float sa = clamp(0.5 - (abs(dA) - strokeW * 0.5) / ws, 0.0, 1.0) * strokeColor.a;
        fragColor = vec4(strokeColor.rgb * sa, sa) * qt_Opacity;
        return;
    }

    float d = unionRound(dA, dB, blend);

    float w = clamp(length(vec2(dFdx(d), dFdy(d))), 1.0e-5, 1.0);
    float a = clamp(0.5 - d / w, 0.0, 1.0) * fillColor.a;
    fragColor = vec4(fillColor.rgb * a, a) * qt_Opacity;
}
