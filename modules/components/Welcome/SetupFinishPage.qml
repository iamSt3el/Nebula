import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

SetupScroll {
    id: scroll

    required property var store
    property bool appsVisited: false
    property var summary: []

    readonly property var ordered: scroll.store.failed.concat(
        scroll.store.resultList.filter(r => r.status !== "error"))

    ColumnLayout {
        width: scroll.contentWidthAvail
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            visible: scroll.summary.length > 0
            spacing: 3

            Repeater {
                model: scroll.summary

                Rectangle {
                    id: line

                    required property var modelData
                    required property int index

                    readonly property bool isFirst: line.index === 0
                    readonly property bool isLast: line.index === scroll.summary.length - 1

                    Layout.fillWidth: true
                    implicitHeight: 56
                    topLeftRadius: line.isFirst ? 20 : 6
                    topRightRadius: line.isFirst ? 20 : 6
                    bottomLeftRadius: line.isLast ? 20 : 6
                    bottomRightRadius: line.isLast ? 20 : 6
                    color: Colors.surfaceContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 16
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 12
                            color: Colors.primaryContainer

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: line.modelData.icon
                                iconSize: 19
                                customColor: Colors.primaryContainerText
                            }
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: line.modelData.text
                            size: 15
                            weight: 500
                            elide: Text.ElideRight
                        }

                        MaterialIconSymbol {
                            content: line.modelData.ok === false ? "radio_button_unchecked" : "check_circle"
                            iconSize: 20
                            fill: 1
                            customColor: line.modelData.ok === false ? Colors.outline : Colors.primary
                        }
                    }
                }
            }
        }

        RowLayout {
            visible: scroll.store.applying
            spacing: 12

            CustomCircularLoader {
                size: 28
                trackWidth: 3
            }

            CustomText {
                content: "Writing colour files"
                size: 14
                weight: 500
                customColor: Colors.surfaceVariantText
            }
        }

        GridLayout {
            Layout.fillWidth: true
            visible: scroll.appsVisited && scroll.ordered.length > 0
            columns: 2
            columnSpacing: 10
            rowSpacing: 8

            Repeater {
                model: scroll.ordered

                Rectangle {
                    id: res

                    required property var modelData

                    readonly property bool bad: res.modelData.status === "error"
                    readonly property bool ok: res.modelData.status === "ok"

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.columnSpan: res.bad ? 2 : 1
                    implicitHeight: 60
                    radius: 16
                    color: res.bad ? Colors.errorContainer : Colors.surfaceContainerLow

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 14
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 16
                            color: res.bad ? Colors.error : res.ok ? Colors.secondaryContainer : Colors.surfaceContainerHighest

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: res.bad ? "error" : res.ok ? "check" : "info"
                                iconSize: 19
                                customColor: res.bad ? Colors.errorText : res.ok ? Colors.primary : Colors.surfaceVariantText
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            CustomText {
                                Layout.fillWidth: true
                                content: res.modelData.name
                                size: 14
                                weight: 500
                                customColor: res.bad ? Colors.errorContainerText : Colors.surfaceText
                            }

                            CustomText {
                                Layout.fillWidth: true
                                content: res.modelData.message
                                size: 12
                                weight: 400
                                customColor: res.bad ? Colors.errorContainerText : Colors.outline
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            visible: (res.modelData.backups ?? 0) > 0
                            spacing: 4

                            MaterialIconSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                content: "backup"
                                iconSize: 15
                                customColor: Colors.tertiary
                            }

                            CustomText {
                                anchors.verticalCenter: parent.verticalCenter
                                content: ".bak saved"
                                size: 12
                                weight: 500
                                customColor: Colors.tertiary
                            }
                        }

                        M3Button {
                            visible: res.bad
                            size: "xsmall"
                            variant: "tonal"
                            icon: "refresh"
                            label: "Retry"
                            enabledButton: !scroll.store.applying
                            onClicked: scroll.store.apply()
                        }
                    }
                }
            }
        }

        TilePackages {
            Layout.fillWidth: true
        }
    }
}
