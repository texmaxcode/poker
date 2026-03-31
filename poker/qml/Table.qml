import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: table_container
    Layout.fillWidth: true
    Layout.fillHeight: true

    property int pot_amount: 333
    property alias model: repeater.model

    Rectangle {
        id: pot_display
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
        id: pot_text
        anchors.centerIn: pot_display
        text: `$${table_container.pot_amount}`
        color: "white"
        font.bold: true
        font.pointSize: 24
    }

    Item {
        id: cards
        width: 670
        height: 190
        anchors.bottom: table_container.bottom
        anchors.horizontalCenter: table_container.horizontalCenter
        anchors.bottomMargin: 20

        RowLayout {
            Repeater {
                id: repeater
                model: table_container.model
                delegate: Card {
                    card: model.card
                    flipped: model.flipped
                }
            }
        }
    }
}