import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

ColumnLayout {
    id: page

    spacing: 22

    readonly property var roles: [
        { name: "Primary",                fill: Colors.primary,               ink: Colors.primaryText },
        { name: "Secondary",              fill: Colors.secondary,             ink: Colors.secondaryText },
        { name: "Tertiary",               fill: Colors.tertiary,              ink: Colors.tertiaryText },
        { name: "Primary container",      fill: Colors.primaryContainer,      ink: Colors.primaryContainerText },
        { name: "Secondary container",    fill: Colors.secondaryContainer,    ink: Colors.secondaryContainerText },
        { name: "Surface container high", fill: Colors.surfaceContainerHigh,  ink: Colors.surfaceText }
    ]

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 20
        rowSpacing: 14

        CustomText {
            content: "Mode"
            size: 14
            weight: 500
            customColor: Colors.surfaceVariantText
        }

        M3ButtonGroup {
            Layout.preferredWidth: 240
            Layout.preferredHeight: 36
            fillWidth: true
            textSize: 13
            iconSize: 16
            model: [
                { value: "dark",  label: "Dark",  icon: "dark_mode"  },
                { value: "light", label: "Light", icon: "light_mode" }
            ]
            activeCheck: v => (SettingsConfig.theme.matugenTheme ?? "dark") === v
            onSegmentClicked: v => {
                if ((SettingsConfig.theme.matugenTheme ?? "dark") === v) return
                SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, { matugenTheme: v })
                ServiceWallpaper.applyTheme()
            }
        }

        CustomText {
            content: "Scheme"
            size: 14
            weight: 500
            customColor: Colors.surfaceVariantText
        }

        CustomListNew {
            Layout.preferredWidth: 240
            Layout.preferredHeight: 36
            color: Colors.surfaceContainerHighest
            list: Settings.matugen
            currentVal: SettingsConfig.theme.matugenScheme
            onListChildClicked: child => {
                const currentVal = child.name
                if (!currentVal || currentVal === SettingsConfig.theme.matugenScheme) return
                SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, { matugenScheme: currentVal })
                if (Colors.sourceWallpaper !== "")
                    ServiceWallpaper.reapply()
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: 10
        rowSpacing: 10

        Repeater {
            model: page.roles

            Rectangle {
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 96
                radius: 20
                color: modelData.fill

                Behavior on color { ColorAnimation { duration: 320 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 0

                    CustomText {
                        Layout.fillWidth: true
                        content: modelData.name
                        size: 13
                        weight: 600
                        customColor: modelData.ink
                    }

                    Item { Layout.fillHeight: true }

                    CustomText {
                        content: String(modelData.fill)
                        size: 12
                        weight: 400
                        family: "JetBrains Mono"
                        customColor: modelData.ink
                    }
                }
            }
        }
    }

    CustomText {
        Layout.fillWidth: true
        content: "Changes apply straight away, to the shell and to every app you pick next."
        size: 13
        weight: 400
        customColor: Colors.outline
        wrapMode: Text.WordWrap
    }

    Item { Layout.fillHeight: true }
}
