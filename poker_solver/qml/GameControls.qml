import QtQuick
import QtQuick.Controls
import QtQuick.Layouts



Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    Rectangle {
      id: message
      anchors.bottom: buttons.top
      anchors.bottomMargin: 10
      width:  460
      height: 60
      color: "white"
      radius: 20

      Text {
        anchors.centerIn: parent
        text: "The winner has Two Pair AsAc"
        font.pointSize: 20
        font.bold: true
      }

    }
    RowLayout {
        id: buttons
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        Rectangle {
            id: fold_button
            color: "#D61F1F"
            width: 150
            height: 60
            radius: 10

            Text {
                anchors.centerIn: parent
                text: "FOLD"
                font.pointSize: 24
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: stackView.push("About.qml")
            }
        }

        Rectangle {
            id: call_button
            color: "#FFD301"
            width: 150
            height: 60
            radius: 10

            Text {
                anchors.centerIn: parent
                text: "CALL"
                font.pointSize: 24
                font.bold: true
            }
        }

        Rectangle {
            id: raise_button
            color: "#006B3D"
            width: 150
            height: 60
            radius: 10

            Text {
                anchors.centerIn: parent
                text: "RAISE"
                font.pointSize: 24
                font.bold: true
            }
        }
    }
}