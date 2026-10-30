import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "profileRings"
    tile: WidgetSizes.wide
    defaultPos: Qt.point(585, 620)

    readonly property real screenGoal: 4 * 3600000
    readonly property int commitGoal: 5

    readonly property var rings: [
        { label: "screen time", color: Colors.primary, r: 74,
          frac: ServiceProfile.screenMs / root.screenGoal,
          value: ServiceProfile.span(ServiceProfile.screenMs), goal: " / 4 h" },
        { label: "commits", color: Colors.tertiary, r: 58,
          frac: ServiceProfile.commitsToday / root.commitGoal,
          value: String(ServiceProfile.commitsToday),
          goal: " / " + root.commitGoal + (ServiceProfile.commitsToday >= root.commitGoal ? " · done" : "") },
        { label: "focus sessions", color: Colors.secondary, r: 42,
          frac: ServiceFocus.done / ServiceFocus.rounds,
          value: String(ServiceFocus.done), goal: " / " + ServiceFocus.rounds }
    ]

    WidgetCard {
        id: card
        anchors.fill: parent

        RowLayout {
            anchors.fill: parent
            anchors.margins: card.pad
            spacing: 14

            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 160
                implicitHeight: 160

                Repeater {
                    model: root.rings

                    delegate: Item {
                        id: ring
                        required property var modelData
                        readonly property real frac: Math.max(0, Math.min(1, ring.modelData.frac))
                        anchors.fill: parent

                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: Colors.surfaceContainerHigh
                                strokeWidth: 12
                                PathAngleArc { centerX: 80; centerY: 80; radiusX: ring.modelData.r; radiusY: ring.modelData.r; startAngle: 0; sweepAngle: 360 }
                            }

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: ring.modelData.color
                                strokeWidth: ring.frac > 0 ? 12 : 0
                                capStyle: ShapePath.RoundCap
                                PathAngleArc { centerX: 80; centerY: 80; radiusX: ring.modelData.r; radiusY: ring.modelData.r; startAngle: -90; sweepAngle: 360 * ring.frac }
                            }
                        }
                    }
                }

                ProfileAvatar {
                    anchors.centerIn: parent
                    width: 58
                    height: 58
                    radius: 29
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 12

                Repeater {
                    model: root.rings

                    delegate: RowLayout {
                        id: legend
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            implicitWidth: 4
                            implicitHeight: 28
                            radius: 2
                            color: legend.modelData.color
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            CustomText {
                                Layout.fillWidth: true
                                content: legend.modelData.value + legend.modelData.goal
                                size: 13
                                weight: 800
                                elide: Text.ElideRight
                            }
                            CustomText {
                                content: legend.modelData.label
                                size: 10
                                weight: 600
                                customColor: Colors.surfaceVariantText
                            }
                        }
                    }
                }
            }
        }
    }
}
