import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import com.musclecomputing

Page {
    Game {
        id: game
    }

    Image {
        id: poker_table
        fillMode: Image.PreserveAspectCrop
        anchors.fill: parent
        source: "assets/images/poker_table.jpg"
    }

    RowLayout {
        anchors.fill: parent
        ColumnLayout {
            Seat {
                id: first_seat
            }
            Seat {
                id: second_player
            }
        }
        ColumnLayout {
            Seat {
                id: third_player
            }
            Table {
                id: table
                pot_amount: game.game_pot
            }
            Seat {
                id: fourth_player
            }
        }
        ColumnLayout {
            Seat {
                id: player_five
                color: "red"
            }
            GameControls {
                id: game_controls
            }
        }
    }
}