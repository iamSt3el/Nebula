import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Bar

Item {
    id: osdRoot
    implicitWidth: 300
    implicitHeight: 64

    property bool vertical: false
    property real pad: 8
    property real outerRadius: -1
    readonly property var kinds: GlobalStates.osdKinds.length > 0 ? GlobalStates.osdKinds : [GlobalStates.osdKind]
    readonly property bool expressive: (BarLayout.opt("osd", "style") ?? "expressive") !== "fill"

    opacity: 0
    NumberAnimation on opacity { from: 0; to: 1; duration: 220; running: true; easing.type: Easing.OutCubic }

    Rectangle {
        anchors.fill: parent
        visible: osdRoot.expressive
        radius: osdRoot.outerRadius >= 0 ? osdRoot.outerRadius : Math.min(width, height) / 2
        color: Colors.surface
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: osdRoot.pad
        spacing: 8

        Repeater {
            model: osdRoot.kinds
            delegate: Loader {
                required property string modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: osdRoot.expressive ? expressiveComp : fillComp
                onLoaded: item.kind = modelData
            }
        }
    }

    Component {
        id: fillComp
        FillPill {}
    }

    Component {
        id: expressiveComp
        ExpressivePill {}
    }

    component ExpressivePill: Item {
        id: ex
        property string kind: "volume"
        readonly property bool bright: ex.kind === "brightness"
        readonly property bool muted: !ex.bright && ServicePipewire.muted
        readonly property real level: ex.bright
            ? Math.max(0, Math.min(1, ServiceBrightness.changedMonitor?.brightness ?? 0))
            : Math.max(0, Math.min(1, ServicePipewire.volume))
        readonly property string glyph: ex.bright
            ? (ex.level > 0.66 ? "brightness_7" : ex.level > 0.33 ? "brightness_6" : "brightness_5")
            : ex.muted ? "volume_off"
            : ex.level > 0.6 ? "volume_up"
            : ex.level > 0.2 ? "volume_down"
            : "volume_mute"
        readonly property bool vert: osdRoot.vertical

        readonly property color activeColor: ex.muted ? Qt.alpha(Colors.surfaceText, 0.38) : ex.bright ? Colors.tertiary : Colors.primary
        readonly property color onActive: ex.muted ? Qt.alpha(Colors.surfaceText, 0.38) : ex.bright ? Colors.tertiaryText : Colors.primaryText
        readonly property color inactiveColor: ex.muted ? Qt.alpha(Colors.surfaceText, 0.12) : Colors.secondaryContainer
        readonly property color onInactive: ex.muted ? Qt.alpha(Colors.surfaceText, 0.38) : Colors.secondaryContainerText

        property real shown: ex.level
        Behavior on shown { SpatialAnim { speed: "fast" } }

        readonly property real labelSpan: ex.vert ? 30 : 46
        readonly property real cross: ex.vert ? ex.width : ex.height
        readonly property real along: Math.max(0, (ex.vert ? ex.height : ex.width) - ex.labelSpan)
        readonly property real trackH: Math.min(40, ex.cross - 4)
        readonly property real handleH: Math.min(44, ex.cross)
        readonly property real handleW: 4
        readonly property real gap: 6
        readonly property real corner: Math.min(12, ex.trackH / 2)
        readonly property real inside: 2
        readonly property real iconSize: Math.min(24, Math.max(12, ex.trackH - 16))
        readonly property real iconPad: 10
        readonly property real trackStart: ex.handleW / 2
        readonly property real trackLen: Math.max(0, ex.along - ex.handleW)
        readonly property real valueAt: Math.max(0, Math.min(1, ex.shown)) * ex.trackLen
        readonly property real handleAt: ex.trackStart + ex.valueAt
        readonly property real endGap: ex.handleW / 2 + ex.gap
        readonly property real activeLen: Math.max(0, ex.valueAt - ex.endGap)
        readonly property bool activeShown: ex.activeLen > ex.corner
        readonly property real inactiveStart: ex.handleAt + ex.endGap
        readonly property real inactiveLen: Math.max(0, ex.trackStart + ex.trackLen - ex.inactiveStart)
        readonly property bool inactiveShown: ex.inactiveLen > ex.corner
        readonly property real startCorner: ex.corner
        readonly property real endCorner: ex.corner
        readonly property bool iconInActive: ex.activeShown && ex.activeLen >= ex.iconSize + 2 * ex.iconPad
        readonly property bool iconInInactive: !ex.iconInActive && ex.inactiveShown && ex.inactiveLen >= ex.iconSize + 2 * ex.iconPad
        readonly property real stopAt: ex.trackStart + ex.trackLen - ex.corner
        readonly property bool stopShown: ex.inactiveShown && ex.stopAt - ex.handleAt > ex.endGap

        Item {
            width: ex.width
            height: ex.height

            Rectangle {
                visible: ex.activeShown
                x: ex.vert ? (ex.width - ex.trackH) / 2 : ex.trackStart
                y: ex.vert ? ex.height - ex.trackStart - ex.activeLen : (ex.height - ex.trackH) / 2
                width: ex.vert ? ex.trackH : ex.activeLen
                height: ex.vert ? ex.activeLen : ex.trackH
                color: ex.activeColor
                topLeftRadius: ex.vert ? ex.inside : ex.startCorner
                bottomLeftRadius: ex.startCorner
                topRightRadius: ex.inside
                bottomRightRadius: ex.vert ? ex.startCorner : ex.inside
            }

            Rectangle {
                visible: ex.inactiveShown
                x: ex.vert ? (ex.width - ex.trackH) / 2 : ex.inactiveStart
                y: ex.vert ? ex.height - ex.inactiveStart - ex.inactiveLen : (ex.height - ex.trackH) / 2
                width: ex.vert ? ex.trackH : ex.inactiveLen
                height: ex.vert ? ex.inactiveLen : ex.trackH
                color: ex.inactiveColor
                topLeftRadius: ex.vert ? ex.endCorner : ex.inside
                bottomLeftRadius: ex.inside
                topRightRadius: ex.endCorner
                bottomRightRadius: ex.vert ? ex.inside : ex.endCorner
            }

            Rectangle {
                x: ex.vert ? (ex.width - ex.handleH) / 2 : ex.handleAt - ex.handleW / 2
                y: ex.vert ? ex.height - ex.handleAt - ex.handleW / 2 : (ex.height - ex.handleH) / 2
                width: ex.vert ? ex.handleH : ex.handleW
                height: ex.vert ? ex.handleW : ex.handleH
                radius: ex.handleW / 2
                color: ex.activeColor
            }

            Rectangle {
                visible: ex.stopShown
                width: 4
                height: 4
                radius: 2
                x: ex.vert ? ex.width / 2 - 2 : ex.stopAt - 2
                y: ex.vert ? ex.height - ex.stopAt - 2 : ex.height / 2 - 2
                color: ex.onInactive
            }

            MaterialIconSymbol {
                visible: ex.iconInActive || ex.iconInInactive
                width: ex.iconSize
                height: ex.iconSize
                horizontalAlignment: Text.AlignHCenter
                content: ex.glyph
                iconSize: ex.iconSize
                customColor: ex.iconInActive ? ex.onActive : ex.onInactive
                readonly property real at: ex.iconInActive ? ex.trackStart + ex.iconPad : ex.inactiveStart + ex.iconPad
                x: ex.vert ? (ex.width - ex.iconSize) / 2 : at
                y: ex.vert ? ex.height - at - ex.iconSize : (ex.height - ex.iconSize) / 2
            }
        }

        CustomText {
            x: ex.vert ? 0 : ex.along
            y: 0
            width: ex.vert ? ex.width : ex.labelSpan
            height: ex.vert ? ex.labelSpan : ex.height
            horizontalAlignment: Text.AlignHCenter
            content: String(Math.round(ex.level * 100))
            family: SettingsConfig.general.displayFont ?? "Titan One"
            renderType: Text.QtRendering
            size: ex.vert ? 14 : 17
            weight: 400
            customColor: ex.muted ? Colors.outline : Colors.surfaceText
            elide: Text.ElideNone
        }
    }

    component PillInk: Item {
        id: ink
        property string glyph: ""
        property string name: ""
        property string value: ""
        property color ink: Colors.surfaceText
        property color valueInk: Colors.surfaceText

        RowLayout {
            visible: !osdRoot.vertical
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 16
            spacing: 10

            MaterialIconSymbol {
                content: ink.glyph
                iconSize: 22
                customColor: ink.ink
            }
            CustomText {
                Layout.fillWidth: true
                content: ink.name
                size: 14
                weight: 500
                customColor: ink.ink
            }
            CustomText {
                content: ink.value
                size: 16
                weight: 700
                customColor: ink.valueInk
            }
        }

        ColumnLayout {
            visible: osdRoot.vertical
            anchors.fill: parent
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 0

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: ink.value
                size: 13
                weight: 700
                customColor: ink.valueInk
            }
            Item { Layout.fillHeight: true }
            MaterialIconSymbol {
                Layout.alignment: Qt.AlignHCenter
                content: ink.glyph
                iconSize: 20
                customColor: ink.ink
            }
        }
    }

    component FillPill: Item {
        id: pill
        property string kind: "volume"
        readonly property bool bright: pill.kind === "brightness"
        readonly property bool muted: !pill.bright && ServicePipewire.muted
        readonly property real level: pill.bright
            ? Math.max(0, Math.min(1, ServiceBrightness.changedMonitor?.brightness ?? 0))
            : Math.max(0, Math.min(1, ServicePipewire.volume))
        readonly property string glyph: pill.bright
            ? (pill.level > 0.66 ? "brightness_7" : pill.level > 0.33 ? "brightness_6" : "brightness_5")
            : pill.muted ? "volume_off"
            : pill.level > 0.6 ? "volume_up"
            : pill.level > 0.2 ? "volume_down"
            : "volume_mute"
        readonly property string name: pill.muted ? "Muted"
            : pill.bright ? "Display"
            : (ServicePipewire.sink?.nickname || ServicePipewire.sink?.description || "Volume")
        readonly property string value: String(Math.round(pill.level * 100))
        readonly property color fillColor: pill.muted ? Colors.outlineVariant : pill.bright ? Colors.tertiary : Colors.primary
        readonly property color inkOn: pill.muted ? Colors.surfaceText : pill.bright ? Colors.tertiaryText : Colors.primaryText
        readonly property color inkOff: pill.muted ? Colors.error : Colors.surfaceText
        readonly property real r: osdRoot.outerRadius >= 0
            ? Math.max(4, Math.min(osdRoot.outerRadius - osdRoot.pad, Math.min(pill.width, pill.height) / 2))
            : (osdRoot.vertical ? pill.width / 2 : pill.height / 2)
        readonly property real along: osdRoot.vertical ? pill.height : pill.width

        property real shown: pill.level
        Behavior on shown { SpatialAnim { speed: "fast" } }
        readonly property real fillLen: Math.round(Math.max(0, Math.min(1, pill.shown)) * pill.along)
        readonly property real lead: pill.shown > 0.98 ? 0 : Math.min(4, pill.fillLen / 2)

        ClippingRectangle {
            id: track
            anchors.fill: parent
            radius: pill.r
            color: Colors.surfaceContainerHigh

            PillInk {
                width: pill.width
                height: pill.height
                glyph: pill.glyph
                name: pill.name
                value: pill.value
                ink: pill.inkOff
                valueInk: pill.muted ? Colors.outline : Colors.surfaceText
            }

            Rectangle {
                id: fill
                visible: pill.fillLen > 0
                x: 0
                y: osdRoot.vertical ? pill.height - pill.fillLen : 0
                width: osdRoot.vertical ? pill.width : pill.fillLen
                height: osdRoot.vertical ? pill.fillLen : pill.height
                color: pill.fillColor
                topLeftRadius: osdRoot.vertical ? pill.lead : 0
                topRightRadius: pill.lead
                bottomLeftRadius: 0
                bottomRightRadius: osdRoot.vertical ? 0 : pill.lead
                clip: true

                PillInk {
                    x: 0
                    y: -fill.y
                    width: pill.width
                    height: pill.height
                    glyph: pill.glyph
                    name: pill.name
                    value: pill.value
                    ink: pill.inkOn
                    valueInk: pill.inkOn
                }
            }
        }
    }
}
