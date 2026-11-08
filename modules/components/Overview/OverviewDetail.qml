import Quickshell
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

ColumnLayout {
    id: root
    spacing: 14

    required property int wsId
    property string label: ""
    property string searchText: ""
    property bool moveMode: false
    property var draggingToplevel: null

    property rect screenRect: Quickshell.screens[0] ? Qt.rect(0, 0, Quickshell.screens[0].width, Quickshell.screens[0].height) : Qt.rect(0, 0, 1920, 1080)
    property bool hideTiles: false

    function tileRectFor(tl, sr, target) {
        const geo = tl?.lastIpcObject
        if (!geo || !geo.size || !geo.at || geo.size[0] <= 0 || geo.size[1] <= 0)
            return null
        const s = Math.min(stage.width / Math.max(1, sr.width), stage.height / Math.max(1, sr.height))
        const ox = (stage.width - sr.width * s) / 2
        const oy = (stage.height - sr.height * s) / 2
        return stage.mapToItem(target, ox + (geo.at[0] - sr.x) * s, oy + (geo.at[1] - sr.y) * s,
                               Math.max(40, geo.size[0] * s), Math.max(30, geo.size[1] * s))
    }

    signal activateRequested()
    signal renamed(string name)
    signal moveAllRequested()
    signal moveCancelled()
    signal closeAllRequested()
    signal windowActivateRequested(var toplevel)
    signal windowDragStarted(var toplevel, real wx, real wy)
    signal windowDragMoved(real wx, real wy)
    signal windowDragEnded()

    readonly property var workspace: ServiceWorkspaces.getWorkspace(root.wsId)
    readonly property var toplevels: root.workspace?.toplevels?.values ?? []
    readonly property int windowCount: root.toplevels.length

    property bool renaming: false
    property bool confirmingClose: false

    function matches(tl) {
        const q = root.searchText.trim().toLowerCase()
        if (q === "") return true
        const title = (tl?.title ?? "").toLowerCase()
        const appId = (tl?.wayland?.appId ?? "").toLowerCase()
        return title.indexOf(q) !== -1 || appId.indexOf(q) !== -1
    }

    function beginRename() {
        root.confirmingClose = false
        root.renaming = true
        nameField.text = root.label
        nameField.selectAll()
        nameField.forceActiveFocus()
    }

    function commitRename() {
        root.renaming = false
        root.renamed(nameField.text.trim())
    }

    onWsIdChanged: {
        root.renaming = false
        root.confirmingClose = false
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        CustomText {
            content: root.wsId.toString()
            size: 28
            weight: 800
            customColor: Colors.primary
        }

        CustomText {
            visible: !root.renaming
            content: root.label
            size: 28
            weight: 800
            customColor: Colors.surfaceText
        }

        Rectangle {
            visible: root.renaming
            Layout.preferredWidth: 280
            Layout.preferredHeight: 40
            radius: 20
            color: Colors.surfaceContainerHigh

            TextInput {
                id: nameField
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 18
                font.weight: 700
                font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                color: Colors.surfaceText
                selectionColor: Colors.primary
                selectedTextColor: Colors.primaryText
                clip: true

                Keys.onReturnPressed: root.commitRename()
                Keys.onEnterPressed: root.commitRename()
                Keys.onEscapePressed: root.renaming = false
            }
        }

        CustomText {
            content: root.windowCount === 0
                ? "No windows"
                : root.windowCount + (root.windowCount === 1 ? " window" : " windows")
            size: 14
            weight: 400
            customColor: Colors.outline
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            visible: root.moveMode
            Layout.preferredHeight: 30
            Layout.preferredWidth: hintRow.implicitWidth + 28
            radius: 15
            color: Qt.alpha(Colors.primary, 0.16)

            RowLayout {
                id: hintRow
                anchors.centerIn: parent
                spacing: 7

                MaterialIconSymbol { content: "arrow_back"; iconSize: 15; customColor: Colors.primary }
                CustomText {
                    content: "Pick a workspace on the left"
                    size: 12; weight: 600
                    customColor: Colors.primary
                }
            }
        }
    }

    Rectangle {
        id: stage
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 18
        color: Colors.surfaceContainer
        clip: true

        readonly property real scaleFactor: {
            const sw = Math.max(1, root.screenRect.width)
            const sh = Math.max(1, root.screenRect.height)
            return Math.min(stage.width / sw, stage.height / sh)
        }

        readonly property real offsetX: (stage.width  - root.screenRect.width  * stage.scaleFactor) / 2
        readonly property real offsetY: (stage.height - root.screenRect.height * stage.scaleFactor) / 2

        Image {
            id: stageWall
            anchors.fill: parent
            source: WallpaperTheme.wallpaperScreen
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(1280, 720)
            asynchronous: true
            opacity: 0.35

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width:  stageWall.width
                    height: stageWall.height
                    radius: 18
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6
            visible: root.windowCount === 0

            MaterialIconSymbol {
                Layout.alignment: Qt.AlignHCenter
                content: "web_asset_off"
                iconSize: 26
                customColor: Colors.outline
            }

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: "Nothing on this workspace"
                size: 12
                weight: 600
                customColor: Colors.outline
            }
        }

        Repeater {
            model: root.workspace?.toplevels ?? null

            delegate: OverviewWindowTile {
                id: tile
                required property var modelData

                readonly property var geo: modelData?.lastIpcObject ?? null
                readonly property bool placed:
                    tile.geo && tile.geo.size && tile.geo.size[0] > 0 && tile.geo.size[1] > 0

                toplevel: modelData
                visible: tile.placed
                dragging: root.draggingToplevel === modelData
                opacity: root.hideTiles ? 0 : (root.matches(modelData) ? (dragging ? 0.35 : 1) : 0.25)

                x: tile.placed ? stage.offsetX + (tile.geo.at[0] - root.screenRect.x) * stage.scaleFactor : 0
                y: tile.placed ? stage.offsetY + (tile.geo.at[1] - root.screenRect.y) * stage.scaleFactor : 0
                width:  tile.placed ? Math.max(40, tile.geo.size[0] * stage.scaleFactor) : 0
                height: tile.placed ? Math.max(30, tile.geo.size[1] * stage.scaleFactor) : 0

                onActivateRequested: root.windowActivateRequested(modelData)
                onDragStarted: (wx, wy) => root.windowDragStarted(modelData, wx, wy)
                onDragMoved:   (wx, wy) => root.windowDragMoved(wx, wy)
                onDragEnded:   root.windowDragEnded()
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ActionBtn {
            icon: "arrow_forward"
            label: "Go to"
            filled: true
            onActivated: root.activateRequested()
        }

        ActionBtn {
            icon: "edit"
            label: "Rename"
            onActivated: root.beginRename()
        }

        ActionBtn {
            icon: root.moveMode ? "close" : "move_group"
            label: root.moveMode ? "Cancel move" : "Move all to…"
            enabled: root.windowCount > 0 || root.moveMode
            onActivated: {
                if (root.moveMode) root.moveCancelled()
                else               root.moveAllRequested()
            }
        }

        ActionBtn {
            icon: root.confirmingClose ? "warning" : "close"
            label: root.confirmingClose
                   ? "Close " + root.windowCount + "?"
                   : "Close all"
            danger: true
            enabled: root.windowCount > 0
            onActivated: {
                if (root.confirmingClose) {
                    root.confirmingClose = false
                    root.closeAllRequested()
                } else {
                    root.confirmingClose = true
                }
            }
        }

        Item { Layout.fillWidth: true }
    }

    component ActionBtn: Rectangle {
        id: ab

        property string icon: ""
        property string label: ""
        property bool filled: false
        property bool danger: false
        property bool enabled: true
        signal activated()

        implicitHeight: 38
        implicitWidth: abRow.implicitWidth + 32
        radius: 19
        opacity: ab.enabled ? 1 : 0.4

        color: ab.filled ? Colors.primary
             : abMa.containsMouse ? Colors.surfaceContainerHigh
                                  : Colors.surfaceContainer
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        readonly property color tint: ab.filled  ? Colors.primaryText
                                    : ab.danger  ? Colors.error
                                                 : Colors.surfaceText

        RowLayout {
            id: abRow
            anchors.centerIn: parent
            spacing: 6

            MaterialIconSymbol {
                content: ab.icon
                iconSize: 17
                customColor: ab.tint
            }

            CustomText {
                content: ab.label
                size: 13
                weight: 600
                customColor: ab.tint
            }
        }

        MouseArea {
            id: abMa
            anchors.fill: parent
            hoverEnabled: ab.enabled
            enabled: ab.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: ab.activated()
        }
    }
}
