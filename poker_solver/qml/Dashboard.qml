import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    Image {
        id: poker_table
        fillMode: Image.PreserveAspectCrop
        anchors.fill: parent
        source: "assets/images/poker_table.jpg"
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
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Rectangle {
                    id: controls
                    anchors.fill: parent
                    opacity: 0.1
                    color: "black"
                }
                Button {
                    anchors.centerIn: parent
                    text: "About"
                    onClicked: stackView.push("About.qml")
                }
            }
        }
    }
}