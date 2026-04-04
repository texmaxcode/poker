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
        topPadding: Theme.uiScrollViewTopPadding

        Item {
            id: lobbyScrollContent
            width: lobbyScroll.availableWidth
            /// `ScrollView.availableHeight` is often 0 before the first layout pass; using it alone makes
            /// `height` jump when it becomes real. Prefer the page height, then scroll viewport.
            readonly property real lobbyViewportH: {
                const av = lobbyScroll.availableHeight
                const ph = lobbyPage.height
                if (ph > 1)
                    return ph
                if (av > 1)
                    return av
                return Math.max(av, ph, 400)
            }
            height: Math.max(lobbyViewportH, mainCol.implicitHeight)

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }

                ColumnLayout {
                    id: mainCol
                    Layout.preferredWidth: Math.min(Theme.trainerContentMaxWidth, Math.max(280, lobbyScroll.availableWidth - 40))
                    Layout.maximumWidth: Theme.trainerContentMaxWidth
                    Layout.fillHeight: true
                    spacing: 16

                    Item {
                        Layout.fillHeight: true
                        Layout.minimumHeight: 0
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(360, lobbyPage.height * 0.38)
                        Layout.maximumHeight: 460

                        Image {
                            id: lobbyLogo
                            anchors.centerIn: parent
                            width: Math.min(520, parent.width - 24)
                            height: Math.min(parent.height, width * 0.72)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            source: "qrc:/assets/images/logo.png"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: lobbyLogo.bottom
                            anchors.topMargin: 8
                            width: parent.width - 24
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            visible: lobbyLogo.status === Image.Error
                            text: qsTr("Logo image failed to load.")
                            color: Theme.dangerText
                            font.pixelSize: Theme.trainerCaptionPx
                        }
                    }

                    ThemedPanel {
                        Layout.fillWidth: true
                        panelTitle: qsTr("What would you like to do?")
                        panelTitlePixelSize: Theme.uiLobbyPanelTitlePx
                        panelSectionSpacing: 14
                        panelPadding: Theme.trainerPanelPadding + 4
                        panelOpacity: 0.45
                        borderOpacity: 0.45

                        RowLayout {
                            id: navTilesRow
                            Layout.fillWidth: true
                            spacing: Theme.uiLobbyNavRowSpacing

                            LobbyNavTile {
                                title: qsTr("Texas Hold'em")
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
                                sub: qsTr("Practice drills")
                                detailTip: qsTr(
                                    "Preflop and postflop trainers with immediate feedback, mistake tracking, and progress stats.")
                                iconSource: "qrc:/assets/icons/home.svg"
                                onClicked: lobbyPage.go(5)
                            }
                            LobbyNavTile {
                                title: qsTr("Stats")
                                sub: qsTr("Ranks & charts")
                                detailTip: qsTr(
                                    "Stack rankings and profit vs baseline, plus a line chart of each player’s total chips after every completed hand. "
                                    + "Set wallet and on-the-table amount on each player’s tab under Bots & ranges.")
                                iconSource: "qrc:/assets/icons/stats.svg"
                                onClicked: lobbyPage.go(4)
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        Layout.minimumHeight: 0
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }
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
        Layout.minimumWidth: 72
        Layout.maximumWidth: 260
        Layout.preferredHeight: Theme.uiLobbyNavTileMinHeight

        Rectangle {
            id: tileFace
            anchors.fill: parent
            radius: 14
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

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.uiLobbyNavTilePadding
                spacing: Theme.uiLobbyNavTileStackSpacing

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.uiLobbyNavIconPx
                    Layout.maximumHeight: Theme.uiLobbyNavIconPx
                    Image {
                        anchors.centerIn: parent
                        width: Theme.uiLobbyNavIconPx
                        height: Theme.uiLobbyNavIconPx
                        fillMode: Image.PreserveAspectFit
                        source: tileRoot.iconSource
                        opacity: navMa.containsMouse ? 1 : 0.88
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.minimumHeight: Theme.uiLobbyNavTitleBlockH
                    Layout.maximumHeight: Theme.uiLobbyNavTitleBlockH
                    Text {
                        anchors.fill: parent
                        text: title
                        color: Qt.lighter(lobbyPage.gold, navMa.containsMouse ? 1.04 : 1.0)
                        font.family: Theme.fontFamilyUi
                        font.pixelSize: Theme.uiLobbyNavTileTitlePx
                        font.bold: true
                        font.capitalization: Font.AllUppercase
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignTop
                        lineHeight: Theme.uiLobbyNavTileTitleLineHeight
                    }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.minimumHeight: Theme.uiLobbyNavSubBlockH
                    Layout.maximumHeight: Theme.uiLobbyNavSubBlockH
                    Text {
                        anchors.fill: parent
                        text: sub
                        color: Theme.textSecondary
                        font.family: Theme.fontFamilyUi
                        font.pixelSize: Theme.uiLobbyNavSubPx
                        font.weight: Font.Medium
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignTop
                        lineHeight: Theme.uiLobbyNavTileSubLineHeight
                    }
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
