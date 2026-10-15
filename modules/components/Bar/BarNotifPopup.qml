import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Osd

Item {
    id: root

    signal moreClicked()

    readonly property int maxCards: Math.max(1, Math.min(5, SettingsConfig.notifications?.maxVisible ?? 3))
    readonly property bool grouped: SettingsConfig.notifications?.groupPopups ?? true
    readonly property bool urgentSticky: SettingsConfig.notifications?.urgentSticky ?? true

    onMaxCardsChanged: root.sync()
    onGroupedChanged: root.sync()
    property var cards: []
    property int version: 0
    property bool ready: false
    property bool showOsd: false

    readonly property int hiddenCount: {
        root.version
        return Math.max(0, root.liveCount - root.cards.filter(c => !c.leaving).reduce((s, c) => s + c.items.length, 0))
    }
    readonly property int liveCount: ServiceNotification.popups.length

    implicitHeight: col.implicitHeight + 24

    function keyOf(n) {
        return (n?.appName ?? "") + "|" + (n?.appIcon ?? "")
    }

    function groupsNow() {
        const live = [...ServiceNotification.popups].reverse()
        const order = []
        const map = {}
        for (const n of live) {
            const k = root.grouped ? root.keyOf(n) : (n.id + "@" + n.arrivalTimestamp)
            if (!map[k]) {
                map[k] = { key: k, items: [], critical: false, latest: n.arrivalTimestamp }
                order.push(k)
            }
            map[k].items.push(n)
            if (n.isCritical)
                map[k].critical = true
        }
        const groups = order.map(k => map[k])
        const pinned = groups.filter(g => g.critical).concat(groups.filter(g => !g.critical))
        return pinned.slice(0, root.maxCards)
    }

    function sync() {
        const want = root.groupsNow()
        const old = {}
        root.cards.forEach((c, i) => old[c.key] = { card: c, index: i })
        const next = []
        for (const g of want) {
            const prev = old[g.key]
            const card = prev ? prev.card : { key: g.key, born: Date.now() }
            card.items = g.items
            card.critical = g.critical
            card.leaving = false
            next.push(card)
            delete old[g.key]
        }
        for (const k of Object.keys(old)) {
            const o = old[k]
            if (o.card.items.length === 0)
                continue
            o.card.leaving = true
            next.splice(Math.min(o.index, next.length), 0, o.card)
        }
        root.cards = next
        root.version++
    }

    function finishLeave(card) {
        if (!card.leaving)
            return
        root.cards = root.cards.filter(c => c !== card)
        root.version++
    }

    function dismissCard(card) {
        for (const n of card.items)
            n.popup = false
    }

    function openCard(card) {
        const n = card.items[0]
        if (!n)
            return
        const d = (n.notification?.actions ?? []).find(a => a.identifier === "default")
        if (d)
            d.invoke()
        root.dismissCard(card)
    }

    Connections {
        target: ServiceNotification
        function onPopupsChanged() { root.sync() }
    }

    Component.onCompleted: {
        root.sync()
        readyTimer.start()
    }

    Timer {
        id: readyTimer
        interval: 350
        onTriggered: root.ready = true
    }

    HoverHandler { id: hov }

    Binding {
        target: ServiceNotification
        property: "popupsPaused"
        value: hov.hovered
        when: root.visible && root.liveCount > 0
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 0

        Loader {
            active: root.showOsd
            visible: active
            Layout.fillWidth: true
            Layout.preferredHeight: active ? 48 : 0
            Layout.bottomMargin: active ? 8 : 0
            sourceComponent: OsdContent { pad: 0 }
        }

        Repeater {
            model: ScriptModel { values: root.cards }
            delegate: PopupCard {}
        }

        Rectangle {
            visible: root.hiddenCount > 0
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.preferredHeight: 32
            radius: 16
            color: moreMa.containsMouse ? Colors.surfaceContainer : Qt.alpha(Colors.surfaceContainer, 0)
            Behavior on color { EffectsColorAnim { speed: "fast" } }

            CustomText {
                anchors.centerIn: parent
                content: "+" + root.hiddenCount + " more · open notifications"
                size: 12
                weight: 600
                customColor: Colors.surfaceVariantText
            }

            MouseArea {
                id: moreMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.moreClicked()
            }
        }
    }

    component PopupCard: Item {
        id: pc

        required property var modelData
        required property int index

        readonly property var card: pc.modelData
        readonly property var items: { root.version; return pc.card.items ?? [] }
        readonly property var lead: pc.items.length > 0 ? pc.items[0] : null
        readonly property bool multi: pc.items.length > 1
        readonly property bool critical: { root.version; return pc.card.critical === true }
        readonly property bool sticky: pc.critical && root.urgentSticky
        readonly property bool leavingNow: { root.version; return pc.card.leaving === true }
        readonly property bool isTop: { root.version; return root.cards.find(c => !c.leaving) === pc.card }
        readonly property string imageSrc: IconUtil.imageSource(pc.lead?.image)
        readonly property bool hasImage: pc.imageSrc !== "" && !pc.imageSrc.startsWith("image://icon/")
        readonly property var acts: (pc.lead?.actions ?? []).slice(0, 3)
        readonly property color bg: pc.critical ? Colors.errorContainer : Colors.surfaceContainerHigh
        readonly property color ink: pc.critical ? Colors.errorContainerText : Colors.surfaceText
        readonly property color subInk: pc.critical ? Qt.alpha(Colors.errorContainerText, 0.8) : Colors.surfaceVariantText

        property real keep: 1
        property real lift: 0
        property real fade: 1
        property real slide: 0

        Layout.fillWidth: true
        Layout.topMargin: pc.index > 0 ? 8 * pc.keep : 0
        Layout.preferredHeight: cardRect.height * pc.keep
        clip: pc.keep < 0.999

        Component.onCompleted: if (root.ready && root.cards.some(c => c !== pc.card && !c.leaving)) enterFx.start()
        onLeavingNowChanged: if (pc.leavingNow) exitFx.start()

        ParallelAnimation {
            id: enterFx
            NumberAnimation { target: pc; property: "keep"; from: 0; to: 1; duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: M3Motion.panel.openCurve }
            NumberAnimation { target: pc; property: "lift"; from: -14; to: 0; duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: M3Motion.panel.openCurve }
            NumberAnimation { target: pc; property: "fade"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
        }

        SequentialAnimation {
            id: exitFx
            ParallelAnimation {
                NumberAnimation { target: pc; property: "fade"; to: 0; duration: 180; easing.type: Easing.InCubic }
                NumberAnimation { target: pc; property: "slide"; to: pc.slide === 0 ? 24 : Math.sign(pc.slide) * (pc.width + 40); duration: 180; easing.type: Easing.InCubic }
            }
            NumberAnimation { target: pc; property: "keep"; to: 0; duration: 240; easing.type: Easing.OutCubic }
            ScriptAction {
                script: {
                    const c = pc.card
                    root.finishLeave(c)
                }
            }
        }

        Rectangle {
            id: cardRect
            width: pc.width
            height: body.implicitHeight + 24
            x: pc.slide + dragX
            radius: 20
            color: pc.bg
            opacity: pc.fade * (1 - Math.min(0.9, Math.abs(cardRect.dragX) / Math.max(1, pc.width)))
            clip: true
            transform: Translate { y: pc.lift }

            property real dragX: 0
            Behavior on dragX {
                enabled: !cardMa.dragging
                SpatialAnim { speed: "fast" }
            }
            Behavior on height {
                enabled: root.ready && !pc.leavingNow
                SpatialAnim { speed: "fast" }
            }

            MouseArea {
                id: cardMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                property real pressX: 0
                property bool dragging: false

                onPressed: event => {
                    if (event.button === Qt.MiddleButton) {
                        root.dismissCard(pc.card)
                        return
                    }
                    cardMa.pressX = cardMa.mapToItem(pc, event.x, 0).x
                    cardMa.dragging = false
                }
                onPositionChanged: event => {
                    if (!cardMa.pressed)
                        return
                    const d = cardMa.mapToItem(pc, event.x, 0).x - cardMa.pressX
                    if (!cardMa.dragging && Math.abs(d) < 6)
                        return
                    cardMa.dragging = true
                    cardRect.dragX = d
                }
                onReleased: event => {
                    if (!cardMa.dragging) {
                        if (event.button === Qt.LeftButton)
                            root.openCard(pc.card)
                        return
                    }
                    if (Math.abs(cardRect.dragX) > pc.width * 0.35) {
                        pc.slide = cardRect.dragX
                        cardRect.dragX = 0
                        cardMa.dragging = false
                        root.dismissCard(pc.card)
                    } else {
                        cardMa.dragging = false
                        cardRect.dragX = 0
                    }
                }
                onCanceled: {
                    cardMa.dragging = false
                    cardRect.dragX = 0
                }
            }

            Item {
                id: ringBox
                z: 2
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 12
                anchors.rightMargin: 12
                readonly property real remaining: Math.max(0, 1 - (pc.lead?.progress ?? 0))
                readonly property bool showX: pc.sticky || cardMa.containsMouse || ringMa.containsMouse
                implicitWidth: 24
                implicitHeight: 24

                Shape {
                    anchors.fill: parent
                    visible: !pc.sticky
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: Qt.alpha(pc.ink, 0.14)
                        strokeWidth: 2.5
                        fillColor: "transparent"
                        PathAngleArc { centerX: 12; centerY: 12; radiusX: 10; radiusY: 10; startAngle: 0; sweepAngle: 360 }
                    }

                    ShapePath {
                        strokeColor: Colors.primary
                        strokeWidth: 2.5
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 12; centerY: 12; radiusX: 10; radiusY: 10; startAngle: -90; sweepAngle: 360 * ringBox.remaining }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: pc.sticky ? 0 : 4
                    radius: width / 2
                    color: ringMa.containsMouse ? Qt.alpha(pc.ink, 0.18) : pc.sticky ? Qt.alpha(pc.ink, 0.10) : "transparent"
                    opacity: ringBox.showX ? 1 : 0
                    Behavior on opacity { EffectsAnim { speed: "fast" } }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "close"
                        iconSize: pc.sticky ? 15 : 12
                        customColor: pc.ink
                    }
                }

                MouseArea {
                    id: ringMa
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismissCard(pc.card)
                }
            }

            ColumnLayout {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; leftMargin: 14; rightMargin: 44 }
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Item {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignTop

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            anchors.margins: 1
                            source: IconUtil.getIconPath(pc.lead?.appIcon || pc.lead?.appName || "", "")
                            sourceSize: Qt.size(72, 72)
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: appIcon.status !== Image.Ready
                            radius: 18
                            color: pc.critical ? Qt.alpha(Colors.errorContainerText, 0.16) : Qt.alpha(Colors.primary, 0.14)

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: pc.critical ? "priority_high" : "notifications"
                                iconSize: 18
                                customColor: pc.critical ? Colors.errorContainerText : Colors.primary
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            CustomText {
                                Layout.fillWidth: true
                                content: pc.multi ? (pc.lead?.appName || "") : (pc.lead?.summary || pc.lead?.appName || "")
                                size: 13
                                weight: 700
                                customColor: pc.ink
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                visible: pc.multi
                                implicitWidth: countText.implicitWidth + 14
                                implicitHeight: 20
                                radius: 10
                                color: pc.critical ? Qt.alpha(Colors.errorContainerText, 0.16) : Colors.surfaceContainerHighest

                                CustomText {
                                    id: countText
                                    anchors.centerIn: parent
                                    content: String(pc.items.length)
                                    size: 11
                                    weight: 700
                                    customColor: pc.ink
                                }
                            }
                        }

                        CustomText {
                            visible: !pc.multi && (pc.lead?.body ?? "") !== ""
                            Layout.fillWidth: true
                            content: (pc.lead?.body ?? "").replace(/\s+/g, " ")
                            size: 12
                            customColor: pc.subInk
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Repeater {
                            model: pc.multi ? pc.items.slice(0, 2) : []

                            delegate: RowLayout {
                                id: pv
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 5

                                CustomText {
                                    Layout.maximumWidth: body.width * 0.4
                                    content: pv.modelData?.summary ?? ""
                                    size: 12
                                    weight: 700
                                    customColor: pc.ink
                                    elide: Text.ElideRight
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    content: (pv.modelData?.body ?? "").replace(/\s+/g, " ")
                                    size: 12
                                    customColor: pc.subInk
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    ClippingRectangle {
                        visible: pc.hasImage && !pc.multi
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        Layout.alignment: Qt.AlignTop
                        radius: 12
                        color: Colors.surfaceContainerHighest

                        Image {
                            anchors.fill: parent
                            source: pc.hasImage ? pc.imageSrc : ""
                            sourceSize: Qt.size(88, 88)
                            asynchronous: pc.imageSrc.startsWith("file:")
                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                }

                Flow {
                    visible: pc.isTop && pc.acts.length > 0
                    Layout.fillWidth: true
                    Layout.leftMargin: 48
                    spacing: 6

                    Repeater {
                        model: pc.isTop ? pc.acts : []

                        delegate: Rectangle {
                            id: actBtn
                            required property var modelData
                            required property int index
                            readonly property bool primary: actBtn.index === 0
                            width: actText.implicitWidth + 28
                            height: 30
                            radius: 15
                            color: actBtn.primary ? (actMa.containsMouse ? Qt.lighter(Colors.primary, 1.08) : Colors.primary)
                                 : actMa.containsMouse ? Qt.alpha(pc.ink, 0.10) : Qt.alpha(pc.ink, 0)
                            border.width: actBtn.primary ? 0 : 1
                            border.color: pc.critical ? Qt.alpha(Colors.errorContainerText, 0.4) : Colors.outlineVariant
                            Behavior on color { EffectsColorAnim { speed: "fast" } }

                            CustomText {
                                id: actText
                                anchors.centerIn: parent
                                content: actBtn.modelData.text ?? ""
                                size: 12
                                weight: 600
                                customColor: actBtn.primary ? Colors.primaryText : pc.ink
                            }

                            MouseArea {
                                id: actMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const a = actBtn.modelData
                                    const c = pc.card
                                    const popup = root
                                    a.invoke()
                                    popup.dismissCard(c)
                                }
                            }
                        }
                    }
                }
            }

        }
    }
}
