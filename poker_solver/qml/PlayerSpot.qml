 import QtQuick
 import QtQuick.Layouts

 Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Rectangle {
        id: border
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        radius: 30
        opacity: 0.5
        color: "black"
        width: 20
        height: 20
        PropertyAnimation on width { to: 230}
        PropertyAnimation on height { to: 290}
    }

    RowLayout {
        anchors.top: border.top
        anchors.horizontalCenter: border.horizontalCenter
        anchors.topMargin: 20

        Rectangle {
            color: "white"
            width: 100
            height: 160
            radius: 5
            Image {
              id: first_card 
              width: 100 
              height: 160 
              source: "assets/cards_svgs/clubs_ace.svg"
            }
        }

        Rectangle {
            color: "white"
            width: 100
            height: 160
            radius: 5
            Image {
              id: second_card 
              width: 100 
              height: 160 
              source: "assets/cards_svgs/spades_2.svg"
            }
        }
    }

    Rectangle {
        id: name
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: stack_count.top
            bottomMargin: 7 
        }
        radius: 10
        opacity: 0.8
        color: "white"
        width: 20
        height: 20
        PropertyAnimation on width { to: 200}
        PropertyAnimation on height { to: 40}

        Text {
            anchors.centerIn: parent
            text: "Max Gloom"
            color: "black"
            font.pointSize: 22
            font.bold: true
        }
    }

    Rectangle {
        id: stack_count
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 15
        }
        radius: 10
        color: "black"
        width: 20
        height: 20
        PropertyAnimation on width { to: 200}
        PropertyAnimation on height { to: 40}

        Text {
            anchors.centerIn: parent
            text: "300 BB"
            color: "white"
            font.pointSize: 22
        }
    }
}