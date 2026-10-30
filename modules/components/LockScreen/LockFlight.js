.pragma library

const standard = [0.2, 0.0, 0.0, 1.0]
const decel = [0.05, 0.7, 0.1, 1.0]
const late = [0.4, 0.0, 0.2, 1.0]
const soft = [0.34, 1.12, 0.3, 1.0]

function clamp(v) {
    return Math.max(0, Math.min(1, v))
}

function lerp(a, b, t) {
    return a + (b - a) * t
}

function bez(t, c) {
    if (t <= 0)
        return 0
    if (t >= 1)
        return 1
    let u = t
    for (let i = 0; i < 8; i++) {
        const x = 3 * (1 - u) * (1 - u) * u * c[0] + 3 * (1 - u) * u * u * c[2] + u * u * u - t
        const dx = 3 * (1 - u) * (1 - u) * c[0] + 6 * (1 - u) * u * (c[2] - c[0]) + 3 * u * u * (1 - c[2])
        if (Math.abs(x) < 1e-4 || dx === 0)
            break
        u = clamp(u - x / dx)
    }
    return 3 * (1 - u) * (1 - u) * u * c[1] + 3 * (1 - u) * u * u * c[3] + u * u * u
}

function phase(pos, a, b, c, leaving) {
    const u = clamp((pos - a) / (b - a))
    return leaving ? 1 - bez(1 - u, c) : bez(u, c)
}

function ramp(a, b, v) {
    const t = clamp((v - a) / (b - a))
    return t * t * (3 - 2 * t)
}

function box(x, y, w, h) {
    return { x: x, y: y, width: w, height: h }
}

function arcRect(S, D, px, py, ps) {
    const w = lerp(S.width, D.width, ps)
    const h = lerp(S.height, D.height, ps)
    const c = lerp(S.x + S.width / 2, D.x + D.width / 2, px)
    const bottom = lerp(S.y + S.height, D.y + D.height, py)
    return box(c - w / 2, bottom - h, w, h)
}

function leftRect(S, D, p) {
    const h = lerp(S.height, D.height, p)
    return box(lerp(S.x, D.x, p), lerp(S.y, D.y, p), S.width * h / Math.max(1, S.height), h)
}

function widthRect(S, D, p) {
    const end = D.width / Math.max(1, S.width)
    const k = lerp(1, end, p)
    const y = D.y + (D.height - S.height * end) / 2
    return box(lerp(S.x, D.x, p), lerp(S.y, y, p), S.width * k, S.height * k)
}

function staticDate(S, pos, leaving) {
    const k = phase(pos, 0, 0.3, standard, leaving)
    return { rect: box(S.x, S.y + 12 * k, S.width, S.height), face: 1 - k, copy: 0 }
}

function glide(pos, leaving, S, D) {
    const L = leaving
    const out = { reveal: ramp(0.93, 0.995, pos) }
    const face = 1 - ramp(0.95, 1, pos)
    if (S.hours && D.hours)
        out.hours = {
            rect: arcRect(S.hours, D.hours, phase(pos, 0, 0.82, decel, L), phase(pos, 0, 0.86, late, L), phase(pos, 0, 0.9, soft, L)),
            face: face, copy: 0
        }
    if (S.minutes && D.minutes)
        out.minutes = {
            rect: arcRect(S.minutes, D.minutes, phase(pos, 0.07, 0.88, decel, L), phase(pos, 0.07, 0.92, late, L), phase(pos, 0.07, 0.95, soft, L)),
            face: face, copy: 0
        }
    if (S.date && D.date)
        out.date = { rect: widthRect(S.date, D.date, phase(pos, 0.12, 0.96, standard, L)), face: face, copy: 0 }
    else if (S.date)
        out.date = staticDate(S.date, pos, L)
    return out
}

function arc(pos, leaving, S, D) {
    const L = leaving
    const out = { reveal: ramp(0.94, 0.995, pos) }
    if (S.hours && D.hours && S.minutes && D.minutes) {
        const hx = phase(pos, 0.08, 0.94, standard, L)
        const H = arcRect(S.hours, D.hours, hx, hx, phase(pos, 0.08, 1, soft, L))
        const M = arcRect(S.minutes, D.minutes, phase(pos, 0, 0.84, decel, L), phase(pos, 0, 0.86, late, L), phase(pos, 0.02, 0.9, soft, L))
        out.hours = { rect: H, face: 1 - ramp(0.24, 0.38, pos), copy: ramp(0.22, 0.36, pos) }
        out.minutes = { rect: M, face: 1 - ramp(0.18, 0.32, pos), copy: ramp(0.16, 0.3, pos) }
        if (D.colon) {
            const k = H.height / Math.max(1, D.hours.height)
            const cin = phase(pos, 0.55, 0.82, standard, L)
            const w = D.colon.width * k * lerp(0.7, 1, cin)
            const h = D.colon.height * k * lerp(0.7, 1, cin)
            const mid = (H.x + H.width + M.x) / 2
            const cy = H.y + (D.colon.y + D.colon.height / 2 - D.hours.y) * k
            out.colon = { rect: box(mid - w / 2, cy - h / 2, w, h), face: 0, copy: cin }
        }
    }
    if (S.date && D.date)
        out.date = { rect: leftRect(S.date, D.date, phase(pos, 0.42, 0.98, standard, L)), face: 1 - ramp(0.52, 0.72, pos), copy: ramp(0.54, 0.74, pos) }
    else if (S.date)
        out.date = staticDate(S.date, pos, L)
    return out
}

function plan(style, pos, leaving, S, D) {
    return style === "arc" ? arc(pos, leaving, S, D) : glide(pos, leaving, S, D)
}
