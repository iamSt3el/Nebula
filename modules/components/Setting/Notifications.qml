import Quickshell
import QtQuick
import QtQuick.Layouts
import Qt.labs.platform
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.Bar
import QtQuick.Controls

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    readonly property bool popupsOn: SettingsConfig.notifications?.showBanners ?? true
    readonly property bool popupItemPlaced: BarLayout.baseId(BarLayout.popupHostItem) === "popups"
    readonly property string popupWhere: {
        const mode = BarLayout.popupMode
        const host = BarLayout.popupHostItem
        if (mode === "item") {
            const b = BarLayout.allBlocks.find(x => x.items.indexOf(host) >= 0)
            const where = b && b.edge === "bottom" ? "the dock" : "the bar"
            return root.popupItemPlaced ? "The Popups item on " + where : "The bell on " + where
        }
        if (mode === "icon")
            return "Dock icons"
        return "The screen corner"
    }
    readonly property string popupIcon: root.popupItemPlaced ? "notifications_active"
        : BarLayout.popupMode === "item" ? "notifications"
        : BarLayout.popupMode === "icon" ? "chat_bubble" : "bottom_right_click"

    FileDialog {
        id: notifSoundPicker
        title: "Select a notification sound file"
        nameFilters: ["WAV files (*.wav)"]
        onAccepted: {
            const path = notifSoundPicker.file.toString().replace(/^file:\/\//, "")
            SettingsConfig.notifications = Object.assign({}, SettingsConfig.notifications, { soundPath: path })
            GlobalStates.fileDialogOpen = false
        }
        onRejected: GlobalStates.fileDialogOpen = false
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
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            anchors.topMargin: 5
            spacing: 0

            // ── Page header ──────────────────────────────────────────────
            // ── Focus ────────────────────────────────────────────────────
            CustomText { Layout.topMargin: 24; content: "Focus"; size: 13; customColor: Colors.primary }

            CustomCard {
                Layout.topMargin: 6
                autoRadius: false; topRadius: 20; bottomRadius: 20

                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        spacing: 2
                        CustomText { content: "Do Not Disturb"; size: 14 }
                        CustomText { content: "Suppress all notification popups"; size: 12; customColor: Colors.outline }
                    }
                    Item { Layout.fillWidth: true }
                    CustomToogle {
                        isToggleOn: SettingsConfig.notifications?.doNotDisturb ?? false
                        onToggled: function(state) {
                            SettingsConfig.notifications = Object.assign({}, SettingsConfig.notifications, { doNotDisturb: state })
                        }
                    }
                }
            }

            // ── Popups ───────────────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Popups"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            CustomText { content: "Show Popups"; size: 14 }
                            CustomText { content: "Show new notifications as popups. They always land in the notification center too"; size: 12; customColor: Colors.outline; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                        CustomToogle {
                            isToggleOn: SettingsConfig.notifications?.showBanners ?? true
                            onToggled: function(state) {
                                SettingsConfig.notifications = Object.assign({}, SettingsConfig.notifications, { showBanners: state })
                            }
                        }
                    }
                }
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    visible: root.popupsOn
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                radius: 14
                                color: Colors.secondaryContainer

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: root.popupIcon
                                    iconSize: 20
                                    customColor: Colors.secondaryContainerText
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                CustomText { content: "Popups open from"; size: 12; customColor: Colors.outline }
                                CustomText { content: root.popupWhere; size: 14; weight: 600; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            }

                            M3Button {
                                icon: "edit"
                                label: root.popupItemPlaced ? "Move it" : "Place it"
                                onClicked: {
                                    GlobalStates.settingsOpen = false
                                    GlobalStates.openEdit("edges")
                                }
                            }
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: root.popupItemPlaced
                                ? "Popups grow out of the block holding the Popups item, floating or merged like that block's panels."
                                : "In edit mode, add the Popups item to any bar or dock block and popups will open from it. Until then:"
                            size: 12
                            customColor: Colors.outline
                            wrapMode: Text.WordWrap
                        }

                        M3ButtonGroup {
                            visible: !root.popupItemPlaced
                            model: [
                                { value: "item", label: "From the bell", icon: "notifications" },
                                { value: "icon", label: "Dock icons",    icon: "chat_bubble" }
                            ]
                            activeCheck: function(value) { return ((SettingsConfig.general?.notifPopupStyle ?? "item") === "icon" ? "icon" : "item") === value }
                            onSegmentClicked: function(value) {
                                SettingsConfig.general = Object.assign({}, SettingsConfig.general, { notifPopupStyle: value })
                            }
                        }
                    }
                }
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    visible: root.popupsOn
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            CustomText { content: "Popup Timeout"; size: 14 }
                            CustomText { content: "Seconds a popup stays before it leaves. Hovering pauses it"; size: 12; customColor: Colors.outline; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            inc: 1
                            limit: 30
                            min: 1
                            value: SettingsConfig.notifications?.popupTimeout ?? 5
                            onValChanged: {
                                if (val !== value)
                                    SettingsConfig.notifications = Object.assign({}, SettingsConfig.notifications, { popupTimeout: val })
                            }
                        }
                    }
                }
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    visible: root.popupsOn
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            CustomText { content: "Cards at Once"; size: 14 }
                            CustomText { content: "How many popup cards show together. The rest wait behind a +N more row"; size: 12; customColor: Colors.outline; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                        CustomSpinBox {
                            color: Colors.surfaceContainerHighest
                            inc: 1
                            limit: 5
                            min: 1
                            value: SettingsConfig.notifications?.maxVisible ?? 3
                            onValChanged: {
                                if (val !== value)
                                    SettingsConfig.notifications = Object.assign({}, SettingsConfig.notifications, { maxVisible: val })
                            }
                        }
                    }
                }
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    visible: root.popupsOn
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            CustomText { content: "Group by App"; size: 14 }
                            CustomText { content: "Several popups from one app share a single card with a count"; size: 12; customColor: Colors.outline; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                        CustomToogle {
                            isToggleOn: SettingsConfig.notifications?.groupPopups ?? true
                            onToggled: function(state) {
                                SettingsConfig.notifications = Object.assign({}, SettingsConfig.notifications, { groupPopups: state })
                            }
                        }
                    }
                }
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 5
                    visible: root.popupsOn
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            CustomText { content: "Keep Urgent Until Dismissed"; size: 14 }
                            CustomText { content: "Urgent notifications, like low battery, stay until you close them"; size: 12; customColor: Colors.outline; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                        CustomToogle {
                            isToggleOn: SettingsConfig.notifications?.urgentSticky ?? true
                            onToggled: function(state) {
                                SettingsConfig.notifications = Object.assign({}, SettingsConfig.notifications, { urgentSticky: state })
                            }
                        }
                    }
                }
                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Edge Light"; size: 14 }
                            CustomText { content: "Light sweeps around the screen edge in the app's colour. Important = urgent notifications and the apps listed below"; size: 12; customColor: Colors.outline; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                        M3ButtonGroup {
                            model: [
                                { value: "off",       label: "Off",       icon: "block" },
                                { value: "important", label: "Important", icon: "priority_high" },
                                { value: "all",       label: "All",       icon: "light_mode" }
                            ]
                            activeCheck: function(value) { return (SettingsConfig.notifications?.edgeLight ?? "important") === value }
                            onSegmentClicked: function(value) {
                                SettingsConfig.notifications = Object.assign({}, SettingsConfig.notifications, { edgeLight: value })
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 10
                            color: Colors.surfaceContainerHighest
                            visible: (SettingsConfig.notifications?.edgeLight ?? "important") === "important"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10
                                spacing: 6

                                MaterialIconSymbol { content: "apps"; iconSize: 16; customColor: Colors.outline }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    TextInput {
                                        id: edgeApps
                                        anchors.fill: parent
                                        text: Array.from(SettingsConfig.notifications?.edgeLightApps ?? []).join(", ")
                                        color: Colors.inverseSurface
                                        font.pixelSize: 13
                                        clip: true
                                        verticalAlignment: TextInput.AlignVCenter
                                        onEditingFinished: {
                                            const list = text.split(",").map(x => x.trim()).filter(x => x.length > 0)
                                            SettingsConfig.notifications = Object.assign({}, SettingsConfig.notifications, { edgeLightApps: list })
                                        }
                                    }

                                    CustomText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: edgeApps.text.length === 0 && !edgeApps.activeFocus
                                        content: "Apps that count as important, e.g. discord, telegram"
                                        size: 12
                                        customColor: Colors.outline
                                    }
                                }
                            }
                        }
                    }
                }

            }

            // ── Notification Center ──────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Notification Center"; size: 13; customColor: Colors.primary }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 3

                CustomCard {
                    autoRadius: false; topRadius: 20; bottomRadius: 5
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Show in Center"; size: 14 }
                            CustomText { content: "Store notifications in the notification center"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.notifications?.showInCenter ?? true
                            onToggled: function(state) {
                                SettingsConfig.notifications = Object.assign({}, SettingsConfig.notifications, { showInCenter: state })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5
                    bottomRadius: (SettingsConfig.notifications?.playSound ?? false) ? 5 : 20
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Play Sound"; size: 14 }
                            CustomText { content: "Play a sound when a notification arrives"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        CustomToogle {
                            isToggleOn: SettingsConfig.notifications?.playSound ?? false
                            onToggled: function(state) {
                                SettingsConfig.notifications = Object.assign({}, SettingsConfig.notifications, { playSound: state })
                            }
                        }
                    }
                }

                CustomCard {
                    autoRadius: false; topRadius: 5; bottomRadius: 20
                    visible: SettingsConfig.notifications?.playSound ?? false
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            CustomText { content: "Sound File"; size: 14 }
                            CustomText { content: "WAV file only (uncompressed PCM)"; size: 12; customColor: Colors.outline }
                        }
                        Item { Layout.fillWidth: true }
                        RowLayout {
                            spacing: 4
                            Rectangle {
                                implicitHeight: 32; implicitWidth: 180
                                topLeftRadius: 16; bottomLeftRadius: 16
                                topRightRadius: 6;  bottomRightRadius: 6
                                color: Colors.surfaceContainerHighest
                                clip: true
                                CustomText {
                                    anchors.left: parent.left; anchors.leftMargin: 12
                                    anchors.right: parent.right; anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    content: (SettingsConfig.notifications?.soundPath ?? "") === ""
                                             ? "No file selected"
                                             : SettingsConfig.notifications.soundPath.split("/").pop()
                                    size: 11
                                    customColor: (SettingsConfig.notifications?.soundPath ?? "") === "" ? Colors.outline : Colors.surfaceText
                                    elide: Text.ElideLeft
                                }
                            }
                            M3IconButton {
                                implicitHeight: 32; implicitWidth: 40
                                topLeftRadius: 6;   bottomLeftRadius: 6
                                topRightRadius: 16; bottomRightRadius: 16
                                icon: "audio_file"; iconSize: 18
                                onClicked: {
                                    GlobalStates.fileDialogOpen = true
                                    notifSoundPicker.open()
                                }
                            }
                        }
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
}
