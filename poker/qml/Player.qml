import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

/// Seat panel — hole cards hidden when folded; street chips shown in gold.
Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true

    property string name: "Default"
    property string first_card: ""
    property string second_card: ""
    property color stackFill: Theme.seatStackTint
    property string position: ""
    property bool isDealer: false
    property bool isActing: false
    /// Seat 0: use engine countdown for determinate progress; bots use indeterminate bar.
    property bool isHumanSeat: false
    property int decisionSecondsLeft: 0
    readonly property int decisionTimeTotal: 20
    property bool show_cards: false
    property bool inHand: true
    property bool foldedDim: false
    /// Seat 0: show "Watching" when sitting out (not a fold).
    property bool humanWatching: false
    /// False when this seat is turned off in setup (bots only).
    property bool seatAtTable: true
    property int stackChips: 100
    property int streetBetChips: 0
    /// Engine label: Call / Raise / Check / Fold / SB / BB.
    property string streetActionText: ""
    property int maxStreetContrib: 0
    /// Table pot before this seat’s call (same as center HUD); used for pot-odds copy on the seat.
    property int tablePotChips: 0
    /// Off-table reserve (for busted seats; can buy back in).
    property int reserveChips: 0

    readonly property color gold: Theme.gold
    readonly property color borderAct: Theme.seatBorderAct
    readonly property color borderDealer: Theme.gold
    readonly property color borderIdle: Theme.seatBorderIdle

    /// Fixed footprint so seats do not jump when fold / watch / acting / street text changes.
    implicitHeight: 282
    implicitWidth: 204

    opacity: (foldedDim && seatAtTable) ? 0.52 : 1.0

    property bool secondHoleRevealed: false

    property int stackDisplay: root.stackChips
    onStackChipsChanged: stackDisplay = root.stackChips

    Timer {
        id: holeStagger
        interval: 300
        repeat: false
        onTriggered: root.secondHoleRevealed = true
    }

    onShow_cardsChanged: {
        if (root.show_cards) {
            root.secondHoleRevealed = false
            holeStagger.start()
        } else {
            holeStagger.stop()
            root.secondHoleRevealed = false
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.seatPanel
        border.color: root.isActing ? root.borderAct : (root.isDealer ? root.borderDealer : root.borderIdle)
        border.width: root.isActing ? 3 : (root.isDealer ? 2 : 1)
        clip: false

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 2

            /// Same height for cards / folded / inactive so the seat does not shift between states.
            StackLayout {
                Layout.preferredHeight: 148
                Layout.maximumHeight: 148
                Layout.minimumHeight: 148
                Layout.fillWidth: true
                currentIndex: !root.seatAtTable ? 2 : (root.inHand ? 0 : 1)

                Item {
                    Card {
                        id: c1
                        anchors.right: parent.horizontalCenter
                        anchors.rightMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        card: root.first_card
                        flipped: root.show_cards
                    }

                    Card {
                        anchors.left: parent.horizontalCenter
                        anchors.leftMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        card: root.second_card
                        flipped: root.show_cards && root.secondHoleRevealed
                    }
                }

                Item {
                    Text {
                        anchors.fill: parent
                        anchors.margins: 4
                        text: root.humanWatching ? qsTr("WATCHING") : qsTr("FOLDED")
                        color: root.humanWatching ? Theme.accentBlue : Theme.textMuted
                        font.pointSize: 11
                        font.bold: true
                        font.letterSpacing: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                Item {
                    Text {
                        anchors.fill: parent
                        anchors.margins: 4
                        text: qsTr("INACTIVE")
                        color: Theme.textMuted
                        font.pointSize: 11
                        font.bold: true
                        font.letterSpacing: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            /// Reserved row: same height always (no jump when street label appears).
            Item {
                Layout.preferredHeight: 22
                Layout.maximumHeight: 22
                Layout.minimumHeight: 22
                Layout.fillWidth: true

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 2
                    anchors.rightMargin: 2
                    visible: root.inHand && root.seatAtTable && root.streetActionText.length > 0
                    radius: 4
                    color: Theme.hudBg1
                    border.width: 1
                    border.color: root.gold
                    clip: true

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: root.streetActionText
                        color: root.gold
                        font.pointSize: 9
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 34
                Layout.maximumHeight: 34
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 6
                    color: Theme.panelElevated
                    clip: true

                    Text {
                        anchors.fill: parent
                        anchors.margins: 3
                        text: root.isActing ? (root.name + "\n" + qsTr("Thinking…")) : root.name
                        color: Theme.textPrimary
                        font.pointSize: root.isActing ? 8 : 9
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        lineHeight: root.isActing ? 1.08 : 1.0
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 2
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    radius: 6
                    color: root.isDealer ? Theme.hudBg0 : Theme.panelElevated
                    border.width: root.isDealer ? 2 : 1
                    border.color: root.isDealer ? root.gold : Theme.panelBorderMuted
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 4
                        text: root.position
                        color: root.isDealer ? Theme.textPrimary : Theme.textSecondary
                        font.pointSize: 10
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
            }

            Item {
                id: thinkBarSlot
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                Layout.maximumHeight: 8
                Layout.minimumHeight: 8

                ProgressBar {
                    id: thinkBar
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    enabled: root.isActing
                    opacity: root.isActing ? 1 : 0
                    padding: 0
                    from: 0
                    to: 1
                    value: root.isHumanSeat
                           ? Math.max(0, Math.min(1, root.decisionSecondsLeft / root.decisionTimeTotal))
                           : 0
                    indeterminate: root.isActing && !root.isHumanSeat

                    background: Rectangle {
                        implicitHeight: 6
                        implicitWidth: 200
                        color: Theme.progressTrack
                        radius: 3
                    }

                    contentItem: Item {
                        implicitHeight: 6

                        Rectangle {
                            width: thinkBar.visualPosition * parent.width
                            height: parent.height
                            radius: 3
                            color: root.borderAct
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 2

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 30
                    Layout.maximumHeight: 30
                    radius: 6
                    color: root.stackFill
                    border.width: 1
                    border.color: Qt.alpha(Theme.gold, 0.33)

                    Text {
                        anchors.centerIn: parent
                        text: "$" + root.stackDisplay
                        color: Theme.textPrimary
                        font.pointSize: 12
                        font.bold: true
                    }
                }

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 14
                    Layout.maximumHeight: 14
                    Layout.minimumHeight: 14
                    Layout.fillWidth: true

                    Text {
                        anchors.centerIn: parent
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        visible: root.stackChips === 0 && root.reserveChips > 0
                        text: qsTr("Reserve $%1").arg(root.reserveChips)
                        color: Theme.textSecondary
                        font.pointSize: 9
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
