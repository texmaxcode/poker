import QtQuick
import QtQuick.Layouts
import Theme 1.0
import PokerUi 1.0

/// Pot HUD + board below. Pot ticks up with animation; pot bumps when chips grow.
/// **One combined total** during play (engine still splits main/side for payouts; `GameControls` banner may list both).
Item {
    id: table_container
    anchors.fill: parent

    property int pot_amount: 0
    property int actingSeat: -1
    property int decisionSecondsLeft: 0
    property int facingNeedChips: 0
    property bool humanSittingOut: false
    readonly property bool humanDeciding: actingSeat === 0 && decisionSecondsLeft > 0 && !humanSittingOut
    readonly property bool showToCallHint: humanDeciding && facingNeedChips > 0

    property string board0: ""
    property string board1: ""
    property string board2: ""
    property string board3: ""
    property string board4: ""

    property int smallBlind: 1
    property int bigBlind: 3

    readonly property color gold: Theme.gold

    /// From `GameScreen.tableArea.tableScale` — matches seat/orbit scaling on small windows.
    property real centerScale: 1.0

    readonly property real _rowW: 5 * Theme.boardCardWidth + 4 * 6
    /// Shrink pot + board when narrow **or** vertically tight (wide+short windows were width-only before).
    readonly property real widthScale: Math.min(1.0, (width - 32) / table_container._rowW)
    readonly property real heightScale: Math.min(1.0, Math.max(0.32, height / 280))
    readonly property real boardRowScale: Math.min(widthScale, heightScale) * centerScale

    readonly property real _tableShort: Math.min(table_container.width, table_container.height)
    /// Pot bar + typography: same shrink as the board on tight layouts, but can grow past 1× on large table areas (bar was width-capped at 340px before).
    readonly property real potHudScale: Math.max(0.38, Math.min(1.42,
            boardRowScale * Math.min(1.4, Math.max(0.9, _tableShort / 780.0))))

    /// Animated display value (counts toward current pot)
    property int potShown: 0
    property int _prevPotForBump: 0

    readonly property int _potAnimDuration: 320

    Component.onCompleted: {
        potShown = pot_amount
        _prevPotForBump = pot_amount
    }

    onPot_amountChanged: {
        if (pot_amount > _prevPotForBump && _prevPotForBump >= 0)
            potBumpAnim.restart()
        _prevPotForBump = pot_amount
        potShown = pot_amount
    }

    Behavior on potShown {
        NumberAnimation {
            duration: table_container._potAnimDuration
            easing.type: Easing.OutCubic
        }
    }

    Column {
        id: col
        spacing: Math.max(10, Math.round(18 * Math.max(table_container.boardRowScale,
                table_container.potHudScale * 0.92)))
        anchors.centerIn: parent

        Rectangle {
            id: potBlindsHud
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property real _pw: table_container.width
            /// Compact pot strip: narrower than board row; scales with table width without dominating.
            width: Math.max(140, Math.min(Math.max(248, Math.round(_pw * 0.19)),
                    Math.min(_pw * 0.72, _pw - 24)))
            height: Math.max(Math.round(28 * table_container.potHudScale),
                             potHudInner.implicitHeight + Math.round(8 * table_container.potHudScale))
            radius: Math.max(5, Math.round(11 * table_container.potHudScale))
            color: Theme.hudBg1
            border.width: Math.max(1, Math.round(2 * table_container.potHudScale))
            border.color: Theme.potHudBorder
            clip: true

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.hudBg0
                }
                GradientStop {
                    position: 1
                    color: Theme.hudBg1
                }
            }

            Column {
                id: potHudInner
                anchors.centerIn: parent
                spacing: Math.max(2, Math.round(4 * table_container.potHudScale))
                width: parent.width - Math.max(8, Math.round(10 * table_container.potHudScale))

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.max(8, Math.round(10 * table_container.potHudScale))

                    Text {
                        id: potValueText
                        anchors.verticalCenter: parent.verticalCenter
                        text: "$" + Math.round(table_container.potShown)
                        color: gold
                        font.family: Theme.fontFamilyMono
                        font.bold: true
                        font.pointSize: Math.max(12, Math.round(Theme.uiPotMainPt * table_container.potHudScale))
                        horizontalAlignment: Text.AlignHCenter

                        transform: Scale {
                            id: potValueScale
                            origin.x: potValueText.width * 0.5
                            origin.y: potValueText.height * 0.5
                            xScale: 1
                            yScale: 1
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: table_container.showToCallHint
                        text: qsTr("·")
                        color: Theme.textMuted
                        font.family: Theme.fontFamilyMono
                        font.bold: true
                        font.pointSize: Math.max(8, Math.round(Theme.uiPotSepPt * table_container.potHudScale))
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: table_container.showToCallHint
                        text: qsTr("Call $%1").arg(table_container.facingNeedChips)
                        color: Theme.focusGold
                        font.family: Theme.fontFamilyMono
                        font.bold: true
                        font.pointSize: Math.max(9, Math.round(Theme.uiPotCallPt * table_container.potHudScale))
                    }
                }
            }

            SequentialAnimation {
                id: potBumpAnim
                ParallelAnimation {
                    NumberAnimation {
                        target: potValueScale
                        property: "xScale"
                        to: 1.08
                        duration: 95
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: potValueScale
                        property: "yScale"
                        to: 1.08
                        duration: 95
                        easing.type: Easing.OutCubic
                    }
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: potValueScale
                        property: "xScale"
                        to: 1.0
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: potValueScale
                        property: "yScale"
                        to: 1.0
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        /// `scale` does not shrink layout bounds — clip to scaled size so the column does not reserve 564px on narrow tables.
        Item {
            id: boardCluster
            readonly property real s: table_container.boardRowScale
            readonly property real rowW: 5 * Theme.boardCardWidth + 4 * 6
            width: Math.ceil(rowW * s + 8)
            height: Math.ceil(Theme.boardCardHeight * s + 8)
            anchors.horizontalCenter: parent.horizontalCenter

            Row {
                id: cardRow
                anchors.centerIn: parent
                spacing: 6
                scale: boardCluster.s
                transformOrigin: Item.Center

                TableBoardCard {
                    boardScale: table_container.boardRowScale
                    card: table_container.board0
                    staggerIndex: 0
                }
                TableBoardCard {
                    boardScale: table_container.boardRowScale
                    card: table_container.board1
                    staggerIndex: 1
                }
                TableBoardCard {
                    boardScale: table_container.boardRowScale
                    card: table_container.board2
                    staggerIndex: 2
                }
                TableBoardCard {
                    boardScale: table_container.boardRowScale
                    card: table_container.board3
                    staggerIndex: 3
                }
                TableBoardCard {
                    boardScale: table_container.boardRowScale
                    card: table_container.board4
                    staggerIndex: 4
                }
            }
        }
    }
}
