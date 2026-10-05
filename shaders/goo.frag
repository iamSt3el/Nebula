#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 b0;
    vec4 b1;
    vec4 b2;
    vec4 color;
    float k;
    float neck;
};

float smin(float a, float b, float r) {
    float h = clamp(0.5 + 0.5 * (b - a) / r, 0.0, 1.0);
    return mix(b, a, h) - r * h * (1.0 - h);
}

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
    return length(pa - ba * h);
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    float d = length(p - b0.xy) - b0.z;
    d = smin(d, length(p - b1.xy) - b1.z, k);
    d = smin(d, segment(p, b0.xy, b1.xy) - neck, k);
    d = smin(d, length(p - b2.xy) - b2.z, k);
    float a = clamp(0.5 - d, 0.0, 1.0) * color.a * qt_Opacity;
    fragColor = vec4(color.rgb * a, a);
}
