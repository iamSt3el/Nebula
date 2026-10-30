import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "profileStatus"
    tile: WidgetSizes.strip
    resizable: true
    minSpan: Qt.size(3, 1.5)
    maxSpan: Qt.size(4, 1.5)
    defaultPos: Qt.point(915, 165)

    readonly property bool focusing: ServiceFocus.phase === "focus" || ServiceFocus.phase === "break"
    readonly property string mode: root.focusing ? "focus" : ServiceNotification.dnd ? "quiet" : "available"

    readonly property color tone: root.mode === "focus" ? Colors.primary
                                : root.mode === "quiet" ? Colors.secondaryContainer : Colors.tertiaryContainer
    readonly property color onTone: root.mode === "focus" ? Colors.primaryText
                                  : root.mode === "quiet" ? Colors.secondaryContainerText : Colors.tertiaryContainerText

    readonly property string label: root.mode === "focus" ? (ServiceFocus.onBreak ? "On a break" : "Focusing")
                                  : root.mode === "quiet" ? "Quiet" : "Available"

    readonly property string detail: {
        if (root.mode === "focus") {
            const left = ServiceFocus.running ? ServiceFocus.clock + " left" : "Paused at " + ServiceFocus.clock
            if (ServiceFocus.onBreak)
                return left + " · " + (ServiceFocus.longBreakNext ? "long break" : "short break")
                     + " after session " + ((ServiceFocus.done - 1) % ServiceFocus.rounds + 1)
            return left + " · session " + (ServiceFocus.sessionInRound + 1) + " of " + ServiceFocus.rounds
        }
        if (root.mode === "quiet")
            return "Notifications are muted"
        if (ServiceProfile.liveApp !== "")
            return "In " + ServiceProfile.appName(ServiceProfile.liveApp) + " · " + ServiceProfile.span(ServiceProfile.liveAppMs) + " today"
        return "On the desktop"
    }

    function setMode(m) {
        if (m === "focus") {
            if (!root.focusing)
                ServiceFocus.startFocus()
            return
        }
        if (root.focusing)
            ServiceFocus.stop()
        ServiceNotification.setDnd(m === "quiet")
    }

    WidgetCard {
        id: card
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: card.pad
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item {
                    implicitWidth: 48
                    implicitHeight: 48

                    ProfileAvatar {
                        anchors.fill: parent
                        radius: 24
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -2
                        width: 18
                        height: 18
                        radius: 9
                        color: root.mode === "focus" ? Colors.primary
                             : root.mode === "quiet" ? Colors.outline : Colors.tertiary
                        border.width: 3
                        border.color: WidgetSizes.cardColor
                        Behavior on color { EffectsColorAnim {} }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    CustomText {
                        Layout.fillWidth: true
                        content: ServiceProfile.name
                        size: 20
                        weight: 400
                        family: SettingsConfig.general?.displayFont || "Titan One"
                        renderType: Text.QtRendering
                        elide: Text.ElideRight
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: root.label + " · " + root.detail
                        size: 11
                        weight: 600
                        customColor: Colors.surfaceVariantText
                        elide: Text.ElideRight
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Item {
                Layout.fillWidth: true
                implicitHeight: 38

                RowLayout {
                    anchors.fill: parent
                    spacing: 2

                    Repeater {
                        model: [{ id: "available", icon: "check", text: "Available" },
                                { id: "focus", icon: "timer", text: "Focus" },
                                { id: "quiet", icon: "do_not_disturb_on", text: "Quiet" }]

                        delegate: Rectangle {
                            id: seg
                            required property var modelData
                            required property int index
                            readonly property bool on: root.mode === seg.modelData.id
                            readonly property real full: height / 2
                            readonly property real startR: seg.on || seg.index === 0 ? seg.full : 6
                            readonly property real endR: seg.on || seg.index === 2 ? seg.full : 6
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            topLeftRadius: seg.startR
                            bottomLeftRadius: seg.startR
                            topRightRadius: seg.endR
                            bottomRightRadius: seg.endR
                            color: seg.on ? root.tone : segMouse.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                            Behavior on color { EffectsColorAnim {} }
                            Behavior on topLeftRadius { SpatialAnim { speed: "fast" } }
                            Behavior on topRightRadius { SpatialAnim { speed: "fast" } }
                            Behavior on bottomLeftRadius { SpatialAnim { speed: "fast" } }
                            Behavior on bottomRightRadius { SpatialAnim { speed: "fast" } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 5

                                MaterialIconSymbol {
                                    content: seg.modelData.icon
                                    iconSize: 15
                                    fill: seg.on ? 1 : 0
                                    customColor: seg.on ? root.onTone : Colors.surfaceVariantText
                                }

                                CustomText {
                                    content: seg.modelData.text
                                    size: 12
                                    weight: seg.on ? 800 : 700
                                    customColor: seg.on ? root.onTone : Colors.surfaceVariantText
                                }
                            }

                            MouseArea {
                                id: segMouse
                                anchors.fill: parent
                                enabled: !root.preview
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setMode(seg.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
