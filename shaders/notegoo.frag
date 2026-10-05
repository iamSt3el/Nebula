#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 nub;
    vec4 blob;
    vec4 color;
    float nubR;
    float blobR;
    float k;
};

float box(vec2 p, vec4 r, float rad) {
    vec2 h = r.zw * 0.5;
    vec2 c = r.xy + h;
    float rr = min(rad, min(h.x, h.y));
    vec2 q = abs(p - c) - h + rr;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rr;
}

float smin(float a, float b, float r) {
    float h = clamp(0.5 + 0.5 * (b - a) / r, 0.0, 1.0);
    return mix(b, a, h) - r * h * (1.0 - h);
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    float d = smin(box(p, nub, nubR), box(p, blob, blobR), k);
    float a = clamp(0.5 - d, 0.0, 1.0) * color.a * qt_Opacity;
    fragColor = vec4(color.rgb * a, a);
}
