import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

Page {
    id: game_screen
    objectName: "game_screen"
    padding: 0
    font.family: Theme.fontFamilyUi

    BotNames {
        id: botNames
    }

    property int pot: 0
    /// Per-tier side pot sizes (main first); length > 1 means multiple pots — see `Table` HUD.
    property var sidePotAmounts: []
    property var seatStacks: [100, 100, 100, 100, 100, 100]
    property var seatC1: ["", "", "", "", "", ""]
    property var seatC2: ["", "", "", "", "", ""]
    property var seatInHand: [true, true, true, true, true, true]
    property var seatStreetChips: [0, 0, 0, 0, 0, 0]
    /// Engine: last action label this street per seat (Call / Raise / Check / Fold / …).
    property var seatStreetActions: ["", "", "", "", "", ""]
    property int maxStreetContrib: 0
    property int buttonSeat: 0
    property int sbSeat: -1
    property int bbSeat: -1
    property int playerCount: 6

    property string board0: ""
    property string board1: ""
    property string board2: ""
    property string board3: ""
    property string board4: ""
    property string statusText: qsTr("Starting…")
    /// Filenames like `spades_ace.svg` for the winning hole cards (win banner mini-cards).
    property var resultBannerCardAssets: []
    property string humanHandText: ""
    property bool showdown: false
    /// Bumps each new hand (`game::clear_for_new_hand`) so seats reset hole-card flip state.
    property int handSeq: 0
    property int actingSeat: -1
    property int decisionSecondsLeft: 0
    property bool humanMoreTimeAvailable: false
    property bool humanCanCheck: false
    property bool humanBbPreflopOption: false
    property bool humanCanRaiseFacing: false
    property int facingNeedChips: 0
    property int facingMinRaiseChips: 0
    property int facingMaxChips: 0
    property int facingPotAmount: 0
    property int openRaiseMinChips: 0
    property int openRaiseMaxChips: 0
    property int bbPreflopMinChips: 0
    property int bbPreflopMaxChips: 0
    property int humanStackChips: 0
    property bool humanBbCanRaise: false
    property var pokerGameAccess: null
    property bool humanSittingOut: false
    property var seatParticipating: [true, true, true, true, true, true]
    property bool humanCanBuyBackIn: false
    property int buyInChips: 100

    signal buttonClicked(string button)

    function seatRole(seat) {
        var n = game_screen.playerCount > 0 ? game_screen.playerCount : 6
        var btn = game_screen.buttonSeat
        var sb = game_screen.sbSeat
        var bb = game_screen.bbSeat
        var part = game_screen.seatParticipating
        function inDealingPool(idx) {
            if (idx < 0 || idx >= n)
                return false
            if (part && part.length > idx && part[idx] === false)
                return false
            return true
        }
        if (bb < 0)
            return "—"
        // Heads-up: BTN posts SB — show dealer as BTN, not SB (engine still posts SB correctly).
        if (seat === btn)
            return "BTN"
        if (sb >= 0 && seat === sb)
            return "SB"
        if (bb >= 0 && seat === bb)
            return "BB"
        // Clockwise from BB: non-blind seats are UTG, then optional middle(s), then CO (last before BTN).
        // 6-max: UTG — HJ — CO; 5-max: UTG — CO only (second seat is not "HJ"). Matches common charts / WPF flow.
        var order = []
        for (var k = 1; k <= n; k++) {
            var s = (bb + k) % n
            if (s !== btn && s !== sb && s !== bb && inDealingPool(s))
                order.push(s)
        }
        var m = order.length
        if (m > 0 && seat === order[0])
            return "UTG"
        if (m >= 2 && seat === order[m - 1])
            return "CO"
        if (m >= 3 && seat === order[m - 2])
            return "HJ"
        return "—"
    }

    background: BrandedBackground {
        anchors.fill: parent
    }

    Item {
        id: tableArea
        z: 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        readonly property point feltCenter: Qt.point(width / 2, height / 2)

        readonly property real seatHalfW: 109
        readonly property real seatHalfH: 156
        readonly property real seatGap: 10
        readonly property real maxLayoutOvalW: Math.max(260, width - 4 * seatHalfW - 2 * seatGap - 28)
        readonly property real maxLayoutOvalH: Math.max(200, height - 4 * seatHalfH - 2 * seatGap - 40)
        readonly property real layoutOvalW: Math.min(Math.min(width * 0.99, height * 1.36), maxLayoutOvalW)
        readonly property real layoutOvalH: Math.min(Math.min(height * 0.76, width * 0.48), maxLayoutOvalH)
        readonly property real feltBleedW: Math.max(360, width * 0.22)
        readonly property real feltBleedH: Math.max(280, height * 0.24)
        readonly property real feltOvalW: Math.min(layoutOvalW + feltBleedW, width - 8)
        readonly property real feltOvalH: Math.min(layoutOvalH + feltBleedH, height - 8)
        readonly property real orbitRxRaw: layoutOvalW * 0.5 + seatGap + seatHalfW
        readonly property real orbitRyRaw: layoutOvalH * 0.5 + seatGap + seatHalfH
        readonly property real orbitRx: Math.min(orbitRxRaw, (width * 0.5 - seatHalfW - 12) / 0.866)
        readonly property real orbitRy: Math.min(orbitRyRaw, (height * 0.5 - seatHalfH - 12) / 0.866)

        TableFelt {
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
            sidePotAmounts: game_screen.sidePotAmounts
            actingSeat: game_screen.actingSeat
            decisionSecondsLeft: game_screen.decisionSecondsLeft
            facingNeedChips: game_screen.facingNeedChips
            humanSittingOut: game_screen.humanSittingOut
            board0: game_screen.board0
            board1: game_screen.board1
            board2: game_screen.board2
            board3: game_screen.board3
            board4: game_screen.board4
        }

        Repeater {
            id: seatRepeater
            z: 2
            model: 6
            delegate: Item {
                id: seatWrap
                required property int index
                width: 218
                height: 312
                readonly property real angle: Math.PI / 2 - index * 2 * Math.PI / 6
                readonly property real cornerBoost: (index === 1 || index === 2 || index === 4 || index === 5) ? 1.09 : 1.0
                readonly property real scx: tableArea.feltCenter.x + tableArea.orbitRx * Math.cos(angle) * cornerBoost
                readonly property real scy: tableArea.feltCenter.y + tableArea.orbitRy * Math.sin(angle) * cornerBoost
                x: scx - width / 2
                y: scy - height / 2

                Player {
                    anchors.fill: parent
                    name: botNames.displayName(index)
                    position: game_screen.seatRole(index)
                    isDealer: index === game_screen.buttonSeat
                    seatAtTable: {
                        var p = game_screen.seatParticipating
                        if (!p || p.length <= index)
                            return true
                        return p[index] !== false
                    }
                    inHand: game_screen.seatInHand[index] !== false
                    first_card: (seatAtTable && game_screen.seatInHand[index] !== false
                                 && game_screen.seatC1[index] !== undefined)
                                ? game_screen.seatC1[index] : ""
                    second_card: (seatAtTable && game_screen.seatInHand[index] !== false
                                  && game_screen.seatC2[index] !== undefined)
                                 ? game_screen.seatC2[index] : ""
                    stackChips: game_screen.seatStacks[index] !== undefined ? game_screen.seatStacks[index] : 100
                    streetBetChips: game_screen.seatStreetChips[index] !== undefined ? game_screen.seatStreetChips[index] : 0
                    streetActionText: game_screen.seatStreetActions[index] !== undefined
                                      ? game_screen.seatStreetActions[index] : ""
                    show_cards: seatAtTable && (game_screen.seatInHand[index] !== false)
                                  && (game_screen.showdown
                                      || (index === 0 && game_screen.seatC1[index] !== undefined
                                          && game_screen.seatC1[index] !== ""))
                    isActing: game_screen.actingSeat === index
                    isHumanSeat: index === 0
                    decisionSecondsLeft: game_screen.decisionSecondsLeft
                    foldedDim: (game_screen.seatInHand[index] === false)
                    humanWatching: index === 0 && game_screen.humanSittingOut
                    handEpoch: game_screen.handSeq
                }
            }
        }

        readonly property Item humanSeat: seatRepeater.count > 0 ? seatRepeater.itemAt(0) : null
        readonly property real hudPanelW: Math.min(400, Math.max(Theme.trainerEmbeddedHudMinWidth, width * 0.36))

        GameControls {
            id: game_controls
            z: 20
            embeddedMode: true
            visible: true
            panelWidth: tableArea.hudPanelW
            x: {
                var hs = tableArea.humanSeat
                if (!hs)
                    return 8
                var gap = 8
                var w = tableArea.hudPanelW
                var placeRight = hs.x + hs.width + gap
                if (placeRight + w <= tableArea.width - 6)
                    return placeRight
                return Math.max(6, hs.x - w - gap)
            }
            y: {
                var hs = tableArea.humanSeat
                if (!hs)
                    return 0
                var ideal = hs.y + hs.height - game_controls.height
                return Math.min(Math.max(6, ideal), tableArea.height - game_controls.height - 6)
            }
            pageRoot: game_screen
            statusText: game_screen.statusText
            resultBannerCardAssets: game_screen.resultBannerCardAssets
            humanHandText: game_screen.humanHandText
            decisionSecondsLeft: game_screen.decisionSecondsLeft
            humanMoreTimeAvailable: game_screen.humanMoreTimeAvailable
            humanCanCheck: game_screen.humanCanCheck
            humanBbPreflopOption: game_screen.humanBbPreflopOption
            humanCanRaiseFacing: game_screen.humanCanRaiseFacing
            facingNeedChips: game_screen.facingNeedChips
            facingMinRaiseChips: game_screen.facingMinRaiseChips
            facingMaxChips: game_screen.facingMaxChips
            facingPotAmount: game_screen.facingPotAmount
            openRaiseMinChips: game_screen.openRaiseMinChips
            openRaiseMaxChips: game_screen.openRaiseMaxChips
            bbPreflopMinChips: game_screen.bbPreflopMinChips
            bbPreflopMaxChips: game_screen.bbPreflopMaxChips
            humanStackChips: game_screen.humanStackChips
            humanBbCanRaise: game_screen.humanBbCanRaise
            humanSitOut: game_screen.humanSittingOut
            pokerGame: game_screen.pokerGameAccess
            humanCanBuyBackIn: game_screen.humanCanBuyBackIn
            buyInChips: game_screen.buyInChips
        }

        MouseArea {
            z: 19
            anchors.fill: parent
            visible: game_controls.sizingDialogOpen
            onClicked: {
                game_controls.raiseSizingExpanded = false
                game_controls.openRaiseSizingExpanded = false
                game_controls.bbPreflopSizingExpanded = false
            }
        }
    }
}
