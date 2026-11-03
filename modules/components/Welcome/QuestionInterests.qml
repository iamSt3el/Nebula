import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

ColumnLayout {
    id: page

    property bool showAll: false

    readonly property var interests: [
        { id: "info",  icon: "partly_cloudy_day", title: "Keep me up to date",          features: ["weather", "events", "headlines", "countdowns"] },
        { id: "phone", icon: "smartphone",        title: "My phone is usually nearby",  features: ["phone", "clipboard"] },
        { id: "music", icon: "music_note",        title: "Music is always playing",     features: ["visualiser", "soundscape", "soundFx", "wiz"] },
        { id: "read",  icon: "menu_book",         title: "I read and write a lot",      features: ["reading", "books", "notes"] },
        { id: "desk",  icon: "view_quilt",        title: "I keep a tidy desk",          features: ["tuck", "scenes"] },
        { id: "hypr",  icon: "tune",              title: "I like to tweak Hyprland",    features: ["hyprDisplays", "hyprWindows", "hyprInput", "hyprBinds"] },
        { id: "track", icon: "timer",             title: "Show me where my time goes",  features: ["screenTime", "claudeCode"] }
    ]
    readonly property int onCount: Features.list.filter(f => Features.on(f.id)).length
    readonly property int keyFrom: page.showAll ? 0 : 1
    readonly property int keyTo: page.showAll ? 0 : page.interests.length

    function isOn(item) {
        return item.features.every(id => Features.on(id))
    }

    function detail(item) {
        const names = item.features.map(id => Features.byId[id]?.name ?? id)
        const missing = item.features.filter(id => Features.missingTool(id)).map(id => Features.byId[id]?.pkg ?? Features.byId[id]?.tool ?? id)
        const list = names.length > 1 ? names.slice(0, -1).join(", ") + " and " + names[names.length - 1] : names[0]
        return missing.length > 0 ? list + " · needs " + missing.join(", ") : list
    }

    function toggle(item) {
        if (!page.isOn(item)) {
            for (const id of item.features)
                Features.set(id, true)
            return
        }
        const keep = {}
        for (const other of page.interests)
            if (other.id !== item.id && page.isOn(other))
                for (const id of other.features)
                    keep[id] = true
        for (const id of item.features)
            if (!keep[id])
                Features.set(id, false)
    }

    function pick(n) {
        if (page.showAll || n < 1 || n > page.interests.length)
            return false
        page.toggle(page.interests[n - 1])
        return true
    }

    spacing: 12

    GridLayout {
        Layout.fillWidth: true
        visible: !page.showAll
        columns: 2
        columnSpacing: 8
        rowSpacing: 8

        Repeater {
            model: page.interests

            SetupAnswer {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                padding: 14
                number: index + 1
                title: modelData.title
                detail: page.detail(modelData)
                icon: modelData.icon
                selected: page.isOn(modelData)
                onClicked: page.toggle(modelData)
            }
        }
    }

    SetupFeaturesPage {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: page.showAll
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        CustomText {
            Layout.fillWidth: true
            content: page.onCount + " of " + Features.list.length + " features on. Anything off never runs."
            size: 13
            weight: 400
            customColor: Colors.outline
        }

        M3Button {
            size: "xsmall"
            variant: "text"
            icon: page.showAll ? "grid_view" : "list"
            label: page.showAll ? "Back to the short list" : "Show every feature"
            onClicked: page.showAll = !page.showAll
        }
    }

    Item {
        Layout.fillHeight: true
        visible: !page.showAll
    }
}
