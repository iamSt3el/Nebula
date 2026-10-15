#version 440

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

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
    vec4 pill[96];
    vec4 seg[192];
    vec4 flare[32];
    vec4 tab[56];
};

out gl_PerVertex { vec4 gl_Position; };

void main()
{
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * qt_Vertex;
}
