import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

/// Framed panel matching Training home: semi-transparent `Theme.panel`, chrome border, section title.
Rectangle {
    id: root
    property string panelTitle: ""
    property real panelOpacity: 0.5
    property real borderOpacity: 0.5

    Layout.fillWidth: true
    clip: true
    default property alias content: body.data

    radius: Theme.trainerPanelRadius
    color: Qt.alpha(Theme.panel, panelOpacity)
    border.width: 1
    border.color: Qt.alpha(Theme.chromeLine, borderOpacity)

    implicitHeight: col.implicitHeight + 2 * Theme.trainerPanelPadding

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.trainerPanelPadding
        spacing: Theme.uiGroupInnerSpacing

        Label {
            visible: root.panelTitle.length > 0
            Layout.fillWidth: true
            text: root.panelTitle
            font.bold: true
            font.pixelSize: Theme.trainerSectionPx
            color: Theme.textPrimary
            wrapMode: Text.WordWrap
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: Theme.uiGroupInnerSpacing
        }
    }
}
