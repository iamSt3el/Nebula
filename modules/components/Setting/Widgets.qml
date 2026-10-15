import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import "../Widgets" as W
import QtQuick.Controls
import qs.modules.components.Widgets as WM

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    readonly property bool panelOn: SettingsConfig.widgets.showWidgets ?? true

    // ── Reusable section header ───────────────────────────────────────────
    component SectionLabel: CustomText {
        Layout.topMargin: 20
        size: 13
        customColor: Colors.primary
    }

    readonly property var networkWindows: [
        { name: "1 min" }, { name: "3 min" }, { name: "5 min" },
        { name: "10 min" }, { name: "15 min" }, { name: "30 min" }
    ]
    readonly property var networkIntervals: [
        { name: "1 s" }, { name: "2 s" }, { name: "5 s" }, { name: "10 s" }, { name: "30 s" }
    ]

    readonly property var visualizerStyles: [
        { name: "Wave" }, { name: "Chart" }
    ]
    readonly property var visualizerColors: [
        { name: "Primary" }, { name: "Secondary" }, { name: "Tertiary" },
        { name: "Two-tone" }, { name: "Deep" }, { name: "Warm" }
    ]
    readonly property var visualizerFps: [
        { name: "15 fps" }, { name: "30 fps" }, { name: "60 fps" },
        { name: "90 fps" }, { name: "120 fps" }
    ]

    readonly property int placedCount: {
        let n = 0
        const cat = WM.WidgetCatalog.catalog
        for (let i = 0; i < cat.length; i++)
            for (let j = 0; j < cat[i].items.length; j++)
                if (WM.WidgetCatalog.isActive(cat[i].items[j]))
                    n++
        return n
    }

    function openStudio(add) {
        GlobalStates.settingsOpen = false
        GlobalStates.widgetOpenAdd = add
        GlobalStates.openEdit("desktop")
    }

    component StudioButton: Rectangle {
        id: sb
        property string icon: ""
        property string label: ""
        property bool filled: true
        signal clicked()
        implicitWidth: sbRow.implicitWidth + 32
        implicitHeight: 40
        radius: 20
        opacity: root.panelOn ? 1 : 0.4
        color: sb.filled ? Colors.primary : Colors.surfaceContainerHighest
        Behavior on opacity { EffectsAnim { speed: "fast" } }

        RowLayout {
            id: sbRow
            anchors.centerIn: parent
            spacing: 8
            MaterialIconSymbol { content: sb.icon; iconSize: 18; customColor: sb.filled ? Colors.primaryText : Colors.surfaceText }
            CustomText { content: sb.label; size: 13; weight: 700; customColor: sb.filled ? Colors.primaryText : Colors.surfaceText }
        }

        RippleEffect {
            anchors.fill: parent
            radius: 20
            enabled: root.panelOn
            onClicked: sb.clicked()
        }
    }

    Flickable {
        ScrollBar.vertical: CustomScrollBar {}
        id: flick
        anchors.fill: parent
        contentHeight: column.implicitHeight
        contentWidth: width
        clip: true

        ColumnLayout {
            id: column
            width: parent.width
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors { leftMargin: 5; rightMargin: 5; topMargin: 5 }
            spacing: 0

            // ── Page header ──────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item { Layout.fillWidth: true }

                CustomToogle {
                    isToggleOn: root.panelOn
                    onToggled: function(state) {
                        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { showWidgets: state })
                    }
                }
            }

            CustomText {
                Layout.topMargin: 6
                content: root.panelOn
                    ? "Widgets are added, arranged and styled on the desktop itself, in the widget studio."
                    : "The desktop panel is off. Switch it on to add and arrange widgets."
                size: 12
                customColor: Colors.outline
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 14
                Layout.preferredHeight: studioRow.implicitHeight + 28
                radius: 20
                color: Colors.surfaceContainer

                RowLayout {
                    id: studioRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 18
                    anchors.rightMargin: 14
                    spacing: 14

                    Rectangle {
                        implicitWidth: 48
                        implicitHeight: 48
                        radius: 16
                        color: Colors.primaryContainer
                        MaterialIconSymbol { anchors.centerIn: parent; content: "dashboard_customize"; iconSize: 24; customColor: Colors.primaryContainerText }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        CustomText {
                            content: root.placedCount === 0 ? "No widgets on the desktop"
                                : root.placedCount === 1 ? "1 widget on the desktop"
                                : root.placedCount + " widgets on the desktop"
                            size: 16
                            weight: 700
                            customColor: Colors.primary
                        }
                        CustomText {
                            Layout.fillWidth: true
                            content: "Browse every widget with live previews, drop it where you want it, then resize and style it in place."
                            size: 12
                            customColor: Colors.outline
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                        }
                    }

                    StudioButton {
                        icon: "drag_pan"
                        label: "Arrange"
                        filled: false
                        onClicked: root.openStudio(false)
                    }

                    StudioButton {
                        icon: "add"
                        label: "Add widgets"
                        onClicked: root.openStudio(true)
                    }
                }
            }

            SectionLabel { content: "Appearance" }

            ColumnLayout {
                Layout.topMargin: 6
                Layout.fillWidth: true
                spacing: 3

                CustomCard {
                    autoRadius: false
                    topRadius: 20
                    bottomRadius: WidgetSizes.cardStyle !== "flat" ? 5 : 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Card Surface"; size: 14 }
                            CustomText {
                                content: "How widget backgrounds treat the wallpaper"
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                        Item { Layout.fillWidth: true }
                        M3ButtonGroup {
                            model: [
                                { value: "flat",    label: "Solid",  icon: "square" },
                                { value: "frosted", label: "Frost",  icon: "blur_on" }
                            ]
                            activeCheck: function(v) { return WidgetSizes.cardStyle === v }
                            onSegmentClicked: function(v) {
                                SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { cardStyle: v })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false
                    topRadius: 5
                    bottomRadius: 20
                    visible: WidgetSizes.cardStyle !== "flat"
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Card Opacity"; size: 14 }
                            CustomText {
                                content: "How much wallpaper shows through"
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                        Item { Layout.fillWidth: true }
                        M3Slider {
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 30
                            stepCount: 5
                            stepLabels: ["clear", "frosted", "hazy", "light", "solid"]
                            currentStep: {
                                const vals = [0.30, 0.45, 0.60, 0.75, 0.90]
                                const cur = SettingsConfig.widgets.cardOpacity ?? 0.60
                                let best = 0
                                for (var i = 1; i < vals.length; i++)
                                    if (Math.abs(vals[i] - cur) < Math.abs(vals[best] - cur)) best = i
                                return best
                            }
                            onStepChanged: step => {
                                const vals = [0.30, 0.45, 0.60, 0.75, 0.90]
                                SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { cardOpacity: vals[step] })
                            }
                        }
                    }
                }
            }

            // ── Visualizer options (not widgets) ─────────────────────────
            SectionLabel { content: "Visualizer" }

            ColumnLayout {
                Layout.fillWidth: true; Layout.topMargin: 6; spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Cava Visualizer"; size: 14 }
                            CustomText { content: "Audio bar overlay alongside the circular player"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.general.musicVisOn
                            onToggled: function(state) {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { musicVisOn: state })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Visualizer Style"; size: 14 }
                            CustomText { content: "Smooth wave or segmented trapezoid chart"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30; Layout.preferredWidth: 160
                            color: Colors.surfaceContainerHighest
                            currentVal: SettingsConfig.general.musicVisStyle ?? "Wave"
                            list: root.visualizerStyles
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.general.musicVisStyle)
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general,
                                                                           { musicVisStyle: currentVal })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Visualizer Color"; size: 14 }
                            CustomText { content: "Theme role for the bars and their ghost cap"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30; Layout.preferredWidth: 160
                            color: Colors.surfaceContainerHighest
                            currentVal: SettingsConfig.general.musicVisColor ?? "Primary"
                            list: root.visualizerColors
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.general.musicVisColor)
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general,
                                                                           { musicVisColor: currentVal })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Visualizer Frame Rate"; size: 14 }
                            CustomText { content: "Higher is smoother and costs more CPU"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30; Layout.preferredWidth: 160
                            color: Colors.surfaceContainerHighest
                            currentVal: SettingsConfig.general.musicVisFps ?? "30 fps"
                            list: root.visualizerFps
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.general.musicVisFps)
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general,
                                                                           { musicVisFps: currentVal })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Visualizer Bars"; size: 14 }
                            CustomText { content: "Number of frequency bands to render"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            value: SettingsConfig.general.musicVisBars ?? 60
                            onValChanged: {
                                if (val !== value)
                                    SettingsConfig.general = Object.assign({}, SettingsConfig.general, { musicVisBars: val })
                            }
                        }
                    }
                }
            }

            // ── Network options (not widgets) ────────────────────────────
            SectionLabel { content: "Network" }

            ColumnLayout {
                Layout.fillWidth: true; Layout.topMargin: 6; spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Stats Duration"; size: 14 }
                            CustomText {
                                content: "How much history the network graph spans"
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30; Layout.preferredWidth: 160
                            color: Colors.surfaceContainerHighest
                            currentVal: SettingsConfig.widgets.networkGraphWindow ?? "3 min"
                            list: root.networkWindows
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.widgets.networkGraphWindow)
                                    SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets,
                                                                           { networkGraphWindow: currentVal })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Update Interval"; size: 14 }
                            CustomText {
                                content: "How often the speeds are re-read"
                                size: 12
                                customColor: Colors.outline
                            }
                        }
                        Item { Layout.fillWidth: true }
                        CustomListNew {
                            Layout.preferredHeight: 30; Layout.preferredWidth: 160
                            color: Colors.surfaceContainerHighest
                            currentVal: SettingsConfig.widgets.networkGraphInterval ?? "2 s"
                            list: root.networkIntervals
                            onCurrentValChanged: {
                                if (currentVal && currentVal !== SettingsConfig.widgets.networkGraphInterval)
                                    SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets,
                                                                           { networkGraphInterval: currentVal })
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
    ScrollFade {
        anchors.fill: parent
        flickable: flick
    }
}
