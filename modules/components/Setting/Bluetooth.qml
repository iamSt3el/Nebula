import Quickshell
import Quickshell.Widgets
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
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

    property bool hasConnectedDevices: {
        const l = ServiceBluetooth.list ?? []
        for (let i = 0; i < l.length; i++) if (l[i].state === 1) return true
        return false
    }
    property bool hasPairedDevices: {
        const l = ServiceBluetooth.list ?? []
        for (let i = 0; i < l.length; i++) {
            const d = l[i]
            if ((d.paired ?? d.bonded ?? false) && d.state !== 1) return true
        }
        return false
    }
    property bool hasNearbyDevices: {
        const l = ServiceBluetooth.list ?? []
        for (let i = 0; i < l.length; i++) {
            const d = l[i]
            if (!(d.paired ?? d.bonded ?? false) && d.state !== 1) return true
        }
        return false
    }

    Flickable {
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

            // ── Page header ──────────────────────────────────────
            RowLayout {
                spacing: 10
                MaterialIconSymbol { content: "bluetooth"; iconSize: 20 }
                CustomText { content: "Bluetooth"; size: 20; customColor: Colors.primary }
            }

            // ── Adapter ──────────────────────────────────────────
            CustomText { Layout.topMargin: 24; content: "Adapter"; size: 13; customColor: Colors.primary }

            CustomCard {
                Layout.topMargin: 6
                autoRadius: false; topRadius: 20; bottomRadius: 20

                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        spacing: 2
                        CustomText { content: "Bluetooth"; size: 14 }
                        CustomText { content: "Enable or disable the Bluetooth adapter"; size: 12; customColor: Colors.outline }
                    }
                    Item { Layout.fillWidth: true }
                    CustomToogle {
                        isToggleOn: Bluetooth.defaultAdapter?.enabled ?? false
                        onToggled: function(state) {
                            const adapter = Bluetooth.defaultAdapter
                            if (adapter) adapter.discovering = state
                        }
                    }
                }
            }

            // ── Connected ────────────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Connected"; size: 13; customColor: Colors.primary }

            // Empty state — none connected
            Rectangle {
                Layout.topMargin: 6
                Layout.fillWidth: true
                implicitHeight: 90
                visible: !root.hasConnectedDevices
                color: Colors.surfaceContainerHigh
                radius: 20

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 46; implicitHeight: 46

                        MaterialShapes.ShapeCanvas {
                            anchors.fill: parent
                            roundedPolygon: MaterialShapeFn.getCookie6Sided()
                            color: Colors.surfaceContainerHighest
                        }
                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "bluetooth_disabled"; iconSize: 22; customColor: Colors.outline
                        }
                    }
                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: "No connected devices"; size: 13; customColor: Colors.outline
                    }
                }
            }

            ColumnLayout {
                Layout.topMargin: 6
                Layout.fillWidth: true
                spacing: 3
                visible: root.hasConnectedDevices

                Repeater {
                    model: ServiceBluetooth.list
                    delegate: BluetoothPill {
                        Layout.fillWidth: true
                        bluetooth: (modelData?.state === 1) ? modelData : null
                        topRadius: {
                            const l = ServiceBluetooth.list ?? []
                            for (let i = 0; i < l.length; i++) {
                                if (l[i].state === 1) return (i === index) ? 20 : 5
                            }
                            return 20
                        }
                        bottomRadius: {
                            const l = ServiceBluetooth.list ?? []
                            let last = -1
                            for (let i = 0; i < l.length; i++) {
                                if (l[i].state === 1) last = i
                            }
                            return (last === index) ? 20 : 5
                        }
                    }
                }
            }

            // ── Paired Devices ───────────────────────────────────
            CustomText { Layout.topMargin: 16; content: "Paired Devices"; size: 13; customColor: Colors.primary }

            // Empty state — none paired
            Rectangle {
                Layout.topMargin: 6
                Layout.fillWidth: true
                implicitHeight: 90
                visible: !root.hasPairedDevices
                color: Colors.surfaceContainerHigh
                radius: 20

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 46; implicitHeight: 46

                        MaterialShapes.ShapeCanvas {
                            anchors.fill: parent
                            roundedPolygon: MaterialShapeFn.getCookie6Sided()
                            color: Colors.surfaceContainerHighest
                        }
                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "bluetooth_searching"; iconSize: 22; customColor: Colors.outline
                        }
                    }
                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: "No paired devices"; size: 13; customColor: Colors.outline
                    }
                }
            }

            ColumnLayout {
                Layout.topMargin: 6
                Layout.fillWidth: true
                spacing: 3
                visible: root.hasPairedDevices

                Repeater {
                    model: ServiceBluetooth.list
                    delegate: BluetoothPill {
                        Layout.fillWidth: true
                        bluetooth: {
                            const d = modelData
                            return (d && (d.paired ?? d.bonded ?? false) && d.state !== 1) ? d : null
                        }
                        topRadius: {
                            const l = ServiceBluetooth.list ?? []
                            for (let i = 0; i < l.length; i++) {
                                if ((l[i].paired ?? l[i].bonded ?? false) && l[i].state !== 1)
                                    return (i === index) ? 20 : 5
                            }
                            return 20
                        }
                        bottomRadius: {
                            const l = ServiceBluetooth.list ?? []
                            let last = -1
                            for (let i = 0; i < l.length; i++) {
                                if ((l[i].paired ?? l[i].bonded ?? false) && l[i].state !== 1) last = i
                            }
                            return (last === index) ? 20 : 5
                        }
                    }
                }
            }

            // ── Nearby Devices ───────────────────────────────────
            RowLayout {
                Layout.topMargin: 16
                Layout.fillWidth: true
                CustomText { content: "Nearby Devices"; size: 13; customColor: Colors.primary }
                Item { Layout.fillWidth: true }
                MaterialIconSymbol {
                    content: "refresh"; iconSize: 18; customColor: Colors.outline
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = true
                        }
                    }
                }
            }

            // Empty state — none nearby
            Rectangle {
                Layout.topMargin: 6
                Layout.fillWidth: true
                implicitHeight: 90
                visible: !root.hasNearbyDevices
                color: Colors.surfaceContainerHigh
                radius: 20

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 46; implicitHeight: 46

                        MaterialShapes.ShapeCanvas {
                            anchors.fill: parent
                            roundedPolygon: MaterialShapeFn.getCookie6Sided()
                            color: Colors.surfaceContainerHighest
                        }
                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "bluetooth_searching"; iconSize: 22; customColor: Colors.outline
                        }
                    }
                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: "No nearby devices"; size: 13; customColor: Colors.outline
                    }
                }
            }

            ColumnLayout {
                Layout.topMargin: 6
                Layout.fillWidth: true
                spacing: 3
                visible: root.hasNearbyDevices

                Repeater {
                    model: ServiceBluetooth.list
                    delegate: BluetoothPill {
                        Layout.fillWidth: true
                        bluetooth: {
                            const d = modelData
                            return (d && !(d.paired ?? d.bonded ?? false) && d.state !== 1) ? d : null
                        }
                        topRadius: {
                            const l = ServiceBluetooth.list ?? []
                            for (let i = 0; i < l.length; i++) {
                                if (!(l[i].paired ?? l[i].bonded ?? false) && l[i].state !== 1)
                                    return (i === index) ? 20 : 5
                            }
                            return 20
                        }
                        bottomRadius: {
                            const l = ServiceBluetooth.list ?? []
                            let last = -1
                            for (let i = 0; i < l.length; i++) {
                                if (!(l[i].paired ?? l[i].bonded ?? false) && l[i].state !== 1) last = i
                            }
                            return (last === index) ? 20 : 5
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
