import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/// Entry screen: logo + navigation to table, setup, solver.
Page {
    id: lobbyPage
    padding: 0

    property StackLayout stackLayout: null

    readonly property color bgDeep: "#08080a"
    readonly property color gold: "#d4af37"
    readonly property color silver: "#c8c8d0"
    readonly property color accentFire: "#ff6a1a"

    background: Rectangle {
        color: lobbyPage.bgDeep
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#0f0a0a"
            }
            GradientStop {
                position: 0.5
                color: "#08080c"
            }
            GradientStop {
                position: 1
                color: "#0a0508"
            }
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
            color: lobbyPage.silver
            font.pointSize: 13
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            LobbyNavTile {
                title: qsTr("Poker table")
                sub: qsTr("Play hands")
                detailTip: qsTr(
                    "6-max Texas Hold’em table: you in seat 1, bots elsewhere. "
                    + "Use the HUD to act; you can sit out and watch bots. Blinds and pot are centered on the felt.")
                iconSource: "qrc:/assets/icons/table.svg"
                onClicked: lobbyPage.go(1)
            }
            LobbyNavTile {
                title: qsTr("Bots & ranges")
                sub: qsTr("Configure bots")
                detailTip: qsTr(
                    "Set stakes and stack, pick a bot archetype per seat, and edit 13×13 range grids or paste "
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
        }

        Item {
            Layout.fillHeight: true
        }
    }

    component LobbyNavTile: Rectangle {
        id: tileRoot
        property string title: ""
        property string sub: ""
        property string detailTip: ""
        property string iconSource: ""
        signal clicked()

        Layout.preferredWidth: Math.min(188, (lobbyPage.width - 64) / 3)
        Layout.minimumWidth: 128
        Layout.preferredHeight: 104
        radius: 12
        color: "#15151c"
        border.width: 2
        border.color: navMa.containsMouse ? lobbyPage.accentFire : "#3a3038"

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
                opacity: 0.95
            }

            Text {
                Layout.fillWidth: true
                text: title
                color: lobbyPage.gold
                font.pointSize: 13
                font.bold: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                Layout.fillWidth: true
                text: sub
                color: "#9a9aaa"
                font.pointSize: 10
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
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
