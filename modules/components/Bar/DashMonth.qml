pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes

GridLayout {
    id: root

    property real cellH: 30
    property real textSize: 13
    property bool cookie: false
    property bool dots: false

    readonly property var cells: {
        ServiceClock.date
        ServiceClock.holidaysLoaded
        const now = new Date()
        const y = now.getFullYear()
        const m = now.getMonth()
        const lead = (new Date(y, m, 1).getDay() + 6) % 7
        const days = new Date(y, m + 1, 0).getDate()
        const out = []
        for (let i = 0; i < lead; i++) out.push({ n: 0, today: false, past: false, mark: false })
        for (let d = 1; d <= days; d++)
            out.push({ n: d, today: d === now.getDate(), past: d < now.getDate(),
                       mark: root.dots && ServiceClock.checkHoliday(d, y, m).isHoliday })
        while (out.length % 7 !== 0) out.push({ n: 0, today: false, past: false, mark: false })
        return out
    }

    columns: 7
    rowSpacing: 0
    columnSpacing: 0

    Repeater {
        model: ["M", "T", "W", "T", "F", "S", "S"]

        CustomText {
            required property string modelData
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.preferredHeight: 22
            horizontalAlignment: Text.AlignHCenter
            content: modelData
            size: 11
            weight: 600
            customColor: Colors.surfaceVariantText
        }
    }

    Repeater {
        model: root.cells

        Item {
            id: cell
            required property var modelData
            readonly property real side: Math.min(width, root.cellH) - 2

            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.preferredHeight: root.cellH

            Rectangle {
                anchors.centerIn: parent
                width: cell.side
                height: cell.side
                radius: cell.side / 2
                visible: cell.modelData.today && !root.cookie
                color: Colors.tertiaryContainer
            }

            MaterialShapes.ShapeCanvas {
                anchors.centerIn: parent
                width: cell.side + 4
                height: cell.side + 4
                visible: cell.modelData.today && root.cookie
                roundedPolygon: "cookie9"
                color: Colors.tertiaryContainer
            }

            CustomText {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: cell.modelData.mark ? -3 : 0
                visible: cell.modelData.n > 0
                content: String(cell.modelData.n)
                size: root.textSize
                weight: cell.modelData.today ? 800 : cell.modelData.past ? 400 : 600
                customColor: cell.modelData.today ? Colors.tertiaryContainerText
                    : cell.modelData.past ? Colors.outline : Colors.surfaceText
            }

            Rectangle {
                visible: cell.modelData.mark
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: root.textSize * 0.6 + 2
                width: 4
                height: 4
                radius: 2
                color: cell.modelData.today ? Colors.tertiaryContainerText : Colors.tertiary
            }
        }
    }
}
