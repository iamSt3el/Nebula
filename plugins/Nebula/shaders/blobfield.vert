#version 440

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

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
};

out gl_PerVertex { vec4 gl_Position; };

void main()
{
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * qt_Vertex;
}
