import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    function launch(args) {
        GlobalStates.panelHold = true
        Quickshell.execDetached(args)
    }
    anchors.fill: parent

    signal closed
    signal back

    readonly property string base: ServicePhone.storageRoot
    property string current: ""
    property var selected: ({})
    readonly property int selCount: Object.keys(root.selected).length
    readonly property real selBytes: Object.values(root.selected).reduce((n, v) => n + v, 0)
    property var thumbs: ({})
    property int thumbVersion: 0
    property var thumbQueue: []
    property var thumbInflight: ({})
    property var thumbLive: ({})
    property var entries: []
    property bool listing: false
    property string listError: ""

    readonly property var shown: {
        const q = root.filter.toLowerCase()
        const list = q === "" ? root.entries.slice() : root.entries.filter(e => e.key.indexOf(q) >= 0)
        const byTime = root.byTime
        list.sort((a, b) => a.dir !== b.dir ? (a.dir ? -1 : 1)
                          : byTime && a.mtime !== b.mtime ? b.mtime - a.mtime
                          : a.key < b.key ? -1 : a.key > b.key ? 1 : 0)
        return list
    }
    property bool grid: true
    property bool byTime: true
    property string filter: ""
    property var places: []
    property string toast: ""

    readonly property var placeDefs: [
        { rel: "DCIM/Camera", label: "Camera", icon: "photo_camera" },
        { rel: "Pictures/Screenshots", label: "Screenshots", icon: "screenshot_monitor" },
        { rel: "DCIM/Screenshots", label: "Screenshots", icon: "screenshot_monitor" },
        { rel: "Download", label: "Downloads", icon: "download" },
        { rel: "Documents", label: "Documents", icon: "description" },
        { rel: "Pictures", label: "Pictures", icon: "image" },
        { rel: "Movies", label: "Videos", icon: "movie" },
        { rel: "Music", label: "Music", icon: "music_note" },
        { rel: "Recordings", label: "Recordings", icon: "mic" },
        { rel: "Android/media/com.whatsapp/WhatsApp/Media", label: "WhatsApp", icon: "chat" },
        { rel: "Pictures/Telegram", label: "Telegram", icon: "send" }
    ]

    readonly property string activePlace: {
        let best = ""
        for (const p of root.places) {
            const path = root.base + "/" + p.rel
            if ((root.current === path || root.current.startsWith(path + "/")) && path.length > best.length)
                best = path
        }
        return best !== "" ? best : root.base
    }

    readonly property var crumbs: {
        if (root.base === "" || root.current === "") return []
        const rel = root.current.slice(root.base.length).split("/").filter(p => p !== "")
        const out = [{ label: ServicePhone.label, path: root.base }]
        let acc = root.base
        for (const p of rel) {
            acc += "/" + p
            out.push({ label: p, path: acc })
        }
        return out
    }

    function go(path) {
        if (path === root.current) return
        root.current = path
        root.entries = []
        root.selected = ({})
        root.filter = ""
        search.text = ""
        root.list()
        root.thumbQueue = []
        if (thumbProc.busy) {
            thumbProc.aborted = true
            thumbProc.running = false
        }
    }

    function reload() {
        root.list()
    }

    function list() {
        root.listError = ""
        if (root.current === "") {
            root.listing = false
            return
        }
        root.listing = true
        if (listProc.busy) {
            listProc.again = true
            listProc.running = false
            return
        }
        listProc.target = root.current
        listProc.busy = true
        listProc.command = ["bash", "-c", "cd -- \"$1\" || exit 3; find . -mindepth 1 -maxdepth 1 ! -name '.*' -printf '%y\\t%s\\t%T@\\t%f\\0'", "list", root.current]
        listProc.running = true
    }

    function fileUri(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/")
    }

    function isMedia(name) {
        return /\.(jpe?g|png|webp|gif|bmp|heic|mp4|mkv|webm|mov|3gp|avi)$/i.test(name)
    }

    function isVideo(name) {
        return /\.(mp4|mkv|webm|mov|3gp|avi)$/i.test(name)
    }

    function iconFor(name) {
        if (/\.(pdf)$/i.test(name)) return "picture_as_pdf"
        if (/\.(apk)$/i.test(name)) return "android"
        if (/\.(mp3|m4a|ogg|opus|flac|wav|aac)$/i.test(name)) return "music_note"
        if (/\.(zip|rar|7z|tar|gz)$/i.test(name)) return "folder_zip"
        if (/\.(txt|md|doc|docx|odt)$/i.test(name)) return "description"
        if (root.isVideo(name)) return "movie"
        if (root.isMedia(name)) return "image"
        return "draft"
    }

    function human(bytes) {
        return ServicePhone.humanSize ? ServicePhone.humanSize(bytes) : String(bytes)
    }

    function toggle(path, size) {
        const next = Object.assign({}, root.selected)
        if (next[path] !== undefined) delete next[path]
        else next[path] = size
        root.selected = next
    }

    function selectedPaths() {
        return Object.keys(root.selected)
    }

    function copyToPc(paths) {
        if (paths.length === 0) return
        ServicePhone.pull(paths)
        root.selected = ({})
        root.toast = ""
    }

    function want(path) {
        if (!root.isMedia(path)) return
        root.thumbLive[path] = (root.thumbLive[path] ?? 0) + 1
        if (root.thumbs[path] !== undefined || root.thumbInflight[path] || root.thumbQueue.indexOf(path) >= 0) return
        root.thumbQueue.push(path)
        thumbKick.restart()
    }

    function unwant(path) {
        const n = (root.thumbLive[path] ?? 0) - 1
        if (n > 0) root.thumbLive[path] = n
        else delete root.thumbLive[path]
    }

    function pumpThumbs() {
        if (thumbProc.busy) return
        const live = root.thumbQueue.filter(p => root.thumbLive[p] !== undefined && root.thumbs[p] === undefined)
        const batch = live.slice(0, 12)
        root.thumbQueue = live.slice(12)
        if (batch.length === 0) return
        const inflight = {}
        for (const p of batch) inflight[p] = true
        root.thumbInflight = inflight
        thumbProc.aborted = false
        thumbProc.busy = true
        thumbProc.command = [Quickshell.shellDir + "/bin/nebula", "phone-thumbs"].concat(batch)
        thumbProc.running = true
    }

    function open() {
        root.places = []
        placeProc.command = ["bash", "-c", "cd \"$1\" 2>/dev/null || exit 0; shift; for d in \"$@\"; do [ -d \"$d\" ] && echo \"$d\"; done", "places", root.base]
            .concat(root.placeDefs.map(p => p.rel))
        placeProc.running = true
    }

    function ensureMounted() {
        if (ServicePhone.ready && !ServicePhone.mounting)
            ServicePhone.mount()
    }

    onBaseChanged: {
        root.go("")
        if (root.base !== "") root.open()
    }

    Component.onCompleted: {
        if (root.base !== "") root.open()
        root.ensureMounted()
    }

    Connections {
        target: ServicePhone
        function onReadyChanged() { root.ensureMounted() }
        function onStorageVersionChanged() {
            if (root.base !== "" && root.current !== "") root.reload()
        }
        function onPullFinished(copied, failed) {
            root.toast = failed === 0 ? "Copied " + copied + " to " + ServicePhone.baseName(ServicePhone.downloads)
                       : copied === 0 ? "Couldn't copy " + (failed === 1 ? "the file" : failed + " files")
                       : "Copied " + copied + ", " + failed + " failed"
            toastTimer.restart()
        }
    }

    Process {
        id: listProc
        property string target: ""
        property bool busy: false
        property bool again: false
        stdout: StdioCollector {
            id: listOut
        }
        onExited: code => {
            listProc.busy = false
            if (listProc.again || listProc.target !== root.current) {
                listProc.again = false
                root.list()
                return
            }
            const out = []
            for (const rec of listOut.text.split("\0")) {
                const f = rec.split("\t")
                if (f.length < 4) continue
                const name = f.slice(3).join("\t")
                out.push({ name: name, key: name.toLowerCase(), path: listProc.target + "/" + name, dir: f[0] === "d",
                           size: Number(f[1]), mtime: Number(f[2]) * 1000 })
            }
            root.entries = out
            root.listing = false
            root.listError = code === 0 || out.length > 0 ? "" : "Couldn't open this folder"
        }
    }

    Timer {
        id: thumbKick
        interval: 120
        onTriggered: root.pumpThumbs()
    }

    Timer {
        id: thumbFlush
        interval: 90
        onTriggered: root.thumbVersion++
    }

    Process {
        id: thumbProc
        property bool aborted: false
        property bool busy: false
        stdout: SplitParser {
            onRead: line => {
                const i = line.indexOf("\t")
                if (i < 0 || thumbProc.aborted) return
                const path = line.slice(0, i)
                root.thumbs[path] = line.slice(i + 1)
                delete root.thumbInflight[path]
                if (!thumbFlush.running) thumbFlush.start()
            }
        }
        onExited: {
            if (!thumbProc.aborted) {
                for (const p in root.thumbInflight) root.thumbs[p] = ""
                if (!thumbFlush.running) thumbFlush.start()
            }
            root.thumbInflight = ({})
            thumbProc.aborted = false
            thumbProc.busy = false
            root.pumpThumbs()
        }
    }

    Process {
        id: placeProc
        stdout: StdioCollector {
            onStreamFinished: {
                const have = text.split("\n").filter(l => l !== "")
                const seen = {}
                root.places = root.placeDefs.filter(p => {
                    if (have.indexOf(p.rel) < 0 || seen[p.label]) return false
                    seen[p.label] = true
                    return true
                })
                if (root.current === "" && root.base !== "")
                    root.go(root.places.length > 0 ? root.base + "/" + root.places[0].rel : root.base)
            }
        }
    }

    Timer {
        id: toastTimer
        interval: 4000
        onTriggered: root.toast = ""
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 220
            radius: 22
            color: Colors.surfaceContainer

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    M3IconButton {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        icon: "arrow_back"
                        iconSize: 18
                        iconColor: Colors.surfaceVariantText
                        onClicked: root.back()
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        CustomText {
                            Layout.fillWidth: true
                            content: ServicePhone.label
                            size: 15
                            weight: 700
                            elide: Text.ElideRight
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: ServicePhone.storageName || "Phone storage"
                            size: 11
                            weight: 400
                            customColor: Colors.outline
                            elide: Text.ElideRight
                        }
                    }
                }

                Item { implicitHeight: 10 }

                Repeater {
                    model: root.places.concat([{ rel: "", label: "All files", icon: "folder_open" }])

                    delegate: Rectangle {
                        id: place
                        required property var modelData
                        readonly property string path: root.base + (place.modelData.rel !== "" ? "/" + place.modelData.rel : "")
                        readonly property bool on: root.activePlace === place.path
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: 20
                        color: place.on ? Colors.secondaryContainer : placeMouse.containsMouse ? Colors.surfaceContainerHigh : Qt.alpha(Colors.surfaceContainerHigh, 0)
                        Behavior on color { EffectsColorAnim {} }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            spacing: 12

                            MaterialIconSymbol {
                                content: place.modelData.icon
                                iconSize: 18
                                fill: place.on ? 1 : 0
                                customColor: place.on ? Colors.secondaryContainerText : Colors.surfaceVariantText
                            }

                            CustomText {
                                Layout.fillWidth: true
                                content: place.modelData.label
                                size: 13
                                weight: place.on ? 600 : 500
                                customColor: place.on ? Colors.secondaryContainerText : Colors.surfaceText
                            }
                        }

                        MouseArea {
                            id: placeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.go(place.path)
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true
                    visible: ServicePhone.mountError !== ""
                    implicitHeight: warnCol.implicitHeight + 20
                    radius: 14
                    color: Colors.surfaceContainerHigh

                    ColumnLayout {
                        id: warnCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 12
                        spacing: 4

                        RowLayout {
                            spacing: 6
                            MaterialIconSymbol { content: "folder_off"; iconSize: 15; customColor: Colors.primary }
                            CustomText { content: "Limited access"; size: 12; weight: 600 }
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: "On the phone, allow KDE Connect “All files access” to see every folder."
                            size: 11
                            weight: 400
                            customColor: Colors.outline
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                Flickable {
                    id: crumbFlick
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    contentWidth: crumbRow.implicitWidth
                    clip: true
                    onContentWidthChanged: crumbFlick.contentX = Math.max(0, crumbFlick.contentWidth - crumbFlick.width)
                    onWidthChanged: crumbFlick.contentX = Math.max(0, crumbFlick.contentWidth - crumbFlick.width)
                    interactive: contentWidth > width

                    Row {
                        id: crumbRow
                        height: parent.height
                        spacing: 2

                        Repeater {
                            model: root.crumbs

                            delegate: Row {
                                id: crumb
                                required property var modelData
                                required property int index
                                readonly property bool last: crumb.index === root.crumbs.length - 1
                                height: 34
                                spacing: 2

                                MaterialIconSymbol {
                                    visible: crumb.index > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    content: "chevron_right"
                                    iconSize: 16
                                    customColor: Colors.outline
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: crumbText.implicitWidth + 18
                                    height: 30
                                    radius: 15
                                    color: crumbMouse.containsMouse && !crumb.last ? Colors.surfaceContainerHigh : "transparent"

                                    CustomText {
                                        id: crumbText
                                        anchors.centerIn: parent
                                        content: crumb.modelData.label
                                        size: crumb.last ? 15 : 13
                                        weight: crumb.last ? 700 : 500
                                        customColor: crumb.last ? Colors.surfaceText : Colors.surfaceVariantText
                                    }

                                    MouseArea {
                                        id: crumbMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !crumb.last
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.go(crumb.modelData.path)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 210
                    Layout.preferredHeight: 38
                    radius: 19
                    color: Colors.surfaceContainer
                    border.width: search.activeFocus ? 2 : 0
                    border.color: Colors.primary

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 8

                        MaterialIconSymbol { content: "search"; iconSize: 17; customColor: Colors.outline }

                        TextInput {
                            id: search
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            verticalAlignment: TextInput.AlignVCenter
                            color: Colors.surfaceText
                            font.pixelSize: 13
                            font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                            clip: true
                            onTextChanged: filterTimer.restart()
                            Keys.onEscapePressed: { text = ""; focus = false }

                            CustomText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: search.text === ""
                                content: "Filter this folder"
                                size: 13
                                weight: 400
                                customColor: Colors.outline
                            }
                        }
                    }

                    Timer {
                        id: filterTimer
                        interval: 200
                        onTriggered: root.filter = search.text.trim()
                    }
                }

                M3IconButton {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    enabled: root.current !== ""
                    icon: "refresh"
                    iconSize: 18
                    iconColor: Colors.surfaceVariantText
                    onClicked: {
                        root.reload()
                        root.ensureMounted()
                    }
                }

                M3IconButton {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    icon: root.byTime ? "schedule" : "sort_by_alpha"
                    iconSize: 18
                    iconColor: Colors.surfaceVariantText
                    onClicked: root.byTime = !root.byTime
                }

                M3IconButton {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    icon: root.grid ? "view_list" : "grid_view"
                    iconSize: 18
                    iconColor: Colors.surfaceVariantText
                    onClicked: root.grid = !root.grid
                }

                M3IconButton {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    icon: "drive_file_move"
                    iconSize: 18
                    iconColor: Colors.surfaceVariantText
                    onClicked: root.launch(["xdg-open", root.current !== "" ? root.current : ServicePhone.storageRoot])
                }

                M3IconButton {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    icon: "close"
                    iconSize: 18
                    iconColor: Colors.outline
                    onClicked: root.closed()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: !ServicePhone.ready || root.base === "" || root.current === "" || root.listing || root.shown.length === 0
                    spacing: 10

                    MaterialIconSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        content: !ServicePhone.ready ? "phonelink_off"
                               : root.base === "" ? (ServicePhone.mounting ? "hourglass_top" : "folder_off")
                               : root.current === "" || root.listing ? "hourglass_top" : root.listError !== "" ? "folder_off" : "folder_open"
                        iconSize: 40
                        customColor: Colors.outline
                    }

                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: !ServicePhone.ready ? ServicePhone.label + " isn't connected"
                               : root.base === "" ? (ServicePhone.mounting ? "Opening phone storage…" : "Couldn't open the phone's storage")
                               : root.current === "" || root.listing ? "Loading…"
                               : root.listError !== "" ? root.listError
                               : root.filter !== "" ? "Nothing matches “" + root.filter + "”" : "This folder is empty"
                        size: 14
                        weight: 500
                        customColor: Colors.surfaceVariantText
                    }

                    M3Button {
                        Layout.alignment: Qt.AlignHCenter
                        visible: ServicePhone.ready && root.base === "" && !ServicePhone.mounting
                        size: "xsmall"
                        variant: "filled"
                        icon: "refresh"
                        label: "Try again"
                        onClicked: ServicePhone.mount()
                    }
                }

                GridView {
                    id: gridView
                    anchors.fill: parent
                    visible: root.grid && root.shown.length > 0 && ServicePhone.ready && root.base !== "" && !root.listing
                    clip: true
                    model: root.grid ? root.shown : []
                    cacheBuffer: 400
                    boundsBehavior: Flickable.StopAtBounds
                    readonly property int cols: Math.max(3, Math.floor(width / 168))
                    cellWidth: Math.floor(width / gridView.cols)
                    cellHeight: gridView.cellWidth + 30
                    bottomMargin: root.selCount > 0 ? 80 : 0

                    delegate: Item {
                        id: tile
                        required property var modelData
                        readonly property string fileName: tile.modelData.name
                        readonly property string filePath: tile.modelData.path
                        readonly property bool fileIsDir: tile.modelData.dir
                        readonly property real fileSize: tile.modelData.size
                        readonly property bool picked: root.selected[tile.filePath] !== undefined
                        readonly property string thumb: { root.thumbVersion; return root.thumbs[tile.filePath] ?? "" }
                        width: gridView.cellWidth
                        height: gridView.cellHeight
                        Component.onCompleted: if (!tile.fileIsDir) root.want(tile.filePath)
                        Component.onDestruction: if (!tile.fileIsDir) root.unwant(tile.filePath)

                        Rectangle {
                            id: tileBox
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: 18
                            color: tile.picked ? Colors.secondaryContainer : tileMouse.containsMouse ? Colors.surfaceContainerHigh : Qt.alpha(Colors.surfaceContainerHigh, 0)
                            border.width: tile.picked ? 2 : 0
                            border.color: Colors.primary
                            Behavior on color { EffectsColorAnim {} }

                            ClippingRectangle {
                                id: art
                                x: 6
                                y: 6
                                width: parent.width - 12
                                height: width
                                radius: 13
                                color: Colors.surfaceContainer

                                Image {
                                    anchors.fill: parent
                                    visible: tile.thumb !== ""
                                    source: tile.thumb !== "" ? "file://" + tile.thumb : ""
                                    sourceSize.width: 320
                                    sourceSize.height: 320
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    visible: tile.thumb === ""
                                    content: tile.fileIsDir ? "folder" : root.iconFor(tile.fileName)
                                    iconSize: Math.round(art.width * 0.32)
                                    fill: tile.fileIsDir ? 1 : 0
                                    customColor: tile.fileIsDir ? Colors.primary : Colors.outline
                                }

                                Rectangle {
                                    visible: root.isVideo(tile.fileName)
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 6
                                    width: 26
                                    height: 26
                                    radius: 13
                                    color: Qt.alpha(Colors.surface, 0.8)

                                    MaterialIconSymbol {
                                        anchors.centerIn: parent
                                        content: "play_arrow"
                                        iconSize: 16
                                        fill: 1
                                        customColor: Colors.surfaceText
                                    }
                                }

                                Rectangle {
                                    visible: !tile.fileIsDir && (tile.picked || tileMouse.containsMouse)
                                    x: 6
                                    y: 6
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: tile.picked ? Colors.primary : Qt.alpha(Colors.surface, 0.75)
                                    border.width: tile.picked ? 0 : 2
                                    border.color: Colors.surfaceText

                                    MaterialIconSymbol {
                                        anchors.centerIn: parent
                                        visible: tile.picked
                                        content: "check"
                                        iconSize: 16
                                        customColor: Colors.primaryText
                                    }
                                }
                            }

                            CustomText {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: art.bottom
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.topMargin: 6
                                horizontalAlignment: Text.AlignHCenter
                                content: tile.fileName
                                size: 11
                                weight: 500
                                elide: Text.ElideMiddle
                            }
                        }

                        Item {
                            id: dragProxy
                            Drag.active: tileMouse.drag.active
                            Drag.dragType: Drag.Automatic
                            Drag.supportedActions: Qt.CopyAction
                            Drag.mimeData: ({ "text/uri-list": (tile.picked ? root.selectedPaths() : [tile.filePath])
                                                                   .map(p => root.fileUri(p)).join("\r\n") })
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            drag.target: tile.fileIsDir ? null : dragProxy
                            onClicked: {
                                if (tile.fileIsDir) root.go(tile.filePath)
                                else root.toggle(tile.filePath, tile.fileSize)
                            }
                            onDoubleClicked: {
                                if (tile.fileIsDir) return
                                root.toggle(tile.filePath, tile.fileSize)
                                root.launch(["xdg-open", tile.filePath])
                            }
                        }
                    }
                }

                ListView {
                    id: listView
                    anchors.fill: parent
                    visible: !root.grid && root.shown.length > 0 && ServicePhone.ready && root.base !== "" && !root.listing
                    clip: true
                    spacing: 4
                    model: root.grid ? [] : root.shown
                    cacheBuffer: 400
                    boundsBehavior: Flickable.StopAtBounds
                    bottomMargin: root.selCount > 0 ? 80 : 0

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property string fileName: row.modelData.name
                        readonly property string filePath: row.modelData.path
                        readonly property bool fileIsDir: row.modelData.dir
                        readonly property real fileSize: row.modelData.size
                        readonly property bool picked: root.selected[row.filePath] !== undefined
                        readonly property string thumb: { root.thumbVersion; return root.thumbs[row.filePath] ?? "" }
                        width: listView.width
                        height: 52
                        Component.onCompleted: if (!row.fileIsDir) root.want(row.filePath)
                        Component.onDestruction: if (!row.fileIsDir) root.unwant(row.filePath)
                        radius: 14
                        color: row.picked ? Colors.secondaryContainer : rowMouse.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainer

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 14
                            spacing: 12

                            ClippingRectangle {
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                radius: 10
                                color: Colors.surfaceContainerHighest

                                Image {
                                    anchors.fill: parent
                                    visible: row.thumb !== ""
                                    source: row.thumb !== "" ? "file://" + row.thumb : ""
                                    sourceSize.width: 96
                                    sourceSize.height: 96
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    visible: row.thumb === ""
                                    content: row.fileIsDir ? "folder" : root.iconFor(row.fileName)
                                    iconSize: 19
                                    fill: row.fileIsDir ? 1 : 0
                                    customColor: row.fileIsDir ? Colors.primary : Colors.outline
                                }
                            }

                            CustomText {
                                Layout.fillWidth: true
                                content: row.fileName
                                size: 13
                                weight: 500
                                elide: Text.ElideMiddle
                            }

                            CustomText {
                                visible: !row.fileIsDir
                                content: root.human(row.fileSize)
                                size: 11
                                weight: 400
                                customColor: Colors.outline
                            }

                            CustomText {
                                Layout.preferredWidth: 90
                                horizontalAlignment: Text.AlignRight
                                content: Qt.formatDate(new Date(row.modelData.mtime), "d MMM yyyy")
                                size: 11
                                weight: 400
                                customColor: Colors.outline
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (row.fileIsDir) root.go(row.filePath)
                                else root.toggle(row.filePath, row.fileSize)
                            }
                            onDoubleClicked: {
                                if (row.fileIsDir) return
                                root.toggle(row.filePath, row.fileSize)
                                root.launch(["xdg-open", row.filePath])
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    visible: root.selCount > 0 || root.toast !== "" || ServicePhone.pulling
                    width: barRow.implicitWidth + 24
                    height: 56
                    radius: 28
                    color: Colors.surfaceContainerHighest

                    RowLayout {
                        id: barRow
                        anchors.centerIn: parent
                        spacing: 8

                        CustomText {
                            Layout.leftMargin: 8
                            Layout.rightMargin: 6
                            content: root.selCount > 0 ? root.selCount + " selected · " + root.human(root.selBytes)
                                   : ServicePhone.pulling ? "Copying " + (ServicePhone.pullDone + 1) + " of " + ServicePhone.pullTotal + "…"
                                   : root.toast
                            size: 13
                            weight: 600
                        }

                        M3Button {
                            visible: root.selCount > 0
                            size: "xsmall"
                            variant: "filled"
                            icon: "download"
                            label: "Copy to PC"
                            onClicked: root.copyToPc(root.selectedPaths())
                        }

                        M3Button {
                            visible: root.selCount > 0
                            size: "xsmall"
                            variant: "tonal"
                            icon: "open_in_new"
                            label: "Open"
                            onClicked: {
                                for (const p of root.selectedPaths().slice(0, 5))
                                    root.launch(["xdg-open", p])
                            }
                        }

                        M3Button {
                            visible: root.selCount === 0 && !ServicePhone.pulling && root.toast.startsWith("Copied")
                            size: "xsmall"
                            variant: "tonal"
                            icon: "folder_open"
                            label: "Show"
                            onClicked: root.launch(["xdg-open", ServicePhone.downloads])
                        }

                        M3IconButton {
                            visible: root.selCount > 0
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            icon: "close"
                            iconSize: 16
                            iconColor: Colors.outline
                            onClicked: root.selected = ({})
                        }
                    }
                }
            }
        }
    }
}
