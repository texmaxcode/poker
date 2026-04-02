import QtQuick

Flipable {
    id: flipable
    width: 100
    height: 148

    property bool flipped: false
    property string card: "spades_ace.svg"
    /// Community cards are always face-up; holes use flipped/show_cards from Player.
    property bool tableCard: false
    /// Bumps each new hand (`Game.handSeq`) so rotation snaps to match concealed/revealed state.
    property int dealEpoch: 0

    front: Image {
        source: "qrc:/assets/cards/blue2.svg"
        anchors.fill: parent
    }
    back: Image {
        source: (card.length === 0)
                ? "qrc:/assets/cards/blue2.svg"
                : ("qrc:/assets/cards/" + card)
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
        /// Hole cards: never rotate to the rank/suit side without a real card string (avoids stuck / phantom faces).
        when: tableCard || (flipable.flipped && card.length > 0)
    }

    transitions: [
        Transition {
            to: "back"
            NumberAnimation {
                target: rotation
                property: "angle"
                duration: 620
                easing.type: Easing.InOutCubic
            }
        },
        Transition {
            from: "back"
            NumberAnimation {
                target: rotation
                property: "angle"
                duration: 0
            }
        }
    ]

    onDealEpochChanged: {
        if (tableCard)
            return
        rotation.angle = 0
    }

    onCardChanged: {
        if (tableCard)
            return
        if (card.length === 0)
            rotation.angle = 0
    }
}
