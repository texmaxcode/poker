 import QtQuick
 import QtQuick.Layouts

 Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true
    property var player
    property string name: ""
    property string first_card: ""
    property string second_card: ""
    property string color: "black"
    property string position: ""
    property bool show_cards: false
    property bool is_empty: true
    property int stack: 0

    Rectangle {
        id: border
        anchors.centerIn: parent
        radius: 30
        opacity: 0.5
        width: 20
        height: 20
        color: root.color
        PropertyAnimation on width { to: 300}
        PropertyAnimation on height { to: 330}
    }

    Row {
        anchors.top: border.top
        anchors.horizontalCenter: border.horizontalCenter
        anchors.topMargin: 20
        spacing: 7

        Item {
            visible: !root.is_empty
            Card {
                id: first_card
                card: root.first_card
                flipped: root.show_cards
            }

            Card {
                id: second_card
                card: root.second_card
                flipped: root.show_cards
            }
        }
    }

    Row {
        anchors.bottom: stack_count.top
        anchors.horizontalCenter: border.horizontalCenter
        anchors.bottomMargin: 10
        spacing: 7
        Rectangle {
            id: name
            radius: 10
            opacity: 0.8
            color: "white"
            width: 200
            height: 40

            Text {
                anchors.centerIn: parent
                text: root.name
                color: "black"
                font.pointSize: 18
            }
        }

        Rectangle {
            id: position
            radius: 10
            opacity: 0.8
            color: "pink"
            width: 65
            height: 40

            MouseArea {
               anchors.fill: parent
               onClicked: {root.show_cards = !root.show_cards;}
            }

            Text {
                anchors.centerIn: parent
                text: root.position
                color: "black"
                font.pointSize: 22
                font.bold: true
            }
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
            text: !is_empty ? `BB ${root.stack}`: ""
            color: "white"
            font.pointSize: 22
        }
    }
}