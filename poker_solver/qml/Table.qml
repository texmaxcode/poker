import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property int pot_amount
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
        text: "$" + root.pot_amount
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
                card: "hearts_king.svg"
                flipped: true
            }
            Card {
                id: second_flop
                card: "diamonds_10.svg"
                flipped: true
            }
            Card {
                id: third_flop
                card: "spades_7.svg"
                flipped: true
            }
            Card {
                id: turn
                card: "clubs_jack.svg"
                flipped: true
            }
            Card {
                id: river
                card: "hearts_2.svg"
                flipped: true
            }
        }
    }
}