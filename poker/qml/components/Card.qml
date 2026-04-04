import QtQuick
import Theme 1.0

Flipable {
    id: flipable
    width: Theme.boardCardWidth
    height: Theme.boardCardHeight

    property bool flipped: false
    property string card: "spades_ace.svg"
    /// Community cards are always face-up; holes use flipped/show_cards from Player.
    property bool tableCard: false
    /// Skip flip animation (training / instant reveal).
    property bool instantFace: false
    /// Bumps each new hand (`Game.handSeq`) so rotation snaps to match concealed/revealed state.
    property int dealEpoch: 0

    front: Image {
        source: "qrc:/assets/cards/blue2.svg"
        anchors.fill: parent
        fillMode: Image.Stretch
        /// Rasterize SVGs at widget size so the art fills the rect (avoids letterboxing from aspect fit).
        sourceSize.width: Math.max(1, Math.round(flipable.width))
        sourceSize.height: Math.max(1, Math.round(flipable.height))
    }
    back: Image {
        source: (card.length === 0)
                ? "qrc:/assets/cards/blue2.svg"
                : ("qrc:/assets/cards/" + card)
        anchors.fill: parent
        fillMode: Image.Stretch
        sourceSize.width: Math.max(1, Math.round(flipable.width))
        sourceSize.height: Math.max(1, Math.round(flipable.height))
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
                duration: flipable.instantFace ? 0 : 620
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
        /// Training: skip the “deal face-down” snap — stay revealed (see `instantFace` on `Player`).
        if (instantFace && flipped && card.length > 0) {
            rotation.angle = 180
            return
        }
        rotation.angle = 0
    }

    onCardChanged: {
        if (tableCard)
            return
        if (card.length === 0)
            rotation.angle = 0
    }
}
