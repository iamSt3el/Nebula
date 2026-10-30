import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Rectangle {
    id: hero

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string value: ""
    property string valueCaption: ""
    property string tone: "primary"
    property Component lead: null
    default property alias actions: actionRow.data

    readonly property color ink: hero.tone === "primary" ? Colors.primaryContainerText
        : hero.tone === "tertiary" ? Colors.tertiaryContainerText : Colors.surfaceText
    readonly property color tileColor: hero.tone === "primary" ? Colors.primary
        : hero.tone === "tertiary" ? Colors.tertiaryContainerText : Colors.surfaceContainerHighest
    readonly property color tileInk: hero.tone === "primary" ? Colors.primaryText
        : hero.tone === "tertiary" ? Colors.tertiaryContainer : Colors.primary

    Layout.fillWidth: true
    implicitHeight: heroCol.implicitHeight + 36
    radius: 28
    color: hero.tone === "primary" ? Colors.primaryContainer
        : hero.tone === "tertiary" ? Colors.tertiaryContainer : Colors.surfaceContainerHigh

    ColumnLayout {
        id: heroCol
        x: 20
        y: 18
        width: hero.width - 40
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Loader {
                active: hero.lead !== null
                visible: active
                sourceComponent: hero.lead
            }

            Rectangle {
                visible: hero.icon !== "" && hero.lead === null
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                radius: 18
                color: hero.tileColor

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: hero.icon
                    iconSize: 28
                    fill: 1
                    customColor: hero.tileInk
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                CustomText {
                    Layout.fillWidth: true
                    content: hero.title
                    family: SettingsConfig.general.displayFont ?? "Rubik"
                    renderType: Text.QtRendering
                    size: 26
                    elide: Text.ElideRight
                    customColor: hero.ink
                }

                CustomText {
                    Layout.fillWidth: true
                    visible: hero.subtitle !== ""
                    content: hero.subtitle
                    size: 12
                    wrapMode: Text.WordWrap
                    customColor: hero.ink
                    opacity: 0.85
                }
            }

            ColumnLayout {
                visible: hero.value !== ""
                spacing: 0

                CustomText {
                    Layout.alignment: Qt.AlignRight
                    content: hero.value
                    family: SettingsConfig.general.displayFont ?? "Rubik"
                    renderType: Text.QtRendering
                    size: 28
                    customColor: hero.ink
                }

                CustomText {
                    Layout.alignment: Qt.AlignRight
                    visible: hero.valueCaption !== ""
                    content: hero.valueCaption
                    size: 12
                    customColor: hero.ink
                    opacity: 0.85
                }
            }
        }

        RowLayout {
            id: actionRow
            visible: actionRow.children.length > 0
            spacing: 8
        }
    }
}
