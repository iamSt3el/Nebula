import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

ColumnLayout {
    id: page

    required property var store

    readonly property var groups: [
        { id: "terminal", label: "Terminal" },
        { id: "desktop",  label: "Desktop" },
        { id: "apps",     label: "Apps" }
    ]
    readonly property bool allPicked: page.store.installedApps.length > 0
        && page.store.pickedApps.length === page.store.installedApps.length
    readonly property int keyFrom: 0
    readonly property int keyTo: 0

    function pick(n) {
        return false
    }

    spacing: 16

    RowLayout {
        visible: page.store.scanning && !page.store.scanned
        spacing: 12

        CustomCircularLoader {
            size: 28
            trackWidth: 3
        }

        CustomText {
            content: "Looking for apps on this computer"
            size: 14
            weight: 500
            customColor: Colors.surfaceVariantText
        }
    }

    Repeater {
        model: page.store.scanned ? page.groups : []

        ColumnLayout {
            id: group

            required property var modelData

            readonly property var apps: page.store.installedApps.filter(a => a.group === group.modelData.id)

            Layout.fillWidth: true
            visible: group.apps.length > 0
            spacing: 8

            CustomText {
                content: group.modelData.label
                size: 13
                weight: 600
                customColor: Colors.surfaceVariantText
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: group.apps

                    M3Button {
                        required property var modelData

                        readonly property bool on: page.store.isPicked(modelData.id)

                        size: "small"
                        variant: "outlined"
                        toggled: on
                        icon: on ? "check" : ""
                        label: modelData.name
                        onClicked: page.store.setPicked(modelData.id, !on)
                    }
                }
            }
        }
    }

    CustomText {
        Layout.fillWidth: true
        visible: page.store.scanned && page.store.missingApps.length > 0
        content: "Not installed, so left out: " + page.store.missingApps.map(a => a.name).join(", ")
        size: 13
        weight: 400
        customColor: Colors.outline
        wrapMode: Text.WordWrap
    }

    RowLayout {
        Layout.fillWidth: true
        visible: page.store.scanned && page.store.installedApps.length > 0
        spacing: 12

        M3Button {
            size: "xsmall"
            variant: "tonal"
            label: page.allPicked ? "Pick none" : "Pick all " + page.store.installedApps.length
            onClicked: page.allPicked ? page.store.pickNone() : page.store.pickAll()
        }

        MaterialIconSymbol {
            visible: page.store.replaceCount > 0
            content: "backup"
            iconSize: 18
            customColor: Colors.tertiary
        }

        CustomText {
            Layout.fillWidth: true
            content: page.store.replaceCount > 0
                ? (page.store.replaceCount === 1 ? "1 pick replaces a file" : page.store.replaceCount + " picks replace files") + " you already have. Nebula keeps a .bak copy first."
                : "Files Nebula writes are rewritten each time the wallpaper changes."
            size: 13
            weight: 400
            customColor: Colors.outline
            wrapMode: Text.WordWrap
        }
    }

    CustomText {
        Layout.fillWidth: true
        visible: page.store.scanned && page.store.apps.length === 0
        content: "Couldn't read the app list. Run nebula apps detect in a terminal to see why, then open setup again."
        size: 14
        weight: 400
        customColor: Colors.error
        wrapMode: Text.WordWrap
    }

    Item { Layout.fillHeight: true }
}
