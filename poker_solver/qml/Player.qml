 import QtQuick
 import QtQuick.Layouts

 Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true
    property string name: "Default"
    property string first_card: ""
    property string second_card: ""
    property string color: "black"
    property string position: ""

    Rectangle {
        id: border
        anchors.centerIn: parent
        radius: 30
        opacity: 0.5
        color: root.color
        width: 20
        height: 20
        PropertyAnimation on width { to: 300}
        PropertyAnimation on height { to: 330}
    }

    RowLayout {
        anchors.top: border.top
        anchors.horizontalCenter: border.horizontalCenter
        anchors.topMargin: 20

        Card {
            id: first_card
            card: root.first_card
            flipped: true
        }

        Card {
            id: second_card
            card: root.second_card
            flipped:true
        }
    }

    RowLayout {
        anchors.bottom: stack_count.top
        anchors.horizontalCenter: border.horizontalCenter
        anchors.bottomMargin: 10
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
            text: "300 BB"
            color: "white"
            font.pointSize: 22
        }
    }
}