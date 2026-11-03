import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

ColumnLayout {
    id: page

    required property var palettes

    readonly property string scheme: SettingsConfig.theme.matugenScheme ?? "scheme-content"
    readonly property string mode: SettingsConfig.theme.matugenTheme ?? "dark"
    readonly property var options: [
        { value: "dark",  title: "Dark",  detail: "Easier on the eyes at night", icon: "dark_mode" },
        { value: "light", title: "Light", detail: "Crisp in a bright room",      icon: "light_mode" }
    ]
    readonly property int keyFrom: 1
    readonly property int keyTo: 2

    function choose(v) {
        if (page.mode === v)
            return
        SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, { matugenTheme: v })
        ServiceWallpaper.applyTheme()
    }

    function pick(n) {
        if (n < 1 || n > page.options.length)
            return false
        page.choose(page.options[n - 1].value)
        return true
    }

    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Repeater {
            model: page.options

            SetupAnswer {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                padding: 12
                number: index + 1
                title: modelData.title
                detail: modelData.detail
                icon: modelData.icon
                selected: page.mode === modelData.value
                onClicked: page.choose(modelData.value)

                PalettePreview {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    palette: page.palettes.get(page.scheme, modelData.value)
                }
            }
        }
    }

    CustomText {
        Layout.fillWidth: true
        Layout.topMargin: 4
        content: "GTK, Qt and Firefox switch along with the shell when they're picked on the apps question."
        size: 13
        weight: 400
        customColor: Colors.outline
        wrapMode: Text.WordWrap
    }

    Item { Layout.fillHeight: true }
}
