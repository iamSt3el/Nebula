pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.Edit

ColumnLayout {
    id: row

    property string instanceId: ""
    property var spec: ({})
    property var getter: function(key) { return BarLayout.opt(row.instanceId, key) }
    property var setter: function(key, v) { BarLayout.setOption(row.instanceId, key, v) }
    property var listGetter: function(key) { return [] }
    property var listAdd: function(key, v) {}
    property var listRemove: function(key, v) {}

    readonly property string kind: row.spec.type ?? ""
    readonly property var value: row.getter(row.spec.key)
    readonly property var cond: row.spec.onlyIf ?? null
    readonly property bool shown: !row.cond || row.cond.values.indexOf(row.getter(row.cond.key)) >= 0
    readonly property bool swatches: row.kind === "choice" && row.spec.key === "color"
    readonly property bool picker: (row.kind === "choice" && !row.swatches) || row.kind === "grid"
    readonly property int off: row.spec.auto ? 1 : 0
    readonly property int stops: row.kind === "slider" ? Math.round(((row.spec.max ?? 1) - (row.spec.min ?? 0)) / (row.spec.step ?? 1)) + 1 : 0
    readonly property bool stepper: row.kind === "slider" && (row.stops > 8 || (row.spec.presets ?? []).length > 0)
    readonly property bool stepperInline: row.stepper && (row.spec.presets ?? []).length === 0 && !row.spec.auto

    function set(v) {
        row.setter(row.spec.key, v)
    }

    function toneColor(v) {
        switch (v) {
        case "primary": return Colors.primary
        case "secondary": return Colors.secondary
        case "tertiary": return Colors.tertiary
        case "error": return Colors.error
        case "surfaceText": return Colors.surfaceText
        }
        return Colors.primary
    }

    visible: row.shown
    spacing: 8

    component Chip: Rectangle {
        id: chip
        property string label: ""
        property string icon: ""
        property bool lit: false
        signal clicked
        implicitHeight: 34
        implicitWidth: chipRow.implicitWidth + 24
        radius: 17
        color: chip.lit ? Colors.secondaryContainer
            : chipArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            MaterialIconSymbol {
                visible: chip.icon !== ""
                content: chip.icon
                iconSize: 15
                customColor: chip.lit ? Colors.secondaryContainerText : Colors.surfaceVariantText
            }
            CustomText {
                content: chip.label
                size: 12
                weight: chip.lit ? 700 : 500
                customColor: chip.lit ? Colors.secondaryContainerText : Colors.surfaceText
            }
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    CustomText {
        visible: row.kind === "heading"
        Layout.fillWidth: true
        Layout.topMargin: 4
        content: row.spec.label ?? ""
        size: 12
        weight: 600
        customColor: Colors.primary
    }

    RowLayout {
        visible: row.kind !== "heading"
        Layout.fillWidth: true
        Layout.minimumHeight: row.kind === "toggle" || row.stepperInline ? 40 : 22
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            CustomText {
                Layout.fillWidth: true
                content: row.spec.label ?? ""
                size: row.kind === "toggle" || row.stepperInline ? 14 : 13
                weight: row.kind === "toggle" || row.stepperInline ? 500 : 600
                customColor: row.kind === "toggle" || row.stepperInline ? Colors.surfaceText : Colors.surfaceVariantText
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
            CustomText {
                Layout.fillWidth: true
                visible: (row.spec.sub ?? "") !== ""
                content: row.spec.sub ?? ""
                size: 11
                weight: 400
                customColor: Colors.outline
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }

        CustomToogle {
            visible: row.kind === "toggle"
            isToggleOn: row.value === true
            onToggled: state => row.set(state)
        }

        EditStepper {
            visible: row.stepperInline
            value: row.value ?? (row.spec.min ?? 0)
            from: row.spec.min ?? 0
            to: row.spec.max ?? 1
            stepSize: row.spec.step ?? 1
            unit: row.spec.unit ?? ""
            onPicked: v => {
                if (v !== row.value)
                    row.set(v)
            }
        }

        CustomText {
            visible: row.kind === "slider" && !row.stepper
            content: row.off && (row.value ?? 0) < 0 ? String(row.spec.auto) : String(row.value ?? "")
            size: 12
            weight: 600
            customColor: Colors.surfaceVariantText
        }

        CustomText {
            visible: row.swatches
            content: {
                const c = (row.spec.choices ?? []).find(x => x.value === row.value)
                return c ? c.label : ""
            }
            size: 12
            customColor: Colors.surfaceVariantText
        }
    }

    Row {
        visible: row.swatches
        spacing: 12

        Repeater {
            model: row.swatches ? row.spec.choices : []

            delegate: Item {
                id: sw
                required property var modelData
                readonly property bool on: row.value === sw.modelData.value
                width: 36
                height: 36

                Rectangle {
                    anchors.centerIn: parent
                    width: 44
                    height: 44
                    radius: 22
                    visible: sw.on
                    color: "transparent"
                    border.width: 2
                    border.color: Colors.surfaceText
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    clip: true
                    color: sw.modelData.value === "auto" ? Colors.primary : row.toneColor(sw.modelData.value)

                    Rectangle {
                        visible: sw.modelData.value === "auto"
                        x: parent.width / 2
                        width: parent.width / 2
                        height: parent.height
                        color: Colors.tertiary
                    }
                }

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    visible: sw.on
                    content: "check"
                    iconSize: 18
                    customColor: Colors.primaryText
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.set(sw.modelData.value)
                }
            }
        }
    }

    EditChoice {
        visible: row.picker
        Layout.fillWidth: true
        choices: row.picker ? row.spec.choices : []
        value: row.value
        onPicked: v => row.set(v)
    }

    EditStepper {
        visible: row.stepper && !row.stepperInline
        Layout.fillWidth: true
        value: row.off && (row.value ?? 0) < 0 ? (row.spec.min ?? 0) : (row.value ?? (row.spec.min ?? 0))
        from: row.spec.min ?? 0
        to: row.spec.max ?? 1
        stepSize: row.spec.step ?? 1
        unit: row.spec.unit ?? ""
        presets: row.spec.presets ?? []
        canAuto: !!row.spec.auto
        isAuto: !!row.spec.auto && (row.value ?? 0) < 0
        autoLabel: row.spec.auto ? String(row.spec.auto) : "Auto"
        autoText: row.spec.auto ? String(row.spec.auto) : "Auto"
        onPicked: v => {
            if (v !== row.value)
                row.set(v)
        }
        onAutoPicked: row.set(-1)
    }

    M3Slider {
        id: slider
        visible: row.kind === "slider" && !row.stepper
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        readonly property real lo: row.spec.min ?? 0
        readonly property real st: row.spec.step ?? 1
        stepCount: row.kind === "slider" ? Math.round(((row.spec.max ?? 1) - slider.lo) / slider.st) + 1 + row.off : 0
        currentStep: row.kind !== "slider" ? -1
            : row.off && (row.value ?? 0) < 0 ? 0
            : Math.round(((row.value ?? slider.lo) - slider.lo) / slider.st) + row.off
        valueText: row.off && currentStep === 0 ? String(row.spec.auto) : String(slider.lo + (currentStep - row.off) * slider.st)
        onStepChanged: step => {
            const v = row.off && step === 0 ? -1 : slider.lo + (step - row.off) * slider.st
            if (v !== row.value)
                row.set(v)
        }
    }

    Rectangle {
        visible: row.kind === "text"
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: 12
        color: Colors.surfaceContainerHighest
        border.width: field.activeFocus ? 2 : 0
        border.color: Colors.primary

        TextInput {
            id: field
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            selectByMouse: true
            color: Colors.surfaceText
            selectionColor: Qt.alpha(Colors.primary, 0.35)
            font.pixelSize: 13
            font.family: SettingsConfig.general.defaultFont ?? "Rubik"
            text: row.kind === "text" ? String(row.value ?? "") : ""
            onEditingFinished: {
                if (field.text !== String(row.value ?? ""))
                    row.set(field.text)
            }
        }

        CustomText {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: field.text === "" && !field.activeFocus
            content: row.spec.placeholder ?? ""
            size: 12
            customColor: Colors.outline
        }
    }

    ShapePicker {
        visible: row.kind === "shape"
        Layout.fillWidth: true
        centered: true
        showAuto: false
        selected: row.kind === "shape" ? String(row.value ?? "") : ""
        onPicked: name => row.set(name)
    }

    ColumnLayout {
        id: list
        visible: row.kind === "buttons"
        Layout.fillWidth: true
        spacing: 8

        readonly property var chosen: row.kind === "buttons" ? row.listGetter(row.spec.key) : []
        readonly property var pool: row.kind === "buttons" ? row.spec.catalog.filter(e => list.chosen.indexOf(e.id) < 0) : []

        function entryOf(id) {
            return row.spec.catalog.find(e => e.id === id) ?? null
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: list.chosen
                delegate: Chip {
                    required property string modelData
                    readonly property var e: list.entryOf(modelData)
                    label: e ? e.label : modelData
                    icon: "close"
                    lit: true
                    onClicked: row.listRemove(row.spec.key, modelData)
                }
            }
        }

        CustomText {
            visible: list.pool.length > 0
            content: "Add"
            size: 11
            weight: 600
            customColor: Colors.outline
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: list.pool
                delegate: Chip {
                    required property var modelData
                    label: modelData.label
                    icon: "add"
                    onClicked: row.listAdd(row.spec.key, modelData.id)
                }
            }
        }
    }
}
