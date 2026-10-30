import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.Widgets as WM
import qs.modules.services

Item {
    id: root
    anchors.fill: parent

    readonly property var widgets: SettingsConfig.widgets ?? ({})
    readonly property var general: SettingsConfig.general ?? ({})
    readonly property bool panelOn: root.widgets.showWidgets ?? true
    readonly property bool visOn: root.general.musicVisOn ?? false
    readonly property var opacitySteps: [
        { value: 0.30, label: "Clear" }, { value: 0.45, label: "Frosted" }, { value: 0.60, label: "Hazy" },
        { value: 0.75, label: "Light" }, { value: 0.90, label: "Solid" }
    ]
    readonly property real cardOpacity: {
        const cur = root.widgets.cardOpacity ?? 0.60
        let best = root.opacitySteps[0].value
        for (const s of root.opacitySteps)
            if (Math.abs(s.value - cur) < Math.abs(best - cur))
                best = s.value
        return best
    }
    readonly property int placedCount: {
        let n = 0
        const cat = WM.WidgetCatalog.catalog
        for (let i = 0; i < cat.length; i++)
            for (let j = 0; j < cat[i].items.length; j++)
                if (WM.WidgetCatalog.isActive(cat[i].items[j]))
                    n++
        return n
    }

    function patchWidgets(p) {
        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, p)
    }

    function patchGeneral(p) {
        SettingsConfig.general = Object.assign({}, SettingsConfig.general, p)
    }

    function openStudio(add) {
        GlobalStates.settingsOpen = false
        GlobalStates.widgetOpenAdd = add
        GlobalStates.openEdit("desktop")
    }

    readonly property string side: root.general.notesSide ?? "L"
    readonly property bool stacked: (root.general.notesLayout ?? "stack") === "stack"
    readonly property string anchorAt: root.general.notesAnchor ?? "top"
    readonly property var widths: [300, 340, 400]
    readonly property var noteWidths: [{ value: 300, label: "Compact" }, { value: 340, label: "Regular" }, { value: 400, label: "Wide" }]
    readonly property int cardWidth: root.widths[root.nearest(root.widths, root.general.notesCardWidth ?? 340)]
    readonly property int offset: root.general.notesOffset ?? 200
    readonly property int gap: root.general.notesGap ?? 12
    readonly property var notes: ServiceNotes.notes.slice().sort((a, b) => a.y - b.y)
    readonly property string sideName: root.side === "R" ? "right" : "left"

    function set(key, value) {
        const o = {}
        o[key] = value
        SettingsConfig.general = Object.assign({}, SettingsConfig.general, o)
    }

    function nearest(list, v) {
        let best = 0
        for (let i = 1; i < list.length; i++)
            if (Math.abs(list[i] - v) < Math.abs(list[best] - v))
                best = i
        return best
    }

    function openNote(id) {
        GlobalStates.settingsOpen = false
        ServiceNotes.openId = id
    }

    StageView {
        StagePage {
            stageId: "front"

            CustomCard {
                autoRadius: false; topRadius: 28; bottomRadius: 28

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    CustomToogle {
                        isToggleOn: root.panelOn
                        onToggled: state => root.patchWidgets({ showWidgets: state })
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        CustomText {
                            Layout.fillWidth: true
                            content: "Desktop widgets"
                            size: 14
                            elide: Text.ElideRight
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: (root.panelOn ? root.placedCount + (root.placedCount === 1 ? " widget" : " widgets") : "Widgets hidden")
                                + " · " + root.notes.length + (root.notes.length === 1 ? " note" : " notes")
                            size: 12
                            elide: Text.ElideRight
                            customColor: Colors.outline
                        }
                    }

                    M3Button {
                        visible: root.panelOn
                        icon: "open_with"
                        label: "Arrange"
                        onClicked: root.openStudio(false)
                    }

                    M3Button {
                        visible: root.panelOn
                        variant: "tonal"
                        icon: "add_circle"
                        label: "Widget"
                        onClicked: root.openStudio(true)
                    }

                    M3Button {
                        variant: "tonal"
                        icon: "sticky_note_2"
                        label: "Note"
                        onClicked: root.openNote(ServiceNotes.add())
                    }
                }
            }

            StageHeading { text: "Card look" }

            StageDropdownRow {
                icon: "blur_on"
                title: "Widget cards"
                subtitle: "Frost lets the wallpaper through"
                options: ["Solid", "Frost"]
                current: WidgetSizes.cardStyle === "flat" ? "Solid" : "Frost"
                dropdownWidth: 160
                onPicked: name => root.patchWidgets({ cardStyle: name === "Solid" ? "flat" : "frosted" })
            }

            StageDropdownRow {
                visible: WidgetSizes.cardStyle !== "flat"
                icon: "opacity"
                title: "How clear"
                subtitle: "How much wallpaper shows through widget cards"
                options: root.opacitySteps.map(o => o.label)
                current: root.opacitySteps.find(o => o.value === root.cardOpacity)?.label ?? ""
                dropdownWidth: 160
                onPicked: name => root.patchWidgets({ cardOpacity: root.opacitySteps.find(o => o.label === name).value })
            }

            StageDropdownRow {
                icon: "width"
                title: "Note width"
                subtitle: root.cardWidth + " px"
                options: root.noteWidths.map(o => o.label)
                current: root.noteWidths.find(o => o.value === root.cardWidth)?.label ?? ""
                dropdownWidth: 160
                onPicked: name => root.set("notesCardWidth", root.noteWidths.find(o => o.label === name).value)
            }

            StageHeading { text: "Also on the desktop" }

            StageRow {
                icon: "graphic_eq"
                title: "Music visualizer"
                subtitle: (root.general.musicVisStyle ?? "Wave") + " · " + (root.general.musicVisColor ?? "Primary") + " · " + (root.general.musicVisFps ?? "30 fps") + " · " + (root.general.musicVisBars ?? 60) + " bars · " + (root.general.musicVisEdge ?? "bottom")
                target: "visualizer"

                CustomToogle {
                    isToggleOn: root.visOn
                    onToggled: state => root.patchGeneral({ musicVisOn: state })
                }
            }

            StageNavRow {
                icon: root.side === "R" ? "align_horizontal_right" : "align_horizontal_left"
                title: "Where notes sit"
                subtitle: (root.side === "R" ? "Right" : "Left") + " edge · " + (root.stacked ? "stacked from the " + root.anchorAt + " · " + root.gap + " px apart" : "placed freely")
                target: "notesPlacement"
            }

            StageNavRow {
                icon: "network_check"
                title: "Network speeds"
                subtitle: "How often widgets re-read upload and download"
                value: root.widgets.networkGraphInterval ?? "2 s"
                target: "network"
            }
        }

        StageLazy {
            stageId: "visualizer"

            StagePage {
                stageId: "visualizer"
                title: "Music visualizer"

                StageSwitchRow {
                    icon: "graphic_eq"
                    title: "Show the visualizer"
                    subtitle: "Audio bars along the bottom of the desktop"
                    checked: root.visOn
                    onToggled: on => root.patchGeneral({ musicVisOn: on })
                }

                StageGap {}

                StageChoiceRow {
                    enabled: root.visOn
                    title: "Style"
                    subtitle: "Smooth wave, glowing line, LED blocks, bar chart or a vibrating string"
                    options: [
                        { value: "Wave", label: "Wave", icon: "waves" },
                        { value: "Neon", label: "Neon line", icon: "show_chart" },
                        { value: "LED", label: "LED blocks", icon: "grid_view" },
                        { value: "Chart", label: "Chart", icon: "bar_chart" },
                        { value: "String", label: "String", icon: "airwave" }
                    ]
                    current: (root.general.musicVisStyle ?? "Wave") === "Mirror" ? "Wave" : (root.general.musicVisStyle ?? "Wave")
                    onPicked: v => root.patchGeneral({ musicVisStyle: v })
                }

                StageChoiceRow {
                    enabled: root.visOn
                    title: "Edge"
                    subtitle: "All sides runs one wave round the whole screen, bass at the bottom, treble at the top"
                    options: [
                        { value: "bottom", label: "Bottom", icon: "align_vertical_bottom" },
                        { value: "top", label: "Top", icon: "align_vertical_top" },
                        { value: "left", label: "Left", icon: "align_horizontal_left" },
                        { value: "right", label: "Right", icon: "align_horizontal_right" },
                        { value: "all", label: "All sides", icon: "crop_free" }
                    ]
                    current: root.general.musicVisEdge ?? "bottom"
                    onPicked: v => root.patchGeneral({ musicVisEdge: v })
                }

                StageChoiceRow {
                    enabled: root.visOn
                    title: "Layer"
                    subtitle: "Draw it behind your desktop widgets or in front of them"
                    options: [
                        { value: "behind", label: "Behind widgets", icon: "flip_to_back" },
                        { value: "front", label: "In front", icon: "flip_to_front" }
                    ]
                    current: root.general.musicVisLayer ?? "behind"
                    onPicked: v => root.patchGeneral({ musicVisLayer: v })
                }

                StageSliderRow {
                    enabled: root.visOn
                    title: "Height"
                    subtitle: "How far it reaches in from the edge, in pixels"
                    from: 60
                    to: 500
                    step: 10
                    current: root.general.musicVisHeight ?? 200
                    onCommitted: v => root.patchGeneral({ musicVisHeight: Math.round(v) })
                }

                StageSliderRow {
                    enabled: root.visOn && (root.general.musicVisStyle ?? "Wave") === "String"
                    title: "String spacing"
                    subtitle: "Distance between the zig-zag strokes of the String style, in pixels"
                    from: 4
                    to: 60
                    step: 1
                    current: root.general.musicVisStringGap ?? 12
                    onCommitted: v => root.patchGeneral({ musicVisStringGap: Math.round(v) })
                }

                StageSliderRow {
                    enabled: root.visOn
                    title: "Brightness"
                    subtitle: "How strongly it shows over the wallpaper, in percent"
                    from: 15
                    to: 100
                    step: 5
                    current: root.general.musicVisBrightness ?? 75
                    onCommitted: v => root.patchGeneral({ musicVisBrightness: Math.round(v) })
                }

                StageDropdownRow {
                    enabled: root.visOn
                    title: "Colour"
                    subtitle: "Theme role for the bars and their ghost cap"
                    options: ["Primary", "Secondary", "Tertiary", "Two-tone", "Deep", "Warm"]
                    current: root.general.musicVisColor ?? "Primary"
                    onPicked: name => root.patchGeneral({ musicVisColor: name })
                }

                StageDropdownRow {
                    enabled: root.visOn
                    title: "Frame rate"
                    subtitle: "Higher is smoother and costs more CPU"
                    options: ["15 fps", "30 fps", "60 fps", "90 fps", "120 fps"]
                    current: root.general.musicVisFps ?? "30 fps"
                    onPicked: name => root.patchGeneral({ musicVisFps: name })
                }

                StageSliderRow {
                    enabled: root.visOn
                    title: "Bars"
                    subtitle: "Number of frequency bands to render"
                    from: 10
                    to: 256
                    step: 2
                    current: root.general.musicVisBars ?? 60
                    onCommitted: v => root.patchGeneral({ musicVisBars: Math.round(v) })
                }

                StageGap {}

                StageSwitchRow {
                    enabled: root.visOn && (root.general.musicVisEdge ?? "bottom") !== "all"
                    icon: "flip"
                    title: "Mirror"
                    subtitle: (root.general.musicVisEdge ?? "bottom") === "all"
                        ? "All sides is already mirrored: bass at the bottom, treble at the top"
                        : "Bass in the centre, treble out to both ends"
                    checked: root.general.musicVisMirror === true || root.general.musicVisStyle === "Mirror"
                    onToggled: on => root.patchGeneral(root.general.musicVisStyle === "Mirror"
                        ? { musicVisMirror: on, musicVisStyle: "Wave" } : { musicVisMirror: on })
                }

                StageSwitchRow {
                    enabled: root.visOn
                    icon: "bolt"
                    title: "Beat pulse"
                    subtitle: "Flashes brighter and jumps a little on each bass hit"
                    checked: root.general.musicVisBeat ?? true
                    onToggled: on => root.patchGeneral({ musicVisBeat: on })
                }

                StageSwitchRow {
                    enabled: root.visOn
                    icon: "gradient"
                    title: "Colour by frequency"
                    subtitle: "Bass in your colour, fading to a second accent towards the treble"
                    checked: root.general.musicVisFreqColors ?? true
                    onToggled: on => root.patchGeneral({ musicVisFreqColors: on })
                }

                StageSwitchRow {
                    enabled: root.visOn
                    icon: "volume_off"
                    title: "Fade when quiet"
                    subtitle: "Sinks away after two seconds of silence and rises when sound comes back"
                    checked: root.general.musicVisFade ?? true
                    onToggled: on => root.patchGeneral({ musicVisFade: on })
                }
            }
        }

        StageLazy {
            stageId: "network"

            StagePage {
                stageId: "network"
                title: "Network speeds"

                StageDropdownRow {
                    title: "Update every"
                    subtitle: "How often the speeds are re-read"
                    options: ["1 s", "2 s", "5 s", "10 s", "30 s"]
                    current: root.widgets.networkGraphInterval ?? "2 s"
                    onPicked: name => root.patchWidgets({ networkGraphInterval: name })
                }
            }
        }

        StageLazy {
            stageId: "notesPlacement"

            StagePage {
                stageId: "notesPlacement"
                title: "Placement"

                StageDropdownRow {
                    icon: root.side === "R" ? "align_horizontal_right" : "align_horizontal_left"
                    title: "Screen edge"
                    options: ["Left", "Right"]
                    current: root.side === "R" ? "Right" : "Left"
                    dropdownWidth: 160
                    onPicked: name => {
                        const v = name === "Right" ? "R" : "L"
                        root.set("notesSide", v)
                        ServiceNotes.moveAll(v)
                    }
                }

                StageDropdownRow {
                    icon: root.stacked ? "view_agenda" : "open_with"
                    title: "Arrangement"
                    options: ["Stacked", "Free"]
                    current: root.stacked ? "Stacked" : "Free"
                    dropdownWidth: 160
                    onPicked: name => root.set("notesLayout", name === "Stacked" ? "stack" : "free")
                }

                StageDropdownRow {
                    visible: root.stacked
                    icon: root.anchorAt === "bottom" ? "vertical_align_bottom" : root.anchorAt === "middle" ? "vertical_align_center" : "vertical_align_top"
                    title: "Position"
                    options: ["Top", "Middle", "Bottom"]
                    current: root.anchorAt.charAt(0).toUpperCase() + root.anchorAt.slice(1)
                    dropdownWidth: 160
                    onPicked: name => root.set("notesAnchor", name.toLowerCase())
                }

                StageSpinRow {
                    visible: root.stacked && root.anchorAt !== "middle"
                    icon: "height"
                    title: "Distance from the " + root.anchorAt
                    subtitle: "From the screen " + root.anchorAt
                    from: 0
                    to: 800
                    step: 20
                    suffix: " px"
                    current: root.offset
                    onStepped: v => root.set("notesOffset", v)
                }

                StageSpinRow {
                    visible: root.stacked
                    icon: "density_medium"
                    title: "Gap between notes"
                    subtitle: "Space between stacked notes"
                    from: 0
                    to: 48
                    step: 2
                    suffix: " px"
                    current: root.gap
                    onStepped: v => root.set("notesGap", v)
                }
            }
        }
    }
}
