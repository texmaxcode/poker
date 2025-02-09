import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Rectangle {
        id: controls
        anchors.fill: parent
        opacity: 0.1
        color: "black"
    }
    Button {
        anchors.centerIn: parent
        text: "About"
        onClicked: stackView.push("About.qml")
    }
}