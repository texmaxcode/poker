import QtQuick
import QtQuick.Layouts

/// Seat panel — hole cards hidden when folded; street bet shown in gold.
Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    property string name: "Default"
    property string first_card: ""
    property string second_card: ""
    property string color: "#2a1f18"
    property string position: ""
    property bool isDealer: false
    property bool isActing: false
    property bool show_cards: false
    property bool inHand: true
    property bool foldedDim: false
    /// Seat 0: show "Watching" when sitting out (not a fold).
    property bool humanWatching: false
    property int stackChips: 100
    property int streetBetChips: 0

    readonly property color gold: "#d4af37"
    readonly property color borderAct: "#ff8c42"
    readonly property color borderDealer: "#d4af37"
    readonly property color borderIdle: "#4a3a32"

    implicitHeight: 282
    implicitWidth: 228

    opacity: foldedDim ? 0.52 : 1.0

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "#15151c"
        border.color: root.isActing ? root.borderAct : (root.isDealer ? root.borderDealer : root.borderIdle)
        border.width: root.isActing ? 3 : (root.isDealer ? 2 : 1)
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 4

            /// Fixed height matches Card (148px) so fold / watch does not resize the seat panel.
            StackLayout {
                Layout.preferredHeight: 148
                Layout.fillWidth: true
                currentIndex: root.inHand ? 0 : 1

                Item {
                    Card {
                        id: c1
                        anchors.right: parent.horizontalCenter
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        card: root.first_card
                        flipped: root.show_cards
                    }

                    Card {
                        anchors.left: parent.horizontalCenter
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        card: root.second_card
                        flipped: root.show_cards
                    }
                }

                Item {
                    Text {
                        anchors.centerIn: parent
                        text: root.humanWatching ? qsTr("WATCHING") : qsTr("FOLDED")
                        color: root.humanWatching ? "#6a8aaa" : "#8a6a5a"
                        font.pointSize: root.humanWatching ? 18 : 22
                        font.bold: true
                        font.letterSpacing: 2
                    }
                }
            }

            /// Reserve one line so posting a bet does not jump the stack row.
            Item {
                Layout.preferredHeight: 26
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(200, parent.width - 8)
                    height: (root.inHand && root.streetBetChips > 0) ? 26 : 0
                    visible: height > 0
                    radius: 8
                    color: "#281a12"
                    border.width: 1
                    border.color: root.gold
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Bet %1").arg(root.streetBetChips)
                        color: root.gold
                        font.pointSize: 12
                        font.bold: true
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                Rectangle {
                    radius: 8
                    color: "#1e1e28"
                    implicitWidth: 156
                    implicitHeight: 48

                    Text {
                        anchors.fill: parent
                        anchors.margins: 4
                        text: root.isActing ? (root.name + "\n" + qsTr("Thinking…")) : root.name
                        color: "#e8e4dc"
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
                    color: root.isDealer ? "#3d3020" : "#2a2520"
                    border.width: root.isDealer ? 2 : 1
                    border.color: root.isDealer ? root.gold : "#5a4a40"
                    implicitWidth: 48
                    implicitHeight: 34

                    Text {
                        anchors.centerIn: parent
                        text: root.position
                        color: root.isDealer ? "#fff8e0" : "#e8c8a0"
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
                border.color: "#55d4af37"

                Text {
                    anchors.centerIn: parent
                    text: "$" + root.stackChips
                    color: "#f5f0e8"
                    font.pointSize: 15
                    font.bold: true
                }
            }
        }
    }
}
