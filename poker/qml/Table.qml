import QtQuick
import QtQuick.Layouts
import Theme 1.0

/// Pot + blinds in one HUD; street + board below. Pot ticks up with animation; pot bumps when chips grow.
Item {
    id: table_container
    anchors.fill: parent

    property int pot_amount: 0
    property int actingSeat: -1
    property int decisionSecondsLeft: 0
    property int facingNeedChips: 0
    property bool humanSittingOut: false
    property var seatStreetActions: ["", "", "", "", "", ""]
    property int maxStreetContrib: 0
    property int playerCount: 6

    readonly property bool humanDeciding: actingSeat === 0 && decisionSecondsLeft > 0 && !humanSittingOut
    readonly property bool showToCallHint: humanDeciding && facingNeedChips > 0

    property string board0: ""
    property string board1: ""
    property string board2: ""
    property string board3: ""
    property string board4: ""
    property string streetPhase: ""

    readonly property color gold: Theme.gold

    /// Animated display value (counts toward current pot)
    property int potShown: 0
    property int _prevPotForBump: 0
    property bool _streetReady: false

    readonly property int _potAnimDuration: 320

    Component.onCompleted: {
        potShown = pot_amount
        _prevPotForBump = pot_amount
        Qt.callLater(function () {
            table_container._streetReady = true
        })
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

    onStreetPhaseChanged: {
        if (_streetReady && streetPhase.length > 0)
            streetPhaseAnim.restart()
    }

    Column {
        id: col
        spacing: 10
        anchors.centerIn: parent

        /// Fixed-size pot (total in the middle; raises add chips here in the engine) + call hint when you act.
        Rectangle {
            id: potBlindsHud
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(340, Math.max(260, table_container.width * 0.38))
            height: 56
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

            Row {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    id: potValueText
                    anchors.verticalCenter: parent.verticalCenter
                    text: "$" + Math.round(table_container.potShown)
                    color: gold
                    font.bold: true
                    font.pointSize: 20
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
                    font.bold: true
                    font.pointSize: 18
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: table_container.showToCallHint
                    text: qsTr("To call $%1").arg(table_container.facingNeedChips)
                    color: Theme.focusGold
                    font.bold: true
                    font.pointSize: 14
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

        Item {
            id: streetWrap
            width: Math.max(streetText.implicitWidth, 80)
            height: streetText.implicitHeight
            anchors.horizontalCenter: parent.horizontalCenter
            visible: table_container.streetPhase.length > 0
            opacity: 1

            Text {
                id: streetText
                anchors.horizontalCenter: parent.horizontalCenter
                text: table_container.streetPhase
                color: Theme.accentBlue
                font.pointSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            transform: Scale {
                id: streetScale
                origin.x: streetWrap.width * 0.5
                origin.y: streetWrap.height * 0.5
                xScale: 1
                yScale: 1
            }

            SequentialAnimation {
                id: streetPhaseAnim
                ParallelAnimation {
                    NumberAnimation {
                        target: streetWrap
                        property: "opacity"
                        from: 0.2
                        to: 1.0
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: streetScale
                        property: "xScale"
                        from: 0.88
                        to: 1.0
                        duration: 280
                        easing.type: Easing.OutBack
                    }
                    NumberAnimation {
                        target: streetScale
                        property: "yScale"
                        from: 0.88
                        to: 1.0
                        duration: 280
                        easing.type: Easing.OutBack
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
