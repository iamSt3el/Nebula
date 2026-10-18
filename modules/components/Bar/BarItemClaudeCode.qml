import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true
    readonly property bool iconSizable: true
    readonly property bool verticalReady: root.vertical
    readonly property bool vertical: !!root.host && root.host.vertical === true
    readonly property real box: BarLayout.boxFor(root.itemId, root.host)
    readonly property real iconPx: BarLayout.iconPxFor(root.itemId, root.box, 18)
    readonly property real plate: BarLayout.platePxFor(root.box, root.iconPx, 18, 28)
    readonly property real labelPx: BarLayout.scaleFor(root.iconPx, 18, 13, 8)
    readonly property real gapPx: BarLayout.scaleFor(root.iconPx, 18, 6, 3)
    readonly property bool plateless: BarLayout.chipHovers(root.itemId, root.implicitWidth, root.implicitHeight)
    readonly property bool open: !!root.host && root.host.panelKind === "claudeCode"

    readonly property var session: ServiceClaudeCode.limitFor("session")
    readonly property var weekly: ServiceClaudeCode.limitFor("weekly")
    readonly property real sessionPct: root.session ? (root.session.percent ?? 0) : 0
    readonly property real weeklyPct: root.weekly ? (root.weekly.percent ?? 0) : 0
    readonly property bool hot: ServiceClaudeCode.toneOf(root.session) !== "normal"
    readonly property color sessionTone: ServiceClaudeCode.colorOf(root.session, Colors.primary)
    readonly property color weeklyTone: ServiceClaudeCode.colorOf(root.weekly, Colors.secondary)
    readonly property bool hasLimits: root.session !== null
    readonly property string countdown: root.session ? ServiceClaudeCode.formatSpan(root.session.secondsLeft ?? 0) : ""
    readonly property color ink: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText

    Component.onCompleted: ServiceClaudeCode.retain()
    Component.onDestruction: ServiceClaudeCode.release()

    implicitWidth: root.vertical ? Math.max(root.plate, face.implicitWidth + 8) : face.implicitWidth + root.plate - root.iconPx + 6
    implicitHeight: root.vertical ? face.implicitHeight + 10 : root.plate
    radius: Math.min(width, height) / 2
    color: root.plateless ? Qt.alpha(Colors.primaryContainer, 0) : hov.containsMouse ? Colors.primaryContainer : Qt.alpha(Colors.primaryContainer, 0)
    Behavior on color { ColorAnimation { duration: 150 } }

    Grid {
        id: face
        anchors.centerIn: parent
        spacing: root.vertical ? 2 : root.gapPx
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Item {
            width: root.iconPx + 4
            height: root.iconPx + 4
            opacity: ServiceClaudeCode.limitsStale ? 0.45 : 1

            CustomCircularProgressBar {
                anchors.fill: parent
                thickness: 2.4
                radius: parent.width / 2 - 1.6
                progress: Math.min(1, root.weeklyPct / 100)
                showText: false
                baseColor: Colors.surfaceContainerHighest
                lineColor: root.weeklyTone
            }

            CustomCircularProgressBar {
                anchors.fill: parent
                thickness: 2.4
                radius: parent.width / 2 - 5.6
                progress: Math.min(1, root.sessionPct / 100)
                showText: false
                baseColor: Colors.surfaceContainerHighest
                lineColor: root.sessionTone
            }

            Rectangle {
                visible: ServiceClaudeCode.live
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: -2
                width: 8
                height: 8
                radius: 4
                color: Colors.tertiary
                border.width: 2
                border.color: Colors.surface
            }
        }

        CustomText {
            visible: root.hasLimits
            content: Math.round(root.sessionPct) + "%"
            size: root.vertical ? root.labelPx - 2 : root.labelPx
            weight: 700
            customColor: root.hot && !hov.containsMouse ? root.sessionTone : root.ink
        }

        CustomText {
            visible: root.hasLimits && !root.vertical
            content: root.countdown
            size: root.labelPx - 1
            weight: 500
            customColor: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceVariantText
        }

        Repeater {
            model: root.hasLimits && root.vertical ? root.countdown.split(" ").filter(p => p !== "") : []

            CustomText {
                required property string modelData
                content: modelData
                size: root.labelPx - 3
                weight: 500
                customColor: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceVariantText
            }
        }
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.host) root.host.openPanel("claudeCode", root)
    }

    CustomToolTip {
        content: ServiceClaudeCode.live ? "Claude Code, working in " + ServiceClaudeCode.project : "Claude Code"
        detail: root.hasLimits ? "Session " + Math.round(root.sessionPct) + "%, week " + Math.round(root.weeklyPct) + "%" : "No usage data yet"
        visible: hov.containsMouse && !root.open
    }
}
