pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings

Item {
    id: root

    readonly property var session: ServiceClaudeCode.limitFor("session")
    readonly property var weekly: ServiceClaudeCode.limitFor("weekly")
    readonly property var today: ServiceClaudeCode.today
    readonly property var series: ServiceClaudeCode.series ?? []
    readonly property real seriesMax: Math.max(1, ...root.series.map(d => d.tokens ?? 0))
    readonly property string model: ServiceClaudeCode.modelLabel(root.today.models?.[0]?.name)

    function pct(limit) {
        return limit ? (limit.percent ?? 0) : 0
    }

    function ago(sec) {
        return sec < 60 ? "just now" : ServiceClaudeCode.formatSpan(sec) + " ago"
    }

    function count(n) {
        return Number(n ?? 0).toLocaleString(Qt.locale("en_US"), "f", 0)
    }

    Component.onCompleted: ServiceClaudeCode.retain()
    Component.onDestruction: ServiceClaudeCode.release()

    implicitWidth: 400
    implicitHeight: col.implicitHeight + 36

    ColumnLayout {
        id: col
        x: 18
        y: 18
        width: root.width - 36
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 12
                color: Colors.secondaryContainer

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: "terminal"
                    iconSize: 22
                    customColor: Colors.secondaryContainerText
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                CustomText {
                    content: "Claude Code"
                    size: 15
                    weight: 600
                }

                RowLayout {
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 7
                        Layout.preferredHeight: 7
                        radius: 4
                        color: ServiceClaudeCode.live ? Colors.tertiary : Colors.outline
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: ServiceClaudeCode.live ? "Working in " + ServiceClaudeCode.project
                            : ServiceClaudeCode.lastAgeSec > 0 ? "Idle for " + ServiceClaudeCode.formatSpan(ServiceClaudeCode.lastAgeSec)
                            : "Idle"
                        size: 12
                        customColor: Colors.surfaceVariantText
                    }
                }
            }

            Rectangle {
                visible: root.model !== ""
                Layout.preferredHeight: 26
                Layout.preferredWidth: modelText.implicitWidth + 20
                radius: 13
                color: "transparent"
                border.width: 1
                border.color: Colors.outlineVariant

                CustomText {
                    id: modelText
                    anchors.centerIn: parent
                    content: root.model
                    size: 12
                    weight: 500
                    customColor: Colors.surfaceVariantText
                }
            }
        }

        CustomCard {
            visible: ServiceClaudeCode.lastPrompt !== ""
            autoRadius: false
            topRadius: 16
            bottomRadius: 16
            color: Colors.surfaceContainerLow

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                CustomText {
                    content: "Last prompt, " + root.ago(ServiceClaudeCode.lastAgeSec)
                    size: 11
                    customColor: Colors.outline
                }

                CustomText {
                    Layout.fillWidth: true
                    content: ServiceClaudeCode.lastPrompt
                    size: 13
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    lineHeight: 1.15
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 14
            opacity: ServiceClaudeCode.limitsStale ? 0.55 : 1

            Repeater {
                model: [
                    { name: "Session", limit: root.session, fallback: Colors.primary },
                    { name: "Week", limit: root.weekly, fallback: Colors.secondary }
                ]

                delegate: ColumnLayout {
                    id: meter
                    required property var modelData
                    readonly property color tone: ServiceClaudeCode.colorOf(meter.modelData.limit, meter.modelData.fallback)
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        CustomText {
                            Layout.fillWidth: true
                            content: meter.modelData.name
                            size: 13
                            weight: 500
                        }

                        CustomText {
                            content: meter.modelData.limit ? Math.round(root.pct(meter.modelData.limit)) + "%" : "–"
                            size: 13
                            weight: 700
                            customColor: ServiceClaudeCode.toneOf(meter.modelData.limit) !== "normal" ? meter.tone : Colors.surfaceText
                        }
                    }

                    M3Slider {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                        interactive: false
                        showValueLabel: false
                        progress: Math.min(1, root.pct(meter.modelData.limit) / 100)
                        activeColor: meter.tone
                        handleColor: meter.tone
                    }

                    CustomText {
                        content: meter.modelData.limit
                            ? "Resets in " + ServiceClaudeCode.formatSpan(meter.modelData.limit.secondsLeft ?? 0)
                            : "No data yet"
                        size: 11
                        customColor: Colors.surfaceVariantText
                    }
                }
            }
        }

        CustomText {
            visible: ServiceClaudeCode.limitsStale
            content: "Limits from " + ServiceClaudeCode.formatSpan(ServiceClaudeCode.limitsAgeSec) + " ago. They refresh while Claude Code is running."
            size: 11
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            customColor: Qt.hsla(0.09, 0.85, 0.55, 1)
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 8

            Repeater {
                model: [
                    { value: ServiceClaudeCode.formatTokens(root.today.tokens ?? 0), label: "tokens" },
                    { value: ServiceClaudeCode.formatTokens(root.today.output ?? 0), label: "written" },
                    { value: root.count(root.today.messages), label: "messages" },
                    { value: root.count(root.today.sessions), label: "sessions" }
                ]

                delegate: CustomCard {
                    id: stat
                    required property var modelData
                    autoRadius: false
                    topRadius: 14
                    bottomRadius: 14
                    color: Colors.surfaceContainerLow
                    Layout.preferredWidth: 1

                    ColumnLayout {
                        spacing: 0

                        CustomText {
                            content: stat.modelData.value
                            size: 18
                            weight: 700
                        }

                        CustomText {
                            content: stat.modelData.label
                            size: 11
                            customColor: Colors.surfaceVariantText
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                CustomText {
                    Layout.fillWidth: true
                    content: "This week"
                    size: 12
                    weight: 500
                }

                CustomText {
                    content: ServiceClaudeCode.formatTokens(ServiceClaudeCode.week.tokens ?? 0) + " tokens"
                    size: 12
                    customColor: Colors.surfaceVariantText
                }
            }

            TrapezoidChart {
                Layout.fillWidth: true
                Layout.preferredHeight: 84
                values: root.series.length > 1 ? [root.series[0].tokens ?? 0].concat(root.series.map(d => d.tokens ?? 0)) : []
                labels: root.series.map(d => d.weekday ?? "")
                lo: 0
                hi: root.seriesMax * 1.08
                barColor: Colors.primary
                gridColor: "transparent"
                gridValues: []
                gridLabelWidth: 0
                tickHeight: 0
                bottomOffset: 0
                labelHeight: 13
                cornerRadius: 4
            }
        }
    }
}
