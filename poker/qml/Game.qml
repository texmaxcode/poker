import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: game_screen
    objectName: "game_screen"
    padding: 0

    property int pot: 0
    property int smallBlind: 1
    property int bigBlind: 3
    property var seatStacks: [100, 100, 100, 100, 100, 100]
    property var seatC1: ["", "", "", "", "", ""]
    property var seatC2: ["", "", "", "", "", ""]
    property var seatInHand: [true, true, true, true, true, true]
    property int buttonSeat: 0

    property string board0: ""
    property string board1: ""
    property string board2: ""
    property string board3: ""
    property string board4: ""
    property string statusText: qsTr("Starting…")
    property bool showdown: false
    property int actingSeat: -1
    property int decisionSecondsLeft: 0
    property bool humanMoreTimeAvailable: false
    property bool humanCanCheck: false

    signal buttonClicked(string button)

    readonly property real screenRef: Math.max(320, Math.min(width, height))

    function seatRole(seat) {
        var n = 6
        var r = (seat - game_screen.buttonSeat + n * 10) % n
        var names = ["BTN", "SB", "BB", "UTG", "HJ", "CO"]
        return names[r]
    }

    background: Rectangle {
        color: "transparent"
    }

    // Playfield uses full window width; stops above the bottom HUD so nothing hides under it.
    Item {
        id: tableArea
        z: 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: game_controls.top
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        anchors.topMargin: 0
        anchors.bottomMargin: 0

        readonly property point feltCenter: Qt.point(width / 2, height / 2)

        // Seats sit outside the wood rail (dark carpet), not on the green felt.
        readonly property real seatHalfW: 124
        readonly property real seatHalfH: 136
        readonly property real seatGap: 14
        // Layout ellipse (seat orbit): keeps players roughly where they are now.
        readonly property real maxLayoutOvalW: Math.max(260, width - 4 * seatHalfW - 2 * seatGap - 28)
        readonly property real maxLayoutOvalH: Math.max(200, height - 4 * seatHalfH - 2 * seatGap - 40)
        readonly property real layoutOvalW: Math.min(Math.min(width * 0.99, height * 1.36), maxLayoutOvalW)
        readonly property real layoutOvalH: Math.min(Math.min(height * 0.76, width * 0.48), maxLayoutOvalH)
        // Drawn felt extends well past layout ellipse (seats unchanged).
        readonly property real feltBleedW: Math.max(300, width * 0.16)
        readonly property real feltBleedH: Math.max(240, height * 0.18)
        readonly property real feltOvalW: Math.min(layoutOvalW + feltBleedW, width - 8)
        readonly property real feltOvalH: Math.min(layoutOvalH + feltBleedH, height - 8)
        // Outside rail; cap so diagonal seats (cos 30°) stay inside the window.
        readonly property real orbitRxRaw: layoutOvalW * 0.5 + seatGap + seatHalfW
        readonly property real orbitRyRaw: layoutOvalH * 0.5 + seatGap + seatHalfH
        readonly property real orbitRx: Math.min(orbitRxRaw, (width * 0.5 - seatHalfW - 12) / 0.866)
        readonly property real orbitRy: Math.min(orbitRyRaw, (height * 0.5 - seatHalfH - 12) / 0.866)

        PokerTableBackground {
            z: 0
            anchors.fill: parent
            feltOvalW: tableArea.feltOvalW
            feltOvalH: tableArea.feltOvalH
        }

        Table {
            id: table
            z: 3
            anchors.fill: parent
            pot_amount: game_screen.pot
            smallBlind: game_screen.smallBlind
            bigBlind: game_screen.bigBlind
            board0: game_screen.board0
            board1: game_screen.board1
            board2: game_screen.board2
            board3: game_screen.board3
            board4: game_screen.board4
        }

        Repeater {
            z: 2
            model: 6
            delegate: Item {
                id: seatWrap
                required property int index
                width: 248
                height: 272
                readonly property real angle: Math.PI / 2 - index * 2 * Math.PI / 6
                // Side seats (not top/bottom): nudge outward toward window corners.
                readonly property real cornerBoost: (index === 1 || index === 2 || index === 4 || index === 5) ? 1.09 : 1.0
                readonly property real scx: tableArea.feltCenter.x + tableArea.orbitRx * Math.cos(angle) * cornerBoost
                readonly property real scy: tableArea.feltCenter.y + tableArea.orbitRy * Math.sin(angle) * cornerBoost
                x: scx - width / 2
                y: scy - height / 2

                Player {
                    anchors.fill: parent
                    name: index === 0 ? qsTr("You (seat 1)") : qsTr("Bot %1").arg(index + 1)
                    position: game_screen.seatRole(index)
                    isDealer: index === game_screen.buttonSeat
                    first_card: game_screen.seatC1[index] !== undefined ? game_screen.seatC1[index] : ""
                    second_card: game_screen.seatC2[index] !== undefined ? game_screen.seatC2[index] : ""
                    stackChips: game_screen.seatStacks[index] !== undefined ? game_screen.seatStacks[index] : 100
                    show_cards: index === 0
                    isActing: game_screen.actingSeat === index
                    opacity: (game_screen.seatInHand[index] !== false) ? 1.0 : 0.42
                }
            }
        }
    }

    GameControls {
        id: game_controls
        z: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        pageRoot: game_screen
        statusText: game_screen.statusText
        decisionSecondsLeft: game_screen.decisionSecondsLeft
        humanMoreTimeAvailable: game_screen.humanMoreTimeAvailable
        humanCanCheck: game_screen.humanCanCheck
    }
}
