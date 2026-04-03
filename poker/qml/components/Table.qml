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
        spacing: 18
        anchors.centerIn: parent

        Rectangle {
            id: potBlindsHud
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(340, Math.max(260, table_container.width * 0.38))
            height: Math.max(64, potHudInner.implicitHeight + 20)
            radius: 14
            color: Theme.hudBg1
            border.width: 2
            border.color: Theme.hudBorder
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
                spacing: 4
                width: parent.width - 12

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Text {
                        id: potValueText
                        anchors.verticalCenter: parent.verticalCenter
                        text: "$" + Math.round(table_container.potShown)
                        color: gold
                        font.family: Theme.fontFamilyUi
                        font.bold: true
                        font.pointSize: Theme.uiPotMainPt
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
                        font.family: Theme.fontFamilyUi
                        font.bold: true
                        font.pointSize: Theme.uiPotSepPt
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: table_container.showToCallHint
                        text: qsTr("Call $%1").arg(table_container.facingNeedChips)
                        color: Theme.focusGold
                        font.family: Theme.fontFamilyUi
                        font.bold: true
                        font.pointSize: Theme.uiPotCallPt
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

        Row {
            id: cardRow
            spacing: 6
            anchors.horizontalCenter: parent.horizontalCenter

            TableBoardCard {
                card: table_container.board0
                staggerIndex: 0
            }
            TableBoardCard {
                card: table_container.board1
                staggerIndex: 1
            }
            TableBoardCard {
                card: table_container.board2
                staggerIndex: 2
            }
            TableBoardCard {
                card: table_container.board3
                staggerIndex: 3
            }
            TableBoardCard {
                card: table_container.board4
                staggerIndex: 4
            }
        }
    }
}
