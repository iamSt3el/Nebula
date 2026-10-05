#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float unit;
    float poolY;
    float phase;
    float heat;
    float cornerRadius;
    vec4 b0;
    vec4 b1;
    vec4 b2;
    vec4 b3;
    vec4 b4;
    vec4 b5;
    vec4 b6;
    vec4 b7;
    vec4 tempA;
    vec4 tempB;
    vec4 waxHot;
    vec4 waxCool;
    vec4 music;
};

const float TAU = 6.2831853;
const float ISO = 0.4219;

float roundBox(vec2 p, vec2 half_, float r) {
    vec2 q = abs(p) - half_ + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float pool(vec2 q) {
    float gap = poolY - q.y
        + 0.012 * sin(q.x * 7.0 + TAU * 3.0 * phase)
        + 0.007 * sin(q.x * 13.0 - TAU * 5.0 * phase);
    float dx = abs(q.x - music.z);
    float front = smoothstep(0.0, 1.5, music.y * 16.0 - dx * 22.0 + 1.5);
    gap += music.x * cos(dx * 22.0 - music.y * 16.0) * exp(-dx * 2.5) * front;
    return ISO * exp(-gap * 22.0);
}

float kern(vec2 q, vec4 b) {
    vec2 e = q - b.xy;
    float sq = sqrt(1.0 + 0.6 * abs(b.w));
    float tear = clamp(b.w, -0.4, 0.5);
    float widen = 1.0 + tear * 0.7 * clamp(e.y / b.z, -1.0, 1.0);
    vec2 s = vec2(e.x * sq * widen, e.y / sq);
    float k = max(0.0, 1.0 - dot(s, s) / (4.0 * b.z * b.z));
    return k * k * k;
}

float field(vec2 q) {
    return min(pool(q), 4.0)
        + kern(q, b0) + kern(q, b1) + kern(q, b2) + kern(q, b3)
        + kern(q, b4) + kern(q, b5) + kern(q, b6) + kern(q, b7);
}

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    vec2 q = vec2(px.x - itemSize.x * 0.5, px.y) / unit;

    float fp = min(pool(q), 4.0);
    float k0 = kern(q, b0), k1 = kern(q, b1), k2 = kern(q, b2), k3 = kern(q, b3);
    float k4 = kern(q, b4), k5 = kern(q, b5), k6 = kern(q, b6), k7 = kern(q, b7);
    float f = fp + k0 + k1 + k2 + k3 + k4 + k5 + k6 + k7;

    vec4 c = vec4(0.0);

    if (f > 0.04) {
        const float eps = 0.006;
        vec2 grad = vec2(field(q + vec2(eps, 0.0)) - field(q - vec2(eps, 0.0)),
                         field(q + vec2(0.0, eps)) - field(q - vec2(0.0, eps))) / (2.0 * eps);
        float g = max(length(grad), 1e-4);
        float dpx = (ISO - f) / g * unit;
        float wax = clamp(0.5 - dpx, 0.0, 1.0);

        vec2 out_ = -grad / g;
        float x = 1.0 - clamp((4.0 * pow(f, 1.0 / 3.0) - 3.0) / 1.6, 0.0, 1.0);
        float z = sqrt(1.0 - x * x);
        z = mix(0.12, 1.0, z);
        vec3 n = normalize(vec3(out_ * sqrt(1.0 - z * z), z));

        float t = (fp * 0.9 + k0 * tempA.x + k1 * tempA.y + k2 * tempA.z + k3 * tempA.w
                 + k4 * tempB.x + k5 * tempB.y + k6 * tempB.z + k7 * tempB.w) / max(f, 1e-4);
        t = clamp(t, 0.0, 1.0);
        vec3 base = mix(waxCool.rgb, waxHot.rgb, smoothstep(0.25, 0.8, t));
        base *= 0.85 + 0.25 * t;

        vec3 key = normalize(vec3(-0.45, -0.6, 0.65));
        float diff = max(dot(n, key), 0.0);
        float bulb = pow(max(dot(n, normalize(vec3(0.0, 1.0, 0.25))), 0.0), 1.5);
        float spec = pow(max(dot(n, normalize(key + vec3(0.0, 0.0, 1.0))), 0.0), 40.0);
        float rim = pow(1.0 - n.z, 3.0);

        vec3 col = base * (0.6 + 0.4 * diff);
        col += waxHot.rgb * bulb * (0.25 + 0.25 * heat) * (0.6 + 0.4 * t);
        col = mix(col, vec3(1.0), min(1.0, 0.5 * spec * (1.0 + 1.2 * music.w)));
        col *= 1.0 - 0.2 * rim * (1.0 - bulb);

        float halo = (1.0 - wax) * 0.22 * (0.5 + 0.5 * heat + 0.6 * music.w) * smoothstep(0.04, ISO, f);
        c = vec4(col * wax, wax) + vec4(waxHot.rgb * halo, halo);
    }

    float box = roundBox(px - itemSize * 0.5, itemSize * 0.5, cornerRadius);
    float clip = clamp(0.5 - box, 0.0, 1.0);
    fragColor = c * clip * qt_Opacity;
}
