.pragma library

function clamp(v) { return Math.max(0, Math.min(1, v)) }
function seg(p, a, b) { return clamp((p - a) / (b - a)) }
function lerp(a, b, t) { return a + (b - a) * t }
function glerp(a, b, t) { return Math.exp(lerp(Math.log(Math.max(a, 0.001)), Math.log(Math.max(b, 0.001)), t)) }

function bezier(x1, y1, x2, y2, x) {
    if (x <= 0) return 0
    if (x >= 1) return 1
    const cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx
    const cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by
    let t = x
    for (let i = 0; i < 10; i++) {
        const d = (3 * ax * t + 2 * bx) * t + cx
        if (Math.abs(d) < 1e-7) break
        t -= (((ax * t + bx) * t + cx) * t - x) / d
    }
    t = clamp(t)
    return ((ay * t + by) * t + cy) * t
}
function std(x) { return bezier(0.2, 0, 0, 1, x) }
function soft(x) { return bezier(0.4, 0, 0.2, 1, x) }
function emph(x) { return bezier(0.3, 0, 0.1, 1, x) }
function accel(x) { return bezier(0.3, 0, 0.8, 0.15, x) }

function coverSize(w, h) { return Math.hypot(w, h) / 2 / 0.064 * 1.05 }
