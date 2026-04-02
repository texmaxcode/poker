import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

/// Seat panel — hole cards hidden when folded; street chips shown in gold.
Item {
    id: root

    property string name: "Default"
    property string first_card: ""
    property string second_card: ""
    property color stackFill: Theme.seatStackTint
    property string position: ""
    property bool isDealer: false
    property bool isActing: false
    /// Seat 0: human uses the same countdown source as the table HUD (`decisionSecondsLeft`).
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
    /// From `Game.handSeq`: new value each hand so hole cards snap face-down and stagger resets.
    property int handEpoch: 0
    /// Training: show hole cards face-up without flip delay.
    property bool instantHoleCards: false

    readonly property color gold: Theme.gold
    readonly property color borderAct: Theme.seatBorderAct
    readonly property color borderDealer: Theme.gold
    readonly property color borderIdle: Theme.seatBorderIdle

    readonly property color streetActionColor: {
        var t = root.streetActionText.toLowerCase()
        // Match All-in / ALL IN / Allin (engine uses "All-in $N"); must come before "raise".
        var letters = t.replace(/[^a-z]/g, "")
        if (t.indexOf("all-in") >= 0 || t.indexOf("all in") >= 0 || letters.indexOf("allin") >= 0)
            return Theme.streetActionAllIn
        if (t.indexOf("raise") >= 0)
            return Theme.streetActionRaise
        if (t.indexOf("call") >= 0)
            return Theme.streetActionCall
        if (t.indexOf("check") >= 0)
            return Theme.streetActionCheck
        if (t.indexOf("fold") >= 0)
            return Theme.streetActionFold
        return Theme.gold
    }

    /// Fixed footprint so seats do not jump when fold / watch / acting / street text changes.
    /// Width = pair of hole cards + horizontal inner padding (see `seatInnerPad`).
    readonly property int seatInnerPad: 11
    implicitHeight: 330
    implicitWidth: Theme.holePairTotalWidth + 2 * seatInnerPad

    /// Cards / street / name / stack share one column width (see `Theme.holePairTotalWidth`).
    readonly property int contentWidth: Theme.holePairTotalWidth

    opacity: (foldedDim && seatAtTable) ? 0.52 : 1.0
    Behavior on opacity {
        NumberAnimation { duration: 280; easing.type: Easing.InOutQuad }
    }

    property int stackDisplay: root.stackChips
    onStackChipsChanged: stackDisplay = root.stackChips

    Behavior on stackDisplay {
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    /// Bots block the UI thread briefly; drive a local depleting bar so seats show urgency.
    property real botTurnFrac: 1.0
    Timer {
        id: botActTimer
        interval: 45
        repeat: true
        running: root.isActing && !root.isHumanSeat
        onTriggered: root.botTurnFrac = Math.max(0, root.botTurnFrac - 0.152)
    }

    onIsActingChanged: {
        if (root.isActing && !root.isHumanSeat)
            root.botTurnFrac = 1.0
    }

    Rectangle {
        id: seatShadow
        anchors.fill: parent
        anchors.margins: -2
        anchors.topMargin: 0
        anchors.bottomMargin: -4
        radius: 16
        color: "#40000000"
        z: -1
    }

    Rectangle {
        id: actGlow
        visible: root.isActing
        anchors.fill: parent
        anchors.margins: -4
        radius: 18
        color: "transparent"
        border.width: 2
        border.color: Qt.alpha(root.borderAct, actGlow._pulse)
        property real _pulse: 0.35
        SequentialAnimation on _pulse {
            loops: Animation.Infinite
            running: root.isActing
            NumberAnimation { from: 0.35; to: 0.7; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.7; to: 0.35; duration: 800; easing.type: Easing.InOutSine }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.seatPanel
        border.color: root.isActing ? root.borderAct : (root.isDealer ? root.borderDealer : root.borderIdle)
        border.width: root.isActing ? 3 : (root.isDealer ? 2 : 1)
        clip: true
        Behavior on border.color {
            ColorAnimation { duration: 200 }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.seatInnerPad
            spacing: 2

            /// Same height for cards / folded / inactive so the seat does not shift between states.
            StackLayout {
                Layout.preferredHeight: Theme.holeCardHeight + 12
                Layout.maximumHeight: Theme.holeCardHeight + 12
                Layout.minimumHeight: Theme.holeCardHeight + 12
                Layout.preferredWidth: root.contentWidth
                Layout.maximumWidth: root.contentWidth
                Layout.minimumWidth: root.contentWidth
                Layout.alignment: Qt.AlignHCenter
                currentIndex: !root.seatAtTable ? 2 : (root.inHand ? 0 : 1)

                Item {
                    width: root.contentWidth
                    height: Theme.holeCardHeight + 12

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.holeCardGap

                        Card {
                            width: Theme.holeCardWidth
                            height: Theme.holeCardHeight
                            card: root.first_card
                            flipped: root.show_cards && root.first_card.length > 0
                            dealEpoch: root.handEpoch
                            instantFace: root.instantHoleCards
                        }

                        Card {
                            width: Theme.holeCardWidth
                            height: Theme.holeCardHeight
                            card: root.second_card
                            flipped: root.show_cards && root.second_card.length > 0
                            dealEpoch: root.handEpoch
                            instantFace: root.instantHoleCards
                        }
                    }
                }

                Item {
                    width: root.contentWidth
                    height: Theme.holeCardHeight + 12
                    Text {
                        anchors.fill: parent
                        anchors.margins: 4
                        text: root.humanWatching ? qsTr("WATCHING") : qsTr("FOLDED")
                        color: root.humanWatching ? Theme.accentBlue : Theme.textMuted
                        font.family: Theme.fontFamilyUi
                        font.pointSize: Theme.uiSeatFoldPt
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
                    width: root.contentWidth
                    height: Theme.holeCardHeight + 12
                    Text {
                        anchors.fill: parent
                        anchors.margins: 4
                        text: qsTr("INACTIVE")
                        color: Theme.textMuted
                        font.family: Theme.fontFamilyUi
                        font.pointSize: Theme.uiSeatFoldPt
                        font.bold: true
                        font.letterSpacing: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            /// Reserved row: same height always (no jump when street label appears).
            Item {
                Layout.preferredHeight: 26
                Layout.maximumHeight: 26
                Layout.minimumHeight: 26
                Layout.preferredWidth: root.contentWidth
                Layout.maximumWidth: root.contentWidth
                Layout.minimumWidth: root.contentWidth
                Layout.alignment: Qt.AlignHCenter

                Rectangle {
                    anchors.fill: parent
                    visible: root.inHand && root.seatAtTable && root.streetActionText.length > 0
                    radius: 4
                    color: Theme.hudBg1
                    border.width: 1
                    border.color: Qt.alpha(root.streetActionColor, 0.92)
                    clip: true

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: root.streetActionText
                        color: root.streetActionColor
                        font.family: Theme.fontFamilyUi
                        font.pointSize: Theme.uiSeatStreetPt
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 40
                Layout.maximumHeight: 40
                Layout.preferredWidth: root.contentWidth
                Layout.maximumWidth: root.contentWidth
                Layout.minimumWidth: root.contentWidth
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 6
                    color: Theme.panelElevated
                    clip: true

                    Text {
                        anchors.fill: parent
                        anchors.margins: 6
                        text: root.name
                        color: Theme.textPrimary
                        font.family: Theme.fontFamilyUi
                        font.pointSize: Theme.uiSeatNamePt
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 2
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
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
                        font.family: Theme.fontFamilyUi
                        font.pointSize: Theme.uiSeatPosPt
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
            }

            Item {
                id: thinkBarSlot
                Layout.preferredWidth: root.contentWidth
                Layout.maximumWidth: root.contentWidth
                Layout.minimumWidth: root.contentWidth
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 12
                Layout.maximumHeight: 12
                Layout.minimumHeight: 12

                ProgressBar {
                    id: thinkBar
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 6
                    enabled: root.isActing
                    opacity: root.isActing ? 1 : 0
                    padding: 2
                    from: 0
                    to: 1
                    value: {
                        if (!root.isActing)
                            return 0
                        if (root.isHumanSeat)
                            return Math.max(0, Math.min(1,
                                    root.decisionSecondsLeft / root.decisionTimeTotal))
                        return root.botTurnFrac
                    }

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
                Layout.preferredWidth: root.contentWidth
                Layout.maximumWidth: root.contentWidth
                Layout.minimumWidth: root.contentWidth
                spacing: 2

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
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
                        font.family: Theme.fontFamilyUi
                        font.pointSize: Theme.uiStackPt
                        font.bold: true
                    }
                }

            }
        }
    }
}
