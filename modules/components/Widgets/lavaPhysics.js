.pragma library

const COUNT = 8

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v))
}

function create(halfW, h) {
    const blobs = []
    for (let i = 0; i < COUNT; i++) {
        const r = 0.07 + 0.045 * ((i * 0.618 + 0.3) % 1)
        blobs.push({
            x: ((i + 0.5) / COUNT - 0.5) * 1.8 * halfW,
            y: h,
            vx: 0,
            vy: 0,
            t: 0.15 + 0.45 * Math.random(),
            r: r,
            st: 0,
            wobA: 0,
            wobT: 0,
            seed: Math.random() * 6.283,
            gain: 0.6 + 0.8 * Math.random()
        })
    }
    return { blobs: blobs, time: 0, depth: 0.2, rippleA: 0, rippleT: 9, rippleX: 0, launchedAt: -9 }
}

function poolSurface(sim, h) {
    return h - sim.depth
}

function kick(sim, strength, halfW, h) {
    const pool = poolSurface(sim, h)
    sim.rippleA = Math.min(0.04, sim.rippleA * 0.5 + 0.03 * strength)
    sim.rippleT = 0
    sim.rippleX = (Math.random() - 0.5) * 1.2 * halfW
    let launch = null
    for (let i = 0; i < sim.blobs.length; i++) {
        const o = sim.blobs[i]
        const contact = clamp(1 - (pool - o.y) / (o.r * 1.2), 0, 1)
        if (o.vy < 0.02)
            o.vy -= 0.05 * strength * contact
        o.vx += (Math.random() - 0.5) * 0.03 * strength
        o.wobA = Math.min(0.35, o.wobA + 0.22 * strength * (1 - 0.5 * contact))
        o.wobT = 0
        if (contact > 0.6 && (!launch || o.t > launch.t))
            launch = o
    }
    if (launch && sim.time - sim.launchedAt > 2.0) {
        launch.vy -= 0.2 * strength
        launch.t = clamp(launch.t + 0.05, 0, 1)
        sim.launchedAt = sim.time
    }
}

function wobble(o) {
    return o.st + o.wobA * Math.sin(o.wobT * 22)
}

function step(sim, dt, heat, halfW, h, top) {
    const n = Math.max(1, Math.ceil(dt / 0.02))
    for (let s = 0; s < n; s++)
        _step(sim, dt / n, heat, halfW, h, top)
}

function _step(sim, dt, heat, halfW, h, top) {
    const b = sim.blobs
    sim.time += dt
    sim.rippleA *= Math.exp(-dt * 2.5)
    sim.rippleT += dt
    const pool = poolSurface(sim, h)
    const power = 0.25 + 0.75 * heat

    let pooled = 0
    for (let i = 0; i < b.length; i++)
        if (b[i].y > pool - b[i].r)
            pooled++
    const depth = 0.12 + 0.08 * pooled / b.length
    sim.depth += (depth - sim.depth) * Math.min(1, dt * 0.6)

    const ax = new Array(b.length).fill(0)
    const ay = new Array(b.length).fill(0)

    for (let i = 0; i < b.length; i++) {
        const o = b[i]
        const gap = pool - o.y
        const contact = clamp(1 - gap / (o.r * 1.5), 0, 1)
        const height = clamp(gap / Math.max(0.1, pool - top), 0, 1)

        const warm = contact * 0.006 / o.r * o.gain * power * (1 - o.t)
        const cool = (0.01 + 0.6 * Math.pow(height, 4)) * (o.t - 0.15)
        o.t += dt * (warm - cool)
        o.t = clamp(o.t, 0, 1)

        ay[i] -= (o.t - 0.5) * (1.6 + 1.2 * heat)

        if (contact > 0 && contact < 1)
            ay[i] += 0.5 * contact * (1 - contact) * (0.6 + 0.4 * (1 - heat))

        const ceil = top + o.r
        if (o.y < ceil)
            ay[i] += 9 * (ceil - o.y)

        const wall = halfW - o.r * 0.9
        if (Math.abs(o.x) > wall)
            ax[i] -= 10 * (Math.abs(o.x) - wall) * Math.sign(o.x)

        ax[i] += 0.05 * Math.sin(sim.time * (0.25 + 0.1 * o.gain) + o.seed)
    }

    for (let i = 0; i < b.length; i++) {
        for (let j = i + 1; j < b.length; j++) {
            const p = b[i], q = b[j]
            const dx = q.x - p.x, dy = q.y - p.y
            const d = Math.max(1e-4, Math.hypot(dx, dy))
            const R = p.r + q.r
            if (d > R * 1.1)
                continue
            const nx = dx / d, ny = dy / d
            const f = d < R * 0.8 ? -6 * (R * 0.8 - d) : 0.2 * (d - R * 0.8)
            ax[i] += f * nx / p.r * 0.1; ay[i] += f * ny / p.r * 0.1
            ax[j] -= f * nx / q.r * 0.1; ay[j] -= f * ny / q.r * 0.1
            const touch = clamp(1 - d / (R * 0.8), 0, 1)
            const dt2 = (q.t - p.t) * Math.min(0.5, dt * 0.3 * touch)
            p.t += dt2; q.t -= dt2
            const kv = Math.min(0.5, dt * 1.2 * touch)
            const dvx = (q.vx - p.vx) * kv, dvy = (q.vy - p.vy) * kv
            p.vx += dvx; p.vy += dvy
            q.vx -= dvx; q.vy -= dvy
        }
    }

    const drag = Math.exp(-dt * 2.2)
    for (let i = 0; i < b.length; i++) {
        const o = b[i]
        o.vx = clamp((o.vx + ax[i] * dt) * drag, -0.35, 0.35)
        o.vy = clamp((o.vy + ay[i] * dt) * drag, -0.45, 0.45)
        o.x += o.vx * dt
        o.y += o.vy * dt
        const floor = pool + o.r * 0.35
        if (o.y > floor) {
            o.y = floor
            o.vy = Math.min(0, o.vy)
        }
        o.x = clamp(o.x, -halfW + o.r * 0.5, halfW - o.r * 0.5)
        const stretch = o.y > pool - o.r * 0.5 ? 0 : clamp(-o.vy * 1.6, -0.4, 0.5)
        o.st += (stretch - o.st) * Math.min(1, dt * 4)
        o.wobA *= Math.exp(-dt * 5)
        o.wobT += dt
    }
}
