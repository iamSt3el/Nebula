import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Edit

ColumnLayout {
    id: pinsSection
    required property Item host
    readonly property bool isSection: true
    Layout.fillWidth: true
    spacing: 12

    EditHeading {
        Layout.fillWidth: true
        Layout.topMargin: 10
        visible: true
        content: "Pinned apps"
        size: 13
        customColor: Colors.primary
    }
    ColumnLayout {
        id: drawerGroup15
        Layout.fillWidth: true
        visible: true
        spacing: 8
        EditRow {
            visible: true
            ColumnLayout {
                id: pinSection
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 8
                visible: true

                property string query: ""
                readonly property var results: pinSection.query.trim().length === 0 ? []
                    : ServiceApps.fuzzyQuery(pinSection.query.trim()).slice(0, 8)

                CustomText { content: "Pinned apps"; size: 13; customColor: Colors.primary }

                CustomText {
                    content: "Drag icons in the dock to reorder them, or onto this card to unpin."
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    size: 12
                    customColor: Colors.outline
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 18
                    color: Colors.surfaceContainerHigh
                    border.width: pinInput.activeFocus ? 2 : 0
                    border.color: Colors.primary

                    MaterialIconSymbol {
                        id: pinSearchIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        content: "search"
                        iconSize: 16
                        customColor: Colors.outline
                    }

                    TextInput {
                        id: pinInput
                        anchors.left: pinSearchIcon.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        selectByMouse: true
                        color: Colors.surfaceText
                        selectionColor: Qt.alpha(Colors.primary, 0.35)
                        font.pixelSize: 13
                        font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                        onTextChanged: pinSection.query = pinInput.text
                        Keys.onEscapePressed: event => {
                            if (pinInput.text !== "") {
                                pinInput.text = ""
                                event.accepted = true
                            } else {
                                event.accepted = false
                            }
                        }

                        CustomText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: pinInput.text === ""
                            content: "Search apps to pin"
                            size: 13
                            customColor: Colors.outline
                        }
                    }
                }

                Repeater {
                    model: pinSection.results

                    delegate: RowLayout {
                        id: pinRow
                        required property var modelData
                        readonly property bool pinned: ServiceApps.isPinnedById(pinRow.modelData.id)

                        Layout.fillWidth: true
                        spacing: 10

                        Image {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            source: IconUtil.themeIcon(pinRow.modelData.icon, "image-missing")
                            sourceSize.width: 44
                            sourceSize.height: 44
                            fillMode: Image.PreserveAspectFit
                        }
                        CustomText {
                            Layout.fillWidth: true
                            content: pinRow.modelData.name
                            elide: Text.ElideRight
                            size: 13
                        }
                        M3Button {
                            variant: pinRow.pinned ? "text" : "tonal"
                            icon: pinRow.pinned ? "check" : "push_pin"
                            label: pinRow.pinned ? "Pinned" : "Pin"
                            onClicked: ServiceApps.togglePinById(pinRow.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
