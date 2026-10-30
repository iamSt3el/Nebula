import QtQuick
import QtQuick.Layouts
import Qt.labs.platform
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import qs.modules.components.Bar

Item {
    id: root
    anchors.fill: parent

    readonly property var notif: SettingsConfig.notifications ?? ({})
    readonly property var game: SettingsConfig.gameMode ?? ({})
    readonly property bool popupsOn: root.notif.showBanners ?? true
    readonly property bool soundOn: root.notif.playSound ?? false
    readonly property string edgeMode: root.notif.edgeLight ?? "important"
    readonly property string soundName: (root.notif.soundPath ?? "") === "" ? "" : root.notif.soundPath.split("/").pop()
    readonly property bool popupItemPlaced: BarLayout.baseId(BarLayout.popupHostItem) === "popups"
    readonly property string popupWhere: {
        const mode = BarLayout.popupMode
        const host = BarLayout.popupHostItem
        if (mode === "island") {
            if (host === "")
                return "An island under the clock"
            return root.popupItemPlaced ? "An island beside the Popups item" : "An island beside the bell"
        }
        if (mode === "item") {
            const b = BarLayout.allBlocks.find(x => x.items.indexOf(host) >= 0)
            const where = b && b.edge === "bottom" ? "the dock" : "the bar"
            return root.popupItemPlaced ? "The Popups item on " + where : "The bell on " + where
        }
        if (mode === "icon")
            return "Dock icons"
        return "The screen corner"
    }

    function patch(p) {
        SettingsConfig.notifications = Object.assign({}, SettingsConfig.notifications, p)
    }

    function patchGame(p) {
        SettingsConfig.gameMode = Object.assign({}, SettingsConfig.gameMode, p)
    }

    FileDialog {
        id: soundPicker
        title: "Select a notification sound file"
        nameFilters: ["WAV files (*.wav)"]
        onAccepted: {
            root.patch({ soundPath: soundPicker.file.toString().replace(/^file:\/\//, "") })
            GlobalStates.fileDialogOpen = false
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }

    StageView {
        StagePage {
            stageId: "front"

            StageSwitchRow {
                icon: "do_not_disturb_on"
                title: "Do not disturb"
                subtitle: "Hold back popups; they still reach the notification center"
                checked: root.notif.doNotDisturb ?? false
                onToggled: on => root.patch({ doNotDisturb: on })
            }

            StageRow {
                icon: "sports_esports"
                title: "Game mode"
                subtitle: "Hides the bar and widgets, holds back popups"
                target: "game"

                CustomToogle {
                    isToggleOn: ServiceGameMode.active
                    onToggled: state => ServiceGameMode.active = state
                }
            }

            StageGap {}

            StageNavRow {
                icon: "chat_bubble"
                title: "Popups"
                subtitle: root.popupsOn ? root.popupWhere + " · " + (root.notif.popupTimeout ?? 5) + " s · " + (root.notif.maxVisible ?? 3) + " at once" : "Off"
                target: "popups"
            }

            StageNavRow {
                icon: "music_note"
                title: "Sound"
                subtitle: root.soundOn && root.soundName !== "" ? root.soundName : "No sound when something arrives"
                value: root.soundOn ? "On" : "Off"
                target: "sound"
            }

            StageNavRow {
                icon: "inbox"
                title: "Notification center"
                subtitle: "Where every notification is kept"
                value: (root.notif.showInCenter ?? true) ? "On" : "Off"
                target: "center"
            }

            StageNavRow {
                icon: "light_mode"
                title: "Edge light"
                subtitle: "Glow the screen edge when something arrives"
                value: ({ off: "Off", important: "Important", all: "All" })[root.edgeMode] ?? "Off"
                target: "edge"
            }
        }

        StageLazy {
            stageId: "popups"

            StagePage {
                stageId: "popups"
                title: "Popups"

                StageSwitchRow {
                    title: "Show popups"
                    subtitle: "New notifications pop up; they always land in the center too"
                    checked: root.popupsOn
                    onToggled: on => root.patch({ showBanners: on })
                }

                StageRow {
                    enabled: root.popupsOn
                    title: "Popups open from"
                    subtitle: root.popupWhere

                    M3Button {
                        icon: "edit"
                        label: root.popupItemPlaced ? "Move it" : "Place it"
                        onClicked: {
                            GlobalStates.settingsOpen = false
                            GlobalStates.openEdit("edges")
                        }
                    }
                }

                StageChoiceRow {
                    visible: !root.popupItemPlaced
                    enabled: root.popupsOn
                    title: "Without a Popups item"
                    subtitle: "Add the Popups item to a bar block in edit mode to open them from there"
                    options: [{ value: "item", label: "From the bell", icon: "notifications" }, { value: "icon", label: "Dock icons", icon: "apps" }]
                    current: (SettingsConfig.general?.notifPopupStyle ?? "item") === "icon" ? "icon" : "item"
                    onPicked: v => SettingsConfig.general = Object.assign({}, SettingsConfig.general, { notifPopupStyle: v })
                }

                StageChoiceRow {
                    enabled: root.popupsOn
                    title: "Look"
                    options: [{ value: "cards", label: "Cards", icon: "view_agenda" }, { value: "island", label: "Island", icon: "pill" }]
                    current: root.notif.popupLook ?? "cards"
                    onPicked: v => root.patch({ popupLook: v })
                }

                StageGap {}

                StageSliderRow {
                    enabled: root.popupsOn
                    title: "Seconds on screen"
                    subtitle: "Hovering pauses it"
                    from: 1
                    to: 30
                    step: 1
                    current: root.notif.popupTimeout ?? 5
                    format: v => Math.round(v) + " s"
                    onCommitted: v => root.patch({ popupTimeout: Math.round(v) })
                }

                StageSliderRow {
                    enabled: root.popupsOn
                    title: "Cards at once"
                    subtitle: "The rest wait behind a +N more row"
                    from: 1
                    to: 5
                    step: 1
                    current: root.notif.maxVisible ?? 3
                    onCommitted: v => root.patch({ maxVisible: Math.round(v) })
                }

                StageGap {}

                StageSwitchRow {
                    enabled: root.popupsOn
                    title: "Group by app"
                    subtitle: "Several from one app share a card with a count"
                    checked: root.notif.groupPopups ?? true
                    onToggled: on => root.patch({ groupPopups: on })
                }

                StageSwitchRow {
                    enabled: root.popupsOn
                    title: "Keep urgent ones until dismissed"
                    subtitle: "Like low battery"
                    checked: root.notif.urgentSticky ?? true
                    onToggled: on => root.patch({ urgentSticky: on })
                }
            }
        }

        StageLazy {
            stageId: "sound"

            StagePage {
                stageId: "sound"
                title: "Sound"

                StageSwitchRow {
                    title: "Play a sound"
                    subtitle: "When a notification arrives"
                    checked: root.soundOn
                    onToggled: on => root.patch({ playSound: on })
                }

                StageNavRow {
                    enabled: root.soundOn
                    icon: "audio_file"
                    title: "Sound file"
                    subtitle: "WAV only (uncompressed PCM)"
                    value: root.soundName !== "" ? root.soundName : "Not set"
                    onClicked: {
                        GlobalStates.fileDialogOpen = true
                        soundPicker.open()
                    }
                }
            }
        }

        StageLazy {
            stageId: "center"

            StagePage {
                stageId: "center"
                title: "Notification center"

                StageSwitchRow {
                    title: "Keep notifications in the center"
                    subtitle: "Open it from the bell in the bar"
                    checked: root.notif.showInCenter ?? true
                    onToggled: on => root.patch({ showInCenter: on })
                }
            }
        }

        StageLazy {
            stageId: "edge"

            StagePage {
                stageId: "edge"
                title: "Edge light"

                StageNote { content: "The screen edge glows briefly when a notification arrives, handy when popups are hidden." }

                StageChoiceRow {
                    title: "Glow for"
                    options: [{ value: "off", label: "Off" }, { value: "important", label: "Important", icon: "priority_high" }, { value: "all", label: "All" }]
                    current: root.edgeMode
                    onPicked: v => root.patch({ edgeLight: v })
                }

                StageFieldRow {
                    visible: root.edgeMode === "important"
                    icon: "star"
                    title: "Important apps"
                    subtitle: "Comma separated, e.g. discord, telegram"
                    fieldIcon: "apps"
                    fieldWidth: 240
                    allowEmpty: true
                    text: Array.from(root.notif.edgeLightApps ?? []).join(", ")
                    placeholder: "discord, telegram"
                    onSubmitted: t => root.patch({ edgeLightApps: t.split(",").map(x => x.trim()).filter(x => x.length > 0) })
                }
            }
        }

        StageLazy {
            stageId: "game"

            StagePage {
                stageId: "game"
                title: "Game mode"

                StageHero {
                    tone: ServiceGameMode.active ? "primary" : "plain"
                    icon: "sports_esports"
                    title: ServiceGameMode.active ? "Game mode is on" : "Game mode is off"
                    subtitle: "Turn it off again with your settings shortcut"

                    M3Button {
                        icon: ServiceGameMode.active ? "stop" : "play_arrow"
                        label: ServiceGameMode.active ? "Turn off" : "Turn on"
                        onClicked: ServiceGameMode.active = !ServiceGameMode.active
                    }
                }

                StageHeading { text: "While it is on" }

                StageSwitchRow {
                    title: "Hide the bar"
                    subtitle: "Window gaps drop to zero too"
                    checked: root.game.hideBar ?? true
                    onToggled: on => root.patchGame({ hideBar: on })
                }

                StageSwitchRow {
                    title: "Hide widgets and dock"
                    subtitle: "Desktop widgets, the dock and the music visualizer"
                    checked: root.game.hideWidgets ?? true
                    onToggled: on => root.patchGame({ hideWidgets: on })
                }

                StageSwitchRow {
                    title: "Do not disturb"
                    subtitle: "Popups wait; they still reach the notification center"
                    checked: root.game.dnd ?? true
                    onToggled: on => root.patchGame({ dnd: on })
                }

                StageSwitchRow {
                    title: "Performance tweaks"
                    subtitle: "No blur, shadows or animations; your Hyprland config reloads on exit"
                    checked: root.game.hyprPerf ?? true
                    onToggled: on => root.patchGame({ hyprPerf: on })
                }
            }
        }
    }
}
