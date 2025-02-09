import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    Layout.fillWidth: true
    Layout.fillHeight: true

    Rectangle {
        anchors.fill: parent
        opacity: 0.2
        color: "black"
        SequentialAnimation on color {
            ColorAnimation { to: "red"; duration: 1000; }
            ColorAnimation { to: "yellow"; duration: 1000; }
            ColorAnimation { to: "green"; duration: 1000; }
            running: true
            loops: Animation.Infinite
        }
    }

    Button {
        anchors.centerIn: parent
        text: "About"
        onClicked: stackView.push("About.qml")
    }
}