import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.settings

PanelWindow {
    id: promptWindow

    property var network: null
    property string errorText: ""
    property bool askName: false
    property bool working: false

    signal submitted(string psk)
    signal submittedHidden(string ssid, string psk)
    signal dismissed

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    WlrLayershell.namespace: "quickshell:wifiPrompt"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    readonly property bool ready: promptWindow.askName ? nameField.text.trim().length > 0 && !promptWindow.working
                                                       : pwField.text.length > 0

    function submit() {
        if (!promptWindow.ready) return
        if (promptWindow.askName) promptWindow.submittedHidden(nameField.text.trim(), pwField.text)
        else promptWindow.submitted(pwField.text)
    }

    Timer {
        interval: 60
        running: true
        onTriggered: promptWindow.askName ? nameField.forceActiveFocus() : pwField.forceActiveFocus()
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Qt.alpha(Colors.scrim, 0.55)

        opacity: 0
        EffectsAnim {
            target: scrim
            property: "opacity"
            from: 0; to: 1
            speed: "slow"
            running: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: promptWindow.dismissed()
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 380
            implicitHeight: promptColumn.implicitHeight + 44
            radius: 28
            color: Colors.surfaceContainerHigh

            scale: 0.9
            SpatialAnim {
                target: card
                property: "scale"
                from: 0.9; to: 1
                speed: "fast"
                running: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => mouse.accepted = true
            }

            ColumnLayout {
                id: promptColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: promptWindow.errorText !== "" ? Colors.errorContainer
                                                             : Colors.primaryContainer

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: promptWindow.errorText !== "" ? "error" : promptWindow.askName ? "wifi_add" : "wifi_lock"
                            iconSize: 20
                            customColor: promptWindow.errorText !== "" ? Colors.errorContainerText
                                                                       : Colors.primaryContainerText
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        CustomText {
                            Layout.fillWidth: true
                            content: promptWindow.askName ? "Add network" : promptWindow.network?.name ?? "Wi-Fi network"
                            size: 16
                            weight: 700
                            elide: Text.ElideRight
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: promptWindow.errorText !== "" ? promptWindow.errorText
                                   : promptWindow.working ? "Joining…"
                                   : promptWindow.askName ? "Join a hidden network by its name"
                                   : "This network is password protected"
                            size: 12
                            customColor: promptWindow.errorText !== "" ? Colors.error : Colors.outline
                            elide: Text.ElideRight
                        }
                    }

                    M3IconButton {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 16
                        icon: "close"
                        iconSize: 18
                        onClicked: promptWindow.dismissed()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    visible: promptWindow.askName
                    radius: 16
                    color: Colors.surfaceContainerHighest
                    border.width: 2
                    border.color: nameField.activeFocus ? Colors.primary : Qt.alpha(Colors.primary, 0)

                    Behavior on border.color { EffectsColorAnim {} }

                    TextField {
                        id: nameField
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        background: null
                        padding: 0
                        placeholderText: "Network name"
                        placeholderTextColor: Colors.outline
                        font.pixelSize: 15
                        font.weight: 600
                        font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                        color: Colors.surfaceText
                        selectionColor: Qt.alpha(Colors.primary, 0.35)
                        selectedTextColor: Colors.surfaceText
                        verticalAlignment: TextInput.AlignVCenter
                        onAccepted: pwField.forceActiveFocus()
                        Keys.onEscapePressed: promptWindow.dismissed()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 16
                    color: Colors.surfaceContainerHighest
                    border.width: 2
                    border.color: pwField.activeFocus ? Colors.primary : Qt.alpha(Colors.primary, 0)

                    Behavior on border.color { EffectsColorAnim {} }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 10
                        spacing: 8

                        TextField {
                            id: pwField
                            Layout.fillWidth: true
                            background: null
                            padding: 0
                            placeholderText: promptWindow.askName ? "Password (leave empty if open)" : "Password"
                            placeholderTextColor: Colors.outline
                            echoMode: revealToggle.revealed ? TextInput.Normal : TextInput.Password
                            inputMethodHints: Qt.ImhSensitiveData
                            font.pixelSize: 15
                            font.weight: 600
                            font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                            color: Colors.surfaceText
                            selectionColor: Qt.alpha(Colors.primary, 0.35)
                            selectedTextColor: Colors.surfaceText
                            verticalAlignment: TextInput.AlignVCenter
                            onAccepted: promptWindow.submit()
                            Keys.onEscapePressed: promptWindow.dismissed()
                        }

                        MaterialIconSymbol {
                            id: revealToggle
                            property bool revealed: false
                            content: revealToggle.revealed ? "visibility_off" : "visibility"
                            iconSize: 18
                            customColor: Colors.outline

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: revealToggle.revealed = !revealToggle.revealed
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredHeight: 40
                        Layout.preferredWidth: cancelLabel.implicitWidth + 36
                        radius: 20
                        color: "transparent"

                        CustomText {
                            id: cancelLabel
                            anchors.centerIn: parent
                            content: "Cancel"
                            size: 13
                            weight: 700
                            customColor: Colors.primary
                        }

                        RippleEffect {
                            anchors.fill: parent
                            radius: parent.radius
                            onClicked: promptWindow.dismissed()
                        }
                    }

                    Rectangle {
                        Layout.preferredHeight: 40
                        Layout.preferredWidth: connectLabel.implicitWidth + 44
                        radius: 20
                        color: promptWindow.ready ? Colors.primary : Colors.surfaceContainerHighest

                        Behavior on color { EffectsColorAnim {} }

                        CustomText {
                            id: connectLabel
                            anchors.centerIn: parent
                            content: promptWindow.askName ? "Join" : "Connect"
                            size: 13
                            weight: 700
                            customColor: promptWindow.ready ? Colors.primaryText : Colors.outline
                        }

                        RippleEffect {
                            anchors.fill: parent
                            radius: parent.radius
                            hoverColor: Qt.alpha(Colors.primaryText, 0.1)
                            rippleColor: Qt.alpha(Colors.primaryText, 0.2)
                            onClicked: promptWindow.submit()
                        }
                    }
                }
            }
        }
    }
}
