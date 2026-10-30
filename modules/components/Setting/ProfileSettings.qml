import Quickshell
import QtQuick
import QtQuick.Layouts
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
    readonly property int photoPlaces: [root.lockAvatar, root.greeterAvatar, root.barAvatar, root.profileWidgets > 0].filter(x => x).length

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

    StageView {
        id: stages

        StagePage {
            stageId: "front"

            Item {
                id: hero
                Layout.fillWidth: true
                Layout.preferredHeight: 210

                RoundedImage {
                    anchors.fill: parent
                    radius: 28
                    source: WallpaperTheme.wallpaperScreen
                    sourceSize: Qt.size(1280, 720)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 28
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.alpha(Colors.surface, 0.92) }
                        GradientStop { position: 0.55; color: Qt.alpha(Colors.surface, 0.72) }
                        GradientStop { position: 1; color: Qt.alpha(Colors.surface, 0.15) }
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 16
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
                    anchors.right: parent.right
                    anchors.leftMargin: 26
                    anchors.rightMargin: 26
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 24

                    Item {
                        Layout.preferredWidth: 128
                        Layout.preferredHeight: 128

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -5
                            radius: width / 2
                            color: Colors.primary
                        }

                        LockShapeImage {
                            anchors.fill: parent
                            source: root.avatar
                            shapeName: "circle"
                            sourceSize: 256
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
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
                            Layout.fillWidth: true
                            content: LockSession.greeting + ", " + root.shownName
                            family: root.displayFamily
                            renderType: Text.QtRendering
                            size: 30
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.topMargin: 8
                            spacing: 8

                            M3Button {
                                icon: "photo_camera"
                                label: "Change photo"
                                onClicked: root.pickPhoto()
                            }

                            M3Button {
                                variant: "tonal"
                                icon: "edit"
                                label: "Edit name"
                                onClicked: stages.push("name")
                            }
                        }
                    }
                }
            }

            StageGap {}

            StageNavRow {
                icon: "badge"
                title: "Display name"
                subtitle: "Shown in the shell and on the lock screen"
                value: root.shownName
                target: "name"
            }

            StageNavRow {
                icon: "waving_hand"
                title: "Greeting"
                subtitle: "How the lock and login screens say hello"
                value: ({ time: "Time of day", hello: "Hello", custom: "Custom" })[root.greetingStyle] ?? ""
                target: "greeting"
            }

            StageNavRow {
                icon: root.currentMode.icon
                title: "Status"
                subtitle: root.currentMode.hint
                value: root.currentMode.label
                target: "status"
            }

            StageNavRow {
                icon: "image"
                title: "Where your photo shows"
                subtitle: "Lock screen, login screen, bar logo, widgets"
                value: root.photoPlaces + " of 4"
                target: "photo"
            }
        }

        StageLazy {
            stageId: "name"

            StagePage {
                stageId: "name"
                title: "Display name"

                StageFieldRow {
                    icon: "badge"
                    title: "Display name"
                    subtitle: "Empty uses your login name, " + root.loginName
                    fieldIcon: "person"
                    allowEmpty: true
                    text: SettingsConfig.general.displayName ?? ""
                    placeholder: root.loginName
                    onSubmitted: t => root.setGeneral({ displayName: t })
                }
            }
        }

        StageLazy {
            stageId: "greeting"

            StagePage {
                stageId: "greeting"
                title: "Greeting"

                StageChoiceRow {
                    title: "Say"
                    options: [{ value: "time", label: "Time of day", icon: "schedule" }, { value: "hello", label: "Hello", icon: "waving_hand" }, { value: "custom", label: "Custom", icon: "edit" }]
                    current: root.greetingStyle
                    onPicked: v => root.setGeneral({ greetingStyle: v })
                }

                StageFieldRow {
                    visible: root.greetingStyle === "custom"
                    title: "Your greeting"
                    subtitle: "Followed by your name"
                    text: SettingsConfig.general.greetingText ?? ""
                    placeholder: "Welcome back"
                    onSubmitted: t => root.setGeneral({ greetingText: t })
                }
            }
        }

        StageLazy {
            stageId: "status"

            StagePage {
                stageId: "status"
                title: "Status"

                Repeater {
                    model: root.modes

                    StageRow {
                        required property var modelData
                        readonly property bool current: modelData.value === root.mode
                        icon: modelData.icon
                        title: modelData.label
                        subtitle: modelData.hint
                        tonal: current
                        clickable: !current
                        value: current ? "Now" : ""
                        onClicked: root.setMode(modelData.value)
                    }
                }
            }
        }

        StageLazy {
            stageId: "photo"

            StagePage {
                stageId: "photo"
                title: "Photo"

                StageRow {
                    icon: "image"
                    title: root.avatar !== "" ? root.avatar.split("/").pop() : "No photo"
                    subtitle: "Square images look best"

                    M3Button {
                        variant: "tonal"
                        icon: "delete"
                        label: "Remove"
                        visible: root.avatar !== ""
                        onClicked: root.setGeneral({ profile: "" })
                    }

                    M3Button {
                        icon: "folder_open"
                        label: "Choose"
                        onClicked: root.pickPhoto()
                    }
                }

                StageHeading { text: "Show my photo on" }

                StageSwitchRow {
                    icon: "lock"
                    title: "Lock screen"
                    subtitle: "Next to the clock, in the layouts that have one"
                    checked: root.lockAvatar
                    onToggled: on => root.setLock({ showAvatar: on })
                }

                StageSwitchRow {
                    icon: "login"
                    title: "Login screen"
                    subtitle: "Above the password field before you sign in"
                    checked: root.greeterAvatar
                    onToggled: on => root.setLock({ greeterAvatar: on })
                }

                StageSwitchRow {
                    enabled: root.logoIds.length > 0
                    icon: "token"
                    title: "Bar logo"
                    subtitle: root.logoIds.length > 0 ? "Your photo instead of the Nebula logo" : "Add the Nebula logo item to your bar to use this"
                    checked: root.barAvatar
                    onToggled: on => root.setBarAvatar(on)
                }

                StageNavRow {
                    icon: "widgets"
                    title: "Desktop widgets"
                    subtitle: root.profileWidgets === 0 ? "No profile widgets on your desktop yet"
                        : root.profileWidgets === 1 ? "1 profile widget on your desktop"
                        : root.profileWidgets + " profile widgets on your desktop"
                    value: root.profileWidgets === 0 ? "Add" : "Manage"
                    onClicked: GlobalStates.settingsPage = 3
                }
            }
        }
    }
}
