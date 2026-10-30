#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D mask;

void main() {
    float keep = clamp(texture(mask, qt_TexCoord0).a * 40.0, 0.0, 1.0);
    fragColor = texture(source, qt_TexCoord0) * keep * qt_Opacity;
}
