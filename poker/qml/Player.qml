import QtQuick
import QtQuick.Layouts

/// Dark seat panel — sized for enlarged hole cards.
Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    property string name: "Default"
    property string first_card: ""
    property string second_card: ""
    property string color: "#2d3d5c"
    property string position: ""
    property bool isDealer: false
    property bool isActing: false
    property bool show_cards: false
    property int stackChips: 100

    // Two cards (100+gap) + margins + labels + stack
    implicitHeight: 268
    implicitWidth: 244

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "#252830"
        border.color: root.isActing ? "#3d8fd9" : (root.isDealer ? "#e8b84a" : "#4a5262")
        border.width: root.isActing ? 3 : (root.isDealer ? 2 : 1)
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Card {
                    card: root.first_card
                    flipped: root.show_cards
                }

                Card {
                    card: root.second_card
                    flipped: root.show_cards
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                Rectangle {
                    radius: 8
                    color: "#363c4a"
                    implicitWidth: 156
                    implicitHeight: root.isActing ? 48 : 34

                    Text {
                        anchors.fill: parent
                        anchors.margins: 4
                        text: root.isActing ? (root.name + "\n" + qsTr("Thinking…")) : root.name
                        color: "#e8ecf4"
                        font.pointSize: root.isActing ? 11 : 12
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        lineHeight: root.isActing ? 1.15 : 1.0
                        wrapMode: Text.NoWrap
                    }
                }

                Rectangle {
                    radius: 8
                    color: root.isDealer ? "#5c4a28" : "#4a3f35"
                    border.width: root.isDealer ? 2 : 1
                    border.color: root.isDealer ? "#f0c96a" : "#6b5d4a"
                    implicitWidth: 48
                    implicitHeight: 34

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.show_cards = !root.show_cards
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.position
                        color: root.isDealer ? "#fff0c0" : "#ffd88a"
                        font.pointSize: 14
                        font.bold: true
                    }
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 212
                Layout.preferredHeight: 36
                radius: 8
                color: root.color
                border.width: 1
                border.color: "#55ffffff"

                Text {
                    anchors.centerIn: parent
                    text: "$" + root.stackChips
                    color: "#f0f4ff"
                    font.pointSize: 15
                    font.bold: true
                }
            }
        }
    }
}
