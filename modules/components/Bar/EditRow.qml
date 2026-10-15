import QtQuick
import QtQuick.Layouts

Item {
    id: root

    default property alias content: _layout.data

    Layout.fillWidth: true
    implicitHeight: _layout.implicitHeight + 12

    ColumnLayout {
        id: _layout
        anchors.fill: parent
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        spacing: 12
    }
}
