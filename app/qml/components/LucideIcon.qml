/* Lucide icon wrapper rendered with Apple SF Symbols vector fidelity. */

import QtQuick
import QtQuick.Effects

Item {
    id: root

    property string name: ""
    property color color: "#f2f0e9"

    implicitWidth: 20
    implicitHeight: 20

    Image {
        id: glyph

        anchors.fill: parent
        source: root.name ? ("../assets/lucide/" + root.name + ".svg") : ""
        sourceSize.width: Math.ceil(root.width * Screen.devicePixelRatio)
        sourceSize.height: Math.ceil(root.height * Screen.devicePixelRatio)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: glyph
        colorization: 1
        colorizationColor: Qt.rgba(root.color.r, root.color.g, root.color.b, 1)
        opacity: root.color.a
    }
}
