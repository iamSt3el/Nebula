#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec2 center;
    float radius;
    float feather;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    float d = distance(qt_TexCoord0 * itemSize, center);
    float t = clamp((d - radius + feather) / max(feather, 1.0), 0.0, 1.0);
    float keep = t * t * (3.0 - 2.0 * t);
    fragColor = texture(source, qt_TexCoord0) * keep * qt_Opacity;
}
