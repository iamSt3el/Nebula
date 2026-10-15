#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float lineWidth;
    float outsideAlpha;
    float outer;
    vec4 lineColor;
};

layout(binding = 1) uniform sampler2D source;

float alphaAt(vec2 uv) {
    if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0)
        return outsideAlpha;
    return texture(source, uv).a;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 col = texture(source, uv);
    float a0 = col.a;
    vec2 step = lineWidth / max(itemSize, vec2(1.0));
    if (outer > 0.5) {
        if (a0 >= 0.999) {
            fragColor = col * qt_Opacity;
            return;
        }
        float hi = 0.0;
        for (int i = 0; i < 24; i++) {
            float t = float(i) * 0.26179939;
            vec2 d = vec2(cos(t), sin(t));
            hi = max(hi, texture(source, uv + d * step).a);
            hi = max(hi, texture(source, uv + d * step * 0.5).a);
        }
        float s = smoothstep(0.25, 0.75, hi);
        fragColor = (col + vec4(lineColor.rgb, 1.0) * s * (1.0 - a0)) * qt_Opacity;
        return;
    }
    if (a0 <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    vec2 px = 1.0 / max(itemSize, vec2(1.0));
    float reach = lineWidth + 1.0;
    bool deep = true;
    for (int i = 0; i < 8; i++) {
        float t = float(i) * 0.78539816;
        if (alphaAt(uv + vec2(cos(t), sin(t)) * px * reach) < 0.999) {
            deep = false;
            break;
        }
    }
    if (deep) {
        fragColor = col * qt_Opacity;
        return;
    }
    float depth = a0 < 0.999 ? a0 - 0.5 : 1.0e4;
    for (int k = 1; k <= 6; k++) {
        float r = float(k) * 0.5;
        if (r > reach + 0.01)
            break;
        for (int i = 0; i < 20; i++) {
            float t = (float(i) + 0.5 * mod(float(k), 2.0)) * 0.31415927;
            float ak = alphaAt(uv + vec2(cos(t), sin(t)) * px * r);
            if (ak < 0.999)
                depth = min(depth, r + ak - 0.5);
        }
    }
    float s = 1.0 - smoothstep(lineWidth - 0.5, lineWidth + 0.5, depth);
    vec4 line = vec4(lineColor.rgb, 1.0) * a0;
    fragColor = mix(col, line, s) * qt_Opacity;
}
