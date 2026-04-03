import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0
import PokerUi 1.0

/// Entry screen: logo + navigation to table, setup, solver.
Page {
    id: lobbyPage
    padding: 0
    font.family: Theme.fontFamilyUi

    property StackLayout stackLayout: null

    readonly property color gold: Theme.gold

    background: BrandedBackground {
        anchors.fill: parent
    }

    function go(idx) {
        if (stackLayout)
            stackLayout.currentIndex = idx
    }

    ScrollView {
        id: lobbyScroll
        anchors.fill: parent
        clip: true

        RowLayout {
            width: lobbyScroll.availableWidth
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }

            ColumnLayout {
                id: mainCol
                Layout.preferredWidth: Math.min(Theme.trainerContentMaxWidth, Math.max(280, lobbyScroll.availableWidth - 40))
                Layout.maximumWidth: Theme.trainerContentMaxWidth
                spacing: Theme.trainerColumnSpacing

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(400, lobbyPage.height * 0.46)
            Layout.maximumHeight: 500

            /// Radial fade behind the logo (Canvas: `RadialGradient` is not a Rectangle gradient type in Qt 6 Quick).
            Canvas {
                id: logoBackdropFade
                z: 0
                anchors.centerIn: parent
                width: Math.min(560, parent.width - 16)
                height: Math.min(parent.height - 8, width * 0.78)
                readonly property color stopMid: Qt.alpha(Theme.bgGradientMid, 0.14)
                readonly property color stopBot: Qt.alpha(Theme.bgGradientBottom, 0.42)

                onPaint: {
                    var ctx = getContext("2d")
                    if (width < 8 || height < 8)
                        return
                    ctx.clearRect(0, 0, width, height)
                    var cx = width * 0.5
                    var cy = height * 0.42
                    var r = Math.max(width, height) * 0.72
                    var g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                    g.addColorStop(0, "rgba(0,0,0,0)")
                    g.addColorStop(0.45, stopMid.toString())
                    g.addColorStop(1, stopBot.toString())
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                onWidthChanged: Qt.callLater(requestPaint)
                onHeightChanged: Qt.callLater(requestPaint)
                Component.onCompleted: Qt.callLater(requestPaint)
            }

            Image {
                z: 1
                anchors.centerIn: parent
                width: Math.min(540, parent.width - 24)
                height: Math.min(parent.height, width * 0.72)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                source: "qrc:/assets/images/logo.png"
            }
        }

        ThemedPanel {
            Layout.fillWidth: true
            panelTitle: qsTr("Choose a screen")
            panelOpacity: 0.45
            borderOpacity: 0.45

            RowLayout {
                id: navTilesRow
                Layout.fillWidth: true
                spacing: 6

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
                title: qsTr("Training")
                sub: qsTr("Drills")
                detailTip: qsTr(
                    "Preflop and postflop trainers with immediate feedback, mistake tracking, and progress stats.")
                iconSource: "qrc:/assets/icons/bots.svg"
                onClicked: lobbyPage.go(5)
            }
            LobbyNavTile {
                title: qsTr("Bankroll & stats")
                sub: qsTr("Ranks & charts")
                detailTip: qsTr(
                    "Stack rankings and profit vs baseline, plus a line chart of each player’s total chips after every completed hand. "
                    + "Set total bankroll and table buy-in on each player’s tab under Bots & ranges.")
                iconSource: "qrc:/assets/icons/table.svg"
                onClicked: lobbyPage.go(4)
            }
            }
        }

        Item {
            Layout.fillHeight: true
        }
            }

            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
        }
    }

    component LobbyNavTile: Item {
        id: tileRoot
        property string title: ""
        property string sub: ""
        property string detailTip: ""
        property string iconSource: ""
        signal clicked()

        /// Share the row evenly; `mainCol.width` ignored inner `ThemedPanel` padding and caused overflow.
        Layout.fillWidth: true
        Layout.minimumWidth: 64
        Layout.maximumWidth: 220
        Layout.preferredHeight: Theme.uiLobbyNavTileMinHeight

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
                anchors.margins: Theme.uiLobbyNavTilePadding
                spacing: 5

                Image {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Theme.uiLobbyNavIconPx
                    Layout.preferredHeight: Theme.uiLobbyNavIconPx
                    fillMode: Image.PreserveAspectFit
                    source: tileRoot.iconSource
                    opacity: navMa.containsMouse ? 1 : 0.88
                }

                Text {
                    Layout.fillWidth: true
                    text: title
                    color: Qt.lighter(lobbyPage.gold, navMa.containsMouse ? 1.04 : 1.0)
                    font.family: Theme.fontFamilyUi
                    font.pointSize: Theme.uiLobbyNavTileTitlePt
                    font.bold: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.15
                }
                Text {
                    Layout.fillWidth: true
                    text: sub
                    color: Theme.textSecondary
                    font.family: Theme.fontFamilyUi
                    font.pixelSize: Theme.uiLobbyNavSubPx
                    lineHeight: 1.2
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
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

        ToolTip.visible: navMa.containsMouse && detailTip.length > 0
        ToolTip.delay: 800
        ToolTip.text: detailTip
    }
}
