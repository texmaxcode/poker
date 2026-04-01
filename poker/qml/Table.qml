import QtQuick

/// Pot above board, centered on the full playfield (parent fills tableArea).
Item {
    id: table_container
    anchors.fill: parent

    property int pot_amount: 0
    property int smallBlind: 1
    property int bigBlind: 3
    property string board0: ""
    property string board1: ""
    property string board2: ""
    property string board3: ""
    property string board4: ""

    Column {
        id: col
        spacing: 6
        anchors.centerIn: parent

        Rectangle {
            id: pot_display
            width: 200
            height: 36
            anchors.horizontalCenter: parent.horizontalCenter
            radius: 10
            color: "#cc00113a"
            border.color: "#55ffffff"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "$" + table_container.pot_amount
                color: "white"
                font.bold: true
                font.pointSize: 14
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Blinds %1 / %2").arg(table_container.smallBlind).arg(table_container.bigBlind)
            color: "#c8d8f0"
            font.pointSize: 11
            font.bold: true
        }

        Row {
            id: cardRow
            spacing: 6
            anchors.horizontalCenter: parent.horizontalCenter
            TableBoardCard {
                card: table_container.board0
                staggerIndex: 0
            }
            TableBoardCard {
                card: table_container.board1
                staggerIndex: 1
            }
            TableBoardCard {
                card: table_container.board2
                staggerIndex: 2
            }
            TableBoardCard {
                card: table_container.board3
                staggerIndex: 3
            }
            TableBoardCard {
                card: table_container.board4
                staggerIndex: 4
            }
        }
    }
}
