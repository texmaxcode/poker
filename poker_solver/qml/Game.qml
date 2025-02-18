import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import com.musclecomputing

Page {
    id: root
    width: 1700
    height: 1000

    Game {
        id: game
    }

    property alias pot: table.pot_amount

    Image {
        id: poker_table
        fillMode: Image.PreserveAspectCrop
        anchors.fill: parent
        source: "qrc:/assets/images/poker_table.jpg"
    }

    ListModel {
        id: cardsModel
        ListElement {
            card: "spades_7.svg"
            flipped: true
        }
        ListElement {
            card: "clubs_jack.svg"
            flipped: true
        }
        ListElement {
            card: "hearts_2.svg"
            flipped: true
        }
    }

    RowLayout {
        anchors.fill: parent
        ColumnLayout {
            Player {
                id: first_player
                name: "Bot 1"
                position: "UTG"
                first_card: "hearts_ace.svg"
                second_card: "hearts_king.svg"
            }
            Player {
                id: second_player
                name: "Bot 2"
                position: "SB"
                first_card: "clubs_ace.svg"
                second_card: "clubs_king.svg"
            }
        }
        ColumnLayout {
            Player {
                id: third_player
                name: "Bot 3"
                position: "CO"
                first_card: "diamonds_ace.svg"
                second_card: "diamonds_king.svg"
            }
            Table {
                id: table
                pot_amount: 0
                model: cardsModel
            }
            Player {
                id: fourth_player
                name: "Bot Four"
                show_cards: true
                position: "BB"
                first_card: "spades_ace.svg"
                second_card: "spades_king.svg"
            }
        }
        ColumnLayout {
            Player {
                id: player_five
                color: "red"
                position: "BT"
                name: "Bot Five Lucky"
                first_card: "spades_2.svg"
                second_card: "clubs_2.svg"
            }
            GameControls {
                id: game_controls
            }
        }
    }
}