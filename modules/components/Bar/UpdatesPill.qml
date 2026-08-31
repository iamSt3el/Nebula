import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: pill

    readonly property bool upgrading: ServiceSystemUpdates.upgrading
    readonly property bool aurRunning: ServiceSystemUpdates.aurRunning
    readonly property bool failed: ServiceSystemUpdates.phase === "error"
    readonly property bool succeeded: ServiceSystemUpdates.phase === "done"

    readonly property string accent: pillHov.containsMouse ? Colors.primaryContainerText
                                                           : Colors.surfaceText

    readonly property string detail: {
        if (pill.upgrading) return Math.round(ServiceSystemUpdates.progress * 100) + "%"
        if (pill.aurRunning) return "AUR"
        if (pill.failed) return "failed"
        if (pill.succeeded) return "done"
        return String(ServiceSystemUpdates.totalCount)
    }

    implicitWidth: pillRow.implicitWidth + 18
    implicitHeight: 26
    radius: 13
    color: pillHov.containsMouse ? Colors.primaryContainer : "transparent"

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    RowLayout {
        id: pillRow
        anchors.centerIn: parent
        spacing: pillHov.containsMouse ? 6 : 0

        MaterialIconSymbol {
            content: pill.failed ? "sync_problem"
                   : pill.succeeded ? "check_circle"
                   : (pill.upgrading || pill.aurRunning) ? "sync"
                   : "system_update_alt"
            iconSize: 16
            customColor: pill.accent
            Behavior on customColor { ColorAnimation { duration: 150 } }

            SequentialAnimation on opacity {
                running: pill.upgrading || pill.aurRunning || ServiceSystemUpdates.checking
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.45; duration: 750; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.00; duration: 750; easing.type: Easing.InOutSine }
            }
        }

        CustomText {
            visible: pillHov.containsMouse
            content: pill.detail
            size: 13
            weight: 700
            customColor: pill.accent
            Behavior on customColor { ColorAnimation { duration: 150 } }
        }
    }

    MouseArea {
        id: pillHov
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            GlobalStates.settingsPage = 13
            GlobalStates.settingsOpen = true
        }
    }

    CustomToolTip {
        visible: pillHov.containsMouse
        content: {
            if (pill.upgrading) {
                const p = ServiceSystemUpdates.currentPackage
                return ServiceSystemUpdates.phaseLabel + (p !== "" ? " — " + p : "")
            }
            if (pill.aurRunning) return "AUR upgrade running in a terminal"
            if (pill.failed) return ServiceSystemUpdates.errorText
            if (pill.succeeded) return "System updated"
            const bits = []
            if (ServiceSystemUpdates.repoCount > 0) bits.push(ServiceSystemUpdates.repoCount + " repo")
            if (ServiceSystemUpdates.aurCount > 0) bits.push(ServiceSystemUpdates.aurCount + " AUR")
            if (ServiceSystemUpdates.hasCriticalNews) bits.push("Arch news since last upgrade")
            return bits.join(" · ")
        }
    }
}
