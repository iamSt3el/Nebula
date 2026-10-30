import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.Edit

ColumnLayout {
    id: selectedSection
    required property Item host

    component Crumb: Rectangle {
        id: crumb
        property string icon: ""
        property string text: ""
        property bool lit: false
        signal clicked
        implicitWidth: crumbRow.implicitWidth + 16
        implicitHeight: 24
        radius: 12
        color: crumb.lit ? Colors.primary
            : crumbArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        RowLayout {
            id: crumbRow
            anchors.centerIn: parent
            spacing: 6
            MaterialIconSymbol {
                visible: crumb.icon !== ""
                content: crumb.icon
                iconSize: 15
                customColor: crumb.lit ? Colors.primaryText : Colors.surfaceVariantText
            }
            CustomText {
                content: crumb.text
                size: 11
                weight: crumb.lit ? 700 : 500
                customColor: crumb.lit ? Colors.primaryText : Colors.surfaceText
            }
        }

        MouseArea {
            id: crumbArea
            anchors.fill: parent
            enabled: !crumb.lit
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: crumb.clicked()
        }
    }

    component Chevron: MaterialIconSymbol {
        height: 30
        verticalAlignment: Text.AlignVCenter
        content: "chevron_right"
        iconSize: 16
        customColor: Colors.outline
    }

    Layout.fillWidth: true
    spacing: 8
    visible: host.itemPage

    readonly property var entry: BarLayout.entry(host.selected)
    readonly property var margin: BarLayout.marginsFor(host.selected)
    readonly property var options: {
        const all = selectedSection.entry && selectedSection.entry.options
            ? selectedSection.entry.options : []
        return host.loose && !host.anchorPage ? all.filter(o => o.setting || o.type === "heading") : all
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 100000
            spacing: 0
            CustomText {
                Layout.fillWidth: true
                content: selectedSection.entry ? selectedSection.entry.label : host.selected
                elide: Text.ElideRight
                size: 15
                weight: 600
            }
            CustomText {
                Layout.fillWidth: true
                visible: !crumbs.visible
                content: host.anchorPage && !host.loose ? (host.osdPage ? "Volume and brightness pop out beside this block"
                                                                           : "Notifications pop out beside this block")
                    : host.loose ? "Not in your bar · panel settings only"
                    : selectedSection.entry && selectedSection.entry.group ? selectedSection.entry.group + " item" : "Bar item"
                size: 12
                weight: 400
                customColor: Colors.surfaceVariantText
            }
        }
        M3IconButton {
            icon: "close"
            tip: "Close · Esc"
            onClicked: if (host.editor) host.editor.drawerMode = ""
        }
    }

    Flow {
        id: crumbs
        readonly property var blk: host.itemPage && !host.dashPage && !host.loose
            ? (BarLayout.allBlocks.find(b => b.id !== "__sys" && b.items.indexOf(host.selected) >= 0) ?? null) : null
        Layout.fillWidth: true
        visible: crumbs.blk !== null
        spacing: 4

        Crumb {
            icon: crumbs.blk && (crumbs.blk.edge === "left" || crumbs.blk.edge === "right") ? "dock_to_left" : "dock_to_bottom"
            text: crumbs.blk ? crumbs.blk.edge.charAt(0).toUpperCase() + crumbs.blk.edge.slice(1) + " edge" : ""
            onClicked: {
                const e = host.editor
                if (!e || !crumbs.blk) return
                host.edgeSide = crumbs.blk.edge
                host.tab = "edges"
                e.drawerMode = "settings"
                e.selectedItem = ""
            }
        }
        Chevron {}
        Crumb {
            icon: "view_column"
            text: !crumbs.blk ? "" : crumbs.blk.items.length === 1 ? "Block" : BarLayout.blockName(crumbs.blk.id)
            onClicked: {
                const e = host.editor
                if (!e || !crumbs.blk) return
                const id = crumbs.blk.id
                e.drawerMode = ""
                e.selectedBlock = id
            }
        }
        Chevron {}
        Crumb {
            lit: true
            text: selectedSection.entry ? selectedSection.entry.label : host.selected
        }
    }

    CustomText {
        Layout.fillWidth: true
        visible: host.selected === "wallpaper"
        wrapMode: Text.WordWrap
        content: "The wallpaper panel is open where it normally appears, as a live preview."
        size: 12
        customColor: Colors.outline
    }

    CustomText {
        Layout.fillWidth: true
        visible: host.anchorPage
        wrapMode: Text.WordWrap
        content: host.loose
            ? (host.osdPage ? "Not placed, so the OSD opens at the centre of the " + BarLayout.sysEdge + " edge. Drag OSD from Add to bar onto a block to move it."
                              : "Not placed. Drag Popups from Add to bar onto a block to choose where popups appear.")
            : "Nothing shows in the bar. Drag the pin to another block to move where it appears."
        size: 12
        customColor: Colors.outline
    }

    RowLayout {
        Layout.fillWidth: true
        visible: host.anchorPage
        spacing: 8

        M3Button {
            Layout.fillWidth: true
            icon: host.osdPage ? "volume_up" : "send"
            label: host.osdPage ? "Show volume" : "Send a test popup"
            onClicked: host.osdPage ? BarLayout.testOsd("volume") : BarLayout.testPopup(false)
        }
        M3Button {
            Layout.fillWidth: true
            variant: "tonal"
            icon: host.osdPage ? "brightness_6" : "priority_high"
            label: host.osdPage ? "Show brightness" : "Send an urgent one"
            onClicked: host.osdPage ? BarLayout.testOsd("brightness") : BarLayout.testPopup(true)
        }
    }

    CustomText {
        Layout.fillWidth: true
        visible: host.loose && !host.anchorPage
        wrapMode: Text.WordWrap
        content: "This item isn't in your bar. Only its panel settings are shown."
        size: 12
        customColor: Colors.outline
    }

    CustomText {
        Layout.fillWidth: true
        visible: host.selected === "launcher"
        wrapMode: Text.WordWrap
        content: "The launcher is open as a live preview. Changes show up as you make them."
        size: 12
        customColor: Colors.outline
    }

    Item {
        id: previewStrip
        Layout.preferredHeight: 0
        visible: false

        Item {
            id: stubHost
            width: 0
            height: 0
            visible: false
            readonly property bool editing: false
            readonly property bool split: host.splitItem
            readonly property real barH: Appearance.size.barHeight
            readonly property color plateFill: host.plateFill
            readonly property real maxWidth: -1
            readonly property real fixedWidth: 0
            function hoverOpen(kind, item) {}
            function openPanel(kind, item) {}
            function closePanel() {}
        }

        Loader {
            id: previewLoader
            anchors.centerIn: parent
            enabled: false
            width: item ? item.implicitWidth : 0
            height: item ? item.implicitHeight : 0
            source: host.selected !== "" && !host.dashPage
                    ? BarLayout.urlFor(host.selected) : ""
            onWidthChanged: host.previewW = previewLoader.width
            onHeightChanged: host.previewH = previewLoader.height
            onStatusChanged: if (previewLoader.status !== Loader.Ready)
                host.previewSizable = false
            onLoaded: {
                item.host = stubHost
                if ("itemId" in item)
                    item.itemId = host.selected
                host.previewSizable = item.iconSizable === true
            }
        }
    }

    EditHeading {
        Layout.fillWidth: true
        Layout.topMargin: 10
        visible: host.selected !== "dashboard"
        content: "Options"
        size: 13
        customColor: Colors.primary
    }
    ColumnLayout {
        id: drawerGroup6
        Layout.fillWidth: true
        visible: host.selected !== "dashboard"
        spacing: 8
        Repeater {
            model: selectedSection.options

            delegate: EditOptionRow {
                id: optRow
                required property var modelData
                Layout.fillWidth: true
                compact: true
                listOpen: host.sidePage === "opt" && !!host.sideSpec && host.sideSpec.key === optRow.modelData.key
                onOpenList: host.openSide("opt", optRow, optRow.modelData)
                spec: modelData
                getter: function(key) { return host.optValue(key) }
                setter: function(key, v) { host.setOptValue(key, v) }
                listGetter: function(key) { return host.optList(key) }
                listAdd: function(key, v) { host.optListAdd(key, v) }
                listRemove: function(key, v) { host.optListRemove(key, v) }
            }
        }
        EditRow {
            visible: selectedSection.options.length === 0 && host.selected !== "dashboard"
        }
        EditRow {
            visible: selectedSection.options.length === 0 && host.selected !== "dashboard"
            CustomText {
                Layout.fillWidth: true
                visible: selectedSection.options.length === 0 && host.selected !== "dashboard"
                wrapMode: Text.WordWrap
                content: host.dashPage || host.anchorPage ? "This item has no options."
                                         : "This item has no options besides its margins."
                size: 12
                customColor: Colors.outline
            }
        }
    }

    BarEditDrawerPanel {
        host: selectedSection.host
    }

    ColumnLayout {
        id: drawerSideRows
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: host.itemPage && !host.chromeless
        spacing: 2
        EditSideRow {
            id: lookRow
            icon: "palette"
            label: "Look"
            value: host.lookSummary
            lit: host.sidePage === "look" || host.sidePage === "itemshape"
            onClicked: host.openSide("look", lookRow, null)
        }
        EditSideRow {
            id: spaceRow
            icon: "space_bar"
            label: "Space around it"
            value: host.selMargin[0] + " · " + host.selMargin[1] + " px"
            lit: host.sidePage === "space"
            onClicked: host.openSide("space", spaceRow, null)
        }
    }

    BarEditDrawerGroup {
        host: selectedSection.host
    }

    ColumnLayout {
        id: drawerBlockGroup
        readonly property var blk: host.itemPage && !host.loose && !host.dashPage
            ? (BarLayout.allBlocks.find(b => b.id !== "__sys" && b.items.indexOf(host.selected) > 0) ?? null) : null
        Layout.fillWidth: true
        visible: drawerBlockGroup.blk !== null
        spacing: 8
        EditSideRow {
            icon: "call_split"
            label: "Start a new block here"
            chevron: false
            onClicked: {
                const e = host.editor
                const blk = drawerBlockGroup.blk
                if (!e || !blk)
                    return
                const id = host.selected
                const blockId = blk.id
                e.drawerMode = ""
                e.selectedItem = ""
                Qt.callLater(() => BarLayout.splitBlockAt(blockId, id))
            }
        }
    }
}
