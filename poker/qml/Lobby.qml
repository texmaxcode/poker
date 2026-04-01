import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

/// Entry screen: logo + navigation to table, setup, solver.
Page {
    id: lobbyPage
    padding: 0

    property StackLayout stackLayout: null

    readonly property color gold: Theme.gold
    readonly property color silver: Theme.textSecondary
    readonly property color accentFire: Theme.fire

    background: Item {
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.bgGradientTop
                }
                GradientStop {
                    position: 0.52
                    color: Theme.bgGradientMid
                }
                GradientStop {
                    position: 1
                    color: Theme.bgGradientBottom
                }
            }
        }
        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            opacity: 0.55
            source: "qrc:/assets/images/bg_vignette.svg"
            smooth: true
            mipmap: true
        }
    }

    function go(idx) {
        if (stackLayout)
            stackLayout.currentIndex = idx
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(400, lobbyPage.height * 0.46)
            Layout.maximumHeight: 500

            Image {
                anchors.centerIn: parent
                width: Math.min(540, parent.width - 24)
                height: Math.min(parent.height, width * 0.72)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                source: "qrc:/assets/images/logo.png"
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Choose a screen")
            color: Theme.goldMuted
            font.pointSize: 12
            font.bold: true
            font.letterSpacing: 1.2
            opacity: 0.92
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            LobbyNavTile {
                title: qsTr("Poker table")
                sub: qsTr("Play hands")
                detailTip: qsTr(
                    "6-max Texas Hold’em table: you and five named bots. "
                    + "Use the HUD to act; you can sit out and watch bots. Blinds and pot are centered on the felt.")
                iconSource: "qrc:/assets/icons/table.svg"
                onClicked: lobbyPage.go(1)
            }
            LobbyNavTile {
                title: qsTr("Bots & ranges")
                sub: qsTr("Configure bots")
                detailTip: qsTr(
                    "Set stakes and stack, pick a bot archetype per player, and edit 13×13 range grids or paste "
                    + "text ranges. Reference presets show default charts and full strategy notes on hover there.")
                iconSource: "qrc:/assets/icons/bots.svg"
                onClicked: lobbyPage.go(2)
            }
            LobbyNavTile {
                title: qsTr("Solver & equity")
                sub: qsTr("Study tools")
                detailTip: qsTr(
                    "Monte Carlo equity vs a range or exact villain cards, with optional pot-odds and chip-EV. "
                    + "Helpful for study — not a full multi-street GTO solver.")
                iconSource: "qrc:/assets/icons/solver.svg"
                onClicked: lobbyPage.go(3)
            }
            LobbyNavTile {
                title: qsTr("Bankroll & stats")
                sub: qsTr("Ranks & charts")
                detailTip: qsTr(
                    "Set the starting bankroll for everyone, see stack rankings and profit vs baseline, "
                    + "and a line chart of each player’s stack after every completed hand.")
                iconSource: "qrc:/assets/icons/table.svg"
                onClicked: lobbyPage.go(4)
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    component LobbyNavTile: Item {
        id: tileRoot
        property string title: ""
        property string sub: ""
        property string detailTip: ""
        property string iconSource: ""
        signal clicked()

        Layout.preferredWidth: Math.min(188, (lobbyPage.width - 80) / 4)
        Layout.minimumWidth: 128
        Layout.preferredHeight: 108

        Rectangle {
            id: tileFace
            anchors.fill: parent
            radius: 12
            clip: true
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.lighter(Theme.hudBg0, 1.1)
                }
                GradientStop {
                    position: 0.45
                    color: Theme.hudBg0
                }
                GradientStop {
                    position: 1
                    color: Qt.tint(Theme.hudBg1, "#55301a22")
                }
            }
            border.width: navMa.containsMouse || navMa.pressed ? 2 : 1
            border.color: navMa.containsMouse
                    ? Qt.lighter(Theme.chromeLineGold, 1.15)
                    : Qt.alpha(Theme.chromeLine, 0.85)

            // Light top edge like stamped metal / logo bevel
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                radius: 12
                color: Qt.alpha(Theme.gold, 0.22)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4

                Image {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    fillMode: Image.PreserveAspectFit
                    source: tileRoot.iconSource
                    opacity: navMa.containsMouse ? 1 : 0.88
                }

                Text {
                    Layout.fillWidth: true
                    text: title
                    color: Qt.lighter(lobbyPage.gold, navMa.containsMouse ? 1.04 : 1.0)
                    font.pointSize: 13
                    font.bold: true
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    Layout.fillWidth: true
                    text: sub
                    color: Theme.textSecondary
                    font.pointSize: 10
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 120
                }
            }
            transform: Scale {
                origin.x: tileRoot.width / 2
                origin.y: tileRoot.height / 2
                xScale: navMa.containsMouse ? 1.02 : 1
                yScale: navMa.containsMouse ? 1.02 : 1
                Behavior on xScale {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on yScale {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        MouseArea {
            id: navMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tileRoot.clicked()
        }

        ToolTip.visible: navMa.containsMouse && tileRoot.detailTip.length > 0
        ToolTip.delay: 500
        ToolTip.text: tileRoot.detailTip
    }
}
