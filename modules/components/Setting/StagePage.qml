import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: page

    property string stageId: "front"
    property string title: ""
    property string aside: ""
    property real maxWidth: 680
    default property alias content: column.data

    readonly property bool lazy: !!(page.parent && page.parent.isStageLazy)
    readonly property Item view: page.parent && page.parent.isStageView ? page.parent
        : page.lazy && page.parent.view ? page.parent.view : null
    readonly property int depth: page.view ? page.view.depthOf(page.stageId) : 0
    readonly property bool active: page.depth === 0
    readonly property bool isFront: page.stageId === "front"
    property bool settled: false

    readonly property var decel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var fadeIn: [0.34, 0.88, 0.34, 1, 1, 1]
    readonly property var fadeOut: [0.3, 0, 0.8, 0.15, 1, 1]

    width: page.parent ? page.parent.width : 0
    height: page.parent ? page.parent.height : 0
    x: page.depth < 0 ? -40 : page.depth > 0 ? 56 : 0
    opacity: page.active ? 1 : 0
    visible: page.opacity > 0.01
    enabled: page.active
    layer.enabled: page.opacity > 0.01 && page.opacity < 0.99

    Behavior on x {
        enabled: page.settled
        SequentialAnimation {
            PauseAnimation { duration: page.active ? M3Motion.effects.fastDuration : 0 }
            NumberAnimation {
                duration: page.active ? 380 : M3Motion.effects.fastDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: page.active ? page.decel : page.fadeOut
            }
        }
    }

    Behavior on opacity {
        enabled: page.settled
        SequentialAnimation {
            PauseAnimation { duration: page.active ? M3Motion.effects.fastDuration : 0 }
            NumberAnimation {
                duration: page.active ? M3Motion.effects.slowDuration : M3Motion.effects.fastDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: page.active ? page.fadeIn : page.fadeOut
            }
        }
    }

    Component.onCompleted: {
        if (!page.lazy || !page.active) {
            page.settled = true
            return
        }
        page.x = 56
        page.opacity = 0
        page.settled = true
        page.x = Qt.binding(() => page.depth < 0 ? -40 : page.depth > 0 ? 56 : 0)
        page.opacity = Qt.binding(() => page.active ? 1 : 0)
    }

    RowLayout {
        id: bar
        visible: !page.isFront
        x: Math.round((page.width - column.width) / 2)
        width: column.width
        height: page.isFront ? 0 : 52
        spacing: 10

        M3IconButton {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            icon: "arrow_back"
            iconSize: 22
            tip: "Back"
            onClicked: if (page.view) page.view.back()
        }

        CustomText {
            Layout.fillWidth: true
            content: page.title
            size: 18
            weight: 600
            elide: Text.ElideRight
        }

        CustomText {
            visible: page.aside !== ""
            content: page.aside
            size: 12
            customColor: Colors.outline
        }
    }

    SmoothFlickable {
        id: flick
        anchors.top: bar.visible ? bar.bottom : parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: bar.visible ? 4 : 0
        contentWidth: width
        contentHeight: column.implicitHeight + 28
        wheelStep: 110
        ScrollBar.vertical: CustomScrollBar {}

        ColumnLayout {
            id: column
            x: Math.round((flick.width - width) / 2)
            y: 6
            width: Math.min(page.maxWidth, flick.width - 10)
            spacing: 3
        }
    }
}
