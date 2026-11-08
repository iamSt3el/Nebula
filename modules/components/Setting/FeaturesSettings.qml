import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    readonly property int onCount: Features.list.filter(f => Features.on(f.id)).length
    readonly property var general: SettingsConfig.general ?? ({})
    readonly property var genieInfo: Features.byId.genie
    readonly property bool genieOpenOn: root.general.genieOpen ?? true
    readonly property bool genieCloseOn: root.general.genieClose ?? true
    readonly property int genieOpenMs: root.general.genieOpenMs ?? 600
    readonly property int genieCloseMs: root.general.genieCloseMs ?? 520
    readonly property bool genieWsOn: root.general.genieWorkspace ?? true
    readonly property string genieWsStyle: ["glide", "carousel"].includes(root.general.genieWorkspaceStyle) ? root.general.genieWorkspaceStyle : "dot"
    readonly property bool geniePluginMissing: Features.genie && ServiceGenie.missing

    readonly property string genieSummary: {
        if (!Features.genie)
            return root.genieInfo.description
        const parts = []
        if (root.genieOpenOn)
            parts.push("Opens in " + root.genieOpenMs + " ms")
        if (root.genieCloseOn)
            parts.push("closes in " + root.genieCloseMs + " ms")
        if (parts.length === 0)
            return "Opening and closing are both off"
        const s = parts.join(" · ")
        return s.charAt(0).toUpperCase() + s.slice(1)
    }

    function subtitleOf(f) {
        if (Features.missingTool(f.id))
            return "Needs " + f.pkg + " — install it to use this"
        return f.description
    }

    function patchGeneral(p) {
        SettingsConfig.general = Object.assign({}, SettingsConfig.general, p)
    }

    StageView {
        StagePage {
            stageId: "front"

            StageNote {
                content: root.onCount + " of " + Features.list.length + " features on. A feature that is off never starts: "
                    + "no background work, and its bar items, widgets and panels are hidden but keep their place. "
                    + "Turning one off reloads the shell once you close settings."
            }

            Repeater {
                model: Features.groups

                ColumnLayout {
                    id: group
                    required property string modelData
                    Layout.fillWidth: true
                    spacing: 3

                    StageHeading { text: group.modelData }

                    Repeater {
                        model: Features.list.filter(f => f.group === group.modelData && f.id !== "genie")

                        StageSwitchRow {
                            required property var modelData
                            icon: modelData.icon
                            title: modelData.name
                            subtitle: root.subtitleOf(modelData)
                            tonal: Features.on(modelData.id)
                            checked: Features.on(modelData.id)
                            onToggled: on => Features.set(modelData.id, on)
                        }
                    }

                    StageRow {
                        visible: group.modelData === root.genieInfo.group
                        icon: root.genieInfo.icon
                        title: root.genieInfo.name
                        subtitle: root.genieSummary
                        tonal: Features.genie
                        target: "genie"

                        CustomToogle {
                            isToggleOn: Features.genie
                            onToggled: state => Features.set("genie", state)
                        }
                    }
                }
            }
        }

        StageLazy {
            stageId: "genie"

            StagePage {
                stageId: "genie"
                title: "Dock genie"

                StageHero {
                    tone: Features.genie ? "primary" : "plain"
                    icon: "auto_awesome"
                    title: Features.genie ? "Dock genie is on" : "Dock genie is off"
                    subtitle: "Apps pour out of their dock icon when they open and back into it when they close"

                    M3Button {
                        icon: Features.genie ? "stop" : "play_arrow"
                        label: Features.genie ? "Turn off" : "Turn on"
                        onClicked: Features.set("genie", !Features.genie)
                    }
                }

                StageNote {
                    visible: root.geniePluginMissing
                    content: "The genie Hyprland plugin is not installed. Build it with plugins/HyprGenie/build.sh, then turn Dock genie off and on again."
                }

                StageChoiceRow {
                    enabled: Features.genie
                    title: "Style"
                    options: [{ value: "genie", label: "Genie", icon: "water_drop" }, { value: "shape", label: "Shape morph", icon: "interests" }]
                    current: root.general.genieStyle ?? "genie"
                    onPicked: v => root.patchGeneral({ genieStyle: v })
                }

                StageHeading { text: "Opening" }

                StageSwitchRow {
                    enabled: Features.genie
                    icon: "open_in_new"
                    title: "Open from the dock"
                    subtitle: "Apps you start from the dock pour out of their icon"
                    checked: root.genieOpenOn
                    onToggled: on => root.patchGeneral({ genieOpen: on })
                }

                StageSwitchRow {
                    enabled: Features.genie && root.genieOpenOn
                    icon: "dashboard"
                    title: "Tiled windows rise from the dock"
                    subtitle: "New tiled windows opened any other way come out of their dock icon"
                    checked: root.general.genieTiled ?? true
                    onToggled: on => root.patchGeneral({ genieTiled: on })
                }

                StageSliderRow {
                    enabled: Features.genie && root.genieOpenOn
                    title: "Opening time"
                    subtitle: "How long the pour out of the icon takes"
                    from: 200
                    to: 1500
                    step: 50
                    current: root.genieOpenMs
                    format: v => Math.round(v) + " ms"
                    onCommitted: v => root.patchGeneral({ genieOpenMs: Math.round(v) })
                }

                StageHeading { text: "Workspaces and moves" }

                StageSwitchRow {
                    enabled: Features.genie
                    icon: "view_carousel"
                    title: "Workspace switch"
                    subtitle: "Animate changing workspace in the style below"
                    checked: root.genieWsOn
                    onToggled: on => root.patchGeneral({ genieWorkspace: on })
                }

                StageChoiceRow {
                    enabled: Features.genie && root.genieWsOn
                    title: "Workspace style"
                    options: [{ value: "dot", label: "Into the bar", icon: "trip_origin" }, { value: "glide", label: "Glide", icon: "swipe" }, { value: "carousel", label: "Carousel hop", icon: "view_carousel" }]
                    current: root.genieWsStyle
                    onPicked: v => root.patchGeneral({ genieWorkspaceStyle: v })
                }

                StageNote {
                    visible: root.genieWsStyle === "dot"
                    content: "Windows pour into the old workspace dot and out of the new one in your genie style. This needs a workspaces item in the bar."
                }

                StageNote {
                    visible: root.genieWsStyle === "glide"
                    content: "Each window slides on its own spring, the leading window first, then settles."
                }

                StageNote {
                    visible: root.genieWsStyle === "carousel"
                    content: "The desktop zooms out to show workspaces side by side, glides to the next one and zooms back in."
                }

                StageSliderRow {
                    enabled: Features.genie && root.genieWsOn
                    title: "Workspace switch time"
                    subtitle: root.genieWsStyle === "dot" ? "How long each window takes; new windows start a third of the way in" : "How long the whole switch takes"
                    from: 200
                    to: 1500
                    step: 50
                    current: root.general.genieWorkspaceMs ?? 500
                    format: v => Math.round(v) + " ms"
                    onCommitted: v => root.patchGeneral({ genieWorkspaceMs: Math.round(v) })
                }

                StageSwitchRow {
                    visible: root.genieWsStyle === "glide"
                    enabled: Features.genie && root.genieWsOn
                    icon: "rotate_right"
                    title: "Lean in flight"
                    subtitle: "Windows tilt away and shrink a little while they travel"
                    checked: root.general.genieGlideLean ?? true
                    onToggled: on => root.patchGeneral({ genieGlideLean: on })
                }

                StageSliderRow {
                    visible: root.genieWsStyle === "carousel"
                    enabled: Features.genie && root.genieWsOn
                    title: "Zoom out"
                    subtitle: "How far the desktop pulls back mid-switch"
                    from: 10
                    to: 45
                    step: 1
                    current: root.general.genieCarouselZoom ?? 27
                    format: v => Math.round(v) + "%"
                    onCommitted: v => root.patchGeneral({ genieCarouselZoom: Math.round(v) })
                }

                StageSwitchRow {
                    visible: root.genieWsStyle === "carousel"
                    enabled: Features.genie && root.genieWsOn
                    icon: "label"
                    title: "Workspace cards"
                    subtitle: "Show a card and the workspace name behind each workspace while zoomed out"
                    checked: root.general.genieCarouselCards ?? true
                    onToggled: on => root.patchGeneral({ genieCarouselCards: on })
                }

                StageSwitchRow {
                    enabled: Features.genie
                    icon: "swap_horiz"
                    title: "Window moves"
                    subtitle: "Tiled windows that swap or move travel in your style"
                    checked: root.general.genieMove ?? true
                    onToggled: on => root.patchGeneral({ genieMove: on })
                }

                StageSliderRow {
                    enabled: Features.genie && (root.general.genieMove ?? true)
                    title: "Move time"
                    subtitle: "How long a window takes to reach its new tile"
                    from: 150
                    to: 1500
                    step: 50
                    current: root.general.genieMoveMs ?? 450
                    format: v => Math.round(v) + " ms"
                    onCommitted: v => root.patchGeneral({ genieMoveMs: Math.round(v) })
                }

                StageHeading { text: "Minimize" }

                StageSwitchRow {
                    enabled: Features.genie
                    icon: "minimize"
                    title: "Minimize into the dock"
                    subtitle: "Minimized windows pour into their dock icon and back out when you click it"
                    checked: root.general.genieMinimize ?? true
                    onToggled: on => root.patchGeneral({ genieMinimize: on })
                }

                StageSwitchRow {
                    enabled: Features.genie
                    icon: "ads_click"
                    title: "Click a focused app to minimize it"
                    subtitle: "Clicking the dock icon of the window you're using hides it, like a taskbar"
                    checked: root.general.genieClickMinimize ?? true
                    onToggled: on => root.patchGeneral({ genieClickMinimize: on })
                }

                StageNote {
                    content: "For a shortcut, bind a key to quickshell:minimize, for example hl.bind(\"SUPER + M\", hl.dsp.global(\"quickshell:minimize\"))."
                }

                StageHeading { text: "Overview and edit mode" }

                StageSwitchRow {
                    enabled: Features.genie
                    icon: "overview"
                    title: "Fly windows into the overview"
                    subtitle: "Your windows shrink into the overview's preview when it opens and fly back out when it closes"
                    checked: root.general.genieOverview ?? true
                    onToggled: on => root.patchGeneral({ genieOverview: on })
                }

                StageSwitchRow {
                    enabled: Features.genie
                    icon: "edit"
                    title: "Step windows back in edit mode"
                    subtitle: "Windows shrink toward the middle and dim while you edit the bar, dock and widgets"
                    checked: root.general.genieRecede ?? true
                    onToggled: on => root.patchGeneral({ genieRecede: on })
                }

                StageHeading { text: "Closing" }

                StageSwitchRow {
                    enabled: Features.genie
                    icon: "move_to_inbox"
                    title: "Close into the dock"
                    subtitle: "Closing an app's window pours it back into its dock icon"
                    checked: root.genieCloseOn
                    onToggled: on => root.patchGeneral({ genieClose: on })
                }

                StageSliderRow {
                    enabled: Features.genie && root.genieCloseOn
                    title: "Closing time"
                    subtitle: "How long the pour back into the icon takes"
                    from: 200
                    to: 1500
                    step: 50
                    current: root.genieCloseMs
                    format: v => Math.round(v) + " ms"
                    onCommitted: v => root.patchGeneral({ genieCloseMs: Math.round(v) })
                }
            }
        }
    }
}
