#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float edgeW;
    float smoothing;
    int count;
    vec4 fillColor;
    vec4 edgeColor;
    vec4 shadowColor;
    vec4 shadowInfo;
    vec4 frameHole;
    vec4 frameRad;
    vec4 rect[16];
    vec4 radii[16];
    vec4 extra[16];
    vec4 paint[16];
};

const float far = 1.0e5;

float sdCorners(vec2 p, vec2 c, vec2 h, vec4 rr) {
    float r = p.x < c.x ? (p.y < c.y ? rr.x : rr.z) : (p.y < c.y ? rr.y : rr.w);
    r = min(r, min(h.x, h.y));
    vec2 e = abs(p - c) - h + r;
    return min(max(e.x, e.y), 0.0) + length(max(e, 0.0)) - r;
}

vec3 sdgCorners(vec2 p, vec2 c, vec2 h, vec4 rr) {
    vec2 q = p - c;
    float r = q.x < 0.0 ? (q.y < 0.0 ? rr.x : rr.z) : (q.y < 0.0 ? rr.y : rr.w);
    r = min(r, min(h.x, h.y));
    vec2 sg = vec2(q.x < 0.0 ? -1.0 : 1.0, q.y < 0.0 ? -1.0 : 1.0);
    vec2 e = abs(q) - h + r;
    if (max(e.x, e.y) > 0.0) {
        vec2 m = max(e, 0.0);
        float l = length(m);
        return vec3(l - r, sg * m / max(l, 1.0e-5));
    }
    return vec3(max(e.x, e.y) - r, e.x > e.y ? vec2(sg.x, 0.0) : vec2(0.0, sg.y));
}

float facing(vec2 a, vec2 b) {
    return clamp(1.0 - dot(a, b), 0.0, 1.0);
}

float unionRound(float a, float b, float k) {
    if (k < 0.01)
        return min(a, b);
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

float mergeK(float gap, float scale) {
    float k = smoothing * scale;
    float reach = 0.293 * k;
    return k * clamp(1.0 - gap / max(reach, 0.001), 0.0, 1.0);
}

float boxGap(vec4 a, vec4 b) {
    vec2 d = abs(a.xy - b.xy) - (a.zw + b.zw);
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float gooGroup(float v) {
    return floor(abs(v) / 64.0);
}

float gooK(float v) {
    return abs(v) - 64.0 * gooGroup(v);
}

float pairK(int i, int j) {
    float a = extra[i].w;
    float b = extra[j].w;
    if (a < 0.0 || b < 0.0) {
        if (a == 0.0 || b == 0.0 || gooGroup(a) != gooGroup(b))
            return 0.0;
        return max(gooK(a), gooK(b));
    }
    return mergeK(boxGap(rect[i], rect[j]), min(extra[i].x, extra[j].x));
}

float pocket(vec2 p, vec4 a, vec4 b) {
    vec2 lo = min(a.xy - a.zw, b.xy - b.zw);
    vec2 hi = max(a.xy + a.zw, b.xy + b.zw);
    vec2 q = max(lo - p, p - hi);
    return clamp(0.5 - max(q.x, q.y), 0.0, 1.0);
}

float frameGap(vec4 a) {
    return min(min(a.x - a.z - frameHole.x, frameHole.z - (a.x + a.z)),
               min(a.y - a.w - frameHole.y, frameHole.w - (a.y + a.w)));
}

void main() {
    vec2 p = qt_TexCoord0;
    bool nearFrame = shadowInfo.z > 0.5;
    vec2 hc = (frameHole.xy + frameHole.zw) * 0.5;
    vec2 hh = (frameHole.zw - frameHole.xy) * 0.5;
    vec3 fg = nearFrame ? sdgCorners(p, hc, hh, frameRad) : vec3(-far, 0.0, 0.0);
    float dF = -fg.x;
    vec2 nF = -fg.yz;

    float d[16];
    vec2 n[16];
    float m = dF;
    for (int i = 0; i < 16; i++) {
        if (i >= count)
            break;
        vec3 g = sdgCorners(p, rect[i].xy, rect[i].zw, radii[i]);
        d[i] = g.x;
        n[i] = g.yz;
        m = min(m, d[i]);
    }
    for (int i = 0; i < 16; i++) {
        if (i >= count)
            break;
        if (d[i] >= max(smoothing, gooK(extra[i].w)))
            continue;
        if (nearFrame && dF < smoothing && extra[i].w >= 0.0)
            m = min(m, unionRound(d[i], dF, mergeK(frameGap(rect[i]), extra[i].y) * facing(n[i], nF)));
        for (int j = i + 1; j < 16; j++) {
            if (j >= count)
                break;
            if (d[j] >= max(smoothing, max(gooK(extra[i].w), gooK(extra[j].w))))
                continue;
            m = min(m, unionRound(d[i], d[j], pairK(i, j) * pocket(p, rect[i], rect[j]) * (1.0 - max(extra[i].z, extra[j].z))));
        }
    }

    float w = clamp(length(vec2(dFdx(m), dFdy(m))), 1.0e-4, 1.0);

    float tintK = 0.0;
    vec3 tintRgb = vec3(0.0);
    float clearK = 0.0;
    float shadeK = 0.0;
    float lineK = 0.0;
    float keep = 0.0;
    float reach = max(shadowInfo.x, 1.0);
    for (int i = 0; i < 16; i++) {
        if (i >= count)
            break;
        float cov = clamp(0.5 - (d[i] - 1.0) / w, 0.0, 1.0);
        float c = extra[i].z;
        if (c > 0.0) {
            clearK = max(clearK, c * cov);
            shadeK = max(shadeK, c * (1.0 - smoothstep(0.0, reach, d[i])));
            lineK = max(lineK, c * (1.0 - smoothstep(edgeW + 0.5, edgeW + 2.0, d[i])));
        } else {
            keep = max(keep, clamp(0.5 - d[i] / w, 0.0, 1.0));
        }
        if (paint[i].w > 0.0 && cov * paint[i].w > tintK) {
            tintK = cov * paint[i].w;
            tintRgb = paint[i].rgb;
        }
    }
    clearK *= 1.0 - keep;
    shadeK *= 1.0 - keep;

    float a = clamp(0.5 - m / w, 0.0, 1.0) * fillColor.a;
    vec3 rgb = tintK > 0.0 ? mix(fillColor.rgb, tintRgb, tintK) : fillColor.rgb;
    a *= 1.0 - clearK;
    vec4 col = vec4(rgb * a, a);
    if (edgeW > 0.0) {
        float band = 1.0 - smoothstep(edgeW - 0.5 * w, edgeW + 0.5 * w, m);
        float lineA = band * edgeColor.a * (1.0 - lineK);
        col += vec4(edgeColor.rgb * lineA, lineA) * (1.0 - col.a);
    }
    if (shadowInfo.x > 0.0 && shadowInfo.y > 0.0 && col.a < 1.0) {
        float s = (1.0 - smoothstep(0.0, 1.0, clamp(m / shadowInfo.x, 0.0, 1.0))) * (1.0 - shadeK);
        float sa = s * s * shadowInfo.y * shadowColor.a;
        col += vec4(shadowColor.rgb * sa, sa) * (1.0 - col.a);
    }
    fragColor = col * qt_Opacity;
}
