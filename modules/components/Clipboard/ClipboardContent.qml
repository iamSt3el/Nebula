import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Rectangle{
    id: container
    implicitWidth: parent.width
    property string searchText: ""
    color: Settings.layoutColor
    anchors.bottom: parent.bottom
    topRightRadius: 20
    topLeftRadius: 20
    signal closed
    property var filteredEntries: ServiceCliphist.filteredEntries

    Behavior on implicitHeight{
        NumberAnimation{
            duration: 300
            easing.type: Easing.OutQuad
        }
    }
    //
    // layer.enabled: true
    // layer.effect: MultiEffect{
    //     shadowEnabled: true
    //     shadowBlur: 0.4
    //     shadowOpacity: 1.0
    //     shadowColor: Qt.alpha(Colors.shadow, 1)
    // }
    // Connections{
    //     target: clipLoader
    //     function onAnimationChanged(){
    //         if(clipLoader.animation){
    //             timer.start()
    //         }else{
    //             col.visible = false
    //         }
    //     }
    // }


    Timer{
        id: timer
        interval: 300
        running: true
        onTriggered:{
            col.visible = true
        }
    }


    Component.onCompleted: {
        searchInput.forceActiveFocus()
    }

    ColumnLayout{
        id: col
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        visible: false

        NumberAnimation on opacity{
            from: 0
            to: 1
            duration: 100
            running: col.visible
        }

        NumberAnimation on scale{
            from: 0.8
            to: 1
            duration: 100
            running: col.visible
        }

        Rectangle{
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            radius: 20
            color: Colors.surfaceContainer
            ColumnLayout{
                anchors.fill: parent
                spacing: 0
                Rectangle{
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: Colors.surfaceContainerHigh
                    radius: 20

                    RowLayout{
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        MaterialIconSymbol{
                            content: "search"
                            iconSize: 20
                        }

                        TextInput{
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignVCenter
                            verticalAlignment: TextInput.AlignVCenter
                            focus: true
                            clip: true
                            text: ""
                            font.pixelSize: 16
                            color: Colors.inverseSurface
                            onTextChanged: {
                                ServiceCliphist.updateSearch(text)
                            }



                            onAccepted: {
                                const item = clipboardList.itemAtIndex(clipboardList.activeIndex)
                                if (item) {
                                    container.closed()
                                    ServiceCliphist.copy(item.modelData)
                                }
                            }

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Down) {
                                    if (clipboardList.activeIndex < clipboardList.count - 1) {
                                        clipboardList.activeIndex++
                                        clipboardList.positionViewAtIndex(clipboardList.activeIndex, ListView.Contain)
                                    }
                                    event.accepted = true
                                }
                                else if (event.key === Qt.Key_Up) {
                                    if (clipboardList.activeIndex > 0) {
                                        clipboardList.activeIndex--
                                        clipboardList.positionViewAtIndex(clipboardList.activeIndex, ListView.Contain)
                                    }
                                    event.accepted = true
                                }
                                else if (event.key === Qt.Key_Delete) {
                                    const item = clipboardList.itemAtIndex(clipboardList.activeIndex)
                                    if (item) {
                                        ServiceCliphist.deleteEntry(item.modelData)
                                    }
                                    event.accepted = true
                                }
                                else if(event.key === Qt.Key_Escape){
                                    container.closed()
                                }
                            }

                        }

                    }
                }
                RowLayout{
                    Layout.fillHeight: true
                    Layout.preferredHeight: 40
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10

                    MaterialIconSymbol{
                        content: "notes"
                        iconSize: 22
                    }
                    CustomText{
                        content: ServiceCliphist.items + " Items"
                        size: 14
                    }

                    Item{
                        Layout.fillWidth: true
                    }


                    Rectangle{
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: 30
                        radius: 10
                        color: refreshArea.containsMouse ? Colors.primary : Colors.surfaceContainerHigh

                        MaterialIconSymbol{
                            anchors.centerIn: parent
                            content: "cached"
                            iconSize: 20
                            color: refreshArea.containsMouse ? Colors.primaryText : Colors.surfaceText
                        }


                        Behavior on color{
                            ColorAnimation{
                                duration: 200
                            }
                        }

                        CustomMouseArea{
                            radius: parent.radius
                            id: refreshArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked:{
                                ServiceCliphist.refresh()
                            }
                        }

                        CustomToolTip{
                            visible: refreshArea.containsMouse
                            content: "Refresh"
                        }
                    }

                    Rectangle{
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: 30
                        radius: 10
                        color: area.containsMouse ? Colors.primary : Colors.surfaceContainerHigh

                        MaterialIconSymbol{
                            anchors.centerIn: parent
                            content: "clear_all"
                            iconSize: 20
                            color: area.containsMouse ? Colors.primaryText : Colors.surfaceText
                        }


                        Behavior on color{
                            ColorAnimation{
                                duration: 200
                            }
                        }

                        CustomMouseArea{
                            radius: parent.radius
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked:{
                                ServiceCliphist.wipe()
                            }
                        }

                        CustomToolTip{
                            visible: area.containsMouse
                            content: "Clear all"
                        }
                    }

                }

            }
        }

        ClippingWrapperRectangle{
            id: clippingWrapper
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10
            color: "transparent"
            clip: true

            ListView{
                id: clipboardList
                property int activeIndex : 0
                anchors.fill: parent
                anchors.margins: 5
                spacing: 5
                clip: true
                property bool animationsEnabled: false

                model: ScriptModel{
                    values: {
                        return container.filteredEntries
                        // const isHtmlImageEntry = (entry) => {
                        //     const text = ServiceCliphist.getEntryText(entry)
                        //     return text.startsWith("<meta") && text.includes("<img")
                        // }
                        //
                        // let filteredEntries = ServiceCliphist..filter(entry => !isHtmlImageEntry(entry))
                        //
                        //
                        // return filteredEntries
                    }
                    onValuesChanged: clipboardList.animationsEnabled= true
                }



                add: Transition {
                    enabled: clipboardList.animationsEnabled

                    NumberAnimation {
                        properties: "opacity,scale"
                        from: 0
                        to: 1
                        duration: 400
                        easing.type: Easing.OutQuad
                    }
                }

                remove: Transition {
                    enabled: clipboardList.animationsEnabled

                    NumberAnimation {
                        properties: "opacity,scale"
                        from: 1
                        to: 0
                        duration: 400
                        easing.type: Easing.OutQuad
                    }
                }

                move: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: 400
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        properties: "opacity,scale"
                        to: 1
                        duration: 400
                        easing.type: Easing.OutQuad
                    }
                }

                addDisplaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: 400
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        properties: "opacity,scale"
                        to: 1
                        duration: 400
                        easing.type: Easing.OutQuad
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: 400
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        properties: "opacity,scale"
                        to: 1
                        duration: 400
                        easing.type: Easing.OutQuad
                    }
                }

                delegate: Rectangle{
                    id: clipItem
                    required property var modelData
                    required property int index
                    property bool active: clipboardList.activeIndex === index

                    width: clipboardList.width
                    height: ServiceCliphist.entryIsImage(modelData) ? 120 : 60
                    color:  active ? Colors.primary : "transparent"
                    radius: 10

                    RowLayout{
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Item{
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            CustomText{
                                visible: !ServiceCliphist.entryIsImage(clipItem.modelData)
                                width: parent.width
                                content: ServiceCliphist.getEntryText(clipItem.modelData)
                                color: clipItem.active ? Colors.primaryText : Colors.surfaceVariantText
                                elide: Text.ElideRight
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                verticalAlignment: Text.AlignVCenter
                            }

                            // Image content
                            Loader{
                                visible: ServiceCliphist.entryIsImage(clipItem.modelData)
                                anchors.fill: parent
                                active: ServiceCliphist.entryIsImage(clipItem.modelData)

                                sourceComponent: ClipboardImage{
                                    entry: clipItem.modelData
                                }
                            }
                        }

                        //Delete button
                        Rectangle{
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            color: deleteMouseArea.containsMouse ? Qt.alpha(Colors.error, 0.5) : "transparent"
                            radius: height



                            MaterialIconSymbol{
                                anchors.centerIn: parent
                                content: "close"
                                iconSize: 20
                                fill: 1
                                color: clipItem.active ? Colors.primaryText : Colors.surfaceVariantText

                            }

                            MouseArea{
                                id: deleteMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    ServiceCliphist.deleteEntry(clipItem.modelData)
                                }
                            }
                        }

                    }

                    MouseArea{
                        id: clipItemMouseArea
                        anchors.fill: parent
                        anchors.rightMargin: 50
                        hoverEnabled: true      
                        cursorShape: Qt.PointingHandCursor
                        onEntered:{ 
                            clipboardList.activeIndex = clipItem.index

                        }
                        onClicked: {
                            container.closed()
                            ServiceCliphist.copy(clipItem.modelData)
                        }
                    }
                }
            }
        }   
    }    
}
