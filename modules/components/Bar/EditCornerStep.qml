import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.components.Edit

RowLayout {
    id: step
    required property string key
    required property Item card
    spacing: 0
    EditKit.Pill {
        icon: "remove"
        box: 28
        tip: "Less rounded"
        usable: step.card.valueOf(step.key) > 0
        onClicked: step.card.nudge(step.key, -1)
    }
    CustomText {
        Layout.preferredWidth: 30
        horizontalAlignment: Text.AlignHCenter
        content: Math.round(step.card.valueOf(step.key)) + ""
        size: 12
        weight: 600
        font.features: { "tnum": 1 }
        customColor: step.card.corners[step.key] === null ? Colors.outline : Colors.surfaceText
    }
    EditKit.Pill {
        icon: "add"
        box: 28
        tip: "More rounded"
        usable: step.card.valueOf(step.key) < step.card.full
        onClicked: step.card.nudge(step.key, 1)
    }
    WheelStep {
        onStepped: dir => step.card.nudge(step.key, dir)
    }
}
