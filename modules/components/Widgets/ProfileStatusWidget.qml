import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
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
                    implicitWidth: 56
                    implicitHeight: 56

                    Rectangle {
                        anchors.fill: parent
                        radius: 28
                        color: "transparent"
                        border.width: 3
                        border.color: root.tone
                        Behavior on border.color { EffectsColorAnim {} }
                    }

                    ProfileAvatar {
                        anchors.centerIn: parent
                        width: 44
                        height: 44
                        radius: 22
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -2
                        width: 20
                        height: 20
                        radius: 10
                        color: root.tone
                        border.width: 3
                        border.color: Colors.surface
                        Behavior on color { EffectsColorAnim {} }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        CustomText {
                            Layout.maximumWidth: 150
                            content: ServiceProfile.name
                            size: 18
                            weight: 700
                            elide: Text.ElideRight
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: root.label
                            size: 12
                            weight: 600
                            customColor: root.mode === "quiet" ? Colors.outline : root.tone
                            elide: Text.ElideRight
                        }
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: root.detail
                        size: 12
                        weight: 400
                        customColor: Colors.surfaceVariantText
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 18
                color: Colors.surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 4

                    Repeater {
                        model: [{ id: "available", icon: "circle", text: "Available" },
                                { id: "focus", icon: "timer", text: "Focus" },
                                { id: "quiet", icon: "do_not_disturb_on", text: "Quiet" }]

                        delegate: Rectangle {
                            id: seg
                            required property var modelData
                            readonly property bool on: root.mode === seg.modelData.id
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            radius: height / 2
                            color: seg.on ? root.tone : segMouse.containsMouse ? Colors.surfaceContainerHighest : "transparent"
                            Behavior on color { EffectsColorAnim {} }

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
                                    weight: seg.on ? 600 : 500
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
