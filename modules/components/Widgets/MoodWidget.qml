import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "mood"
    tile: WidgetSizes.strip
    resizable: true
    minSpan: Qt.size(3, 1.5)
    maxSpan: Qt.size(5, 1.5)
    defaultPos: Qt.point(695, 605)

    readonly property var faces: ["sentiment_very_dissatisfied", "sentiment_dissatisfied", "sentiment_neutral", "sentiment_satisfied", "sentiment_very_satisfied"]
    readonly property var sample: [3, 4, 2, 3, 4, 4, 3, 1, 2, 3, 4, 4, 5, 3, 3, 4, 2, 3, 4, 4, 5, 4, 3, 3, 2, 4, 5, 4, 3, 4]
    readonly property var keys: {
        ServiceClock.date
        const out = []
        for (let i = 29; i >= 0; i--) out.push(ServicePersonal.todayKey(-i))
        return out
    }
    readonly property int todayMood: root.preview ? 4 : (ServicePersonal.moods[root.keys[29]] ?? 0)

    function moodAt(i) {
        return root.preview ? root.sample[i] : (ServicePersonal.moods[root.keys[i]] ?? 0)
    }

    WidgetCard {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: parent.pad
            spacing: 8

            WidgetTitle {
                Layout.fillWidth: true
                icon: "mood"
                title: "How’s today?"
                detail: {
                    let n = 0
                    for (let i = 0; i < 30; i++) if (root.moodAt(i) > 0) n++
                    return n > 0 ? n + " of 30 days" : ""
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                Repeater {
                    model: root.faces
                    delegate: Item {
                        id: face
                        required property var modelData
                        required property int index
                        readonly property bool on: root.todayMood === face.index + 1
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        Rectangle {
                            anchors.centerIn: parent
                            width: faceArea.pressed ? 34 : 38
                            height: width
                            radius: 13
                            Behavior on width { SpatialAnim { speed: "fast" } }
                            color: face.on ? Colors.primaryContainer : (faceArea.containsMouse ? Colors.surfaceContainerHigh : Qt.alpha(Colors.surfaceContainerHigh, 0))
                            Behavior on color { EffectsColorAnim { speed: "fast" } }
                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: face.modelData
                                iconSize: faceArea.pressed ? 21 : 24
                                Behavior on iconSize { SpatialAnim { speed: "fast" } }
                                customColor: face.on ? Colors.primaryContainerText : Colors.outline
                            }
                        }
                        MouseArea {
                            id: faceArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.preview
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ServicePersonal.setMood(face.index + 1)
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Row {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    Repeater {
                        model: 30
                        delegate: Rectangle {
                            required property int index
                            readonly property int m: root.moodAt(index)
                            anchors.bottom: parent.bottom
                            width: Math.max(3, (root.width - 2 * WidgetSizes.padFor(root.width) - 29 * 2) / 30)
                            height: m > 0 ? Math.max(4, parent.parent.height * m / 5) : 3
                            radius: 2
                            color: m === 0 ? Colors.surfaceContainerHigh
                                 : Qt.tint(Colors.surfaceContainerHighest, Qt.alpha(Colors.tertiary, 0.2 + m * 0.16))
                        }
                    }
                }
            }
        }
    }
}
