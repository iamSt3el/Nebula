#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float progress;
    float mode;
    vec2 origin;
    float time;
    float seed;
    vec4 accent;
    vec4 fromView;
    vec4 toView;
};

layout(binding = 1) uniform sampler2D fromTex;
layout(binding = 2) uniform sampler2D toTex;

const float PI = 3.14159265;

float fall(float a, float b, float x) { return 1.0 - smoothstep(a, b, x); }

float h21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec2 h22(vec2 p) {
    float n = h21(p);
    return vec2(n, h21(p + n));
}

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x),
               mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) {
        s += a * vnoise(p);
        p = p * 2.03 + 17.1;
        a *= 0.5;
    }
    return s;
}

mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, s, -s, c);
}

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

float farCorner(vec2 o) {
    return max(max(length(o), length(o - vec2(itemSize.x, 0.0))),
               max(length(o - vec2(0.0, itemSize.y)), length(o - itemSize)));
}

float inside(vec2 t) {
    vec2 e = step(vec2(-0.002), t) * step(t, vec2(1.002));
    return e.x * e.y;
}

vec4 A(vec2 uv) {
    vec2 t = fromView.xy + uv * fromView.zw;
    return vec4(texture(fromTex, t).rgb * inside(t), 1.0);
}
vec4 B(vec2 uv) {
    vec2 t = toView.xy + uv * toView.zw;
    return vec4(texture(toTex, t).rgb * inside(t), 1.0);
}

vec2 cellCenter(vec2 cell, float cs) { return (cell + 0.15 + 0.7 * h22(cell + seed)) * cs; }

vec3 vor(vec2 p, float cs) {
    vec2 g = floor(p / cs);
    float d1 = 1e9, d2 = 1e9;
    vec2 best = g;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 cell = g + vec2(float(x), float(y));
            float d = distance(p, cellCenter(cell, cs));
            if (d < d1) {
                d2 = d1;
                d1 = d;
                best = cell;
            } else if (d < d2) {
                d2 = d;
            }
        }
    }
    return vec3(best, d2 - d1);
}

vec4 hexCoords(vec2 u) {
    vec2 r = vec2(1.0, 1.7320508);
    vec2 h = r * 0.5;
    vec2 a = mod(u, r) - h;
    vec2 b = mod(u - h, r) - h;
    vec2 gv = dot(a, a) < dot(b, b) ? a : b;
    return vec4(gv, u - gv);
}

vec4 ink(vec2 uv, vec2 p) {
    float d = distance(p, origin) / farCorner(origin);
    vec2 q = uv * vec2(itemSize.x / itemSize.y, 1.0) * 3.0;
    float n = fbm(q + seed * 7.0);
    float field = d * 0.75 + n * 0.45;
    float front = mix(-0.08, 1.25, progress);
    float m = fall(front - 0.02, front + 0.015, field);
    float band = fall(0.0, 0.09, abs(field - front + 0.02));
    vec2 warp = (vec2(fbm(q * 2.0 + 3.0), fbm(q * 2.0 + 9.0)) - 0.5) * 0.035 * band;
    vec3 col = mix(A(uv + warp).rgb, B(uv - warp * 0.5).rgb, m);
    float rim = fall(0.0, 0.035, abs(field - front + 0.005)) * fall(0.85, 1.0, progress);
    col = mix(col, col * 0.25 + accent.rgb * 0.55, rim * 0.85);
    col *= 1.0 - band * 0.25 * (1.0 - m);
    return vec4(col, 1.0);
}

vec4 ember(vec2 uv, vec2 p) {
    float d = distance(p, origin) / farCorner(origin);
    vec2 q = uv * vec2(itemSize.x / itemSize.y, 1.0) * 2.5;
    float n = fbm(q + seed * 5.0);
    float field = d * 0.55 + n * 0.6;
    float front = mix(-0.1, 1.25, progress);
    float dist = field - front;
    float burnt = fall(-0.01, 0.01, dist);
    float charZ = fall(0.0, 0.08, dist) * step(0.0, dist);
    float glowLine = fall(0.0, 0.018, abs(dist));
    vec2 heat = vec2(0.0, (vnoise(q * 8.0 + time * 3.0) - 0.5) * 0.012) * fall(0.0, 0.15, max(dist, 0.0));
    vec3 a = A(uv + heat).rgb;
    a = mix(a, a * 0.18 + vec3(0.06, 0.03, 0.02), charZ * 0.9);
    vec3 col = mix(a, B(uv).rgb, burnt);
    vec3 glow = mix(vec3(1.0, 0.5, 0.12), accent.rgb, 0.3) * 2.2;
    float flicker = 0.75 + 0.25 * vnoise(q * 20.0 + time * 6.0);
    col += glow * glowLine * flicker * fall(0.9, 1.0, progress);
    return vec4(col, 1.0);
}

vec4 shatter(vec2 uv, vec2 p) {
    float cs = itemSize.y / 5.0;
    vec3 v = vor(p, cs);
    vec2 cell = v.xy;
    vec2 c = cellCenter(cell, cs);
    float t0 = distance(c, origin) / farCorner(origin) * 0.55 + h21(cell + 3.0) * 0.12;
    float local = clamp((progress - t0) / 0.33, 0.0, 1.0);
    vec3 bcol = B(uv).rgb;
    if (local <= 0.0) {
        float crack = fall(0.0, 2.5, v.z) * smoothstep(t0 - 0.14, t0, progress);
        vec3 col = A(uv).rgb;
        col = mix(col, vec3(0.92) + accent.rgb * 0.2, crack * 0.85);
        return vec4(col, 1.0);
    }
    float e = local * local;
    float s = 1.0 - e;
    if (s < 0.02)
        return vec4(bcol, 1.0);
    float ang = (h21(cell + 7.0) - 0.5) * 2.4 * e;
    vec2 drop = vec2((h21(cell + 11.0) - 0.5) * 0.3, 0.35) * e * cs;
    vec2 rel = rot(-ang) * (p - c - drop);
    vec2 q = c + rel / s;
    vec3 vq = vor(q, cs);
    if (vq.x == cell.x && vq.y == cell.y) {
        vec3 col = A(q / itemSize).rgb;
        col += fall(0.0, 6.0, vq.z) * 0.35 * (1.0 - e);
        col *= 1.0 - e * 0.35;
        return vec4(mix(col, bcol, smoothstep(0.75, 1.0, local)), 1.0);
    }
    return vec4(bcol * (0.8 + 0.2 * local), 1.0);
}

vec4 hexFlip(vec2 uv, vec2 p) {
    float R = itemSize.y / 8.0;
    vec4 hc = hexCoords(p / R);
    vec2 gv = hc.xy;
    vec2 cpx = hc.zw * R;
    float t0 = distance(cpx, origin) / farCorner(origin) * 0.6 + h21(hc.zw) * 0.08;
    float local = clamp((progress - t0) / 0.32, 0.0, 1.0);
    if (local <= 0.0)
        return A(uv);
    if (local >= 1.0)
        return B(uv);
    float sx = abs(cos(local * PI));
    vec3 bg = vec3(0.045, 0.035, 0.03);
    if (sx < 0.002)
        return vec4(bg, 1.0);
    vec2 g2 = vec2(gv.x / sx, gv.y);
    float hd = max(dot(abs(g2), normalize(vec2(1.0, 1.7320508))), abs(g2.x));
    float inner = 0.5 - 0.045 * sin(local * PI);
    if (hd > inner)
        return vec4(bg, 1.0);
    vec2 q = (hc.zw + g2) * R / itemSize;
    vec3 col = local < 0.5 ? A(q).rgb : B(q).rgb;
    col *= 0.5 + 0.5 * sx;
    float rimT = smoothstep(inner - 0.07, inner, hd) * sin(local * PI);
    col = mix(col, accent.rgb, rimT * 0.65);
    return vec4(col, 1.0);
}

vec4 shockwave(vec2 uv, vec2 p) {
    float md = farCorner(origin);
    float W = itemSize.y * 0.12;
    float r = mix(-W, md + W, progress);
    float d = distance(p, origin);
    float x = (d - r) / W;
    float band = fall(0.0, 1.0, abs(x));
    vec2 dir = normalize(p - origin + 0.0001);
    float push = sin(clamp(x, -1.0, 1.0) * PI) * band * 26.0;
    vec2 off = dir * push / itemSize;
    vec2 sp = dir * band * 0.006;
    vec3 a = vec3(A(uv - off - sp).r, A(uv - off).g, A(uv - off + sp).b);
    vec3 b = vec3(B(uv - off - sp).r, B(uv - off).g, B(uv - off + sp).b);
    vec3 col = mix(a, b, fall(-0.05, 0.05, x));
    col += accent.rgb * band * band * band * 0.45 * (1.0 - progress * 0.6);
    return vec4(col, 1.0);
}

vec4 vortex(vec2 uv, vec2 p) {
    vec2 rel = p - origin;
    float md = farCorner(origin);
    float d = length(rel);
    float k = sin(progress * PI);
    float tw = k * k * 7.0 * pow(max(0.0, 1.0 - d / (md * 0.9)), 2.0);
    vec2 q = (origin + rot(tw) * rel * (1.0 - 0.12 * k)) / itemSize;
    vec3 col = mix(A(q).rgb, B(q).rgb, smoothstep(0.38, 0.62, progress));
    col *= 1.0 - 0.35 * k * smoothstep(md * 0.2, md * 0.9, d);
    return vec4(col, 1.0);
}

vec4 lightFirst(vec2 uv, vec2 p) {
    vec3 a = A(uv).rgb;
    vec3 b = B(uv).rgb;
    vec2 px = 3.0 / itemSize;
    float lb = (luma(b) + luma(B(uv + vec2(px.x, 0.0)).rgb) + luma(B(uv - vec2(px.x, 0.0)).rgb)
              + luma(B(uv + vec2(0.0, px.y)).rgb) + luma(B(uv - vec2(0.0, px.y)).rgb)) / 5.0;
    float key = (1.0 - lb) * 0.85 + vnoise(uv * 40.0 + seed) * 0.15;
    float th = mix(-0.15, 1.1, progress);
    float m = fall(th - 0.12, th, key);
    float edge = fall(0.0, 0.06, abs(key - th + 0.06)) * fall(0.85, 1.0, progress);
    vec3 col = mix(a, b, m);
    col += (b * 0.6 + accent.rgb * 0.6) * edge * 0.8;
    return vec4(col, 1.0);
}

vec4 melt(vec2 uv, vec2 p) {
    float n = vnoise(vec2(uv.x * itemSize.x / 28.0, seed * 10.0)) * 0.6
            + h21(vec2(floor(uv.x * itemSize.x / 4.0), seed)) * 0.12;
    float speed = 0.9 + n * 1.4;
    float off = pow(progress, 1.8) * speed * 1.25;
    float sy = uv.y - off;
    if (sy < 0.0) {
        float sh = fall(0.0, 0.05, -sy);
        return vec4(B(uv).rgb * (1.0 - 0.45 * sh), 1.0);
    }
    vec3 a = A(vec2(uv.x, sy)).rgb;
    float lip = fall(0.0, 0.012, sy) * step(0.001, off);
    a = mix(a, a * 1.2 + accent.rgb * 0.25, lip);
    return vec4(a, 1.0);
}

vec4 blinds(vec2 uv, vec2 p) {
    float N = 11.0;
    float sh = itemSize.y / N;
    float idx = floor(p.y / sh);
    float ly = p.y - (idx + 0.5) * sh;
    float oi = floor(origin.y / sh);
    float t0 = abs(idx - oi) / N * 0.55;
    float local = clamp((progress - t0) / 0.42, 0.0, 1.0);
    float e = local < 0.5 ? 4.0 * local * local * local : 1.0 - pow(-2.0 * local + 2.0, 3.0) / 2.0;
    float ang = e * PI;
    float cs = cos(ang);
    float ac = abs(cs);
    vec3 bg = vec3(0.04, 0.03, 0.03);
    if (ac < 0.01)
        return vec4(bg, 1.0);
    float qy = ly / ac;
    if (abs(qy) > sh * 0.5)
        return vec4(bg, 1.0);
    vec2 q = vec2(p.x, (idx + 0.5) * sh + qy) / itemSize;
    vec3 col = cs > 0.0 ? A(q).rgb : B(q).rgb;
    col *= 0.55 + 0.45 * ac;
    col += accent.rgb * smoothstep(sh * 0.42, sh * 0.5, abs(qy)) * sin(ang) * 0.35;
    return vec4(col, 1.0);
}

vec4 glitch(vec2 uv, vec2 p) {
    float k = pow(sin(progress * PI), 0.7);
    float tq = floor(time * 18.0);
    float rowH = itemSize.y / (18.0 + 20.0 * h21(vec2(tq, 1.0)));
    float row = floor(p.y / rowH);
    float shift = (h21(vec2(row, tq)) - 0.5) * 0.18 * k * step(0.55, h21(vec2(row, tq + 3.0)));
    float bx = floor(uv.x * 6.0);
    float sel = progress + (h21(vec2(row + bx * 7.0, tq + 5.0)) - 0.5) * 1.2 * k;
    vec2 q = vec2(uv.x + shift, uv.y);
    float sp = 0.012 * k;
    vec3 a = vec3(A(q + vec2(sp, 0.0)).r, A(q).g, A(q - vec2(sp, 0.0)).b);
    vec3 b = vec3(B(q + vec2(sp, 0.0)).r, B(q).g, B(q - vec2(sp, 0.0)).b);
    vec3 col = sel > 0.5 ? b : a;
    col = mix(col, accent.rgb, step(0.94, h21(vec2(row * 5.0 + bx, tq + 13.0))) * k * 0.7);
    col *= 1.0 - 0.12 * k * step(0.5, fract(p.y / 3.0));
    return vec4(col, 1.0);
}

vec4 mosaic(vec2 uv, vec2 p) {
    float k = sin(progress * PI);
    float bs = floor(mix(1.0, 44.0, k * k));
    vec2 cell = floor(p / bs);
    vec2 cpx = (cell + 0.5) * bs;
    vec2 q = bs < 1.5 ? uv : cpx / itemSize;
    float t0 = distance(cpx, origin) / farCorner(origin);
    float sel = progress * 1.5 - t0 * 0.5 + (h21(cell + seed) - 0.5) * 0.25 * k;
    vec3 col = sel > 0.5 ? B(q).rgb : A(q).rgb;
    vec2 f = fract(p / bs);
    float bev = bs > 3.0 ? smoothstep(0.0, 0.12, f.x) * smoothstep(0.0, 0.12, f.y) : 1.0;
    col *= mix(1.0, 0.8 + 0.2 * bev, k);
    col = mix(col, accent.rgb, fall(0.0, 0.12, abs(sel - 0.5)) * k * 0.35);
    return vec4(col, 1.0);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = uv * itemSize;
    int m = int(mode + 0.5);
    vec4 c;
    if (m == 0) c = ink(uv, p);
    else if (m == 1) c = ember(uv, p);
    else if (m == 2) c = shatter(uv, p);
    else if (m == 3) c = hexFlip(uv, p);
    else if (m == 4) c = shockwave(uv, p);
    else if (m == 5) c = vortex(uv, p);
    else if (m == 6) c = lightFirst(uv, p);
    else if (m == 7) c = melt(uv, p);
    else if (m == 8) c = blinds(uv, p);
    else if (m == 9) c = glitch(uv, p);
    else c = mosaic(uv, p);
    fragColor = c * qt_Opacity;
}
