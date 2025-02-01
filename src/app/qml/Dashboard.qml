import QtQuick
import QtQuick.Controls

Page {
    Image {
        id: poker_table
        fillMode: Image.PreserveAspectCrop
        anchors.fill: parent
        source: "assets/images/poker_table.jpg"
    }
    Button {
        anchors.centerIn: parent
        text: "About"
        onClicked: stackView.push("About.qml")
    }
}