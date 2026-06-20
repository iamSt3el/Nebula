import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import qs.modules.utils
import qs.modules.settings
import qs.modules.services

PanelWindow {
    id: panelWindow
    implicitHeight: 200
    visible: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Activate cava when music visualizer is visible
    Component.onCompleted: ServiceCava.retain()
    Component.onDestruction: ServiceCava.release()

    mask: Region{
        item: maskRect
        intersection: Intersection.Xor;
    }

    Rectangle{
        id: maskRect
        anchors.fill: parent
        color: "transparent"
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        Connections {
            target: ServiceCava
            function onCavaDataChanged() { canvas.requestPaint() }
        }

        onPaint: {
            var ctx = getContext('2d')
            ctx.clearRect(0, 0, width, height)
            drawMountainWave(ctx, ServiceCava.cavaData, true)
            drawMountainWave(ctx, ServiceCava.cavaData, false)
        }

        function drawMountainWave(ctx, data, isShadow) {
            if (data.length < 2) return
            var gradient = ctx.createLinearGradient(0, 0, width, height);
            gradient.addColorStop(0.0, Colors.primary)//SettingsConfig.theme.firstColor);
            gradient.addColorStop(0.5, Colors.primary)//SettingsConfig.theme.secondColor);
            gradient.addColorStop(1.0, Colors.primary)//SettingsConfig.theme.thirdColor);

            ctx.beginPath()

            if (isShadow) {
                ctx.globalAlpha = 0.3
                ctx.save()
                ctx.translate(0, -10)
                ctx.scale(1.02, 1.05)
            } else {
                ctx.globalAlpha = 1.0
            }

            ctx.fillStyle = gradient

            ctx.moveTo(0, height)
            var startY = height - (data[0] * height)
            ctx.lineTo(0, startY)

            var barWidth = width / (data.length - 1)

            for (var i = 0; i < data.length - 1; i++) {
                var xCurr = i * barWidth
                var yCurr = height - (data[i] * height)
                var xNext = (i + 1) * barWidth
                var yNext = height - (data[i + 1] * height)
                var xMid = (xCurr + xNext) / 2
                var yMid = (yCurr + yNext) / 2
                ctx.quadraticCurveTo(xCurr, yCurr, xMid, yMid)
            }

            var lastX = (data.length - 1) * barWidth
            var lastY = height - (data[data.length - 1] * height)
            ctx.lineTo(lastX, lastY)
            ctx.lineTo(width, height)
            ctx.closePath()
            ctx.fill()

            if (isShadow) ctx.restore()
        }
    }
}
