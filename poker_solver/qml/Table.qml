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
        anchors.bottom: cards.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
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

    Item {
        id: cards
        width: 670
        height: 190
        anchors.bottom: root.bottom
        anchors.horizontalCenter: root.horizontalCenter
        anchors.bottomMargin: 20

        RowLayout {
            Card {
                id: first_flop
                flipped: true
                card: "hearts_king.svg"
            }
            Card {
                id: second_flop
                card: "diamonds_10.svg"
            }
            Card {
                id: third_flop
                card: "spades_ace.svg"
            }
        }
    }
}