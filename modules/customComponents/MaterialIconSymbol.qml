import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import "MaterialPaths.js" as MaterialPaths

Item {
    id: root

    property string content: ""
    property alias text: root.content
    property real iconSize: 16
    property real fill: 0
    property color customColor: Colors.surfaceText
    property alias color: root.customColor
    property alias horizontalAlignment: fallbackText.horizontalAlignment
    property alias verticalAlignment: fallbackText.verticalAlignment
    property alias renderType: fallbackText.renderType
    property alias elide: fallbackText.elide

    implicitWidth: Math.round(iconSize)
    implicitHeight: Math.round(iconSize)
    width: implicitWidth
    height: implicitHeight

    readonly property string pathData: MaterialPaths.getPath(root.content, root.fill >= 0.5)

    Shape {
        id: vectorShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.pathData !== ""

        ShapePath {
            fillColor: root.customColor
            strokeColor: "transparent"

            Behavior on fillColor {
                ColorAnimation { duration: 200 }
            }

            PathSvg {
                path: root.pathData
            }
        }

        transform: Scale {
            xScale: root.width / 960
            yScale: root.height / 960
            origin.x: 0
            origin.y: 0
        }
    }

    CustomText {
        id: fallbackText
        anchors.centerIn: parent
        visible: root.pathData === ""
        content: root.content
        customColor: root.customColor
        size: Math.round(root.iconSize)
        font.family: root.fill >= 0.5 ? IconFont.filledFamily : IconFont.family
    }
}
