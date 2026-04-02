import QtQuick
import Theme 1.0

/// Compact HUD action pill (fold / call / raise / check). Hover/press use an overlay so `opacity` stays bindable (e.g. dimmed when inactive).
Rectangle {
    id: root

    property alias label: lbl.text
    property color buttonColor: Theme.panelBorder
    property color textColor: Theme.textPrimary
    property int fontSize: 14
    property bool boldFont: true
    property bool clickEnabled: true
    property int pillWidth: 0
    property int horizontalPadding: 24

    signal clicked()

    implicitWidth: pillWidth > 0 ? pillWidth : Math.max(76, lbl.implicitWidth + horizontalPadding)
    implicitHeight: 38
    radius: 6
    color: buttonColor
    clip: true

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: ma.containsMouse && root.clickEnabled
        color: ma.pressed ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.1)
    }

    Text {
        id: lbl
        z: 1
        anchors.centerIn: parent
        color: root.textColor
        font.family: Theme.fontFamilyUi
        font.pointSize: root.fontSize
        font.bold: root.boldFont
    }

    MouseArea {
        id: ma
        z: 2
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.clickEnabled
        onClicked: {
            if (root.clickEnabled)
                root.clicked()
        }
    }
}
