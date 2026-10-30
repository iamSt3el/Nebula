import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: panel

    signal closeRequested

    required property Item host
    readonly property var cfg: ServiceBooks.cfg
    readonly property var pages: [
        { value: "warm",  label: "Warm paper" },
        { value: "sepia", label: "Sepia" },
        { value: "eink",  label: "E-ink" }
    ]
    readonly property var fonts: [
        { value: "Literata", name: "Literata" },
        { value: "Liberation Serif", name: "Liberation Serif" },
        { value: "DejaVu Serif", name: "DejaVu Serif" },
        { value: "Rubik", name: "Rubik" }
    ]

    color: Colors.surfaceContainer
    topLeftRadius: 30
    bottomLeftRadius: 30

    MouseArea { anchors.fill: parent }

    component Label: CustomText {
        size: 12
        weight: 500
        customColor: Colors.primary
    }

    component Row2: RowLayout {
        Layout.fillWidth: true
        Layout.minimumHeight: 44
        spacing: 10
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 22
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 18

            RowLayout {
                Layout.fillWidth: true
                CustomText {
                    Layout.fillWidth: true
                    content: "Reading settings"
                    size: 18
                    weight: 600
                }
                M3IconButton {
                    icon: "close"
                    tip: "Close · Esc"
                    onClicked: panel.closeRequested()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Label { content: "Layout" }
                M3ButtonGroup {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    height: 38
                    fillWidth: true
                    textSize: 13
                    iconSize: 16
                    model: [{ value: "spread", label: "Two pages", icon: "menu_book" }, { value: "single", label: "One page", icon: "article" }]
                    activeCheck: v => (panel.cfg.layout ?? "spread") === v
                    onSegmentClicked: v => ServiceBooks.setCfg({ layout: v })
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Label { content: "Page colour" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: panel.pages
                        delegate: ColumnLayout {
                            id: sw
                            required property var modelData
                            readonly property bool on: panel.host.paperTone === sw.modelData.value
                            readonly property var tone: panel.host.pageColors[sw.modelData.value][panel.host.darkPages ? "dark" : "light"]
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                radius: swArea.pressed ? 10 : 14
                                color: sw.tone.paper
                                Behavior on color { EffectsColorAnim {} }
                                border.width: sw.on ? 2.5 : 1
                                border.color: sw.on ? Colors.primary : Qt.alpha(Colors.outline, 0.5)
                                Behavior on radius { SpatialAnim { speed: "fast" } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Aa"
                                    font.family: "Literata"
                                    font.pixelSize: 17
                                    color: sw.tone.ink
                                }
                                MouseArea {
                                    id: swArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ServiceBooks.setCfg(panel.cfg.page === "night"
                                        ? { page: sw.modelData.value, dark: "on" } : { page: sw.modelData.value })
                                }
                            }
                            CustomText {
                                Layout.alignment: Qt.AlignHCenter
                                content: sw.modelData.label
                                size: 11
                                weight: sw.on ? 600 : 400
                                customColor: sw.on ? Colors.surfaceText : Colors.surfaceVariantText
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Label { content: "Dark pages" }
                M3ButtonGroup {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    height: 38
                    fillWidth: true
                    textSize: 13
                    iconSize: 16
                    model: [{ value: "off", label: "Off", icon: "light_mode" }, { value: "on", label: "On", icon: "dark_mode" },
                            { value: "auto", label: "Match shell", icon: "contrast" }]
                    activeCheck: v => panel.host.darkPref === v
                    onSegmentClicked: v => ServiceBooks.setCfg(panel.cfg.page === "night" ? { dark: v, page: "warm" } : { dark: v })
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Label { content: "Text" }

                Row2 {
                    MaterialIconSymbol { content: "font_download"; iconSize: 18; customColor: Colors.surfaceVariantText }
                    CustomText { Layout.fillWidth: true; content: "Typeface"; size: 13 }
                    CustomListNew {
                        Layout.preferredWidth: 170
                        Layout.preferredHeight: 34
                        color: Colors.surfaceContainerHighest
                        list: panel.fonts
                        currentVal: panel.fonts.find(f => f.value === (panel.cfg.font ?? "Literata"))?.name ?? "Literata"
                        onListChildClicked: child => {
                            if (child && child.value !== panel.cfg.font)
                                ServiceBooks.setCfg({ font: child.value })
                        }
                    }
                }

                Row2 {
                    MaterialIconSymbol { content: "format_size"; iconSize: 18; customColor: Colors.surfaceVariantText }
                    CustomText { Layout.fillWidth: true; content: "Size"; size: 13 }
                    CustomSpinBox {
                        value: panel.cfg.size ?? 17
                        min: 13
                        limit: 28
                        inc: 1
                        onValChanged: if (val !== (panel.cfg.size ?? 17)) ServiceBooks.setCfg({ size: val })
                    }
                }

                Row2 {
                    MaterialIconSymbol { content: "format_line_spacing"; iconSize: 18; customColor: Colors.surfaceVariantText }
                    CustomText { Layout.fillWidth: true; content: "Line spacing"; size: 13 }
                    M3ButtonGroup {
                        Layout.preferredHeight: 34
                        height: 34
                        textSize: 12
                        model: [{ value: "tight", label: "Tight" }, { value: "normal", label: "Normal" }, { value: "loose", label: "Loose" }]
                        activeCheck: v => (panel.cfg.spacing ?? "normal") === v
                        onSegmentClicked: v => ServiceBooks.setCfg({ spacing: v })
                    }
                }

                Row2 {
                    MaterialIconSymbol { content: "format_align_justify"; iconSize: 18; customColor: Colors.surfaceVariantText }
                    CustomText { Layout.fillWidth: true; content: "Justify text"; size: 13 }
                    CustomToogle {
                        isToggleOn: panel.cfg.justify ?? true
                        onToggled: state => ServiceBooks.setCfg({ justify: state })
                    }
                }
            }

            Rectangle {
                visible: Features.reading
                Layout.fillWidth: true
                Layout.preferredHeight: comfort.implicitHeight + 28
                radius: 22
                color: Colors.surfaceContainerHigh

                ColumnLayout {
                    id: comfort
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 10

                    Row2 {
                        MaterialIconSymbol { content: "visibility"; iconSize: 20; customColor: Colors.tertiary }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            CustomText { content: "Eye comfort filter"; size: 13; weight: 600 }
                            CustomText {
                                Layout.fillWidth: true
                                content: "Tints the whole screen while a book is open"
                                wrapMode: Text.WordWrap
                                size: 11
                                customColor: Colors.surfaceVariantText
                            }
                        }
                        CustomToogle {
                            isToggleOn: panel.cfg.eyeComfort ?? true
                            onToggled: state => ServiceBooks.setCfg({ eyeComfort: state })
                        }
                    }

                    M3ButtonGroup {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        height: 34
                        fillWidth: true
                        textSize: 12
                        model: Features.reading ? ServiceReading.filters.map(f => ({ value: f.id, label: f.name })) : []
                        activeCheck: v => Features.reading && ServiceReading.filter === v
                        onSegmentClicked: v => {
                            ServiceBooks.setCfg({ eyeComfort: true })
                            ServiceReading.choose(v)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: Features.reading && ServiceReading.filter === "warm"
                        spacing: 10
                        CustomText { content: "Warmth"; size: 12; customColor: Colors.surfaceVariantText }
                        M3Slider {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            from: 0
                            to: 3100
                            progress: Features.reading ? (6500 - ServiceReading.value("warmTemp")) / 3100 : 0
                            onMoved: v => ServiceReading.setParam("warmTemp", 6500 - v)
                        }
                        CustomText {
                            content: Features.reading ? Math.round(ServiceReading.value("warmTemp")) + " K" : ""
                            size: 12
                            customColor: Colors.surfaceVariantText
                        }
                    }
                }
            }

            CustomText {
                Layout.fillWidth: true
                Layout.topMargin: 6
                wrapMode: Text.WordWrap
                content: "← → or click a page to turn · T contents · Esc back to the library"
                size: 11
                customColor: Colors.outline
            }
        }
    }
}
