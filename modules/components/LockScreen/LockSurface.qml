pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.settings

Item {
    id: root

    property LockContext context: null
    property bool exiting: false
    property bool greeter: LockSession.greeter
    property url desk: ""
    property bool primary: true
    focus: true

    readonly property var _cfg: (root.greeter ? SettingsConfig.greeter : SettingsConfig.lockscreen) ?? ({})
    readonly property string variantStyle: LockCatalog.normalize(root._cfg.layout)
    readonly property Item layoutItem: layoutLoader.item
    readonly property bool _desk: deskImage.status === Image.Ready

    property real defocus: 0
    property real shade: 0
    property real depth: 1.06

    readonly property var _decel: [0.05, 0.7, 0.1, 1.0, 1, 1]
    readonly property var _standard: [0.2, 0.0, 0.0, 1.0, 1, 1]
    readonly property var _accel: [0.3, 0.0, 0.8, 0.15, 1, 1]

    function focusInput() {
        const f = layoutLoader.authField
        if (f && f.input)
            f.input.forceActiveFocus()
    }

    Keys.onPressed: event => root.focusInput()

    onExitingChanged: if (root.exiting) {
        enterAnim.stop()
        exitAnim.start()
    }

    ParallelAnimation {
        id: enterAnim
        running: true

        NumberAnimation {
            target: root; property: "defocus"; to: 1
            duration: 620
            easing.type: Easing.BezierSpline; easing.bezierCurve: root._decel
        }
        SequentialAnimation {
            PauseAnimation { duration: root._desk ? 120 : 0 }
            NumberAnimation {
                target: root; property: "shade"; to: 1
                duration: root._desk ? 560 : 420
                easing.type: Easing.BezierSpline; easing.bezierCurve: root._standard
            }
        }
        NumberAnimation {
            target: root; property: "depth"; to: 1
            duration: 1300
            easing.type: Easing.BezierSpline; easing.bezierCurve: root._decel
        }
    }

    ParallelAnimation {
        id: exitAnim

        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation {
                target: root; property: "shade"; to: 0
                duration: 520
                easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0.0, 0.2, 1.0, 1, 1]
            }
        }
        NumberAnimation {
            target: root; property: "depth"; to: 1.05
            duration: 580
            easing.type: Easing.BezierSpline; easing.bezierCurve: root._accel
        }
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            NumberAnimation {
                target: root; property: "defocus"; to: 0
                duration: 700
                easing.type: Easing.BezierSpline; easing.bezierCurve: root._decel
            }
        }
    }

    Image {
        id: deskImage
        anchors.fill: parent
        source: root.desk
        asynchronous: false
        cache: false
        smooth: true
        visible: root._desk && root.shade < 1
        scale: 1 + 0.05 * root.defocus

        layer.enabled: visible && root.defocus > 0.002
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: root.defocus
            blurMax: 64
            brightness: -0.3 * root.defocus
            saturation: -0.3 * root.defocus
        }
    }

    Item {
        anchors.fill: parent
        opacity: root.shade
        visible: root.shade > 0
        scale: root.depth

        LockBackdrop {
            anchors.fill: parent
            style: LockCatalog.backdropFor(root.variantStyle)
        }
    }

    LockLayoutLoader {
        id: layoutLoader
        anchors.fill: parent
        variant: root.variantStyle
        context: root.context
        exiting: root.exiting
        greeter: root.greeter
        onLoaded: Qt.callLater(root.focusInput)
    }

    Binding {
        target: layoutLoader.authField
        property: "opacity"
        value: 0
        when: !root.primary && layoutLoader.authField !== null
    }

    Timer {
        interval: 700; running: true
        onTriggered: root.focusInput()
    }
}
