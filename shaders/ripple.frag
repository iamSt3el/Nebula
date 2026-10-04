#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 r0;
    vec4 r1;
    vec4 r2;
    vec4 r3;
    vec4 r4;
    vec4 r5;
    vec4 r6;
    vec4 r7;
    vec4 r8;
    vec4 r9;
    vec4 tint;
    float strength;
    vec4 view;
};

layout(binding = 1) uniform sampler2D source;

const float SPEED = 540.0;
const float WAVELEN = 58.0;
const float TAU = 6.28318530718;

float height(float dist, float age, float amp, out float env) {
    float front = age * SPEED;
    float ahead = max(dist - front, 0.0);
    float behind = max(front - dist, 0.0);
    float tail = 150.0 + age * 170.0;
    float shape = exp(-ahead * ahead / 900.0) * exp(-behind / tail);
    float spread = inversesqrt(1.0 + dist / 220.0);
    float life = exp(-age * 1.15) * (1.0 - smoothstep(1.8, 2.5, age));
    float lambda = WAVELEN * (0.75 + 0.25 * clamp(behind / 260.0, 0.0, 1.0));
    float wave = sin((dist - front) / lambda * TAU);
    float a = amp * life * spread;
    env = a * shape;
    float h = wave * env;
    float splashT = clamp(age / 0.32, 0.0, 1.0);
    float splash = exp(-dist * dist / 900.0) * (1.0 - splashT) * (1.0 - splashT) * amp;
    env += splash * 0.8;
    return h - splash * 0.9;
}

void addRipple(vec4 r, vec2 p, inout vec2 grad, inout float h, inout float env) {
    if (r.w <= 0.0 || r.z < 0.0)
        return;
    vec2 d = p - r.xy;
    float dist = length(d);
    float e0, e1, e2;
    float h0 = height(dist, r.z, r.w, e0);
    float h1 = height(dist + 1.0, r.z, r.w, e1);
    float h2 = height(max(dist - 1.0, 0.0), r.z, r.w, e2);
    vec2 dir = d / max(dist, 1.0);
    grad += dir * (h1 - h2) * 0.5;
    h += h0;
    env += e0;
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    vec2 grad = vec2(0.0);
    float h = 0.0;
    float env = 0.0;
    addRipple(r0, p, grad, h, env);
    addRipple(r1, p, grad, h, env);
    addRipple(r2, p, grad, h, env);
    addRipple(r3, p, grad, h, env);
    addRipple(r4, p, grad, h, env);
    addRipple(r5, p, grad, h, env);
    addRipple(r6, p, grad, h, env);
    addRipple(r7, p, grad, h, env);
    addRipple(r8, p, grad, h, env);
    addRipple(r9, p, grad, h, env);

    float a = clamp(env * 5.0, 0.0, 1.0);
    if (a < 0.003) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 slope = grad * 9.0 * strength;
    vec2 off = -slope * 14.0;
    vec2 uv = p / itemSize;
    vec2 px = 1.0 / itemSize;
    float cr = texture(source, view.xy + (uv + off * px * 1.10) * view.zw).r;
    float cg = texture(source, view.xy + (uv + off * px) * view.zw).g;
    float cb = texture(source, view.xy + (uv + off * px * 0.90) * view.zw).b;
    vec2 t = view.xy + uv * view.zw;
    vec2 e = step(vec2(-0.002), t) * step(t, vec2(1.002));
    vec3 col = vec3(cr, cg, cb) * e.x * e.y;

    vec3 n = normalize(vec3(-slope, 1.0));
    vec3 L = normalize(vec3(-0.45, -0.65, 0.62));
    float diff = dot(n, L) - L.z;
    vec3 R = reflect(-L, n);
    float spec = pow(max(R.z, 0.0), 70.0);
    float rim = pow(1.0 - n.z, 2.0);

    col *= 1.0 + diff * 0.9;
    col += tint.rgb * (max(h, 0.0) * 0.22 + rim * 0.9) * strength;
    col += vec3(spec) * 0.55 * min(strength, 1.3);

    fragColor = vec4(clamp(col, 0.0, 1.0) * a, a) * qt_Opacity;
}
