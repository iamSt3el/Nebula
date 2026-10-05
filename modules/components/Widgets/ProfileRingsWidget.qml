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
        { label: "Screen time", color: Colors.primary, r: 74,
          frac: ServiceProfile.screenMs / root.screenGoal,
          value: ServiceProfile.span(ServiceProfile.screenMs), goal: "/ 4 h" },
        { label: "Commits", color: Colors.tertiaryContainer, r: 58,
          frac: ServiceProfile.commitsToday / root.commitGoal,
          value: String(ServiceProfile.commitsToday),
          goal: "/ " + root.commitGoal + (ServiceProfile.commitsToday >= root.commitGoal ? " · done" : "") },
        { label: "Focus", color: Colors.outline, r: 42,
          frac: ServiceFocus.done / ServiceFocus.rounds,
          value: String(ServiceFocus.done), goal: "/ " + ServiceFocus.rounds + " sessions" }
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
                                strokeColor: Colors.surfaceContainerHighest
                                strokeWidth: 11
                                PathAngleArc { centerX: 80; centerY: 80; radiusX: ring.modelData.r; radiusY: ring.modelData.r; startAngle: 0; sweepAngle: 360 }
                            }

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: ring.modelData.color
                                strokeWidth: ring.frac > 0 ? 11 : 0
                                capStyle: ShapePath.RoundCap
                                PathAngleArc { centerX: 80; centerY: 80; radiusX: ring.modelData.r; radiusY: ring.modelData.r; startAngle: -90; sweepAngle: 360 * ring.frac }
                            }
                        }

                        Rectangle {
                            visible: ring.frac === 0
                            x: 80 - 5.5
                            y: 80 - ring.modelData.r - 5.5
                            width: 11
                            height: 11
                            radius: 5.5
                            color: ring.modelData.color
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
                spacing: 9

                CustomText {
                    Layout.fillWidth: true
                    content: ServiceProfile.name
                    size: 20
                    weight: 400
                    family: SettingsConfig.general.displayFont ?? "Titan One"
                    renderType: Text.QtRendering
                    elide: Text.ElideRight
                }

                Repeater {
                    model: root.rings

                    delegate: ColumnLayout {
                        id: legend
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 1

                        RowLayout {
                            spacing: 6
                            Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 4; color: legend.modelData.color }
                            CustomText { content: legend.modelData.label; size: 11; weight: 400; customColor: Colors.outline }
                        }

                        CustomText {
                            Layout.fillWidth: true
                            textFormat: Text.StyledText
                            content: legend.modelData.value + " <font color=\"" + Colors.outline + "\">" + legend.modelData.goal + "</font>"
                            size: 13
                            weight: 600
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
