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
    /// If false (default), hole cards follow the parent binding only — click-to-flip breaks that binding
    /// and was letting opponents’ pockets appear face-up.
    property bool interactivePeek: false

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
        when: tableCard || flipable.flipped
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
        rotation.angle = (tableCard || flipable.flipped) ? 180 : 0
    }

    MouseArea {
        anchors.fill: parent
        enabled: !tableCard && interactivePeek
        onClicked: flipable.flipped = !flipable.flipped
    }
}
