import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MaterialShapeFn

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    property string filter: ""
    property bool showLog: false
    property string confirmAction: ""

    function patch(key, value) {
        SettingsConfig.updates = Object.assign({}, SettingsConfig.updates, { [key]: value })
    }

    readonly property var filteredRepo: {
        const f = root.filter.toLowerCase()
        if (f === "") return ServiceSystemUpdates.repoUpdates
        return ServiceSystemUpdates.repoUpdates.filter(u => u.name.toLowerCase().indexOf(f) >= 0)
    }

    readonly property var filteredAur: {
        const f = root.filter.toLowerCase()
        if (f === "") return ServiceSystemUpdates.aurUpdates
        return ServiceSystemUpdates.aurUpdates.filter(u => u.name.toLowerCase().indexOf(f) >= 0)
    }

    Component.onCompleted: {
        if (ServiceSystemUpdates.lastChecked === 0 && !ServiceSystemUpdates.checking)
            ServiceSystemUpdates.refreshAll()
        else if (ServiceSystemUpdates.news.length === 0)
            ServiceSystemUpdates.refreshNews()
    }

    Flickable {
        id: pageFlick
        ScrollBar.vertical: CustomScrollBar {}
        anchors.fill: parent
        contentHeight: column.implicitHeight
        contentWidth: width
        clip: true

        ColumnLayout {
            id: column
            width: parent.width
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors { leftMargin: 5; rightMargin: 5; topMargin: 5 }
            spacing: 0

            RowLayout {
                spacing: 10
                MaterialIconSymbol { content: "system_update_alt"; iconSize: 20 }
                CustomText { content: "System updates"; size: 20; customColor: Colors.primary }

                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: refreshRow.implicitWidth + 26
                    implicitHeight: 34
                    radius: 17
                    color: ServiceSystemUpdates.checking ? Colors.surfaceContainerHighest : Colors.primary

                    Behavior on color { EffectsColorAnim {} }
                    Behavior on implicitWidth { SpatialAnim { speed: "fast" } }

                    RowLayout {
                        id: refreshRow
                        anchors.centerIn: parent
                        spacing: 8

                        Item {
                            implicitWidth: 16
                            implicitHeight: 16

                            CustomCircularLoader {
                                anchors.centerIn: parent
                                size: 16
                                trackWidth: 2
                                highlightColor: Colors.primary
                                trackColor: Colors.surfaceContainerHigh
                                opacity: ServiceSystemUpdates.checking ? 1 : 0
                                visible: opacity > 0
                                Behavior on opacity { EffectsAnim { speed: "fast" } }
                            }

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: "refresh"
                                iconSize: 16
                                customColor: Colors.primaryText
                                opacity: ServiceSystemUpdates.checking ? 0 : 1
                                visible: opacity > 0
                                rotation: ServiceSystemUpdates.checking ? -120 : 0
                                Behavior on opacity { EffectsAnim { speed: "fast" } }
                                Behavior on rotation { SpatialAnim { speed: "fast" } }
                            }
                        }

                        CustomText {
                            content: ServiceSystemUpdates.checking ? "Checking" : "Check now"
                            size: 13
                            customColor: ServiceSystemUpdates.checking ? Colors.surfaceText : Colors.primaryText
                        }
                    }

                    RippleEffect {
                        anchors.fill: parent
                        radius: 17
                        enabled: !ServiceSystemUpdates.checking && !ServiceSystemUpdates.busy
                        hoverColor: Qt.alpha(Colors.primaryText, 0.10)
                        rippleColor: Qt.alpha(Colors.primaryText, 0.24)
                        onClicked: ServiceSystemUpdates.refreshAll()
                    }
                }
            }

            CustomText { Layout.topMargin: 24; content: "Status"; size: 13; customColor: Colors.primary }

            CustomCard {
                Layout.topMargin: 6
                Layout.fillWidth: true
                autoRadius: false
                topRadius: 20
                bottomRadius: 20

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        Item {
                            implicitWidth: 56
                            implicitHeight: 56

                            MaterialShapes.ShapeCanvas {
                                anchors.fill: parent
                                roundedPolygon: MaterialShapeFn.getCookie6Sided()
                                color: ServiceSystemUpdates.totalCount > 0
                                       ? Colors.primaryContainer
                                       : Colors.surfaceContainerHighest
                            }

                            CustomText {
                                anchors.centerIn: parent
                                content: String(ServiceSystemUpdates.totalCount)
                                size: ServiceSystemUpdates.totalCount > 99 ? 17 : 20
                                weight: 600
                                customColor: ServiceSystemUpdates.totalCount > 0
                                             ? Colors.primaryContainerText
                                             : Colors.outline
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            CustomText {
                                content: ServiceSystemUpdates.totalCount === 0
                                         ? (ServiceSystemUpdates.checking ? "Checking for updates" : "Everything is up to date")
                                         : ServiceSystemUpdates.totalCount + (ServiceSystemUpdates.totalCount === 1 ? " update available" : " updates available")
                                size: 16
                                weight: 600
                            }

                            CustomText {
                                Layout.fillWidth: true
                                content: {
                                    if (ServiceSystemUpdates.checkError !== "")
                                        return ServiceSystemUpdates.checkError
                                    const bits = []
                                    if (ServiceSystemUpdates.repoCount > 0)
                                        bits.push(ServiceSystemUpdates.repoCount + " repo")
                                    if (ServiceSystemUpdates.aurCount > 0)
                                        bits.push(ServiceSystemUpdates.aurCount + " AUR")
                                    if (ServiceSystemUpdates.downloadBytes > 0)
                                        bits.push(ServiceSystemUpdates.formatBytes(ServiceSystemUpdates.downloadBytes) + " to download")
                                    bits.push("checked " + ServiceSystemUpdates.relativeTime(ServiceSystemUpdates.lastChecked))
                                    return bits.join("  ·  ")
                                }
                                size: 12
                                customColor: ServiceSystemUpdates.checkError !== "" ? Colors.error : Colors.outline
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Loader {
                        Layout.fillWidth: true
                        active: ServiceSystemUpdates.upgrading || ServiceSystemUpdates.phase !== ""
                        visible: active

                        sourceComponent: ColumnLayout {
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                CustomText {
                                    content: ServiceSystemUpdates.phaseLabel
                                    size: 12
                                    weight: 600
                                    customColor: ServiceSystemUpdates.phase === "error" ? Colors.error
                                               : ServiceSystemUpdates.phase === "done" ? Colors.primary
                                               : Colors.surfaceText
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    content: ServiceSystemUpdates.currentPackage
                                    size: 12
                                    customColor: Colors.outline
                                    elide: Text.ElideRight
                                }

                                CustomText {
                                    visible: ServiceSystemUpdates.stepTotal > 0 && ServiceSystemUpdates.upgrading
                                    content: ServiceSystemUpdates.doneCount + " / " + ServiceSystemUpdates.stepTotal
                                    size: 12
                                    customColor: Colors.outline
                                }
                            }

                            M3WavyProgressBar {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 12
                                progress: ServiceSystemUpdates.progress
                                indeterminate: ServiceSystemUpdates.phase === "sync"
                                               || ServiceSystemUpdates.phase === "keyring"
                                activeThickness: 8
                                trackThickness: 8
                                waveAmplitude: 0
                                showStopIndicator: true
                                activeColor: ServiceSystemUpdates.phase === "error" ? Colors.error : Colors.primary
                                trackColor: Colors.surfaceContainerHighest

                                Behavior on progress {
                                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                CustomText {
                                    Layout.fillWidth: true
                                    visible: ServiceSystemUpdates.errorText !== ""
                                    content: ServiceSystemUpdates.errorText
                                    size: 12
                                    customColor: Colors.error
                                    wrapMode: Text.WordWrap
                                }

                                Item { Layout.fillWidth: true; visible: ServiceSystemUpdates.errorText === "" }

                                M3Button {
                                    size: "xsmall"
                                    variant: "text"
                                    icon: root.showLog ? "expand_less" : "expand_more"
                                    label: root.showLog ? "Hide log" : "Show log"
                                    visible: ServiceSystemUpdates.logLines.length > 0
                                    onClicked: root.showLog = !root.showLog
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.showLog ? 180 : 0
                                visible: Layout.preferredHeight > 1
                                clip: true
                                radius: 12
                                color: Colors.surfaceContainerHighest

                                Behavior on Layout.preferredHeight { SpatialAnim { speed: "fast" } }

                                ListView {
                                    id: logView
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    clip: true
                                    model: ServiceSystemUpdates.logLines
                                    spacing: 1
                                    onCountChanged: positionViewAtEnd()

                                    delegate: CustomText {
                                        required property string modelData
                                        width: logView.width
                                        content: modelData
                                        size: 11
                                        customColor: /^error/i.test(modelData) ? Colors.error : Colors.outline
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: ServiceSystemUpdates.missingKeyId !== ""
                        implicitHeight: keyRow.implicitHeight + 22
                        radius: 16
                        color: Colors.errorContainer

                        RowLayout {
                            id: keyRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12

                            MaterialIconSymbol {
                                content: "key_off"
                                iconSize: 20
                                customColor: Colors.errorContainerText
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                CustomText {
                                    content: "Missing signing key " + ServiceSystemUpdates.missingKeyId
                                    size: 13
                                    weight: 600
                                    customColor: Colors.errorContainerText
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    content: {
                                        const owner = ServiceSystemUpdates.missingKeyOwner
                                        const blocked = ServiceSystemUpdates.blockedPackages
                                        let t = owner !== ""
                                            ? owner + "'s key ships in archlinux-keyring but was never imported into the system keyring."
                                            : "A signing key shipped by archlinux-keyring was never imported into the system keyring."
                                        t += " Usually a stale zero-byte /etc/pacman.d/gnupg/pubring.gpg.lock blocking every keyring write."
                                        if (blocked.length > 0)
                                            t += " Only " + blocked.join(", ") + " needs it — the rest can upgrade now."
                                        return t
                                    }
                                    size: 11
                                    customColor: Colors.errorContainerText
                                    wrapMode: Text.WordWrap
                                }
                            }

                            CustomCircularLoader {
                                size: 18
                                trackWidth: 2
                                highlightColor: Colors.errorContainerText
                                trackColor: Colors.errorContainer
                                visible: ServiceSystemUpdates.repairingKeyring
                            }

                            M3Button {
                                size: "xsmall"
                                variant: "filled"
                                icon: "skip_next"
                                label: "Skip " + (ServiceSystemUpdates.blockedPackages.length === 1
                                                  ? ServiceSystemUpdates.blockedPackages[0]
                                                  : ServiceSystemUpdates.blockedPackages.length + " packages")
                                visible: !ServiceSystemUpdates.repairingKeyring
                                         && ServiceSystemUpdates.blockedPackages.length > 0
                                enabledButton: !ServiceSystemUpdates.busy
                                onClicked: ServiceSystemUpdates.upgradeRepo(ServiceSystemUpdates.blockedPackages)
                            }

                            M3Button {
                                size: "xsmall"
                                variant: "tonal"
                                icon: "healing"
                                label: "Repair keyring"
                                visible: !ServiceSystemUpdates.repairingKeyring
                                enabledButton: !ServiceSystemUpdates.busy
                                onClicked: root.confirmAction = "key"
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        M3Button {
                            size: "small"
                            variant: "filled"
                            icon: "download"
                            label: ServiceSystemUpdates.upgrading ? "Updating…" : "Update " + ServiceSystemUpdates.repoCount + " repo"
                            enabledButton: !ServiceSystemUpdates.busy && ServiceSystemUpdates.repoCount > 0
                            onClicked: root.confirmAction = "repo"
                        }

                        M3Button {
                            size: "small"
                            variant: "tonal"
                            icon: "terminal"
                            label: ServiceSystemUpdates.aurRunning ? "AUR running…" : "Update " + ServiceSystemUpdates.aurCount + " AUR"
                            visible: ServiceSystemUpdates.aurCount > 0
                            enabledButton: !ServiceSystemUpdates.busy
                            onClicked: ServiceSystemUpdates.upgradeAur()
                        }

                        Item { Layout.fillWidth: true }
                    }

                    CustomText {
                        Layout.fillWidth: true
                        visible: ServiceSystemUpdates.upgrading
                        content: "An upgrade cannot be interrupted safely once pacman holds the database lock. Let it finish."
                        size: 11
                        customColor: Colors.outline
                        wrapMode: Text.WordWrap
                    }

                    CustomText {
                        Layout.fillWidth: true
                        visible: ServiceSystemUpdates.aurCount > 0
                        content: "AUR packages build in a terminal window — they need to ask about PGP keys, conflicts and build diffs."
                        size: 11
                        customColor: Colors.outline
                        wrapMode: Text.WordWrap
                    }
                }
            }

            RowLayout {
                Layout.topMargin: 16
                spacing: 10
                CustomText { content: "Arch news"; size: 13; customColor: Colors.primary }
                Item { Layout.fillWidth: true }
                CustomText {
                    visible: ServiceSystemUpdates.lastUpgrade !== ""
                    content: "last upgrade " + ServiceSystemUpdates.lastUpgrade.split("T")[0]
                    size: 11
                    customColor: Colors.outline
                }
            }

            Rectangle {
                Layout.topMargin: 6
                Layout.fillWidth: true
                visible: ServiceSystemUpdates.hasCriticalNews
                implicitHeight: warnRow.implicitHeight + 24
                radius: 20
                color: Colors.errorContainer

                RowLayout {
                    id: warnRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    MaterialIconSymbol {
                        content: "warning"
                        iconSize: 22
                        customColor: Colors.errorContainerText
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        CustomText {
                            content: ServiceSystemUpdates.criticalNews.length +
                                     (ServiceSystemUpdates.criticalNews.length === 1
                                      ? " news post since your last upgrade"
                                      : " news posts since your last upgrade")
                            size: 13
                            weight: 600
                            customColor: Colors.errorContainerText
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: "Read these before upgrading — some require manual intervention."
                            size: 12
                            customColor: Colors.errorContainerText
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            Repeater {
                model: ServiceSystemUpdates.news.slice(0, 5)

                CustomCard {
                    id: newsCard
                    required property var modelData
                    required property int index

                    readonly property bool isNew: ServiceSystemUpdates.lastUpgradeMs > 0
                                                  && newsCard.modelData.ts > ServiceSystemUpdates.lastUpgradeMs

                    Layout.topMargin: newsCard.index === 0 ? 6 : 3
                    Layout.fillWidth: true
                    autoRadius: false
                    topRadius: newsCard.index === 0 ? 20 : 5
                    bottomRadius: newsCard.index === Math.min(4, ServiceSystemUpdates.news.length - 1) ? 20 : 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 4
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: 4
                            color: newsCard.isNew ? Colors.error : Colors.outline
                            opacity: newsCard.isNew ? 1 : 0.45
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            CustomText {
                                Layout.fillWidth: true
                                content: newsCard.modelData.title
                                size: 13
                                weight: newsCard.isNew ? 600 : 400
                                wrapMode: Text.WordWrap
                            }

                            CustomText {
                                content: newsCard.modelData.ts > 0
                                         ? new Date(newsCard.modelData.ts).toLocaleDateString(Qt.locale(), "d MMM yyyy")
                                         : newsCard.modelData.date
                                size: 11
                                customColor: Colors.outline
                            }
                        }

                        Item {
                            implicitWidth: 18
                            implicitHeight: 18

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: "open_in_new"
                                iconSize: 16
                                customColor: openArea.containsMouse ? Colors.primary : Colors.outline
                            }

                            MouseArea {
                                id: openArea
                                anchors.fill: parent
                                anchors.margins: -7
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ServiceSystemUpdates.openNews(newsCard.modelData.link)
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.topMargin: 6
                Layout.fillWidth: true
                visible: ServiceSystemUpdates.news.length === 0
                implicitHeight: 90
                color: Colors.surfaceContainerHigh
                radius: 20

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 46
                        implicitHeight: 46

                        MaterialShapes.ShapeCanvas {
                            anchors.fill: parent
                            roundedPolygon: MaterialShapeFn.getCookie6Sided()
                            color: Colors.surfaceContainerHighest
                        }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "newspaper"
                            iconSize: 22
                            customColor: Colors.outline
                        }
                    }

                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: ServiceSystemUpdates.newsLoading ? "Loading Arch news" : "No news loaded"
                        size: 13
                        customColor: Colors.outline
                    }
                }
            }

            RowLayout {
                Layout.topMargin: 16
                spacing: 10
                CustomText { content: "Pending packages"; size: 13; customColor: Colors.primary }
                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: 200
                    implicitHeight: 32
                    radius: 16
                    color: Colors.surfaceContainerHighest
                    visible: ServiceSystemUpdates.totalCount > 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 6

                        MaterialIconSymbol { content: "search"; iconSize: 15; customColor: Colors.outline }

                        TextField {
                            id: filterField
                            Layout.fillWidth: true
                            background: null
                            placeholderText: "Filter"
                            placeholderTextColor: Colors.outline
                            color: Colors.surfaceText
                            font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter
                            onTextChanged: root.filter = text
                        }

                        Item {
                            implicitWidth: 16
                            implicitHeight: 16
                            visible: root.filter !== ""

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: "close"
                                iconSize: 14
                                customColor: Colors.outline
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -5
                                cursorShape: Qt.PointingHandCursor
                                onClicked: filterField.text = ""
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.topMargin: 6
                Layout.fillWidth: true
                visible: ServiceSystemUpdates.totalCount === 0
                implicitHeight: 90
                color: Colors.surfaceContainerHigh
                radius: 20

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 46
                        implicitHeight: 46

                        MaterialShapes.ShapeCanvas {
                            anchors.fill: parent
                            roundedPolygon: MaterialShapeFn.getCookie6Sided()
                            color: Colors.surfaceContainerHighest
                        }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "task_alt"
                            iconSize: 22
                            customColor: Colors.outline
                        }
                    }

                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: ServiceSystemUpdates.checking ? "Checking" : "No pending packages"
                        size: 13
                        customColor: Colors.outline
                    }
                }
            }

            PackageGroup {
                title: "Repository"
                icon: "package_2"
                entries: root.filteredRepo
                accent: Colors.primary
            }

            PackageGroup {
                title: "AUR"
                icon: "construction"
                entries: root.filteredAur
                accent: Colors.tertiary
            }

            RowLayout {
                Layout.topMargin: 16
                spacing: 10
                CustomText { content: "Maintenance"; size: 13; customColor: Colors.primary }

                CustomText {
                    Layout.fillWidth: true
                    visible: ServiceSystemUpdates.maintResult !== ""
                    content: ServiceSystemUpdates.maintResult
                    size: 11
                    customColor: /fail|dismiss/i.test(ServiceSystemUpdates.maintResult)
                                 ? Colors.error : Colors.outline
                    elide: Text.ElideRight
                }

                Item { Layout.fillWidth: true; visible: ServiceSystemUpdates.maintResult === "" }

                Item {
                    implicitWidth: 16
                    implicitHeight: 16

                    CustomCircularLoader {
                        anchors.centerIn: parent
                        size: 16
                        trackWidth: 2
                        highlightColor: Colors.primary
                        trackColor: Colors.surfaceContainerHigh
                        opacity: ServiceSystemUpdates.maintScanning ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { EffectsAnim { speed: "fast" } }
                    }
                }
            }

            MaintRow {
                Layout.topMargin: 6
                autoRadius: false
                topRadius: 20
                bottomRadius: 5
                title: "Orphaned packages"
                subtitle: ServiceSystemUpdates.orphanCount === 0
                          ? "Nothing left behind"
                          : ServiceSystemUpdates.orphanCount + " unneeded" +
                            (ServiceSystemUpdates.orphanCascade > ServiceSystemUpdates.orphanCount
                             ? " — " + ServiceSystemUpdates.orphanCascade + " removed once dependencies cascade"
                             : "")
                actionLabel: "Remove"
                actionIcon: "delete_sweep"
                actionEnabled: ServiceSystemUpdates.orphanCount > 0
                busy: ServiceSystemUpdates.maintBusy === "orphans"
                badge: String(ServiceSystemUpdates.orphanCount)
                onTriggered: root.confirmAction = "orphans"
            }

            MaintRow {
                autoRadius: false
                topRadius: 5
                bottomRadius: 5
                title: "Package cache"
                subtitle: {
                    const keep = SettingsConfig.updates?.cacheKeep ?? 2
                    const base = ServiceSystemUpdates.cacheFiles + " packages cached"
                    if (ServiceSystemUpdates.prunableCount === 0)
                        return base + " — nothing has more than " + keep +
                               (keep === 1 ? " version, so keeping 1 frees nothing"
                                           : " versions, so keeping " + keep + " frees nothing")
                    return base + " — keeping " + keep + " prunes " +
                           ServiceSystemUpdates.prunableCount + " files, freeing " +
                           ServiceSystemUpdates.prunableSize
                }
                actionLabel: "Clean"
                actionIcon: "cleaning_services"
                actionEnabled: ServiceSystemUpdates.prunableCount > 0
                busy: ServiceSystemUpdates.maintBusy === "cache"
                badge: ServiceSystemUpdates.formatBytes(ServiceSystemUpdates.cacheBytes)
                onTriggered: root.confirmAction = "cache"
            }

            MaintRow {
                autoRadius: false
                topRadius: 5
                bottomRadius: 5
                title: "Cached packages no longer installed"
                subtitle: ServiceSystemUpdates.uninstalledCount === 0
                          ? "Nothing stale in the cache"
                          : "Removing them frees " + ServiceSystemUpdates.uninstalledSize
                actionLabel: "Remove"
                actionIcon: "delete_outline"
                actionEnabled: ServiceSystemUpdates.uninstalledCount > 0
                busy: ServiceSystemUpdates.maintBusy === "uninstalled"
                badge: String(ServiceSystemUpdates.uninstalledCount)
                onTriggered: root.confirmAction = "uninstalled"
            }

            MaintRow {
                autoRadius: false
                topRadius: 5
                bottomRadius: 20
                title: "Config files to merge"
                subtitle: ServiceSystemUpdates.pacnewCount === 0
                          ? "No .pacnew or .pacsave files"
                          : "Opens pacdiff in a terminal"
                actionLabel: "Review"
                actionIcon: "difference"
                actionEnabled: ServiceSystemUpdates.pacnewCount > 0
                badge: String(ServiceSystemUpdates.pacnewCount)
                onTriggered: ServiceSystemUpdates.openPacdiff()
            }

            Loader {
                Layout.fillWidth: true
                active: ServiceSystemUpdates.pacnewCount > 0
                visible: active

                sourceComponent: ColumnLayout {
                    spacing: 3

                    Repeater {
                        model: ServiceSystemUpdates.pacnewFiles.slice(0, 8)

                        CustomText {
                            required property string modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.topMargin: 4
                            content: modelData
                            size: 11
                            customColor: Colors.outline
                            elide: Text.ElideMiddle
                        }
                    }

                    CustomText {
                        visible: ServiceSystemUpdates.pacnewCount > 8
                        Layout.leftMargin: 14
                        Layout.topMargin: 2
                        content: "+ " + (ServiceSystemUpdates.pacnewCount - 8) + " more"
                        size: 11
                        customColor: Colors.outline
                    }
                }
            }

            CustomText { Layout.topMargin: 16; content: "Behaviour"; size: 13; customColor: Colors.primary }

            CustomCard {
                Layout.topMargin: 6
                Layout.fillWidth: true
                autoRadius: false
                topRadius: 20
                bottomRadius: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    ColumnLayout {
                        spacing: 2
                        CustomText { content: "Check automatically"; size: 14 }
                        CustomText { content: "Runs checkupdates in the background"; size: 12; customColor: Colors.outline }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: 6
                        opacity: (SettingsConfig.updates?.autoCheck ?? true) ? 1 : 0.4

                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            inc: 1
                            limit: 48
                            enabled: SettingsConfig.updates?.autoCheck ?? true
                            Component.onCompleted: val = SettingsConfig.updates?.checkIntervalHours ?? 3
                            onValChanged: if (val > 0) root.patch("checkIntervalHours", val)
                        }

                        CustomText { content: "h"; size: 12; customColor: Colors.outline }
                    }

                    CustomToogle {
                        isToggleOn: SettingsConfig.updates?.autoCheck ?? true
                        onToggled: function(state) { root.patch("autoCheck", state) }
                    }
                }
            }

            CustomCard {
                Layout.topMargin: 3
                Layout.fillWidth: true
                autoRadius: false
                topRadius: 5
                bottomRadius: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    ColumnLayout {
                        spacing: 2
                        CustomText { content: "Notify at startup"; size: 14 }
                        CustomText { content: "One notification per boot when updates are waiting"; size: 12; customColor: Colors.outline }
                    }

                    Item { Layout.fillWidth: true }

                    CustomToogle {
                        isToggleOn: SettingsConfig.updates?.notifyOnStart ?? true
                        onToggled: function(state) { root.patch("notifyOnStart", state) }
                    }
                }
            }

            CustomCard {
                Layout.topMargin: 3
                Layout.fillWidth: true
                autoRadius: false
                topRadius: 5
                bottomRadius: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    ColumnLayout {
                        spacing: 2
                        CustomText { content: "Include AUR"; size: 14 }
                        CustomText {
                            content: ServiceSystemUpdates.aurHelper === ""
                                     ? "No yay or paru found"
                                     : "Checked with " + ServiceSystemUpdates.aurHelper
                            size: 12
                            customColor: Colors.outline
                        }
                    }

                    Item { Layout.fillWidth: true }

                    CustomToogle {
                        isToggleOn: SettingsConfig.updates?.includeAur ?? true
                        onToggled: function(state) { root.patch("includeAur", state) }
                    }
                }
            }

            CustomCard {
                Layout.topMargin: 3
                Layout.fillWidth: true
                autoRadius: false
                topRadius: 5
                bottomRadius: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    ColumnLayout {
                        spacing: 2
                        CustomText { content: "Show pill in bar"; size: 14 }
                        CustomText { content: "Count badge, and live progress while updating"; size: 12; customColor: Colors.outline }
                    }

                    Item { Layout.fillWidth: true }

                    CustomToogle {
                        isToggleOn: SettingsConfig.updates?.showBarPill ?? true
                        onToggled: function(state) { root.patch("showBarPill", state) }
                    }
                }
            }

            CustomCard {
                Layout.topMargin: 3
                Layout.fillWidth: true
                autoRadius: false
                topRadius: 5
                bottomRadius: 20

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    ColumnLayout {
                        spacing: 2
                        CustomText { content: "Cache versions to keep"; size: 14 }
                        CustomText { content: "Used by the cache clean action"; size: 12; customColor: Colors.outline }
                    }

                    Item { Layout.fillWidth: true }

                    CustomSpinBox {
                        color: Colors.surfaceContainerHighest
                        inc: 1
                        limit: 10
                        Component.onCompleted: val = SettingsConfig.updates?.cacheKeep ?? 2
                        onValChanged: root.patch("cacheKeep", val)
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }

    ScrollFade {
        anchors.fill: parent
        flickable: pageFlick
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Colors.surface, 0.72)
        visible: root.confirmAction !== ""

        MouseArea {
            anchors.fill: parent
            onClicked: root.confirmAction = ""
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 60, 420)
            implicitHeight: confirmCol.implicitHeight + 40
            radius: 28
            color: Colors.surfaceContainerHigh

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: confirmCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 10

                MaterialIconSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    content: root.confirmAction === "repo" ? "download"
                           : root.confirmAction === "orphans" ? "delete_sweep"
                           : root.confirmAction === "key" ? "vpn_key"
                           : root.confirmAction === "uninstalled" ? "delete_outline"
                           : "cleaning_services"
                    iconSize: 26
                    customColor: Colors.primary
                }

                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: root.confirmAction === "repo" ? "Upgrade the system?"
                           : root.confirmAction === "orphans" ? "Remove orphaned packages?"
                           : root.confirmAction === "key" ? "Repair the pacman keyring?"
                           : root.confirmAction === "uninstalled" ? "Remove stale cached packages?"
                           : "Clean the package cache?"
                    size: 17
                    weight: 600
                }

                CustomText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    content: {
                        if (root.confirmAction === "repo")
                            return "pacman -Syu will install " + ServiceSystemUpdates.repoCount +
                                   " updates" +
                                   (ServiceSystemUpdates.downloadBytes > 0
                                    ? " and download " + ServiceSystemUpdates.formatBytes(ServiceSystemUpdates.downloadBytes)
                                    : "") +
                                   ". Do not power off while it runs."
                        if (root.confirmAction === "orphans") {
                            const casc = ServiceSystemUpdates.orphanCascade
                            const extra = casc > ServiceSystemUpdates.orphanCount
                                ? " pacman -Rns also drops their now-unneeded dependencies, so " + casc + " packages go in total."
                                : ""
                            return ServiceSystemUpdates.orphanCount + " packages are unneeded." + extra +
                                   " Check the list first if any were installed deliberately."
                        }
                        if (root.confirmAction === "key")
                            return "Removes /etc/pacman.d/gnupg/pubring.gpg.lock only if it is zero bytes (a valid lock holds a PID), " +
                                   "then runs pacman-key --populate archlinux and --updatedb. " +
                                   "Only keys shipped by the archlinux-keyring package are imported — nothing is fetched from a keyserver."
                        if (root.confirmAction === "uninstalled")
                            return "paccache -ruk0 deletes cached packages that are no longer installed (" +
                                   ServiceSystemUpdates.uninstalledCount + " files, " +
                                   ServiceSystemUpdates.uninstalledSize +
                                   "). You lose the ability to reinstall those exact versions offline."
                        return "paccache keeps the newest " + (SettingsConfig.updates?.cacheKeep ?? 2) +
                               " version of each package and deletes the rest. Currently " +
                               ServiceSystemUpdates.formatBytes(ServiceSystemUpdates.cacheBytes) + "."
                    }
                    size: 13
                    customColor: Colors.outline
                    wrapMode: Text.WordWrap
                }

                CustomText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.confirmAction === "repo" && ServiceSystemUpdates.hasCriticalNews
                    content: "There are " + ServiceSystemUpdates.criticalNews.length +
                             " Arch news posts since your last upgrade."
                    size: 12
                    customColor: Colors.error
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.topMargin: 6
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10

                    M3Button {
                        size: "small"
                        variant: "text"
                        label: "Cancel"
                        onClicked: root.confirmAction = ""
                    }

                    M3Button {
                        size: "small"
                        variant: "filled"
                        label: root.confirmAction === "repo" ? "Upgrade"
                             : root.confirmAction === "orphans" ? "Remove"
                             : root.confirmAction === "key" ? "Repair"
                             : root.confirmAction === "uninstalled" ? "Remove"
                             : "Clean"
                        onClicked: {
                            const action = root.confirmAction
                            root.confirmAction = ""
                            if (action === "repo") ServiceSystemUpdates.upgradeRepo([])
                            else if (action === "key") ServiceSystemUpdates.repairKeyring()
                            else if (action === "orphans") ServiceSystemUpdates.removeOrphans()
                            else if (action === "cache") ServiceSystemUpdates.cleanCache()
                            else if (action === "uninstalled") ServiceSystemUpdates.cleanUninstalled()
                        }
                    }
                }
            }
        }
    }

    component MaintRow: CustomCard {
        id: maint
        property string title: ""
        property string subtitle: ""
        property string actionLabel: ""
        property string actionIcon: ""
        property string badge: ""
        property bool actionEnabled: true
        property bool busy: false
        signal triggered

        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    spacing: 8

                    CustomText { content: maint.title; size: 14 }

                    Rectangle {
                        visible: maint.badge !== ""
                        implicitWidth: badgeText.implicitWidth + 14
                        implicitHeight: 20
                        radius: 10
                        color: maint.actionEnabled ? Colors.secondaryContainer : Colors.surfaceContainerHighest

                        CustomText {
                            id: badgeText
                            anchors.centerIn: parent
                            content: maint.badge
                            size: 11
                            weight: 600
                            customColor: maint.actionEnabled ? Colors.secondaryContainerText : Colors.outline
                        }
                    }
                }

                CustomText {
                    Layout.fillWidth: true
                    content: maint.subtitle
                    size: 12
                    customColor: Colors.outline
                    wrapMode: Text.WordWrap
                }
            }

            CustomCircularLoader {
                size: 18
                trackWidth: 2
                highlightColor: Colors.primary
                trackColor: Colors.surfaceContainerHighest
                visible: maint.busy
            }

            M3Button {
                size: "xsmall"
                variant: "tonal"
                icon: maint.actionIcon
                label: maint.actionLabel
                visible: !maint.busy
                enabledButton: maint.actionEnabled && !ServiceSystemUpdates.busy
                                && ServiceSystemUpdates.maintBusy === ""
                onClicked: maint.triggered()
            }
        }
    }

    component PackageGroup: ColumnLayout {
        id: group
        property string title: ""
        property string icon: ""
        property var entries: []
        property string accent: Colors.primary
        property bool expanded: false

        readonly property int cap: group.expanded ? 400 : 25
        readonly property int hidden: Math.max(0, group.entries.length - group.cap)
        readonly property var visibleEntries: group.entries.slice(0, group.cap)

        Layout.fillWidth: true
        spacing: 0
        visible: group.entries.length > 0

        RowLayout {
            Layout.topMargin: 12
            Layout.leftMargin: 4
            Layout.fillWidth: true
            spacing: 8

            MaterialIconSymbol { content: group.icon; iconSize: 15; customColor: group.accent }
            CustomText { content: group.title; size: 12; weight: 600; customColor: group.accent }
            CustomText {
                content: group.entries.length + (root.filter !== "" ? " matching" : "")
                size: 11
                customColor: Colors.outline
            }

            Item { Layout.fillWidth: true }

            M3Button {
                size: "xsmall"
                variant: "text"
                visible: group.hidden > 0 || group.expanded
                icon: group.expanded ? "expand_less" : "expand_more"
                label: group.expanded ? "Show less" : "Show all " + group.entries.length
                onClicked: group.expanded = !group.expanded
            }
        }

        Repeater {
            model: group.visibleEntries

            CustomCard {
                id: pkgCard
                required property var modelData
                required property int index

                Layout.topMargin: pkgCard.index === 0 ? 6 : 3
                Layout.fillWidth: true
                autoRadius: false
                topRadius: pkgCard.index === 0 ? 20 : 5
                bottomRadius: pkgCard.index === group.visibleEntries.length - 1 ? 20 : 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    CustomText {
                        Layout.fillWidth: true
                        content: pkgCard.modelData.name
                        size: 13
                        weight: 500
                        elide: Text.ElideRight
                    }

                    CustomText {
                        content: pkgCard.modelData.oldVersion
                        size: 11
                        customColor: Colors.outline
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: 150
                    }

                    MaterialIconSymbol {
                        content: "arrow_right_alt"
                        iconSize: 15
                        customColor: Colors.outline
                    }

                    CustomText {
                        content: pkgCard.modelData.newVersion
                        size: 11
                        weight: 500
                        customColor: group.accent
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: 150
                    }
                }
            }
        }
    }
}
