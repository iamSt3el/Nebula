import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

Item {
    id: root

    property var handle: null
    property string title: ""
    property real maxHeight: 600
    signal done

    property var stack: []
    readonly property string currentTitle: root.stack.length ? root.stack[root.stack.length - 1].text : root.title

    readonly property var levels: [root.handle].concat(root.stack.map(l => l.entry))
    property var openerList: []
    readonly property var opener: root.openerList.length === root.levels.length ? root.openerList[root.openerList.length - 1] : null

    readonly property var groups: {
        const o = root.opener
        const c = o && o.children ? o.children.values : []
        const out = []
        let cur = []
        for (let i = 0; i < c.length; i++) {
            if (!c[i])
                continue
            if (c[i].isSeparator) {
                if (cur.length)
                    out.push(cur)
                cur = []
            } else {
                cur.push(c[i])
            }
        }
        if (cur.length)
            out.push(cur)
        return out
    }

    onHandleChanged: root.stack = []

    implicitWidth: 260
    implicitHeight: Math.min(root.maxHeight, col.implicitHeight + 20)

    focus: true
    Component.onCompleted: root.forceActiveFocus()
    Keys.onEscapePressed: root.back()

    function clean(t) {
        return String(t ?? "").replace(/__/g, "\u0001").replace(/_/g, "").replace(/\u0001/g, "_")
    }

    function back() {
        if (root.stack.length)
            root.stack = root.stack.slice(0, -1)
        else
            root.done()
    }

    function pick(entry) {
        if (!entry || !entry.enabled)
            return
        if (entry.hasChildren) {
            root.stack = root.stack.concat([{ entry: entry, text: root.clean(entry.text) }])
            return
        }
        entry.triggered()
        root.done()
    }

    Instantiator {
        id: openers
        model: root.levels
        delegate: QsMenuOpener {
            required property var modelData
            menu: modelData
        }
        onObjectAdded: (index, object) => {
            const list = root.openerList.slice()
            list.splice(index, 0, object)
            root.openerList = list
        }
        onObjectRemoved: (index, object) => {
            root.openerList = root.openerList.filter(o => o !== object)
        }
    }

    function iconSource(icon) {
        const s = String(icon ?? "")
        if (s === "")
            return ""
        if (s.indexOf("image://icon/") === 0)
            return IconUtil.themeIcon(s.slice(13).split("?")[0], true)
        return s
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 10
        contentWidth: width
        contentHeight: col.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: col
            width: parent.width
            spacing: 6

            Rectangle {
                width: col.width
                height: 34
                radius: 12
                visible: root.stack.length > 0 || root.currentTitle !== ""
                color: backArea.containsMouse && root.stack.length ? Colors.surfaceContainerHigh : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    MaterialIconSymbol {
                        visible: root.stack.length > 0
                        content: "arrow_back"
                        iconSize: 18
                        customColor: Colors.primary
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: root.currentTitle
                        size: 12
                        weight: 700
                        customColor: root.stack.length ? Colors.surfaceText : Colors.outline
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: backArea
                    anchors.fill: parent
                    enabled: root.stack.length > 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }

            CustomText {
                visible: root.groups.length === 0
                width: col.width
                horizontalAlignment: Text.AlignHCenter
                topPadding: 10
                bottomPadding: 10
                content: "No actions"
                size: 12
                customColor: Colors.outline
            }

            Repeater {
                model: root.groups

                delegate: Rectangle {
                    id: group
                    required property var modelData
                    width: col.width
                    height: groupCol.implicitHeight + 8
                    radius: 14
                    color: Colors.surfaceContainer

                    Column {
                        id: groupCol
                        x: 4
                        y: 4
                        width: parent.width - 8

                        Repeater {
                            model: group.modelData

                            delegate: Rectangle {
                                id: row
                                required property var modelData
                                readonly property var entry: row.modelData
                                readonly property bool live: row.entry.enabled
                                width: groupCol.width
                                height: 34
                                radius: 10
                                color: rowArea.containsMouse && row.live ? Colors.surfaceContainerHighest : "transparent"
                                opacity: row.live ? 1 : 0.45

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 10

                                    Image {
                                        id: entryIcon
                                        readonly property string src: root.iconSource(row.entry.icon)
                                        visible: entryIcon.src !== "" && entryIcon.status !== Image.Error
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 16
                                        source: entryIcon.src
                                        sourceSize.width: 32
                                        sourceSize.height: 32
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    CustomText {
                                        Layout.fillWidth: true
                                        content: root.clean(row.entry.text)
                                        size: 12
                                        elide: Text.ElideRight
                                    }

                                    MaterialIconSymbol {
                                        visible: row.entry.buttonType === QsMenuButtonType.CheckBox
                                        content: row.entry.checkState === Qt.Checked ? "check_box" : "check_box_outline_blank"
                                        iconSize: 18
                                        customColor: row.entry.checkState === Qt.Checked ? Colors.primary : Colors.outline
                                    }

                                    MaterialIconSymbol {
                                        visible: row.entry.buttonType === QsMenuButtonType.RadioButton
                                        content: row.entry.checkState === Qt.Checked ? "radio_button_checked" : "radio_button_unchecked"
                                        iconSize: 18
                                        customColor: row.entry.checkState === Qt.Checked ? Colors.primary : Colors.outline
                                    }

                                    MaterialIconSymbol {
                                        visible: row.entry.hasChildren
                                        content: "chevron_right"
                                        iconSize: 18
                                        customColor: Colors.outline
                                    }
                                }

                                MouseArea {
                                    id: rowArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: row.live ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: root.pick(row.entry)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
