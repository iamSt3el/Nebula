import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MatrialShapeFn

Item {
    id: root
    anchors.fill: parent

    NumberAnimation on scale  { from: 0.93; to: 1; duration: 220; easing.type: Easing.OutBack }
    NumberAnimation on opacity { from: 0;    to: 1; duration: 200 }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 10
        radius: 20
        color: Colors.surfaceContainer

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ── Header ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialShapes.ShapeCanvas {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    roundedPolygon: MatrialShapeFn.getCookie6Sided()
                    color: Colors.primary
                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "neurology"
                        iconSize: 18
                        color: Colors.primaryText
                    }
                }

                CustomText {
                    content: "AI Assistant"
                    size: 15
                    weight: 700
                    color: Colors.surfaceText
                }

                Item { Layout.fillWidth: true }

                // ── Backend segmented switcher ─────────────────────────────
                ButtonGroup {
                    Layout.preferredHeight: 28
                    model: [
                        { value: "ollama", label: "Local", icon: "computer" },
                        { value: "gemini", label: "API",   icon: "cloud"    }
                    ]
                    activeCheck: value => ServiceAi.backend === value
                    onSegmentClicked: value => SettingsConfig.ai = Object.assign({}, SettingsConfig.ai, { backend: value })
                }

                // New chat button
                CustomButton {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    icon: "add"
                    iconSize: 15
                    onClicked: ServiceAi.clearHistory()
                }
            }

            // ── Model info strip ──────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.preferredHeight: 20
                    Layout.preferredWidth: modelRow.implicitWidth + 14
                    radius: 10
                    color: Qt.alpha(Colors.primary, 0.12)

                    RowLayout {
                        id: modelRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIconSymbol {
                            content: ServiceAi.backend === "ollama" ? "computer" : "cloud"
                            iconSize: 11
                            color: Colors.primary
                        }
                        CustomText {
                            content: ServiceAi.currentModel
                            size: 10
                            weight: 600
                            color: Colors.primary
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // ── Empty state ───────────────────────────────────────────────
            Loader {
                active: ServiceAi.chatHistory.length === 0 && !ServiceAi.isLoading && !ServiceAi.isStreaming && !ServiceAi.hasError
                visible: active
                Layout.fillHeight: true
                Layout.fillWidth: true

                sourceComponent: Item {
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 14

                        MaterialShapes.ShapeCanvas {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredHeight: 70
                            Layout.preferredWidth: 70
                            roundedPolygon: MatrialShapeFn.getCookie6Sided()
                            color: Qt.alpha(Colors.primary, 0.14)

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                iconSize: 42
                                content: "neurology"
                                color: Colors.primary
                            }
                        }

                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            content: "How can I help you?"
                            size: 16
                            weight: 700
                            color: Colors.surfaceText
                        }

                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            content: ServiceAi.backend === "ollama"
                                ? "Running " + ServiceAi.ollamaModel + " locally"
                                : "Powered by Gemini 2.0 Flash"
                            size: 11
                            color: Colors.outline
                        }
                    }
                }
            }

            // ── Messages ──────────────────────────────────────────────────
            Loader {
                active: ServiceAi.chatHistory.length > 0 || ServiceAi.isLoading || ServiceAi.isStreaming
                visible: active
                Layout.fillWidth: true
                Layout.fillHeight: true

                sourceComponent: Flickable {
                    id: scrollArea
                    clip: true
                    contentWidth: width
                    contentHeight: Math.max(height, msgCol.y + msgCol.implicitHeight + 12)
                    interactive: contentHeight > height

                    onContentHeightChanged: {
                        scrollArea.contentY = Math.max(0, contentHeight - height)
                    }

                    Column {
                        id: msgCol
                        width: scrollArea.width
                        y: Math.max(0, scrollArea.height - implicitHeight)
                        spacing: 10

                        Repeater {
                            model: ScriptModel { values: ServiceAi.chatHistory }

                            delegate: Item {
                                required property var modelData
                                required property int index
                                property bool isUser: modelData.role === "user"

                                width: msgCol.width
                                height: bubble.implicitHeight + (isUser ? 0 : 4)

                                // AI avatar icon
                                Rectangle {
                                    visible: !isUser
                                    anchors.left: parent.left
                                    anchors.leftMargin: 2
                                    anchors.top: parent.top
                                    anchors.topMargin: 2
                                    width: 24; height: 24
                                    radius: 7
                                    color: Qt.alpha(Colors.primary, 0.18)
                                    MaterialIconSymbol {
                                        anchors.centerIn: parent
                                        content: "neurology"
                                        iconSize: 14
                                        color: Colors.primary
                                    }
                                }

                                Rectangle {
                                    id: bubble
                                    anchors.right: isUser ? parent.right : undefined
                                    anchors.left:  isUser ? undefined : parent.left
                                    anchors.leftMargin:  isUser ? 0 : 32
                                    anchors.rightMargin: isUser ? 0 : 0
                                    width: isUser
                                        ? Math.min(msgText.implicitWidth + 28, parent.width * 0.82)
                                        : parent.width - 36
                                    implicitHeight: msgText.implicitHeight + 22
                                    topLeftRadius:     isUser ? 18 : 4
                                    topRightRadius:    isUser ? 4  : 18
                                    bottomLeftRadius:  18
                                    bottomRightRadius: 18
                                    color: isUser ? Colors.primary : Colors.surfaceContainerHigh

                                    opacity: 0
                                    Component.onCompleted: fadeIn.start()
                                    NumberAnimation {
                                        id: fadeIn
                                        target: bubble
                                        property: "opacity"
                                        from: 0; to: 1; duration: 250
                                        easing.type: Easing.OutQuad
                                    }

                                    TextEdit {
                                        id: msgText
                                        anchors {
                                            left:  parent.left;  right: parent.right
                                            top:   parent.top
                                            margins: 12
                                        }
                                        text: modelData.text
                                        textFormat: isUser ? TextEdit.PlainText : TextEdit.MarkdownText
                                        font.pixelSize: 13
                                        font.family: SettingsConfig.general.defaultFont
                                        color: isUser ? Colors.primaryText : Colors.surfaceVariantText
                                        wrapMode: TextEdit.Wrap
                                        readOnly: true
                                        selectByMouse: true
                                        selectedTextColor: isUser ? Colors.primary : Colors.primaryText
                                        selectionColor:    isUser ? Colors.primaryText : Colors.primary
                                    }
                                }
                            }
                        }

                        // Loading dots
                        Rectangle {
                            visible: ServiceAi.isLoading
                            x: 32
                            width: 60; height: 34
                            radius: 17
                            color: Colors.surfaceContainerHigh
                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                Repeater {
                                    model: 3
                                    Rectangle {
                                        required property int index
                                        width: 7; height: 7; radius: 3.5
                                        color: Colors.primary
                                        SequentialAnimation on opacity {
                                            running: ServiceAi.isLoading
                                            loops: Animation.Infinite
                                            PauseAnimation { duration: index * 180 }
                                            NumberAnimation { to: 0.15; duration: 500; easing.type: Easing.InOutSine }
                                            NumberAnimation { to: 1.0;  duration: 500; easing.type: Easing.InOutSine }
                                        }
                                    }
                                }
                            }
                        }

                        // Streaming bubble
                        Item {
                            visible: ServiceAi.isStreaming
                            width: msgCol.width
                            height: streamBubble.implicitHeight + 4

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.top: parent.top
                                anchors.topMargin: 2
                                width: 24; height: 24
                                radius: 7
                                color: Qt.alpha(Colors.primary, 0.18)
                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: "neurology"
                                    iconSize: 14
                                    color: Colors.primary
                                }
                            }

                            Rectangle {
                                id: streamBubble
                                anchors.left: parent.left
                                anchors.leftMargin: 32
                                width: msgCol.width - 36
                                implicitHeight: streamText.implicitHeight + 22
                                topLeftRadius: 4; topRightRadius: 18
                                bottomLeftRadius: 18; bottomRightRadius: 18
                                color: Colors.surfaceContainerHigh

                                Text {
                                    id: streamText
                                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                                    text: ServiceAi.streamingText
                                    textFormat: Text.MarkdownText
                                    font.pixelSize: 13
                                    font.family: SettingsConfig.general.defaultFont
                                    color: Colors.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                }

                                Rectangle {
                                    anchors.left:       streamText.left
                                    anchors.top:        streamText.bottom
                                    anchors.topMargin:  3
                                    width: 8; height: 8; radius: 4
                                    color: Colors.primary
                                    SequentialAnimation on opacity {
                                        running: ServiceAi.isStreaming
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0; duration: 500 }
                                        NumberAnimation { to: 1; duration: 500 }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Error bar ─────────────────────────────────────────────────
            Loader {
                active: ServiceAi.hasError
                visible: active
                Layout.fillWidth: true

                sourceComponent: Rectangle {
                    implicitHeight: errRow.implicitHeight + 16
                    radius: 12
                    color: Qt.alpha(Colors.error, 0.12)

                    RowLayout {
                        id: errRow
                        anchors { fill: parent; margins: 10 }
                        spacing: 8

                        MaterialIconSymbol {
                            content: "error_outline"
                            iconSize: 16
                            color: Colors.error
                        }
                        CustomText {
                            Layout.fillWidth: true
                            content: ServiceAi.errorMessage
                            size: 11
                            color: Colors.error
                            wrapMode: Text.WordWrap
                        }
                        Rectangle {
                            Layout.preferredWidth: 22; Layout.preferredHeight: 22
                            radius: 6
                            color: Qt.alpha(Colors.error, 0.2)
                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: "close"
                                iconSize: 13
                                color: Colors.error
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { ServiceAi.hasError = false; ServiceAi.errorMessage = "" }
                            }
                        }
                    }
                }
            }

            // ── Input area ────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(180, 56 + inputField.implicitHeight)
                radius: 16
                color: Colors.surfaceContainerHigh

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    TextField {
                        id: inputField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        font.pixelSize: 14
                        wrapMode: TextArea.Wrap
                        background: null
                        color: Colors.surfaceText
                        font.family: SettingsConfig.general.defaultFont
                        verticalAlignment: TextInput.AlignVCenter
                        placeholderText: ServiceAi.backend === "ollama"
                            ? "Message " + ServiceAi.ollamaModel + "…"
                            : "Message Gemini…"
                        enabled: !ServiceAi.isLoading && !ServiceAi.isStreaming
                        Keys.onReturnPressed: event => {
                            if (!(event.modifiers & Qt.ShiftModifier)) sendMsg()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Model chip
                        Rectangle {
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: chipRow.implicitWidth + 14
                            radius: 11
                            color: Qt.alpha(Colors.primary, 0.13)

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialIconSymbol {
                                    content: ServiceAi.backend === "ollama" ? "computer" : "cloud"
                                    iconSize: 11
                                    color: Colors.primary
                                }
                                CustomText {
                                    content: ServiceAi.currentModel
                                    size: 10
                                    weight: 600
                                    color: Colors.primary
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Stop button — shown while loading/streaming
                        Rectangle {
                            visible: ServiceAi.isStreaming || ServiceAi.isLoading
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28
                            radius: 9
                            color: Qt.alpha(Colors.error, 0.15)
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: "stop_circle"
                                iconSize: 16
                                color: Colors.error
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ServiceAi.clearHistory()
                            }
                        }

                        // Send button
                        Rectangle {
                            id: sendBtn
                            Layout.preferredHeight: 28
                            Layout.preferredWidth: 28
                            radius: 9
                            property bool canSend: inputField.text.trim() !== "" && !ServiceAi.isLoading && !ServiceAi.isStreaming
                            color: canSend ? Colors.primary : Qt.alpha(Colors.outline, 0.25)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            scale: sendArea.pressed ? 0.85 : sendArea.containsMouse ? 1.1 : 1.0
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: "send"
                                iconSize: 15
                                color: Colors.primaryText
                            }
                            MouseArea {
                                id: sendArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                enabled: sendBtn.canSend
                                onClicked: sendMsg()
                            }
                        }
                    }
                }
            }
        }
    }

    function sendMsg() {
        let msg = inputField.text.trim()
        if (msg === "" || ServiceAi.isLoading || ServiceAi.isStreaming) return
        inputField.text = ""
        ServiceAi.sendMessage(msg)
    }
}
