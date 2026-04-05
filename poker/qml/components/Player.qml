import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0
import PokerUi 1.0

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
    /// Seat 0: show "WATCHING" when sitting out to observe (not folded); false when autoplaying as bot.
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
    /// Seat index 0–5 for chart-matched name color; `-1` uses default text color.
    property int seatIndex: -1
    /// 1.0 = design size; below 1 on small windows (GameScreen tableScale) so seats match orbit spacing.
    property real uiScale: 1.0
    readonly property real _s: uiScale > 0 ? uiScale : 1.0

    readonly property color gold: Theme.gold
    readonly property color borderAct: Theme.seatBorderAct
    readonly property color borderDealer: Theme.gold
    readonly property color borderIdle: Theme.seatBorderIdle

    /// Name strip: lift background slightly and brighten seat-colored text while this seat is acting.
    readonly property color namePlateBg: root.isActing
            ? Qt.lighter(Qt.tint(Theme.panelElevated, Qt.alpha(Theme.focusGold, 0.14)), 1.09)
            : Theme.panelElevated
    readonly property color nameTextColor: {
        var c = root.seatIndex >= 0 ? Theme.colorForSeat(root.seatIndex) : Theme.textPrimary
        return root.isActing ? Qt.lighter(c, 1.28) : c
    }

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
    readonly property int seatInnerPad: Math.max(4, Math.round(11 * _s))
    /// cardRowH matches hole card height (no extra band); see `cardRowH` / `cardRow` anchors.
    implicitHeight: Math.round(300 * _s)
    implicitWidth: Math.round((Theme.holePairTotalWidth + 22) * _s)

    /// Cards / street / name / stack share one column width (see `Theme.holePairTotalWidth`).
    readonly property int contentWidth: Math.round(Theme.holePairTotalWidth * _s)
    readonly property int cardW: Math.round(Theme.holeCardWidth * _s)
    readonly property int cardH: Math.round(Theme.holeCardHeight * _s)
    readonly property int cardGap: Math.max(2, Math.round(Theme.holeCardGap * _s))
    readonly property int cardRowH: Math.round(Theme.holeCardHeight * _s)
    readonly property int streetRowH: Math.max(18, Math.round(26 * _s))
    readonly property int nameRowH: Math.max(28, Math.round(40 * _s))
    /// Wide enough for “UTG” / “CO” / dealer chip without clipping Merriweather.
    readonly property int posBox: Math.max(34, Math.round(46 * _s))
    readonly property int thinkSlotH: Math.max(8, Math.round(12 * _s))
    readonly property int stackRowH: Math.max(22, Math.round(30 * _s))

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
        anchors.margins: Math.round(-2 * _s)
        anchors.topMargin: 0
        anchors.bottomMargin: Math.round(-4 * _s)
        radius: Math.max(8, Math.round(16 * _s))
        color: "#40000000"
        z: -1
    }

    Rectangle {
        id: actGlow
        visible: root.isActing
        anchors.fill: parent
        anchors.margins: Math.round(-4 * _s)
        radius: Math.max(10, Math.round(18 * _s))
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
        radius: Math.max(8, Math.round(14 * _s))
        color: Theme.seatPanel
        border.color: root.isActing ? root.borderAct : (root.isDealer ? root.borderDealer : root.borderIdle)
        border.width: root.isActing ? Math.max(2, Math.round(3 * _s)) : (root.isDealer ? Math.max(1, Math.round(2 * _s)) : 1)
        clip: true
        Behavior on border.color {
            ColorAnimation { duration: 200 }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: root.seatInnerPad
            anchors.rightMargin: root.seatInnerPad
            anchors.bottomMargin: root.seatInnerPad
            anchors.topMargin: 0
            spacing: 2

            /// Same height for cards / folded / inactive so the seat does not shift between states.
            StackLayout {
                Layout.preferredHeight: root.cardRowH
                Layout.maximumHeight: root.cardRowH
                Layout.minimumHeight: root.cardRowH
                Layout.preferredWidth: root.contentWidth
                Layout.maximumWidth: root.contentWidth
                Layout.minimumWidth: root.contentWidth
                Layout.alignment: Qt.AlignHCenter
                currentIndex: !root.seatAtTable ? 2 : (root.inHand ? 0 : 1)

                Item {
                    width: root.contentWidth
                    height: root.cardRowH

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        spacing: root.cardGap

                        Card {
                            width: root.cardW
                            height: root.cardH
                            /// Match `TableBoardCard` / board row: supersample SVGs when `uiScale` &lt; 1 so holes stay as crisp as board.
                            displayScaleFactor: root._s
                            card: root.first_card
                            flipped: root.show_cards && root.first_card.length > 0
                            dealEpoch: root.handEpoch
                            instantFace: root.instantHoleCards
                        }

                        Card {
                            width: root.cardW
                            height: root.cardH
                            displayScaleFactor: root._s
                            card: root.second_card
                            flipped: root.show_cards && root.second_card.length > 0
                            dealEpoch: root.handEpoch
                            instantFace: root.instantHoleCards
                        }
                    }
                }

                Item {
                    width: root.contentWidth
                    height: root.cardRowH
                    Text {
                        anchors.fill: parent
                        anchors.margins: Math.max(2, Math.round(4 * _s))
                        text: root.humanWatching ? qsTr("WATCHING") : qsTr("FOLDED")
                        color: root.humanWatching ? Theme.accentBlue : Theme.textMuted
                        font.family: Theme.fontFamilyUi
                        font.pointSize: Math.max(8, Theme.uiSeatFoldPt * _s)
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
                    height: root.cardRowH
                    Text {
                        anchors.fill: parent
                        anchors.margins: Math.max(2, Math.round(4 * _s))
                        text: qsTr("INACTIVE")
                        color: Theme.textMuted
                        font.family: Theme.fontFamilyUi
                        font.pointSize: Math.max(8, Theme.uiSeatFoldPt * _s)
                        font.bold: true
                        font.letterSpacing: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            /// Reserved row: same height always (no jump when street label appears).
            Item {
                Layout.preferredHeight: root.streetRowH
                Layout.maximumHeight: root.streetRowH
                Layout.minimumHeight: root.streetRowH
                Layout.preferredWidth: root.contentWidth
                Layout.maximumWidth: root.contentWidth
                Layout.minimumWidth: root.contentWidth
                Layout.alignment: Qt.AlignHCenter

                Rectangle {
                    anchors.fill: parent
                    visible: root.inHand && root.seatAtTable && root.streetActionText.length > 0
                    radius: Math.max(3, Math.round(4 * _s))
                    color: Theme.hudBg1
                    border.width: 1
                    border.color: Qt.alpha(root.streetActionColor, 0.92)
                    clip: true

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: Math.max(4, Math.round(8 * _s))
                        anchors.rightMargin: Math.max(4, Math.round(8 * _s))
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: root.streetActionText
                        color: root.streetActionColor
                        font.family: Theme.fontFamilyUi
                        font.pointSize: Math.max(8, Theme.uiSeatStreetPt * _s)
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: root.nameRowH
                Layout.maximumHeight: root.nameRowH
                Layout.preferredWidth: root.contentWidth
                Layout.maximumWidth: root.contentWidth
                Layout.minimumWidth: root.contentWidth
                spacing: Math.max(2, Math.round(4 * _s))

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.nameRowH
                    radius: Math.max(4, Math.round(6 * _s))
                    color: root.namePlateBg
                    clip: true
                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                            easing.type: Easing.OutQuad
                        }
                    }

                    Text {
                        anchors.fill: parent
                        anchors.margins: Math.max(3, Math.round(6 * _s))
                        text: root.name
                        color: root.nameTextColor
                        font.family: Theme.fontFamilyButton
                        font.pointSize: Math.max(8, Theme.uiSeatNamePt * _s)
                        font.weight: Font.ExtraBold
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 2
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: root.posBox
                    Layout.preferredHeight: root.posBox
                    Layout.alignment: Qt.AlignVCenter
                    radius: Math.max(4, Math.round(6 * _s))
                    color: root.isDealer ? Theme.hudBg0 : Theme.panelElevated
                    border.width: root.isDealer ? 2 : 1
                    border.color: root.isDealer ? root.gold : Theme.panelBorderMuted
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - Math.max(2, Math.round(4 * _s))
                        text: root.position
                        color: root.isDealer ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.fontFamilyUi
                        font.pointSize: Math.max(8, Theme.uiSeatPosPt * _s)
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
                Layout.preferredHeight: root.thinkSlotH
                Layout.maximumHeight: root.thinkSlotH
                Layout.minimumHeight: root.thinkSlotH

                ProgressBar {
                    id: thinkBar
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(4, Math.round(6 * _s))
                    enabled: root.isActing
                    opacity: root.isActing ? 1 : 0
                    padding: Math.max(1, Math.round(2 * _s))
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
                        implicitHeight: Math.max(4, Math.round(6 * _s))
                        implicitWidth: Math.round(200 * _s)
                        color: Theme.progressTrack
                        radius: Math.max(2, Math.round(3 * _s))
                    }

                    contentItem: Item {
                        implicitHeight: Math.max(4, Math.round(6 * _s))

                        Rectangle {
                            width: thinkBar.visualPosition * parent.width
                            height: parent.height
                            radius: Math.max(2, Math.round(3 * _s))
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
                    Layout.preferredHeight: root.stackRowH
                    Layout.maximumHeight: root.stackRowH
                    radius: Math.max(4, Math.round(6 * _s))
                    color: root.stackFill
                    border.width: 1
                    border.color: Qt.alpha(Theme.gold, 0.33)

                    Text {
                        anchors.centerIn: parent
                        text: "$" + root.stackDisplay
                        color: Theme.textPrimary
                        font.family: Theme.fontFamilyMono
                        font.pointSize: Math.max(10, Theme.uiStackPt * _s)
                        font.bold: true
                    }
                }

            }
        }
    }
}
