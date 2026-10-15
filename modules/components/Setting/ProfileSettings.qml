import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.platform
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Bar
import qs.modules.components.LockScreen

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    readonly property string loginName: Quickshell.env("USER") || "user"
    readonly property string shownName: SettingsConfig.profileName || root.loginName
    readonly property string avatar: SettingsConfig.general.profile ?? ""
    readonly property string greetingStyle: SettingsConfig.general.greetingStyle ?? "time"
    readonly property bool lockAvatar: (SettingsConfig.lockscreen ?? ({})).showAvatar ?? true
    readonly property bool greeterAvatar: (SettingsConfig.lockscreen ?? ({})).greeterAvatar ?? true
    readonly property string displayFamily: SettingsConfig.general.displayFont ?? "Titan One"

    readonly property bool focusing: ServiceFocus.phase === "focus" || ServiceFocus.phase === "break"
    readonly property string mode: root.focusing ? "focus" : ServiceNotification.dnd ? "quiet" : "available"

    readonly property var modes: [
        { value: "available", label: "Available", icon: "check_circle", hint: "Everything works as usual", tone: Colors.primary },
        { value: "focus", label: "Focus", icon: "timer", hint: "Starts a focus session", tone: Colors.tertiary },
        { value: "quiet", label: "Quiet", icon: "do_not_disturb_on", hint: "Turns on Do not disturb", tone: Colors.error }
    ]
    readonly property var currentMode: root.modes.find(m => m.value === root.mode) ?? root.modes[0]

    readonly property var logoIds: {
        const out = []
        for (const b of BarLayout.allBlocks)
            for (const id of b.items)
                if (BarLayout.baseId(id) === "logo")
                    out.push(id)
        return out
    }
    readonly property bool barAvatar: root.logoIds.length > 0
        && root.logoIds.every(id => (BarLayout.opt(id, "look") ?? "chip") === "avatar")
    readonly property int profileWidgets: {
        const w = SettingsConfig.widgets ?? ({})
        return ["showProfileBadge", "showProfileDay", "showProfileStatus", "showProfileMachine",
                "showProfileShape", "showProfileRings"].filter(k => w[k] === true).length
    }

    function setGeneral(patch) {
        SettingsConfig.general = Object.assign({}, SettingsConfig.general, patch)
    }

    function setLock(patch) {
        SettingsConfig.lockscreen = Object.assign({}, SettingsConfig.lockscreen ?? ({}), patch)
    }

    function setMode(m) {
        if (m === "focus") {
            if (!root.focusing)
                ServiceFocus.startFocus()
            return
        }
        if (root.focusing)
            ServiceFocus.stop()
        ServiceNotification.setDnd(m === "quiet")
    }

    function setBarAvatar(on) {
        for (const id of root.logoIds)
            BarLayout.setOption(id, "look", on ? "avatar" : "chip")
    }

    function pickPhoto() {
        GlobalStates.fileDialogOpen = true
        imagePicker.open()
    }

    FileDialog {
        id: imagePicker
        title: "Select a profile image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp *.gif)"]
        onAccepted: {
            root.setGeneral({ profile: imagePicker.file.toString().replace(/^file:\/\//, "") })
            GlobalStates.fileDialogOpen = false
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }

    Flickable {
        id: pageFlick
        ScrollBar.vertical: CustomScrollBar {}
        anchors.fill: parent
        contentHeight: column.implicitHeight + 24
        contentWidth: width
        clip: true

        ColumnLayout {
            id: column
            width: parent.width
            spacing: 0

            CustomText { Layout.topMargin: 24; content: "Identity"; size: 13; customColor: Colors.primary }

            Item {
                id: hero
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.preferredHeight: 264

                readonly property real buttonsWidth: heroButtons.implicitWidth + 36
                readonly property real textLeft: 28 + 150 + 28
                readonly property real fieldWidth: Math.max(220, Math.min(440, hero.width - hero.textLeft - hero.buttonsWidth))

                Rectangle {
                    anchors.fill: parent
                    radius: 26
                    color: Colors.surfaceContainerLowest
                }

                RoundedImage {
                    anchors.fill: parent
                    radius: 26
                    source: WallpaperTheme.wallpaperScreen
                    sourceSize: Qt.size(1280, 720)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 26
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.alpha(Colors.surface, 0.92) }
                        GradientStop { position: 0.48; color: Qt.alpha(Colors.surface, 0.72) }
                        GradientStop { position: 1; color: Qt.alpha(Colors.surface, 0.15) }
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 18
                    implicitWidth: statusRow.implicitWidth + 24
                    implicitHeight: 32
                    radius: 16
                    color: Qt.alpha(Colors.surface, 0.72)

                    RowLayout {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 8
                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: root.currentMode.tone
                            Behavior on color { EffectsColorAnim {} }
                        }
                        CustomText { content: root.currentMode.label; size: 12; weight: 500 }
                    }
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.leftMargin: 28
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 28

                    Item {
                        Layout.preferredWidth: 150
                        Layout.preferredHeight: 150

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -6
                            radius: width / 2
                            color: Colors.primary
                        }

                        LockShapeImage {
                            anchors.fill: parent
                            source: root.avatar
                            shapeName: "circle"
                            sourceSize: 320
                        }
                    }

                    ColumnLayout {
                        spacing: 6

                        CustomText {
                            content: "Lock screen greeting"
                            size: 12
                            weight: 500
                            font.letterSpacing: 1.2
                            font.capitalization: Font.AllUppercase
                            customColor: Colors.primary
                        }

                        CustomText {
                            Layout.maximumWidth: hero.width - hero.textLeft - 28
                            content: LockSession.greeting + ", " + root.shownName
                            family: root.displayFamily
                            renderType: Text.QtRendering
                            size: 34
                            weight: 400
                            elide: Text.ElideRight
                        }

                        CustomText {
                            Layout.topMargin: 10
                            content: "Display name"
                            size: 12
                            customColor: Colors.surfaceVariantText
                        }

                        Rectangle {
                            Layout.preferredWidth: hero.fieldWidth
                            Layout.preferredHeight: 40
                            radius: 12
                            color: Qt.alpha(Colors.surface, 0.6)
                            border.width: nameInput.activeFocus ? 2 : 1
                            border.color: nameInput.activeFocus ? Colors.primary : Qt.alpha(Colors.surfaceVariantText, 0.28)

                            TextInput {
                                id: nameInput
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                verticalAlignment: TextInput.AlignVCenter
                                text: SettingsConfig.general.displayName ?? ""
                                color: Colors.surfaceText
                                selectionColor: Colors.primary
                                selectedTextColor: Colors.primaryText
                                font.pixelSize: 15
                                font.weight: 500
                                font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                                maximumLength: 32
                                selectByMouse: true
                                clip: true
                                onEditingFinished: {
                                    const n = text.trim()
                                    if (n !== (SettingsConfig.general.displayName ?? ""))
                                        root.setGeneral({ displayName: n })
                                }
                                onAccepted: focus = false
                                Keys.onEscapePressed: { text = SettingsConfig.general.displayName ?? ""; focus = false }

                                CustomText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: nameInput.text === ""
                                    content: root.loginName
                                    size: 15
                                    weight: 500
                                    customColor: Colors.outline
                                }
                            }
                        }

                        CustomText {
                            Layout.preferredWidth: hero.fieldWidth
                            content: "Shown in the shell and on the lock screen. Empty uses your login name, " + root.loginName + "."
                            size: 12
                            customColor: Colors.surfaceVariantText
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                RowLayout {
                    id: heroButtons
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 18
                    spacing: 8

                    M3Button {
                        visible: root.avatar !== ""
                        variant: "tonal"
                        label: "Remove"
                        onClicked: root.setGeneral({ profile: "" })
                    }

                    M3Button {
                        icon: "add_photo_alternate"
                        label: root.avatar !== "" ? "Change photo" : "Add photo"
                        onClicked: root.pickPhoto()
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 16
                columns: column.width >= 720 ? 2 : 1
                columnSpacing: 10
                rowSpacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    spacing: 6

                    CustomText { content: "Greeting"; size: 13; customColor: Colors.primary }

                    CustomCard {
                        autoRadius: false; topRadius: 22; bottomRadius: 22
                        Layout.fillHeight: true

                        CustomText {
                            Layout.fillWidth: true
                            content: "How the lock and login screens say hello"
                            size: 12
                            customColor: Colors.outline
                        }

                        M3ButtonGroup {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            fillWidth: true
                            textSize: 13
                            iconSize: 17
                            model: [
                                { value: "time", label: "Time of day", icon: "schedule" },
                                { value: "hello", label: "Hello", icon: "waving_hand" },
                                { value: "custom", label: "Custom", icon: "edit" }
                            ]
                            activeCheck: value => value === root.greetingStyle
                            onSegmentClicked: value => root.setGeneral({ greetingStyle: value })
                        }

                        CustomText {
                            Layout.fillWidth: true
                            visible: root.greetingStyle !== "custom"
                            content: root.greetingStyle === "time"
                                ? "Changes with the clock: Good morning, Good afternoon, Good evening."
                                : "Always says Hello, followed by your name."
                            size: 13
                            customColor: Colors.surfaceVariantText
                            wrapMode: Text.WordWrap
                            lineHeight: 1.2
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.greetingStyle === "custom"
                            spacing: 6

                            CustomText { content: "Your greeting"; size: 12; customColor: Colors.surfaceVariantText }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                radius: 12
                                color: Colors.surfaceContainerHighest
                                border.width: greetInput.activeFocus ? 2 : 0
                                border.color: Colors.primary

                                TextInput {
                                    id: greetInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: SettingsConfig.general.greetingText ?? ""
                                    color: Colors.surfaceText
                                    selectionColor: Colors.primary
                                    selectedTextColor: Colors.primaryText
                                    font.pixelSize: 14
                                    font.weight: 500
                                    font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                                    maximumLength: 32
                                    selectByMouse: true
                                    clip: true
                                    onEditingFinished: {
                                        const t = text.trim()
                                        if (t !== (SettingsConfig.general.greetingText ?? ""))
                                            root.setGeneral({ greetingText: t })
                                    }
                                    onAccepted: focus = false

                                    CustomText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: greetInput.text === ""
                                        content: "Welcome back"
                                        size: 14
                                        weight: 500
                                        customColor: Colors.outline
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    spacing: 6

                    CustomText { content: "Status"; size: 13; customColor: Colors.primary }

                    CustomCard {
                        autoRadius: false; topRadius: 22; bottomRadius: 22
                        Layout.fillHeight: true

                        Repeater {
                            model: root.modes

                            delegate: Rectangle {
                                id: opt
                                required property var modelData
                                readonly property bool selected: root.mode === opt.modelData.value

                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                Layout.topMargin: -6
                                radius: 16
                                color: opt.selected ? Colors.primary
                                     : optMouse.containsMouse ? Colors.surfaceContainerHighest : Qt.alpha(Colors.surfaceContainerHighest, 0)
                                Behavior on color { EffectsColorAnim {} }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 14

                                    MaterialIconSymbol {
                                        content: opt.modelData.icon
                                        iconSize: 22
                                        fill: opt.selected ? 1 : 0
                                        customColor: opt.selected ? Colors.primaryText : Colors.surfaceVariantText
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        CustomText {
                                            content: opt.modelData.label
                                            size: 14
                                            weight: 500
                                            customColor: opt.selected ? Colors.primaryText : Colors.surfaceText
                                        }
                                        CustomText {
                                            Layout.fillWidth: true
                                            content: opt.modelData.hint
                                            size: 12
                                            customColor: opt.selected ? Qt.alpha(Colors.primaryText, 0.78) : Colors.outline
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MaterialIconSymbol {
                                        content: opt.selected ? "radio_button_checked" : "radio_button_unchecked"
                                        iconSize: 20
                                        customColor: opt.selected ? Colors.primaryText : Colors.outline
                                    }
                                }

                                MouseArea {
                                    id: optMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setMode(opt.modelData.value)
                                }
                            }
                        }
                    }
                }
            }

            CustomText { Layout.topMargin: 16; content: "Show my photo on"; size: 13; customColor: Colors.primary }

            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                columns: column.width >= 720 ? 4 : 2
                columnSpacing: 10
                rowSpacing: 10

                ProfilePlaceTile {
                    Layout.preferredWidth: 1
                    icon: "lock"
                    title: "Lock screen"
                    hint: "Next to the clock, in the layouts that have one"
                    checked: root.lockAvatar
                    onToggled: state => root.setLock({ showAvatar: state })
                }

                ProfilePlaceTile {
                    Layout.preferredWidth: 1
                    icon: "login"
                    title: "Login screen"
                    hint: "Above the password field before you sign in"
                    checked: root.greeterAvatar
                    onToggled: state => root.setLock({ greeterAvatar: state })
                }

                ProfilePlaceTile {
                    Layout.preferredWidth: 1
                    icon: "token"
                    title: "Bar logo"
                    hint: root.logoIds.length > 0 ? "Your photo instead of the Nebula logo"
                                                  : "Add the Nebula logo item to your bar to use this"
                    warn: root.logoIds.length === 0
                    canToggle: root.logoIds.length > 0
                    checked: root.barAvatar
                    onToggled: state => root.setBarAvatar(state)
                }

                ProfilePlaceTile {
                    Layout.preferredWidth: 1
                    icon: "widgets"
                    title: "Desktop widgets"
                    hint: root.profileWidgets === 0 ? "No profile widgets on your desktop yet"
                        : root.profileWidgets === 1 ? "1 profile widget on your desktop"
                        : root.profileWidgets + " profile widgets on your desktop"
                    action: root.profileWidgets === 0 ? "Add" : "Manage"
                    onActionClicked: {
                        if (GlobalStates.settingsPage === 3)
                            GlobalStates.settingsPage = 19
                        GlobalStates.settingsPage = 3
                    }
                }
            }
        }
    }
}
