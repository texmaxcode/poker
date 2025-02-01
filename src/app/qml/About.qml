import QtQuick
import QtQuick.Controls

Page {
    Text {
        anchors.top: parent.top
        text: "About"
        color: "white"
    }
    Button {
        anchors.centerIn: parent
        text: "Back to Dashboard"

        onClicked: {
          stackView.pop()
          simulator.test_orm()
        }
    }
}