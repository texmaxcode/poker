import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    Rectangle {
        id: pot
        width: 230
        height: 60
        color: "#00113a"
        opacity: 0.5
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        radius: 10
    }

    Text {
        anchors.centerIn: pot
        id: pot_amount
        text: "$3000"
        color: "white"
        font.bold: true
        font.pointSize: 24
    }

    RowLayout {
        id: cards
        anchors.bottom: root.bottom
        anchors.horizontalCenter: root.horizontalCenter

        Card {
            id: first_flop
            width: 100
            height: 160
            card: "hearts_king.svg"
        }
        Card {
            id: second_flop
            width: 100
            height: 160
            card: "diamonds_10.svg"
        }
        Card {
            id: third_flop
            width: 100
            height: 160
            card: "spades_ace.svg"
        }
        Card {
            id: turn
            width: 100
            height: 160
            card: "hearts_queen.svg"
        }
        Card {
            id: river
            width: 100
            height: 160
            card: "clubs_2.svg"
        }
    }
}