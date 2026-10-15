import QtQuick
import qs.modules.utils
import qs.modules.settings

Rectangle {
    id: card

    readonly property real pad: WidgetSizes.padFor(card.width)

    radius: WidgetSizes.radius
    color: WidgetSizes.cardColor

    Rectangle {
        anchors.fill: parent
        z: 1000
        visible: KindleMode.outlines
        radius: card.radius
        color: "transparent"
        border.width: KindleMode.edge
        border.color: Colors.outline
    }

    Component.onCompleted: {
        let p = card.parent
        while (p && p.outlined === undefined)
            p = p.parent
        if (p)
            p.outlined = false
    }
}
