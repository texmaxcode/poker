import QtQuick
import QtQuick.Layouts

/// Pot + blinds in one HUD; street + board below. Pot ticks up with animation; pot bumps when chips grow.
Item {
    id: table_container
    anchors.fill: parent

    property int pot_amount: 0
    property int smallBlind: 1
    property int bigBlind: 3
    property string board0: ""
    property string board1: ""
    property string board2: ""
    property string board3: ""
    property string board4: ""
    property string streetPhase: ""

    readonly property color gold: "#d4af37"
    readonly property color silver: "#c8c8d0"

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

        /// Single card: pot (primary) + divider + SB / BB
        Rectangle {
            id: potBlindsHud
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: hudRow.implicitWidth + 28
            implicitHeight: 52
            radius: 14
            color: "#1a1512"
            border.width: 2
            border.color: "#5a3a18"
            clip: true

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#2a1810"
                }
                GradientStop {
                    position: 1
                    color: "#120c08"
                }
            }

            RowLayout {
                id: hudRow
                anchors.centerIn: parent
                spacing: 0

                RowLayout {
                    id: potBlock
                    spacing: 10
                    Layout.minimumWidth: 120

                    ColumnLayout {
                        spacing: 1

                        Text {
                            text: qsTr("Pot")
                            color: silver
                            font.pointSize: 9
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Item {
                            id: potValBox
                            Layout.preferredWidth: potValueText.implicitWidth
                            Layout.preferredHeight: potValueText.implicitHeight
                            Layout.alignment: Qt.AlignHCenter

                            Text {
                                id: potValueText
                                anchors.centerIn: parent
                                text: "$" + Math.round(table_container.potShown)
                                color: gold
                                font.bold: true
                                font.pointSize: 20
                            }

                            transform: Scale {
                                id: potValueScale
                                origin.x: potValBox.width > 0 ? potValBox.width * 0.5 : 24
                                origin.y: potValBox.height > 0 ? potValBox.height * 0.5 : 14
                                xScale: 1
                                yScale: 1
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Layout.minimumHeight: 36
                    Layout.maximumHeight: 40
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    color: "#5a3a1888"
                }

                RowLayout {
                    spacing: 8

                    Text {
                        text: qsTr("Blinds")
                        color: silver
                        font.pointSize: 9
                        font.bold: true
                    }

                    Rectangle {
                        radius: 8
                        color: "#251810"
                        border.width: 1
                        border.color: "#6a4a28"
                        implicitWidth: sbTxt.implicitWidth + 14
                        implicitHeight: 30

                        Text {
                            id: sbTxt
                            anchors.centerIn: parent
                            text: qsTr("SB %1").arg(table_container.smallBlind)
                            color: gold
                            font.pointSize: 11
                            font.bold: true
                        }
                    }

                    Rectangle {
                        radius: 8
                        color: "#251810"
                        border.width: 1
                        border.color: "#8a5030"
                        implicitWidth: bbTxt.implicitWidth + 14
                        implicitHeight: 30

                        Text {
                            id: bbTxt
                            anchors.centerIn: parent
                            text: qsTr("BB %1").arg(table_container.bigBlind)
                            color: "#ffb060"
                            font.pointSize: 11
                            font.bold: true
                        }
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
                color: "#a8c8ff"
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
