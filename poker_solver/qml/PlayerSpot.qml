 import QtQuick
 import QtQuick.Layouts

 Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Rectangle {
        id: border
        anchors.centerIn: parent
        radius: 30
        opacity: 0.5
        color: "black"
        width: 20
        height: 20
        PropertyAnimation on width { to: 300}
        PropertyAnimation on height { to: 330}
    }

    RowLayout {
        anchors.top: border.top
        anchors.horizontalCenter: border.horizontalCenter
        anchors.topMargin: 20

        Card {
            id: first_card
            card: "clubs_jack.svg"
            flipped: true
        }

        Card {
            id: second_card
            card: "spades_10.svg"
            flipped:true
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
        PropertyAnimation on width { to: 270}
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
            bottom: border.bottom
            bottomMargin: 15
        }
        radius: 10
        color: "black"
        width: 20
        height: 20
        PropertyAnimation on width { to: 270}
        PropertyAnimation on height { to: 40}

        Text {
            anchors.centerIn: parent
            text: "300 BB"
            color: "white"
            font.pointSize: 22
        }
    }
}