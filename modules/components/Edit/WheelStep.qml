import QtQuick

WheelHandler {
    id: wh

    property real acc: 0
    property real lastAt: 0
    signal stepped(int dir)

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    onWheel: ev => {
        const d = ev.angleDelta.y
        if (d === 0)
            return
        const now = Date.now()
        if (now - wh.lastAt > 400 || (wh.acc !== 0 && Math.sign(d) !== Math.sign(wh.acc)))
            wh.acc = 0
        wh.lastAt = now
        wh.acc += d
        while (Math.abs(wh.acc) >= 120) {
            const dir = wh.acc > 0 ? 1 : -1
            wh.acc -= dir * 120
            wh.stepped(dir)
        }
    }
}
