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
            }
            Player {
                id: second_player
                name: "Bot 2"
            }
        }
        ColumnLayout {
            Player {
                id: third_player
                name: "Bot 3"
            }
            Table {
                id: table
            }
            Player {
                id: fourth_player
                name: "Bot Four"
            }
        }
        ColumnLayout {
            Player {
                id: player_five
                name: "Bot Five Lucky"
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