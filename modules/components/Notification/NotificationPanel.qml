import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    implicitHeight: ServiceNotification.popups.length > 0 ? innerItem.height + 20 : 0
    implicitWidth: 380
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: 50

    Behavior on implicitHeight {
        NumberAnimation {
            easing.type: Easing.OutQuint
            duration: 350
        }
    }

    // Shared slow orbit angle for all blobs
    property real orbitAngle: 0
    NumberAnimation on orbitAngle {
        from: 0
        to: Math.PI * 2
        duration: 22000
        loops: Animation.Infinite
        running: ServiceNotification.popups.length > 0
    }

    Item {
        id: innerItem
        width: 380
        height: list.contentHeight + 20
        anchors.top: parent.top
        anchors.right: parent.right

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                orientation: Qt.Vertical
                model: ScriptModel {
                    values: [...ServiceNotification.popups].reverse()
                }
                spacing: 8
                interactive: false

            add: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "x"
                        from: list.width + 20
                        to: 0
                        duration: 420
                        easing.type: Easing.OutQuint
                    }
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 280
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        property: "scale"
                        from: 0.92
                        to: 1
                        duration: 420
                        easing.type: Easing.OutQuint
                    }
                }
            }

            addDisplaced: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: 350
                    easing.type: Easing.OutQuint
                }
            }

            displaced: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: 350
                    easing.type: Easing.OutQuint
                }
            }

            delegate: Item {
                id: delegateRoot
                required property var modelData
                required property real index

                width: list.width
                implicitHeight: popup.implicitHeight

                // ── Typewriter counters ────────────────────────────────────
                property string fullSummary: modelData.summary ?? ""
                property string fullBody: modelData.body ?? ""
                property int typeLenSum: 0
                property int typeLenBody: 0

                ParallelAnimation {
                    running: true
                    NumberAnimation {
                        target: delegateRoot
                        property: "typeLenSum"
                        from: 0
                        to: delegateRoot.fullSummary.length
                        duration: Math.min(delegateRoot.fullSummary.length * 42, 900)
                        easing.type: Easing.OutCubic
                    }
                    SequentialAnimation {
                        PauseAnimation {
                            duration: 180
                        }
                        NumberAnimation {
                            target: delegateRoot
                            property: "typeLenBody"
                            from: 0
                            to: delegateRoot.fullBody.length
                            duration: Math.min(delegateRoot.fullBody.length * 30, 1600)
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Rectangle {
                    id: popup
                    width: parent.width
                    implicitHeight: cardContent.implicitHeight + 24
                    radius: 20
                    clip: true

                    // Card base color — slightly elevated surface with subtle primary tint
                    color: Qt.tint(Colors.surfaceContainer, Qt.alpha(Colors.primary, 0.04))

                    border.color: Qt.alpha(Colors.primary, 0.18)
                    border.width: 1

                    // ── Remove animation ──────────────────────────────────
                    SequentialAnimation {
                        id: removeAnim
                        ParallelAnimation {
                            NumberAnimation {
                                target: delegateRoot
                                property: "x"
                                to: list.width + 20
                                duration: 700
                                easing.type: Easing.OutQuint
                            }
                            NumberAnimation {
                                target: delegateRoot
                                property: "opacity"
                                to: 0
                                duration: 600
                                easing.type: Easing.OutQuint
                            }
                            NumberAnimation {
                                target: popup
                                property: "scale"
                                from: 1
                                to: 0.7
                                duration: 600
                                easing.type: Easing.OutQuint
                            }
                        }
                        NumberAnimation {
                            target: delegateRoot
                            property: "implicitHeight"
                            to: 0
                            duration: 500
                            easing.type: Easing.OutQuint
                        }
                        PropertyAction {
                            target: popup
                            property: "visible"
                            value: false
                        }
                    }

                    Connections {
                        target: modelData
                        function onDismissingChanged() {
                            if (modelData.dismissing)
                                removeAnim.restart()
                        }
                    }

                    // Auto-dismiss
                    Timer {
                        interval: (modelData.timeout > 0 ? modelData.timeout : 6000)
                        running: true
                        onTriggered: ServiceNotification.dismissPopup(modelData)
                    }

                    // ── Blob 1 (primary colour, slow orbit) ───────────────
                    Rectangle {
                        width: parent.width * 0.65
                        height: width
                        radius: width / 2
                        x: (parent.width / 2 - width / 2) + Math.cos(root.orbitAngle * 1.8 + delegateRoot.index * 1.2) * 55
                        y: (parent.height / 2 - height / 2) + Math.sin(root.orbitAngle * 1.8 + delegateRoot.index * 1.2) * 28
                        color: Colors.primary
                        opacity: 0.09
                    }

                    // ── Blob 2 (secondary/tertiary, counter-orbit) ────────
                    Rectangle {
                        width: parent.width * 0.45
                        height: width
                        radius: width / 2
                        x: (parent.width / 2 - width / 2) + Math.sin(root.orbitAngle * 1.3 - delegateRoot.index * 0.9) * -48
                        y: (parent.height / 2 - height / 2) + Math.cos(root.orbitAngle * 1.3 - delegateRoot.index * 0.9) * -36
                        color: Colors.tertiary ?? Colors.secondary ?? Colors.primaryContainer
                        opacity: 0.08
                    }

                    // ── Swipe to dismiss ──────────────────────────────────
                    MouseArea {
                        id: swipeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        z: 0

                        property real startX: 0
                        property bool isDragging: false

                        onPressed: {
                            startX = mouse.x
                            isDragging = false
                        }

                        onPositionChanged: {
                            if (!pressed) return
                            var dx = mouse.x - startX
                            if (dx > 15) {
                                isDragging = true
                                delegateRoot.x = dx - 15
                            }
                        }

                        onReleased: {
                            if (isDragging) {
                                if (delegateRoot.x > 60)
                                    ServiceNotification.dismissPopup(modelData)
                                else
                                    snapBackAnim.start()
                            } else {
                                ServiceNotification.dismissPopup(modelData)
                            }
                        }

                        NumberAnimation {
                            id: snapBackAnim
                            target: delegateRoot
                            property: "x"
                            to: 0
                            duration: 300
                            easing.type: Easing.OutBack
                        }

                        // Hover tint
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.parent.radius
                            color: Colors.primary
                            opacity: parent.containsMouse && !parent.pressed ? 0.06 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                }
                            }
                        }
                    }

                    // ── Card content ──────────────────────────────────────
                    ColumnLayout {
                        id: cardContent
                        z: 1
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 14
                        spacing: 6

                        // ── Header row ────────────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            // App icon
                            Rectangle {
                                id: iconRect
                                width: 40
                                height: 40
                                radius: 12
                                color: usesSymbol ? Colors.primaryContainer : Qt.alpha(Colors.primary, 0.12)

                                readonly property string symbol: {
                                    const ic = (modelData.appIcon ?? "").toLowerCase();
                                    const ap = (modelData.appName ?? "").toLowerCase();
                                    if (ic.includes("camera-photo") || ap.includes("screenshot"))
                                        return "photo_camera";
                                    if (ic.includes("camera-video") || ap.includes("record"))
                                        return "screen_record";
                                    if (ic.includes("dialog-error") || ic.includes("error"))
                                        return "error_outline";
                                    if (ic.includes("bluetooth"))
                                        return "bluetooth";
                                    if (ic.includes("network") || ic.includes("wifi"))
                                        return "wifi";
                                    if (ic.includes("battery"))
                                        return "battery_std";
                                    if (ic.includes("volume") || ic.includes("audio"))
                                        return "volume_up";
                                    return "";
                                }
                                readonly property bool usesSymbol: symbol !== ""

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: iconRect.symbol
                                    iconSize: 20
                                    customColor: Colors.primaryContainerText
                                    visible: iconRect.usesSymbol
                                }
                                Image {
                                    id: appIcon
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    source: iconRect.usesSymbol ? "" : IconUtil.getIconPath(modelData.appIcon)
                                    sourceSize: Qt.size(width, height)
                                    fillMode: Image.PreserveAspectFit
                                    visible: !iconRect.usesSymbol && status === Image.Ready
                                }
                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: "notifications"
                                    iconSize: 20
                                    customColor: Colors.primaryContainerText
                                    visible: !iconRect.usesSymbol && appIcon.status !== Image.Ready
                                }
                            }

                            // App name + summary
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                // App name · time
                                RowLayout {
                                    spacing: 4
                                    visible: (modelData.appName ?? "").length > 0

                                    CustomText {
                                        content: modelData.appName ?? ""
                                        size: 11
                                        weight: 600
                                        customColor: Colors.primary
                                    }
                                    CustomText {
                                        content: "·"
                                        size: 10
                                        customColor: Colors.outline
                                    }
                                    CustomText {
                                        content: {
                                            var diff = Date.now() - (modelData.arrivalTimestamp ?? Date.now());
                                            var mins = Math.floor(diff / 60000);
                                            return mins < 1 ? "now" : mins < 60 ? mins + "m ago" : Math.floor(mins / 60) + "h ago";
                                        }
                                        size: 10
                                        customColor: Colors.outline
                                    }
                                }

                                // Typewriter summary
                                CustomText {
                                    Layout.fillWidth: true
                                    content: delegateRoot.fullSummary.substring(0, delegateRoot.typeLenSum)
                                    size: 14
                                    weight: 700
                                    elide: Text.ElideRight
                                }
                            }

                            // Optional image thumbnail
                            Loader {
                                active: !!modelData.image
                                visible: active
                                Layout.preferredWidth: 48
                                Layout.preferredHeight: 48
                                Layout.alignment: Qt.AlignVCenter
                                sourceComponent: Rectangle {
                                    radius: 10
                                    clip: true
                                    color: "transparent"
                                    Image {
                                        anchors.fill: parent
                                        source: modelData.image ?? ""
                                        sourceSize: Qt.size(width, height)
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                }
                            }
                        }

                        // ── Typewriter body ───────────────────────────────
                        Text {
                            Layout.fillWidth: true
                            text: delegateRoot.fullBody.substring(0, delegateRoot.typeLenBody)
                            font.pixelSize: 13
                            font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                            color: Colors.outline
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            visible: delegateRoot.fullBody.length > 0
                            bottomPadding: delegateRoot.fullBody.length > 0 ? 2 : 0
                        }

                        // ── Action buttons ────────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            spacing: 6
                            visible: (modelData.actions ?? []).length > 0

                            Repeater {
                                model: modelData.actions ?? []

                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    radius: 10

                                    readonly property bool isPrimary: index === 0
                                    color: isPrimary ? (actionArea.containsMouse ? Colors.primary : Qt.alpha(Colors.primary, 0.85)) : (actionArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh)

                                    border.color: isPrimary ? "transparent" : Qt.alpha(Colors.outline, 0.2)
                                    border.width: 1

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }

                                    CustomText {
                                        anchors.centerIn: parent
                                        content: modelData.text ?? "Action"
                                        size: 12
                                        weight: 600
                                        customColor: parent.isPrimary ? Colors.primaryText : Colors.surfaceText
                                    }

                                    MouseArea {
                                        id: actionArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        z: 10
                                        onClicked: {
                                            modelData.invoke();
                                            ServiceNotification.dismissPopup(delegateRoot.modelData);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
