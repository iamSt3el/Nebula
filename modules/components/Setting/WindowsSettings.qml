import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent

    readonly property string layout: String(ServiceHyprConfig.value("general.layout", "dwindle"))
    readonly property var gapsOut: {
        const g = ServiceHyprConfig.value("general.gaps_out", 20)
        return typeof g === "object" ? g : { top: g, right: g, bottom: g, left: g }
    }
    readonly property string layoutName: ({ dwindle: "Dwindle", master: "Master", scrolling: "Scrolling", monocle: "Monocle" })[root.layout] ?? root.layout

    StageView {
        StagePage {
            stageId: "front"

            WindowPreview {
                Layout.fillWidth: true
                Layout.preferredHeight: 200
            }

            HyprTargetRow { area: "windows" }

            HyprChoiceRow {
                title: "Tiling"
                subtitle: "How new windows share the screen"
                path: "general.layout"
                fallback: "dwindle"
                model: [
                    { value: "dwindle", label: "Dwindle", icon: "splitscreen_right" },
                    { value: "master", label: "Master", icon: "view_quilt" },
                    { value: "scrolling", label: "Scrolling", icon: "view_carousel" },
                    { value: "monocle", label: "Monocle", icon: "crop_square" }
                ]
            }

            StageGap {}

            StageNavRow {
                icon: "space_bar"
                title: "Gaps"
                subtitle: "Between windows, floating windows and the screen edges"
                value: ServiceHyprConfig.value("general.gaps_in", 5) + " px"
                target: "gaps"
            }

            StageNavRow {
                icon: "view_quilt"
                title: root.layoutName + " details"
                subtitle: "Split direction, columns, snapping and resizing"
                target: "layout"
            }

            StageNavRow {
                icon: "rounded_corner"
                title: "Borders and corners"
                subtitle: "Border " + ServiceHyprConfig.value("general.border_size", 0) + " px · radius " + ServiceHyprConfig.value("decoration.rounding", 0) + " px"
                target: "look"
            }

            StageNavRow {
                icon: "blur_on"
                title: "Effects"
                subtitle: "Blur, shadows, glow, dimming and animations"
                target: "effects"
            }

            StageNavRow {
                icon: "ads_click"
                title: "Focus"
                subtitle: "Whether apps can pull focus to themselves"
                target: "focus"
            }
        }

        StageLazy {
            stageId: "gaps"

            StagePage {
                stageId: "gaps"
                title: "Gaps"

                HyprSliderRow {
                    title: "Between windows"
                    path: "general.gaps_in"
                    from: 0; to: 40; unit: " px"
                }

                HyprSliderRow {
                    title: "Floating windows"
                    subtitle: "Gap kept from the screen edge when a floating window is moved"
                    path: "general.float_gaps"
                    from: 0; to: 40; unit: " px"
                }

                SidesEditor {
                    barSide: ["right", "bottom", "left"].reduce((a, k) => (ServiceGaps.occupied[k] ?? 0) > (ServiceGaps.occupied[a] ?? 0) ? k : a, "top")
                    maxValue: 40
                    values: ({
                        top: ServiceGaps.gapFor("top"),
                        right: ServiceGaps.gapFor("right"),
                        bottom: ServiceGaps.gapFor("bottom"),
                        left: ServiceGaps.gapFor("left")
                    })
                    onChanged: patch => {
                        const g = Object.assign({}, ServiceGaps.windowGaps, patch)
                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, { windowGaps: g })
                    }
                }

                StageNote { content: "Gap between windows and the bar, the dock and the screen border. Sides you haven't changed follow the border thickness." }
            }
        }

        StageLazy {
            stageId: "layout"

            StagePage {
                stageId: "layout"
                title: "Layout details"

                HyprToggleRow {
                    visible: root.layout === "dwindle"
                    title: "Keep the split direction"
                    subtitle: "Splits stay put when windows close"
                    path: "dwindle.preserve_split"
                }
                HyprToggleRow {
                    visible: root.layout === "master"
                    title: "Focus the master on close"
                    subtitle: "Closing a window moves focus to the master window"
                    path: "master.focus_master_on_close"
                    isNew: true
                }
                HyprSliderRow {
                    visible: root.layout === "scrolling"
                    title: "Column width"
                    subtitle: "Share of the screen a new column takes"
                    path: "scrolling.column_width"
                    from: 0.1; to: 1; step: 0.05; displayScale: 100; unit: "%"
                }
                HyprToggleRow {
                    visible: root.layout === "scrolling"
                    title: "Scroll to the focused window"
                    path: "scrolling.follow_focus"
                }
                HyprToggleRow {
                    title: "Snap floating windows"
                    subtitle: "Floating windows snap to each other and to the screen edges"
                    path: "general.snap.enabled"
                }
                HyprToggleRow {
                    title: "Resize from borders and gaps"
                    path: "general.resize_on_border"
                }

            }
        }

        StageLazy {
            stageId: "look"

            StagePage {
                stageId: "look"
                title: "Borders and corners"

                HyprSliderRow {
                    title: "Border width"
                    path: "general.border_size"
                    from: 0; to: 10; unit: " px"
                }
                HyprSliderRow {
                    title: "Corner radius"
                    path: "decoration.rounding"
                    from: 0; to: 20; unit: " px"
                }
                HyprSliderRow {
                    title: "Corner shape"
                    subtitle: "2 is a circle; higher values give a softer squircle"
                    path: "decoration.rounding_power"
                    from: 2; to: 10; step: 0.5; decimals: 1
                }

            }
        }

        StageLazy {
            stageId: "effects"

            StagePage {
                stageId: "effects"
                title: "Effects"

                HyprToggleRow {
                    title: "Blur behind see-through windows"
                    path: "decoration.blur.enabled"
                }
                HyprSliderRow {
                    visible: !!ServiceHyprConfig.value("decoration.blur.enabled", true)
                    title: "Blur strength"
                    path: "decoration.blur.size"
                    from: 1; to: 20
                }
                HyprSliderRow {
                    visible: !!ServiceHyprConfig.value("decoration.blur.enabled", true)
                    title: "Blur passes"
                    subtitle: "More passes look smoother and cost more GPU time"
                    path: "decoration.blur.passes"
                    from: 1; to: 4
                }
                HyprToggleRow {
                    title: "Shadows"
                    path: "decoration.shadow.enabled"
                }
                HyprToggleRow {
                    title: "Inner glow"
                    subtitle: "A soft glow along the inside edge of each window"
                    path: "decoration.glow.enabled"
                    isNew: true
                }
                HyprToggleRow {
                    title: "Motion blur"
                    subtitle: "Blurs windows while they move or resize"
                    path: "decoration.motion_blur.enabled"
                    isNew: true
                }
                HyprSliderRow {
                    title: "Inactive window opacity"
                    path: "decoration.inactive_opacity"
                    from: 0.3; to: 1; step: 0.05; displayScale: 100; unit: "%"
                }
                HyprToggleRow {
                    title: "Dim inactive windows"
                    path: "decoration.dim_inactive"
                }
                HyprSliderRow {
                    visible: !!ServiceHyprConfig.value("decoration.dim_inactive", false)
                    title: "Dim strength"
                    path: "decoration.dim_strength"
                    from: 0; to: 1; step: 0.05; displayScale: 100; unit: "%"
                }
                HyprToggleRow {
                    title: "Animations"
                    path: "animations.enabled"
                }

            }
        }

        StageLazy {
            stageId: "focus"

            StagePage {
                stageId: "focus"
                title: "Focus"

                HyprToggleRow {
                    title: "Let apps take focus"
                    subtitle: "Focus a window when its app asks for attention"
                    path: "misc.focus_on_activate"
                }

            }
        }
    }

    component WindowPreview: Rectangle {
        id: pv
        radius: 20
        color: Colors.surfaceContainerLowest
        clip: true

        readonly property real k: pv.width / 1280
        readonly property real gin: Number(ServiceHyprConfig.value("general.gaps_in", 5)) * pv.k * 2
        readonly property real gt: Number(root.gapsOut.top ?? 0) * pv.k
        readonly property real gr: Number(root.gapsOut.right ?? 0) * pv.k
        readonly property real gb: Number(root.gapsOut.bottom ?? 0) * pv.k
        readonly property real gl: Number(root.gapsOut.left ?? 0) * pv.k
        readonly property real rad: Number(ServiceHyprConfig.value("decoration.rounding", 0)) * pv.k * 1.6
        readonly property real bw: Math.min(4, Number(ServiceHyprConfig.value("general.border_size", 0)))
        readonly property real dim: Number(ServiceHyprConfig.value("decoration.inactive_opacity", 1))
        readonly property real areaW: pv.width - pv.gl - pv.gr
        readonly property real areaH: pv.height - pv.gt - pv.gb
        readonly property real leftW: (pv.areaW - pv.gin) * 0.55

        PreviewWindow {
            x: pv.gl; y: pv.gt
            width: pv.leftW; height: pv.areaH
            active: true
            radius: pv.rad; borderW: pv.bw; dimOpacity: pv.dim
        }
        PreviewWindow {
            x: pv.gl + pv.leftW + pv.gin; y: pv.gt
            width: pv.areaW - pv.leftW - pv.gin; height: (pv.areaH - pv.gin) / 2
            radius: pv.rad; borderW: pv.bw; dimOpacity: pv.dim
        }
        PreviewWindow {
            x: pv.gl + pv.leftW + pv.gin; y: pv.gt + (pv.areaH - pv.gin) / 2 + pv.gin
            width: pv.areaW - pv.leftW - pv.gin; height: (pv.areaH - pv.gin) / 2
            radius: pv.rad; borderW: pv.bw; dimOpacity: pv.dim
        }
    }

    component PreviewWindow: Rectangle {
        id: w
        property bool active: false
        property real dimOpacity: 1
        property real borderW: 0
        opacity: w.active ? 1 : w.dimOpacity
        color: w.active ? Colors.surfaceContainerHigh : Colors.surfaceContainer
        border.width: w.borderW
        border.color: w.active ? Colors.primary : Colors.outlineVariant

        Column {
            x: 12; y: 12
            spacing: 6
            Rectangle { width: w.width * 0.4; height: 6; radius: 3; color: w.active ? Colors.primary : Colors.surfaceContainerHighest }
            Rectangle { width: w.width * 0.7; height: 6; radius: 3; color: Colors.surfaceContainerHighest }
            Rectangle { width: w.width * 0.55; height: 6; radius: 3; color: Colors.surfaceContainerHighest }
        }
    }
}
