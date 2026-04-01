import QtQuick

Flipable {
    id: flipable
    width: 100
    height: 148

    property bool flipped: false
    property string card: "spades_ace.svg"
    /// Community cards are always face-up; holes use flipped/show_cards from Player.
    property bool tableCard: false

    front: Image {
        source: "qrc:/assets/cards_svgs/blue2.svg"
        anchors.fill: parent
    }
    back: Image {
        source: (card.length === 0)
                ? "qrc:/assets/cards_svgs/blue2.svg"
                : ("qrc:/assets/cards_svgs/" + card)
        anchors.fill: parent
    }

    transform: Rotation {
        id: rotation
        origin.x: flipable.width / 2
        origin.y: flipable.height / 2
        axis {
            x: 0
            y: 1
            z: 0
        }
        angle: 0
    }

    states: State {
        name: "back"
        PropertyChanges {
            target: rotation
            angle: 180
        }
        when: tableCard || flipable.flipped
    }

    transitions: Transition {
        NumberAnimation {
            target: rotation
            property: "angle"
            duration: 620
            easing.type: Easing.InOutCubic
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !tableCard
        onClicked: flipable.flipped = !flipable.flipped
    }
}
