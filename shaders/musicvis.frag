#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 lowColor;
    vec4 highColor;
    vec4 ghostColor;
    float pulse;
    float presence;
    float gradient;
    float glow;
    float style;
    float mirror;
    float frame;
    float depth;
    float outerRadius;
    float bands;
    float period;
};

layout(binding = 1) uniform sampler2D bandTex;

float sampleAt(float i) {
    float c = clamp(i, 0.0, max(bands - 1.0, 0.0));
    vec4 t = texture(bandTex, vec2((c + 0.5) / 256.0, 0.5));
    return (t.r * 65280.0 + t.g * 255.0) / 65535.0;
}

float curveAt(float x) {
    float p = clamp(x, 0.0, 1.0) * max(bands - 1.0, 1.0);
    float i = floor(p);
    float t = p - i;
    float p0 = sampleAt(i - 1.0);
    float p1 = sampleAt(i);
    float p2 = sampleAt(i + 1.0);
    float p3 = sampleAt(i + 2.0);
    float c = 0.5 * (2.0 * p1 + (p2 - p0) * t
        + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
        + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t);
    return clamp(c, 0.0, 1.0);
}

float sdBox(vec2 p, vec2 b, float r) {
    float rr = min(r, max(0.0, min(b.x, b.y)));
    vec2 q = abs(p) - b + rr;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rr;
}

float linearAt(float x) {
    float p = clamp(x, 0.0, 1.0) * max(bands - 1.0, 1.0);
    float i = floor(p);
    return mix(sampleAt(i), sampleAt(i + 1.0), p - i);
}

vec2 frameParam(vec2 p, vec2 hb) {
    float r = clamp(depth * 1.2, 8.0, min(hb.x, hb.y));
    float a = hb.x - r;
    float b = 2.0 * (hb.y - r);
    float P = 2.0 * a + b + 3.14159265 * r;
    float x = abs(p.x);
    float y = p.y;
    float qx = x - a;
    float qy = abs(y) - (hb.y - r);
    float s;
    if (qx > 0.0 && qy > 0.0) {
        if (y > 0.0)
            s = a + r * atan(qx, qy);
        else
            s = a + 1.5707963 * r + b + r * atan(qy, qx);
    } else if (hb.x - x < hb.y - abs(y)) {
        s = a + 1.5707963 * r + ((hb.y - r) - y);
    } else {
        s = y > 0.0 ? x : P - x;
    }
    return vec2(s, P);
}

float bandOf(float along) {
    if (frame < 0.5 && mirror > 0.5)
        return abs(2.0 * along - 1.0);
    return along;
}

void main() {
    float along;
    float lenPx;
    float yPx;
    float sPx;
    vec2 hb = itemSize * 0.5;
    vec2 p = qt_TexCoord0 * itemSize - hb;
    float R = clamp(outerRadius, 0.0, min(hb.x, hb.y));

    if (frame > 0.5) {
        yPx = -sdBox(p, hb, R);
        if (yPx > depth * 1.45 + 40.0) {
            fragColor = vec4(0.0);
            return;
        }
        vec2 fp = frameParam(p, hb);
        sPx = fp.x;
        lenPx = fp.y;
        along = clamp(fp.x / fp.y, 0.0, 1.0);
    } else {
        along = qt_TexCoord0.x;
        lenPx = itemSize.x;
        sPx = along * lenPx;
        yPx = (1.0 - qt_TexCoord0.y) * itemSize.y;
    }

    float bx = bandOf(along);
    float raw = curveAt(bx);
    float lift = presence * (1.0 + 0.1 * pulse);
    float hPx = raw * depth * lift;
    float live = step(0.0005, raw * presence);
    vec3 tint = mix(lowColor.rgb, highColor.rgb, gradient * smoothstep(0.0, 1.0, bx));
    vec3 body = mix(tint, vec3(1.0), 0.16 * pulse);
    float rin = R + depth * 0.5;
    float cap = max(0.0, min(hb.x, hb.y) - 1.0);
    float outerA = frame > 0.5 ? clamp(yPx / 1.2 + 0.5, 0.0, 1.0) : 1.0;
    float inner = frame > 0.5 ? sdBox(p, hb - min(hPx, cap), rin) : hPx - yPx;
    vec4 outc = vec4(0.0);

    if (style > 3.5) {
        float ex = bx;
        float taper = frame > 0.5 ? 1.0 : smoothstep(0.0, 0.06, along) * smoothstep(1.0, 0.94, along);
        float env = curveAt(ex) * taper;
        float amp = depth * 0.46 * lift * env;
        float base = depth * 0.5;
        float gap = max(period, 4.0);
        float ph = 6.2831853 * sPx / gap;
        float f = amp * sin(ph);
        float slope = amp * cos(ph) * 6.2831853 / gap;
        float off = frame > 0.5 ? -sdBox(p, hb - base, R + base) : yPx - base;
        float d = max(abs(off - f) / sqrt(1.0 + slope * slope), abs(off) - abs(amp));
        float core = 1.0 - smoothstep(0.6, 1.5 + 0.5 * pulse, d);
        float halo = exp(-d / (3.5 + 3.5 * pulse)) * (0.18 + 0.22 * pulse) * glow;
        vec3 stint = mix(lowColor.rgb, highColor.rgb, gradient * smoothstep(0.0, 1.0, ex));
        vec3 c = mix(stint, vec3(1.0), 0.08 * core + 0.1 * pulse);
        float a = clamp(core + halo * (1.0 - core), 0.0, 1.0) * presence * outerA;
        outc = vec4(c, 1.0) * a;
    } else if (style < 0.5) {
        float hg = live > 0.5 ? hPx * 1.05 + 10.0 * presence : 0.0;
        float innerG = frame > 0.5 ? sdBox(p, hb - min(hg, cap), rin) : hg - yPx;
        vec3 ghostRgb = mix(ghostColor.rgb, tint, gradient);
        float mainA = clamp(inner / 1.2 + 0.5, 0.0, 1.0) * live * outerA;
        float ghostA = clamp(innerG / 1.2 + 0.5, 0.0, 1.0) * ghostColor.a * outerA * live;
        float glowA = glow * (0.22 + 0.45 * pulse) * exp(-max(0.0, -inner) / 9.0) * live * presence * outerA;
        vec4 under = vec4(ghostRgb, 1.0) * ghostA;
        under += vec4(tint, 1.0) * glowA * (1.0 - under.a);
        vec4 top = vec4(body, 1.0) * mainA;
        outc = top + under * (1.0 - top.a);
    } else if (style < 1.5) {
        float d;
        if (frame > 0.5) {
            d = abs(inner);
        } else {
            float dx = 1.5 / max(lenPx, 1.0);
            float raw2 = curveAt(bandOf(clamp(along + dx, 0.0, 1.0)));
            float slope = (raw2 - raw) * depth * lift / 1.5;
            d = abs(inner) / sqrt(1.0 + slope * slope);
        }
        float core = 1.0 - smoothstep(1.0, 2.2 + pulse, d);
        float halo = exp(-d / (6.0 + 6.0 * pulse)) * (0.45 + 0.35 * pulse) * glow;
        float fill = inner > 0.0 ? 0.07 : 0.0;
        float a = clamp(core + halo * (1.0 - core) + fill, 0.0, 1.0) * presence * outerA;
        vec3 c = mix(tint, vec3(1.0), 0.35 * core + 0.16 * pulse);
        outc = vec4(c, 1.0) * a;
    } else if (style > 2.5) {
        float slotPx = lenPx / max(bands - 1.0, 1.0);
        float pos = mod(bx * lenPx, slotPx);
        float inSlot = clamp(pos - 0.5, 0.0, 1.0) * clamp(slotPx - 1.0 - pos, 0.0, 1.0);
        float lin = linearAt(bx);
        float hL = lin * depth * lift;
        float hB = min(1.0, lin / 0.88) * depth * lift;
        float innerL = frame > 0.5 ? sdBox(p, hb - min(hL, cap), rin) : hL - yPx;
        float innerB = frame > 0.5 ? sdBox(p, hb - min(hB, cap), rin) : hB - yPx;
        float on = step(0.0005, lin * presence);
        float mainA = clamp(innerL + 0.5, 0.0, 1.0) * inSlot * on * outerA;
        float backA = clamp(innerB + 0.5, 0.0, 1.0) * inSlot * on * outerA * ghostColor.a;
        vec4 under = vec4(mix(ghostColor.rgb, tint, gradient), 1.0) * backA;
        vec4 top = vec4(body, 1.0) * mainA;
        outc = top + under * (1.0 - top.a);
    } else if (frame > 0.5) {
        float pitch = clamp(lenPx / max(bands, 1.0), 5.0, 14.0);
        float cell = pitch - 2.0;
        vec2 g = p + hb;
        vec2 cc = (floor(g / pitch) + 0.5) * pitch - hb;
        vec2 fp = frameParam(cc, hb);
        float cbx = clamp(fp.x / fp.y, 0.0, 1.0);
        float chPx = min(curveAt(cbx) * depth * lift, cap);
        float cin = sdBox(cc, hb - chPx, rin);
        float cdepth = -sdBox(cc, hb, R);
        vec2 m = mod(g, pitch);
        float inCell = (1.0 - step(cell, m.x)) * (1.0 - step(cell, m.y)) * step(0.0, cdepth);
        float lit = step(0.0, cin) * step(0.0005, chPx);
        float topRow = lit * (1.0 - step(pitch, cin));
        vec3 ctint = mix(lowColor.rgb, highColor.rgb, gradient * smoothstep(0.0, 1.0, cbx));
        vec3 c = mix(ctint, vec3(1.0), 0.16 * pulse + 0.25 * topRow);
        float off = 0.06 * (1.0 - step(depth, cdepth)) * presence;
        float a = inCell * (lit * presence + (1.0 - lit) * off);
        outc = vec4(c, 1.0) * a;
    } else {
        float pitchX = lenPx / max(bands, 1.0);
        float cellX = max(1.0, pitchX - 2.0);
        float pitchY = 6.0;
        float cellY = 4.0;
        float ci = floor(sPx / pitchX);
        float cAlong = clamp((ci + 0.5) * pitchX / max(lenPx, 1.0), 0.0, 1.0);
        float cbx = bandOf(cAlong);
        float chPx = curveAt(cbx) * depth * lift;
        float ri = floor(yPx / pitchY);
        float inCell = (1.0 - step(cellX, mod(sPx, pitchX))) * (1.0 - step(cellY, mod(yPx, pitchY))) * step(0.0, yPx);
        float lit = step(ri * pitchY + 0.5, chPx);
        float topRow = lit * (1.0 - step((ri + 1.0) * pitchY + 0.5, chPx));
        vec3 ctint = mix(lowColor.rgb, highColor.rgb, gradient * smoothstep(0.0, 1.0, cbx));
        vec3 c = mix(ctint, vec3(1.0), 0.16 * pulse + 0.25 * topRow);
        float off = 0.06 * (1.0 - step(depth, yPx)) * presence;
        float a = inCell * (lit * presence + (1.0 - lit) * off);
        outc = vec4(c, 1.0) * a;
    }

    fragColor = outc * qt_Opacity;
}
