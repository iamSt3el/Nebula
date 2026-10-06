import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
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
        root.current = path
        root.selected = ({})
        root.filter = ""
        search.text = ""
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
        if (paths.length === 0 || copyProc.running) return
        copyProc.files = paths
        copyProc.command = ["bash", "-c", "d=\"$1\"; shift; cp -n -- \"$@\" \"$d\"/", "copy", ServicePhone.downloads].concat(paths)
        copyProc.running = true
        root.toast = "Copying " + paths.length + (paths.length === 1 ? " file…" : " files…")
    }

    function requestThumbs() {
        if (root.base === "" || !root.current.startsWith(root.base)) return
        const want = []
        for (let i = 0; i < folder.count && want.length < 300; i++) {
            if (folder.get(i, "fileIsDir")) continue
            const p = folder.get(i, "filePath")
            if (root.isMedia(p) && root.thumbs[p] === undefined) want.push(p)
        }
        if (want.length === 0) return
        thumbProc.running = false
        thumbProc.command = [Quickshell.shellDir + "/bin/nebula", "phone-thumbs"].concat(want)
        thumbProc.running = true
    }

    onBaseChanged: {
        if (root.base !== "" && root.current === "") {
            placeProc.running = true
            root.go(root.base + "/DCIM/Camera")
        }
    }

    function ensureMounted() {
        if (root.base === "" && ServicePhone.ready && !ServicePhone.mounting)
            ServicePhone.mount()
    }

    Component.onCompleted: {
        if (root.base === "") root.ensureMounted()
        else {
            placeProc.running = true
            root.go(root.base + "/DCIM/Camera")
        }
    }

    Connections {
        target: ServicePhone
        function onReadyChanged() { root.ensureMounted() }
    }

    FolderListModel {
        id: folder
        folder: "file://" + (root.current !== "" ? root.current : "/nonexistent-phone-root")
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: false
        caseSensitive: false
        sortField: root.byTime ? FolderListModel.Time : FolderListModel.Name
        nameFilters: root.filter !== "" ? ["*" + root.filter + "*"] : []
        onStatusChanged: if (status === FolderListModel.Ready) thumbTimer.restart()
        onCountChanged: thumbTimer.restart()
    }

    Timer {
        id: thumbTimer
        interval: 250
        onTriggered: root.requestThumbs()
    }

    Process {
        id: thumbProc
        stdout: SplitParser {
            onRead: line => {
                const i = line.indexOf("\t")
                if (i < 0) return
                root.thumbs[line.slice(0, i)] = line.slice(i + 1)
                root.thumbVersion++
            }
        }
    }

    Process {
        id: placeProc
        command: ["bash", "-c", "cd \"$1\" 2>/dev/null || exit 0; shift; for d in \"$@\"; do [ -d \"$d\" ] && echo \"$d\"; done", "places", root.base]
            .concat(root.placeDefs.map(p => p.rel))
        stdout: StdioCollector {
            onStreamFinished: {
                const have = text.split("\n").filter(l => l !== "")
                const seen = {}
                root.places = root.placeDefs.filter(p => {
                    if (have.indexOf(p.rel) < 0 || seen[p.label]) return false
                    seen[p.label] = true
                    return true
                })
            }
        }
    }

    Process {
        id: copyProc
        property var files: []
        onExited: code => {
            for (const f of copyProc.files)
                ServicePhone.noteReceived(ServicePhone.downloads + "/" + ServicePhone.baseName(f))
            root.toast = code === 0 ? "Copied " + copyProc.files.length + " to " + ServicePhone.baseName(ServicePhone.downloads)
                                    : "Some files were not copied"
            root.selected = ({})
            toastTimer.restart()
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
                        readonly property bool on: place.modelData.rel === "" ? root.current === root.base
                                                                              : root.current === place.path || root.current.startsWith(place.path + "/")
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: 20
                        color: place.on ? Colors.secondaryContainer : placeMouse.containsMouse ? Colors.surfaceContainerHigh : "transparent"
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
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    contentWidth: crumbRow.implicitWidth
                    contentX: Math.max(0, contentWidth - width)
                    clip: true
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
                    visible: !ServicePhone.ready || root.base === "" || (folder.status === FolderListModel.Ready && folder.count === 0)
                             || folder.status === FolderListModel.Loading
                    spacing: 10

                    MaterialIconSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        content: !ServicePhone.ready ? "phonelink_off" : root.base === "" || folder.status === FolderListModel.Loading ? "hourglass_top" : "folder_open"
                        iconSize: 40
                        customColor: Colors.outline
                    }

                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: !ServicePhone.ready ? ServicePhone.label + " isn't connected"
                               : root.base === "" ? (ServicePhone.mounting ? "Opening phone storage…" : "Couldn't open the phone's storage")
                               : folder.status === FolderListModel.Loading ? "Loading…"
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
                    visible: root.grid && folder.count > 0 && ServicePhone.ready && root.base !== ""
                    clip: true
                    model: folder
                    boundsBehavior: Flickable.StopAtBounds
                    readonly property int cols: Math.max(3, Math.floor(width / 168))
                    cellWidth: Math.floor(width / gridView.cols)
                    cellHeight: gridView.cellWidth + 30
                    bottomMargin: root.selCount > 0 ? 80 : 0

                    delegate: Item {
                        id: tile
                        required property string fileName
                        required property string filePath
                        required property bool fileIsDir
                        required property var fileSize
                        readonly property bool picked: root.selected[tile.filePath] !== undefined
                        readonly property string thumb: { root.thumbVersion; return root.thumbs[tile.filePath] ?? "" }
                        width: gridView.cellWidth
                        height: gridView.cellHeight

                        Rectangle {
                            id: tileBox
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: 18
                            color: tile.picked ? Colors.secondaryContainer : tileMouse.containsMouse ? Colors.surfaceContainerHigh : "transparent"
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
                                                                   .map(p => "file://" + encodeURI(p)).join("\r\n") })
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            drag.target: tile.fileIsDir ? null : dragProxy
                            onClicked: {
                                if (tile.fileIsDir) root.go(tile.filePath)
                                else root.toggle(tile.filePath, Number(tile.fileSize))
                            }
                            onDoubleClicked: if (!tile.fileIsDir) root.launch(["xdg-open", tile.filePath])
                        }
                    }
                }

                ListView {
                    id: listView
                    anchors.fill: parent
                    visible: !root.grid && folder.count > 0 && ServicePhone.ready && root.base !== ""
                    clip: true
                    spacing: 4
                    model: folder
                    boundsBehavior: Flickable.StopAtBounds
                    bottomMargin: root.selCount > 0 ? 80 : 0

                    delegate: Rectangle {
                        id: row
                        required property string fileName
                        required property string filePath
                        required property bool fileIsDir
                        required property var fileSize
                        required property var fileModified
                        readonly property bool picked: root.selected[row.filePath] !== undefined
                        readonly property string thumb: { root.thumbVersion; return root.thumbs[row.filePath] ?? "" }
                        width: listView.width
                        height: 52
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
                                content: root.human(Number(row.fileSize))
                                size: 11
                                weight: 400
                                customColor: Colors.outline
                            }

                            CustomText {
                                Layout.preferredWidth: 90
                                horizontalAlignment: Text.AlignRight
                                content: Qt.formatDate(row.fileModified, "d MMM yyyy")
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
                                else root.toggle(row.filePath, Number(row.fileSize))
                            }
                            onDoubleClicked: if (!row.fileIsDir) root.launch(["xdg-open", row.filePath])
                        }
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    visible: root.selCount > 0 || root.toast !== ""
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
                            content: root.toast !== "" && root.selCount === 0 ? root.toast
                                   : root.selCount + " selected · " + root.human(root.selBytes)
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
                            visible: root.selCount === 0 && root.toast.startsWith("Copied")
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
