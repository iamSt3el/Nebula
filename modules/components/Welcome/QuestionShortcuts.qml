import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

ColumnLayout {
    id: page

    required property var keybinds

    property bool showAll: false

    readonly property var essentials: ["appLauncher", "overview", "clipboard", "wallpaperLauncher"]
    readonly property var nebulaEntries: ServiceKeybinds.entries.filter(e => e.group === "Nebula" && e.action !== "")
    readonly property int keyFrom: 0
    readonly property int keyTo: 0

    function entryFor(action) {
        return page.keybinds.entryFor(action)
    }

    function pick(n) {
        return false
    }

    spacing: 12

    GridLayout {
        Layout.fillWidth: true
        visible: !page.showAll
        columns: 2
        columnSpacing: 8
        rowSpacing: 8

        Repeater {
            model: page.essentials

            Rectangle {
                id: tile

                required property string modelData

                readonly property var entry: page.entryFor(tile.modelData)
                readonly property var meta: ServiceKeybinds.actions[tile.modelData] ?? ({ name: tile.modelData, icon: "keyboard" })

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 92
                radius: 22
                color: Colors.surfaceContainer

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10

                    RowLayout {
                        spacing: 8

                        MaterialIconSymbol {
                            content: tile.meta.icon
                            iconSize: 18
                            customColor: Colors.primary
                        }

                        CustomText {
                            content: tile.meta.name
                            size: 14
                            weight: 500
                            customColor: Colors.surfaceVariantText
                        }
                    }

                    Row {
                        visible: tile.entry !== null
                        spacing: 4

                        Repeater {
                            model: tile.entry ? ServiceKeybinds.keyParts(tile.entry.key ?? tile.entry.origKey) : []

                            KeyCap {
                                required property string modelData
                                key: modelData
                                implicitHeight: 30
                            }
                        }
                    }

                    CustomText {
                        visible: tile.entry === null
                        content: {
                            const d = page.keybinds.defaults.find(x => x.action === tile.modelData)
                            return d ? "Not bound yet · Nebula's key is " + ServiceKeybinds.pretty(d.key) : "Not bound yet"
                        }
                        size: 13
                        weight: 400
                        customColor: Colors.outline
                    }
                }
            }
        }
    }

    SetupScroll {
        id: allScroll

        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: page.showAll

        ColumnLayout {
            width: allScroll.contentWidthAvail
            spacing: 3

            Repeater {
                model: page.nebulaEntries

                Rectangle {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool isFirst: row.index === 0
                    readonly property bool isLast: row.index === page.nebulaEntries.length - 1

                    Layout.fillWidth: true
                    implicitHeight: 48
                    topLeftRadius: row.isFirst ? 18 : 6
                    topRightRadius: row.isFirst ? 18 : 6
                    bottomLeftRadius: row.isLast ? 18 : 6
                    bottomRightRadius: row.isLast ? 18 : 6
                    color: Colors.surfaceContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        spacing: 12

                        MaterialIconSymbol {
                            content: row.modelData.icon ?? "keyboard"
                            iconSize: 18
                            customColor: Colors.surfaceVariantText
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: row.modelData.name
                            size: 14
                            weight: 400
                            elide: Text.ElideRight
                        }

                        Row {
                            visible: !row.modelData.unset
                            spacing: 3

                            Repeater {
                                model: row.modelData.unset ? [] : ServiceKeybinds.keyParts(row.modelData.key)
                                KeyCap {
                                    required property string modelData
                                    key: modelData
                                }
                            }
                        }

                        CustomText {
                            visible: row.modelData.unset
                            content: "Not bound"
                            size: 13
                            weight: 400
                            customColor: Colors.outline
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: callout.implicitHeight + 32
        radius: 22
        color: Colors.tertiaryContainer
        visible: page.keybinds.ready

        RowLayout {
            id: callout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 18
            anchors.rightMargin: 16
            spacing: 14

            MaterialIconSymbol {
                Layout.alignment: Qt.AlignTop
                content: page.keybinds.active || page.keybinds.coveredByUser ? "check_circle" : "integration_instructions"
                iconSize: 22
                fill: 1
                customColor: Colors.tertiaryContainerText
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                CustomText {
                    Layout.fillWidth: true
                    content: page.keybinds.active ? "Nebula's shortcuts are on"
                           : page.keybinds.coveredByUser ? "Your config already binds them"
                           : page.keybinds.adding ? "Adding Nebula's shortcuts"
                           : "Add Nebula's shortcuts to hyprland.lua"
                    size: 15
                    weight: 600
                    customColor: Colors.tertiaryContainerText
                }

                CustomText {
                    Layout.fillWidth: true
                    content: {
                        if (page.keybinds.error !== "")
                            return "That didn't work: " + page.keybinds.error
                        if (page.keybinds.active)
                            return "They load from hypr/nebula/keybinds.lua. Change any of them in Settings › Shortcuts."
                        if (page.keybinds.coveredByUser)
                            return "Every Nebula action already has a key in your own config, so nothing needs adding. Change them in Settings › Shortcuts."
                        const u = page.keybinds.unbound.length
                        const base = (u === 1 ? "1 Nebula action has" : u + " Nebula actions have") + " no key yet. This copies nebula/keybinds.lua next to your config and adds one require line when you finish."
                        const n = page.keybinds.conflicts.length
                        if (n === 0)
                            return base + " None of its keys are taken."
                        const keys = page.keybinds.conflicts.slice(0, 3).map(c => ServiceKeybinds.pretty(c.key)).join(", ")
                        return base + " " + n + (n === 1 ? " of its keys is" : " of its keys are") + " already bound in your config (" + keys + (n > 3 ? " and more" : "") + "), and Hyprland would run both."
                    }
                    size: 13
                    weight: 400
                    customColor: page.keybinds.error !== "" ? Colors.error : Colors.tertiaryContainerText
                    wrapMode: Text.WordWrap
                }
            }

            CustomToogle {
                visible: page.keybinds.shouldOffer
                Layout.preferredWidth: 52
                Layout.preferredHeight: 32
                isToggleOn: page.keybinds.want
                onToggled: on => page.keybinds.setWant(on)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        CustomText {
            Layout.fillWidth: true
            content: "No key needed for edit mode: right-click an empty part of the bar, or double-click a widget."
            size: 13
            weight: 400
            customColor: Colors.outline
            wrapMode: Text.WordWrap
        }

        M3Button {
            size: "xsmall"
            variant: "text"
            icon: page.showAll ? "grid_view" : "list"
            label: page.showAll ? "Just the four" : "Show all " + page.nebulaEntries.length
            onClicked: page.showAll = !page.showAll
        }
    }

    Item {
        Layout.fillHeight: true
        visible: !page.showAll
    }
}
