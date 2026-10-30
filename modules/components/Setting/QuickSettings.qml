pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Scope {
    id: scope

    LazyLoader {
        active: GlobalStates.quickSettingsPage >= 0

        PanelWindow {
            id: win

            readonly property int page: GlobalStates.quickSettingsPage
            readonly property var info: win.page >= 0 ? Settings.pages[win.page] ?? null : null
            property bool closing: false

            function close() {
                if (win.closing)
                    return
                win.closing = true
                morph.close()
            }

            function openFull() {
                const p = win.page
                win.close()
                GlobalStates.settingsPage = p
                GlobalStates.settingsOpen = true
            }

            function compFor(p) {
                switch (p) {
                case 0: return themeComp
                case 1: return soundComp
                case 2: return notifComp
                case 3: return widgetsComp
                case 4: return netComp
                case 5: return btComp
                case 6: return weatherComp
                case 7: return weatherComp
                case 9: return themeComp
                case 10: return lockComp
                case 12: return lockComp
                case 15: return displaysComp
                case 16: return windowsComp
                case 17: return inputComp
                }
                return null
            }

            screen: Quickshell.screens.find(s => s.name === GlobalStates.quickSettingsScreen) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:quickSettings"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Connections {
                target: GlobalStates
                function onQuickSettingsPageChanged() {
                    if (GlobalStates.quickSettingsPage >= 0 && win.closing) {
                        win.closing = false
                        morph.open()
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Colors.scrim
                opacity: morph.opened ? 0.4 : 0
                Behavior on opacity { EffectsAnim {} }

                MouseArea {
                    anchors.fill: parent
                    onClicked: win.close()
                }
            }

            MorphCard {
                id: morph

                readonly property rect from: GlobalStates.quickSettingsFrom
                readonly property bool hasFrom: morph.from.width > 0

                width: Math.min(760, win.width - 64)
                contentHeight: Math.min(680, win.height - 120)
                x: Math.round((win.width - morph.width) / 2)
                y: Math.round((win.height - morph.contentHeight) / 2)
                srcWidth: morph.hasFrom ? morph.from.width : 140
                srcHeight: morph.hasFrom ? morph.from.height : 40
                srcRadius: morph.srcHeight / 2
                srcX: morph.hasFrom ? morph.from.x - morph.x : (morph.width - morph.srcWidth) / 2
                srcY: morph.hasFrom ? morph.from.y - morph.y : 0
                cardRadius: 28
                cardColor: Colors.surface
                fadeCard: !morph.hasFrom

                onCloseFinished: if (win.closing) GlobalStates.quickSettingsPage = -1
                Component.onCompleted: Qt.callLater(morph.open)

                Item {
                    anchors.fill: parent
                    focus: true
                    Keys.onEscapePressed: win.close()

                    MouseArea {
                        anchors.fill: parent
                    }

                    RowLayout {
                        id: header
                        x: 20
                        y: 16
                        width: parent.width - 40
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 14
                            color: Colors.primaryContainer

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: win.info ? win.info.icon : "settings"
                                iconSize: 22
                                fill: 1
                                customColor: Colors.primaryContainerText
                            }
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: win.info ? win.info.name : "Settings"
                            size: 20
                            weight: 600
                            elide: Text.ElideRight
                        }

                        M3Button {
                            variant: "tonal"
                            icon: "open_in_new"
                            label: "All settings"
                            onClicked: win.openFull()
                        }

                        M3IconButton {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            icon: "close"
                            iconSize: 20
                            tip: "Close · Esc"
                            onClicked: win.close()
                        }
                    }

                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.top: header.bottom
                        anchors.topMargin: 8
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.bottomMargin: 12
                        clip: true

                        Loader {
                            anchors.fill: parent
                            sourceComponent: win.compFor(win.page)
                        }
                    }
                }
            }

            Component { id: themeComp; Theme {} }
            Component { id: soundComp; Sound {} }
            Component { id: notifComp; Notifications {} }
            Component { id: widgetsComp; Widgets {} }
            Component { id: netComp; Networking {} }
            Component { id: btComp; Bluetooth {} }
            Component { id: weatherComp; WeatherSettings {} }
            Component { id: lockComp; Lockscreen {} }
            Component { id: displaysComp; DisplaysSettings {} }
            Component { id: windowsComp; WindowsSettings {} }
            Component { id: inputComp; InputSettings {} }
        }
    }
}
