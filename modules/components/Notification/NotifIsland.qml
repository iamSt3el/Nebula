import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.NotifKit

Item {
    id: root

    required property Item host

    property var focusN: null
    readonly property var lead: root.focusN && root.host.live.indexOf(root.focusN) >= 0 ? root.focusN : root.host.shown
    readonly property var queue: root.host.live.filter(n => n !== root.lead).slice(0, 4)
    readonly property int waiting: Math.max(0, root.host.live.length - 1)
    readonly property bool critical: root.lead?.isCritical ?? false
    readonly property bool sticky: root.critical && (SettingsConfig.notifications?.urgentSticky ?? true)
    readonly property color fill: root.critical ? Colors.errorContainer : Colors.surfaceContainerLowest
    readonly property color ink: root.critical ? Colors.errorContainerText : Colors.surfaceText
    readonly property color subInk: root.critical ? Qt.alpha(Colors.errorContainerText, 0.8) : Colors.surfaceVariantText
    readonly property var acts: (root.lead?.actions ?? []).slice(0, 3)
    readonly property string imageSrc: {
        const s = IconUtil.imageSource(root.lead?.image)
        return s !== "" && !s.startsWith("image://icon/") ? s : ""
    }

    property point p: Qt.point(root.width / 2, 48)
    property string dir: "top"
    readonly property bool across: root.dir === "left" || root.dir === "right"
    readonly property real gap: 10

    readonly property real capW: Math.min(340, root.width - 24)
    readonly property real capH: 44
    readonly property real cardW: Math.min(400, root.width - 24)
    readonly property real cardH: cardBody.implicitHeight + 32

    property bool expanded: false
    property bool queueOpen: false
    property bool pinned: false
    readonly property bool hovering: boxHover.hovered || bubbleHover.hovered || queueHover.hovered

    property real m: root.expanded ? 1 : 0
    Behavior on m {
        NumberAnimation {
            duration: M3Motion.spatialDuration("default")
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
        }
    }
    readonly property real boxW: root.capW + (root.cardW - root.capW) * root.m
    readonly property real boxH: root.capH + (root.cardH - root.capH) * root.m
    property real q: root.queueOpen ? 1 : 0
    Behavior on q {
        NumberAnimation {
            duration: root.queueOpen ? 420 + 70 * Math.max(0, root.queue.length - 1) : 200
            easing.type: root.queueOpen ? Easing.Linear : Easing.InCubic
        }
    }
    readonly property real stagger: root.queue.length > 1 ? 0.55 / (root.queue.length - 1) : 0

    function queueT(step) {
        const n = Math.max(1, root.queue.length)
        const span = 1 - root.stagger * (n - 1)
        return Math.max(0, Math.min(1, (root.q - root.stagger * step) / Math.max(0.01, span)))
    }

    function backOut(x) {
        const c1 = 1.3
        const c3 = c1 + 1
        return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2)
    }

    readonly property real capFade: 1 - Math.min(1, root.m / 0.3)
    readonly property real cardFade: Math.max(0, Math.min(1, (root.m - 0.3) / 0.366))

    property real t: root.host.active ? 1 : 0
    Behavior on t {
        NumberAnimation {
            duration: root.host.active ? 460 : 220
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.host.active ? [0.38, 1.21, 0.22, 1.0, 1, 1] : [0.3, 0.0, 0.8, 0.15, 1, 1]
        }
    }

    onHoveringChanged: {
        root.host.hovered = root.hovering
        if (root.hovering)
            leaveTimer.stop()
        else
            leaveTimer.restart()
    }

    Timer {
        id: leaveTimer
        interval: 350
        onTriggered: {
            if (root.pinned)
                return
            root.expanded = false
            root.queueOpen = false
            root.focusN = null
        }
    }

    Timer {
        id: pinTimer
        interval: 3000
        onTriggered: {
            root.pinned = false
            if (!root.hovering)
                leaveTimer.restart()
        }
    }

    function openQueued(n) {
        root.focusN = n
        root.queueOpen = false
        root.expanded = true
        root.pinned = true
        leaveTimer.stop()
        pinTimer.restart()
    }

    Connections {
        target: root.host
        function onActiveChanged() {
            if (!root.host.active) {
                root.expanded = false
                root.queueOpen = false
                root.focusN = null
            } else {
                root.place()
            }
        }
    }

    onLeadChanged: if (root.t > 0.5) swapAnim.restart()

    onWaitingChanged: if (root.waiting === 0) root.queueOpen = false

    property real swap: 1
    NumberAnimation { id: swapAnim; target: root; property: "swap"; from: 0; to: 1; duration: M3Motion.effectsDuration("default") }

    function place() {
        const id = root.host.islandAnchor
        if (id !== "") {
            for (const s of root.host.surfaces) {
                if (!s || !s.visible || !s.present)
                    continue
                for (const b of s.visibleBlocks) {
                    if (!b.hasItem(id))
                        continue
                    const rc = s.blockRect(b)
                    const along = b.centerOfItem(id)
                    switch (s.side) {
                    case "top":    root.p = Qt.point(rc.x + along, rc.y + rc.height); break
                    case "bottom": root.p = Qt.point(rc.x + along, rc.y); break
                    case "left":   root.p = Qt.point(rc.x + rc.width, rc.y + along); break
                    default:       root.p = Qt.point(rc.x, rc.y + along)
                    }
                    root.dir = s.side
                    return
                }
            }
        }
        const top = root.host.surfaces.find(s => s && s.visible && s.present && s.side === "top")
        root.p = Qt.point(root.width / 2, top ? top.bandRect.y + top.bandRect.height : 8)
        root.dir = "top"
    }

    Component.onCompleted: root.place()

    Timer {
        interval: 250
        repeat: true
        running: root.t > 0.001
        onTriggered: root.place()
    }

    function clampX(x, w) {
        return Math.max(12, Math.min(root.width - w - 12, x))
    }

    function clampY(y, h) {
        return Math.max(12, Math.min(root.height - h - 12, y))
    }

    function dismiss(n) {
        if (n)
            n.popup = false
    }

    function openDefault(n) {
        if (!n)
            return
        const d = (n.notification?.actions ?? []).find(a => a.identifier === "default")
        if (d) {
            if (Features.genie) ServiceGenie.armNotif(root, n)
            d.invoke()
        }
        root.dismiss(n)
    }

    readonly property rect hit: {
        if (root.t < 0.01)
            return Qt.rect(0, 0, 0, 0)
        let x0 = box.x, y0 = box.y, x1 = box.x + box.width, y1 = box.y + box.height
        if (bubble.visible) {
            x0 = Math.min(x0, bubble.x); y0 = Math.min(y0, bubble.y)
            x1 = Math.max(x1, bubble.x + bubble.width); y1 = Math.max(y1, bubble.y + bubble.height)
        }
        if (queueCol.visible && root.queueOpen) {
            x0 = Math.min(x0, queueCol.x); y0 = Math.min(y0, queueCol.y)
            x1 = Math.max(x1, queueCol.x + queueCol.width); y1 = Math.max(y1, queueCol.y + queueCol.height)
        }
        return Qt.rect(x0, y0, x1 - x0, y1 - y0)
    }

    component Avatar: Item {
        id: av
        property var notif: null
        property real box: 30
        property color tile: Colors.primaryContainer
        property color tileInk: Colors.primaryContainerText
        readonly property string img: {
            const s = IconUtil.imageSource(av.notif?.image)
            return s !== "" && !s.startsWith("image://icon/") ? s : ""
        }
        implicitWidth: av.box
        implicitHeight: av.box

        ClippingRectangle {
            anchors.fill: parent
            visible: av.img !== ""
            radius: av.box / 2
            color: Colors.surfaceContainerHighest
            Image {
                anchors.fill: parent
                source: av.img
                sourceSize: Qt.size(av.box * 2, av.box * 2)
                asynchronous: av.img.startsWith("file:")
                fillMode: Image.PreserveAspectCrop
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: av.img === ""
            radius: av.box / 2
            color: av.tile

            Image {
                id: appIcon
                anchors.centerIn: parent
                width: av.box * 0.62
                height: width
                source: (av.notif?.appIcon || av.notif?.appName) ? IconUtil.getIconPath(av.notif.appIcon || av.notif.appName, "") : ""
                sourceSize: Qt.size(av.box * 2, av.box * 2)
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
            }

            MaterialIconSymbol {
                anchors.centerIn: parent
                visible: appIcon.status !== Image.Ready
                content: av.notif?.isCritical ? "priority_high" : "notifications"
                iconSize: av.box * 0.52
                customColor: av.tileInk
            }
        }
    }

    Item {
        id: box
        z: 3
        visible: root.t > 0.001
        width: root.boxW
        height: root.boxH
        x: root.across ? (root.dir === "left" ? root.p.x + root.gap : root.p.x - root.gap - width)
                       : root.clampX(root.p.x - width / 2, width)
        y: root.across ? root.clampY(root.p.y - height / 2, height)
                       : (root.dir === "top" ? root.p.y + root.gap : root.p.y - root.gap - height)
        opacity: Math.min(1, root.t * 1.6)
        transform: Scale {
            origin.x: root.dir === "left" ? 0 : root.dir === "right" ? box.width : box.width / 2
            origin.y: root.dir === "top" ? 0 : root.dir === "bottom" ? box.height : box.height / 2
            xScale: 0.7 + 0.3 * root.t
            yScale: 0.7 + 0.3 * root.t
        }

        Rectangle {
            anchors.fill: parent
            radius: 22 + 8 * root.m
            color: root.fill
            Behavior on color { EffectsColorAnim { speed: "fast" } }
        }

        HoverHandler {
            id: boxHover
            onHoveredChanged: {
                if (!hovered)
                    return
                root.pinned = false
                if (!root.queueOpen)
                    root.expanded = true
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: event => {
                const n = root.lead
                if (event.button === Qt.MiddleButton)
                    root.dismiss(n)
                else
                    root.openDefault(n)
            }
        }

        RowLayout {
            id: capRow
            visible: root.capFade > 0.001
            opacity: root.capFade * root.swap
            x: 7
            width: root.capW - 15
            height: root.capH
            spacing: 10

            Avatar {
                notif: root.lead
                box: 30
                tile: root.critical ? Colors.error : Colors.primaryContainer
                tileInk: root.critical ? Colors.errorText : Colors.primaryContainerText
            }

            CustomText {
                Layout.maximumWidth: capRow.width * 0.45
                content: root.lead?.summary || root.lead?.appName || ""
                size: 13
                weight: 600
                customColor: root.ink
            }

            CustomText {
                Layout.fillWidth: true
                content: (root.lead?.body ?? "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ")
                size: 13
                weight: 400
                customColor: root.subInk
            }

            Item {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22

                NotifRing {
                    anchors.fill: parent
                    visible: !root.sticky
                    stroke: 2.5
                    remaining: Math.max(0, 1 - (root.lead?.progress ?? 0))
                    ink: root.ink
                    accent: root.critical ? Colors.errorContainerText : Colors.primary
                }

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    visible: root.sticky
                    content: "close"
                    iconSize: 15
                    customColor: root.ink
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: root.sticky
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismiss(root.lead)
                }
            }
        }

        Item {
            anchors.fill: parent
            clip: true
            visible: root.cardFade > 0.001

            ColumnLayout {
                id: cardBody
                x: 16
                y: 16
                width: root.cardW - 32
                opacity: root.cardFade * root.swap
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Avatar {
                        notif: root.lead
                        box: 44
                        tile: root.critical ? Colors.error : Colors.primaryContainer
                        tileInk: root.critical ? Colors.errorText : Colors.primaryContainerText
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        CustomText {
                            Layout.fillWidth: true
                            content: root.lead?.summary || root.lead?.appName || ""
                            size: 15
                            weight: 600
                            customColor: root.ink
                        }

                        CustomText {
                            Layout.fillWidth: true
                            visible: (root.lead?.appName ?? "") !== "" && root.lead?.appName !== root.lead?.summary
                            content: root.lead?.appName ?? ""
                            size: 12
                            weight: 400
                            customColor: root.subInk
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignTop
                        radius: 15
                        color: closeMa.containsMouse ? Qt.alpha(root.ink, 0.18) : Qt.alpha(root.ink, 0.08)
                        Behavior on color { EffectsColorAnim { speed: "fast" } }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "close"
                            iconSize: 16
                            customColor: root.ink
                        }

                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.dismiss(root.lead)
                        }
                    }
                }

                CustomText {
                    Layout.fillWidth: true
                    visible: !fileCard.ok && (root.lead?.body ?? "") !== ""
                    content: (root.lead?.body ?? "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ")
                    size: 15
                    weight: 400
                    customColor: root.ink
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    lineHeight: 1.1
                }

                NotifHero {
                    Layout.fillWidth: true
                    visible: hero.ok && !fileCard.ok
                    id: hero
                    notif: root.lead
                }

                NotifFile {
                    id: fileCard
                    Layout.fillWidth: true
                    notif: root.lead
                    ink: root.ink
                    subInk: root.subInk
                    onOpened: root.dismiss(root.lead)
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.acts.length > 0 && !(fileCard.ok && fileCard.found !== "")
                    spacing: 8

                    Repeater {
                        model: root.acts

                        delegate: M3Button {
                            id: actBtn
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            variant: actBtn.index === 0 ? "filled" : "tonal"
                            label: actBtn.modelData.text ?? ""
                            onClicked: {
                                const a = actBtn.modelData
                                const n = root.lead
                                if (Features.genie) ServiceGenie.armNotif(actBtn, n)
                                a.invoke()
                                root.dismiss(n)
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: bubble
        z: 2
        visible: root.t > 0.001 && root.waiting > 0 && root.m < 0.5
        width: 44
        height: 44
        radius: 22
        x: root.dir === "right" ? box.x - width - 8 : box.x + box.width + 8
        y: box.y + (root.capH - height) / 2
        opacity: Math.min(1, root.t * 1.6) * (1 - root.m * 2)
        color: root.queueOpen ? Colors.primaryContainer : Colors.surfaceContainerLowest
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        CustomText {
            anchors.centerIn: parent
            opacity: 1 - root.q
            scale: 1 - 0.4 * Math.min(1, root.q)
            content: "+" + root.waiting
            size: 12
            weight: 700
            customColor: Colors.primaryContainerText
        }

        MaterialIconSymbol {
            anchors.centerIn: parent
            opacity: Math.min(1, root.q)
            rotation: (root.dir === "bottom" ? 0 : 180) * Math.min(1, root.q) + (root.dir === "bottom" ? 180 : 0) * (1 - Math.min(1, root.q))
            content: "expand_more"
            iconSize: 20
            customColor: Colors.primaryContainerText
        }

        HoverHandler { id: bubbleHover }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.queueOpen = !root.queueOpen
        }
    }

    Column {
        id: queueCol
        z: 1
        visible: root.t > 0.001 && root.q > 0.001 && root.waiting > 0 && root.m < 0.5
        width: root.capW + 32
        spacing: 6
        x: root.dir === "right" ? box.x + box.width - width : box.x
        y: root.dir === "bottom" ? box.y - height - 6 : box.y + box.height + 6

        HoverHandler { id: queueHover }

        Repeater {
            model: root.q > 0.001 || root.queueOpen ? (root.dir === "bottom" ? root.queue.slice().reverse() : root.queue) : []

            delegate: Rectangle {
                id: qi
                required property var modelData
                required property int index
                readonly property int step: root.dir === "bottom" ? root.queue.length - 1 - qi.index : qi.index
                readonly property bool crit: qi.modelData?.isCritical ?? false
                readonly property real lin: root.queueT(qi.step)
                readonly property real e: root.backOut(qi.lin)
                readonly property real indent: (qi.step + 1) * 16 * Math.min(1.08, qi.e)
                x: root.dir === "right" ? queueCol.width - width - qi.indent : qi.indent
                opacity: Math.min(1, qi.lin * 2.5)
                transform: [
                    Translate {
                        y: (1 - qi.e) * (qi.step + 1) * (44 + 6) * (root.dir === "bottom" ? 1 : -1)
                    },
                    Scale {
                        origin.x: qi.width / 2
                        origin.y: 22
                        xScale: 0.86 + 0.14 * Math.min(1, qi.e)
                        yScale: 0.86 + 0.14 * Math.min(1, qi.e)
                    }
                ]
                width: root.capW
                height: 44
                radius: 22
                color: qi.crit ? Colors.errorContainer : Colors.surfaceContainerLowest

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 7
                    anchors.rightMargin: 14
                    spacing: 10

                    Avatar {
                        notif: qi.modelData
                        box: 30
                        tile: qi.crit ? Colors.error : Colors.secondaryContainer
                        tileInk: qi.crit ? Colors.errorText : Colors.secondaryContainerText
                    }

                    CustomText {
                        Layout.maximumWidth: qi.width * 0.4
                        content: qi.modelData?.summary || qi.modelData?.appName || ""
                        size: 13
                        weight: 600
                        customColor: qi.crit ? Colors.errorContainerText : Colors.surfaceText
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: (qi.modelData?.body ?? "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ")
                        size: 13
                        weight: 400
                        customColor: qi.crit ? Qt.alpha(Colors.errorContainerText, 0.8) : Colors.surfaceVariantText
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: event => {
                        const n = qi.modelData
                        if (event.button === Qt.MiddleButton)
                            root.dismiss(n)
                        else
                            root.openQueued(n)
                    }
                }
            }
        }
    }
}
