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
    readonly property var base: [
        { value: "scheme-neutral", title: "Calm",     detail: "Mostly greys, colour only where it matters" },
        { value: "scheme-content", title: "Balanced", detail: "Matches the wallpaper without shouting" },
        { value: "scheme-vibrant", title: "Vivid",    detail: "Bold and saturated, very obviously yours" }
    ]
    readonly property bool custom: page.base.every(o => o.value !== page.scheme)
    readonly property var options: page.custom
        ? page.base.concat([{ value: page.scheme, title: "Keep " + page.pretty(page.scheme), detail: "The scheme you picked in Settings" }])
        : page.base
    readonly property var swatchKeys: ["primary", "primaryContainer", "secondary", "tertiary", "tertiaryContainer"]
    readonly property int keyFrom: 1
    readonly property int keyTo: page.options.length

    function pretty(s) {
        const t = String(s).replace("scheme-", "").replace(/-/g, " ")
        return t.charAt(0).toUpperCase() + t.slice(1)
    }

    function choose(v) {
        if (page.scheme === v)
            return
        SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, { matugenScheme: v })
        if (Colors.sourceWallpaper !== "")
            ServiceWallpaper.reapply()
    }

    function pick(n) {
        if (n < 1 || n > page.options.length)
            return false
        page.choose(page.options[n - 1].value)
        return true
    }

    spacing: 3

    Repeater {
        model: page.options

        SetupAnswer {
            id: answer

            required property var modelData
            required property int index

            readonly property var palette: page.palettes.get(modelData.value, page.mode)

            Layout.fillWidth: true
            first: index === 0
            last: index === page.options.length - 1
            number: index + 1
            title: modelData.title
            detail: modelData.detail
            selected: page.scheme === modelData.value
            onClicked: page.choose(modelData.value)

            trailing: Repeater {
                model: page.swatchKeys

                Rectangle {
                    required property string modelData
                    width: 22
                    height: 34
                    radius: 8
                    color: answer.palette ? answer.palette[modelData] : Colors.surfaceContainerHighest
                    opacity: answer.palette ? 1 : 0.5
                    border.width: 1
                    border.color: Qt.alpha(answer.ink, 0.18)
                    Behavior on color { EffectsColorAnim {} }
                }
            }
        }
    }

    Item { Layout.fillHeight: true }
}
