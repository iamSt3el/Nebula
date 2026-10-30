import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils


ToolTip{
    id: root
    property string content
    property string detail: ""
    opacity: 0
    NumberAnimation on opacity{
        from: 0
        to: 1
        duration: 200
        running: true
    }
    verticalPadding: 7
    horizontalPadding: 10
    background: null
    delay: 400

    property bool placedBeside: false

    onAboutToShow: root.place()
    onImplicitWidthChanged: if (root.visible) root.place()
    onImplicitHeightChanged: if (root.visible) root.place()

    function place() {
        const p = root.parent
        if (!p)
            return
        const o = p.mapToItem(null, 0, 0)
        const e = p.mapToItem(null, 1, 0)
        let inColumn = false
        for (let a = p; a && !inColumn; a = a.parent)
            inColumn = a.vertical === true && a.frame !== undefined
        const turned = inColumn || Math.abs(e.y - o.y) > 0.01 || e.x < o.x
        if (!turned) {
            if (root.placedBeside) {
                root.placedBeside = false
                root.x = (p.width - root.implicitWidth) / 2
                root.y = -root.implicitHeight - 3
            }
            return
        }
        const r = p.mapToItem(null, 0, 0, p.width, p.height)
        const winW = p.Window.window ? p.Window.window.width : 0
        const toRight = r.x + r.width / 2 < winW / 2
        const l = p.mapFromItem(null, toRight ? r.x + r.width + 8 : r.x - root.implicitWidth - 8,
                                r.y + r.height / 2 - root.implicitHeight / 2)
        root.placedBeside = true
        root.x = l.x
        root.y = l.y
    }
    contentItem : Item{
        id: contentItemBackground
        implicitWidth: tooltipTextObject.width + 2 * root.horizontalPadding
        implicitHeight: tooltipTextObject.height + 2 * root.verticalPadding

        Rectangle{
            implicitHeight: tooltipTextObject.height + 2 * padding
            implicitWidth: tooltipTextObject.width + 2 * padding
            anchors.bottom: contentItemBackground.bottom
            anchors.horizontalCenter: contentItemBackground.horizontalCenter
            radius: 10
            color: Colors.surface


            Column{
                id: tooltipTextObject
                anchors.centerIn: parent
                spacing: 2

                CustomText{
                    content: root.content
                    size: 12
                    weight: root.detail !== "" ? 600 : 400
                    wrapMode: Text.Wrap
                    font.hintingPreference: Font.PreferNoHinting
                }

                CustomText{
                    visible: root.detail !== ""
                    content: root.detail
                    size: 11
                    customColor: Colors.outline
                    wrapMode: Text.Wrap
                    font.hintingPreference: Font.PreferNoHinting
                }
            }
        }
    }
}

