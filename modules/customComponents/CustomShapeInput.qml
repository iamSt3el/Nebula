import QtQuick
import qs.modules.utils
import "../MatrialShapes" as MaterialShapes
import "../MatrialShapes/material-shapes.js" as MaterialShapeFn

FocusScope {
    id: root

    property alias text: textInput.text
    property string placeholderText: ""
    property color placeholderColor: Colors.outline

    signal accepted()

    implicitHeight: 40

    ListModel { id: shapesModel }

    TextInput {
        id: textInput
        anchors.fill: parent
        color: "transparent"
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhSensitiveData
        font.pixelSize: 20
        enabled: root.enabled
        focus: true
        cursorDelegate: Item {}

        property int trackedLength: 0

        onLengthChanged: {
            if (length > trackedLength) {
                for (let i = 0; i < length - trackedLength; i++)
                    shapesModel.append({})
            } else {
                for (let i = 0; i < trackedLength - length; i++)
                    if (shapesModel.count > 0)
                        shapesModel.remove(shapesModel.count - 1)
            }
            trackedLength = length
        }

        onAccepted: root.accepted()
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.placeholderText
        color: root.placeholderColor
        font.pixelSize: 20
        visible: textInput.length === 0
    }

    ListView {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 30
        orientation: Qt.Horizontal
        spacing: 5
        clip: false
        interactive: false
        model: shapesModel

        delegate: MaterialShapes.ShapeCanvas {
            width: 30
            height: 30
            color: Colors.primary
            roundedPolygon: MaterialShapeFn.getCircle()
            Component.onCompleted: roundedPolygon = MaterialShapeFn.getCookie7Sided()
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: shapesModel.count * 35
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 30
        radius: 1
        color: Colors.primary
        visible: textInput.activeFocus

        SequentialAnimation on opacity {
            running: textInput.activeFocus
            loops: Animation.Infinite
            NumberAnimation { to: 0; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
        }
    }
}
