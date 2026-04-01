import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/// Compact bottom HUD: primary row + pop-up slider for raise/bet sizing.
Item {
    id: game_controls
    width: parent ? parent.width : implicitWidth
    height: mainCol.height

    property var pageRoot: null
    property var pokerGame: null
    property bool humanSitOut: false
    property string statusText: ""
    property int decisionSecondsLeft: 0
    property bool humanMoreTimeAvailable: false
    property bool humanCanCheck: false
    property bool humanBbPreflopOption: false
    property bool humanCanRaiseFacing: false
    property bool humanBbCanRaise: false
    property int facingNeedChips: 0
    property int facingMinRaiseChips: 0
    property int facingMaxChips: 0
    property int facingPotAmount: 0
    property int openBetMinChips: 0
    property int openBetMaxChips: 0
    property int humanStackChips: 0

    property bool raisePanelOpen: false
    property bool betPanelOpen: false

    readonly property bool humanDecisionActive: decisionSecondsLeft > 0
    readonly property bool humanHasChips: humanStackChips > 0
    /// Busted (0 stack) players watch but do not get bet/call UI.
    readonly property bool showWagerUi: !humanSitOut && humanStackChips > 0
    readonly property bool facingBet: humanDecisionActive && !humanCanCheck && !humanBbPreflopOption
    readonly property bool checkOrBetSized: humanDecisionActive && humanCanCheck && !humanBbPreflopOption
    readonly property bool canFacingCall: facingBet && (facingNeedChips <= 0 || humanHasChips)
    readonly property bool canRaiseFacing: facingBet && humanCanRaiseFacing && humanHasChips
    readonly property bool canOpenBet: checkOrBetSized && humanHasChips && openBetMinChips > 0
            && openBetMaxChips >= openBetMinChips

    readonly property bool showHumanActions: !humanSitOut

    function raiseSpinSafeMin() {
        return Math.min(facingMinRaiseChips, facingMaxChips)
    }

    function raiseSpinSafeMax() {
        return Math.max(facingMinRaiseChips, facingMaxChips)
    }

    function openBetSafeMin() {
        return Math.min(openBetMinChips, openBetMaxChips)
    }

    function openBetSafeMax() {
        return Math.max(openBetMinChips, openBetMaxChips)
    }

    onFacingBetChanged: {
        if (!facingBet)
            raisePanelOpen = false
    }
    onCheckOrBetSizedChanged: {
        if (!checkOrBetSized)
            betPanelOpen = false
    }

    Connections {
        target: game_controls
        function onHumanDecisionActiveChanged() {
            if (!game_controls.humanDecisionActive) {
                game_controls.raisePanelOpen = false
                game_controls.betPanelOpen = false
            }
        }
    }

    Rectangle {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        height: mainCol.height
        color: "#12121a"
        border.width: 0
        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 2
            color: "#3d2818"
        }

        Column {
            id: mainCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 3

            RowLayout {
                id: statusRow
                width: parent.width - 12
                x: 6
                spacing: 6

                CheckBox {
                    id: sitOutCheck
                    text: qsTr("Sit out")
                    font.pointSize: 9
                    padding: 2
                    checked: game_controls.humanSitOut
                    onToggled: {
                        if (pokerGame)
                            pokerGame.setHumanSitOut(sitOutCheck.checked)
                    }
                }

                Text {
                    id: actionsHdr
                    visible: game_controls.showHumanActions && game_controls.showWagerUi
                    text: qsTr("Act")
                    color: "#8b93a8"
                    font.pointSize: 9
                    font.bold: true
                }

                Text {
                    id: timerLbl
                    visible: game_controls.showHumanActions && game_controls.showWagerUi
                            && game_controls.humanDecisionActive
                    text: qsTr("%1s").arg(game_controls.decisionSecondsLeft)
                    color: "#7ec8ff"
                    font.pointSize: 10
                    font.bold: true
                    Layout.preferredWidth: visible ? implicitWidth : 0
                }

                Rectangle {
                    id: moreTimeBtn
                    visible: game_controls.showHumanActions && game_controls.showWagerUi
                            && game_controls.humanDecisionActive
                            && game_controls.humanMoreTimeAvailable
                    color: "#3a4a6a"
                    implicitWidth: visible ? 76 : 0
                    implicitHeight: 26
                    radius: 6
                    Layout.preferredWidth: visible ? 76 : 0

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("More")
                        color: "#d0e4ff"
                        font.pointSize: 9
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pageRoot)
                                pageRoot.buttonClicked("MORE_TIME")
                        }
                        onPressed: parent.opacity = 0.85
                        onReleased: parent.opacity = 1
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 80
                    implicitHeight: Math.max(28, statusLabel.implicitHeight + 8)
                    radius: 6
                    color: "#252a36"
                    border.color: "#3d4555"
                    border.width: 1

                    readonly property string statusFullText: {
                        if (game_controls.humanSitOut)
                            return (game_controls.statusText.length > 0)
                                    ? game_controls.statusText
                                    : qsTr("Watching — next hand you skip.")
                        return game_controls.statusText.length > 0 ? game_controls.statusText : qsTr("Ready.")
                    }

                    HoverHandler {
                        id: statusHover
                    }
                    ToolTip.visible: statusHover.hovered && statusFullText.length > 0
                    ToolTip.delay: 350
                    ToolTip.text: statusFullText

                    Text {
                        id: statusLabel
                        anchors.fill: parent
                        anchors.margins: 5
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: parent.statusFullText
                        color: "#e4e8f0"
                        font.pixelSize: 10
                    }
                }
            }

            // Raise sizing (facing a bet)
            Rectangle {
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && game_controls.raisePanelOpen
                        && game_controls.canRaiseFacing
                width: parent.width
                height: visible ? raiseSizerCol.implicitHeight + 16 : 0
                color: "#22262f"
                border.color: "#3d4555"
                border.width: 1
                clip: true

                Column {
                    id: raiseSizerCol
                    width: parent.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    spacing: 6

                    Slider {
                        id: raiseSlider
                        width: parent.width
                        from: game_controls.raiseSpinSafeMin()
                        to: game_controls.raiseSpinSafeMax()
                        stepSize: 1
                        snapMode: Slider.SnapAlways
                        value: from

                        function syncRaiseSlider() {
                            raiseSlider.from = game_controls.raiseSpinSafeMin()
                            raiseSlider.to = game_controls.raiseSpinSafeMax()
                            if (raiseSlider.to < raiseSlider.from) {
                                raiseSlider.value = raiseSlider.from
                                return
                            }
                            raiseSlider.value = Math.min(
                                Math.max(game_controls.facingMinRaiseChips, raiseSlider.from),
                                raiseSlider.to)
                        }

                        Component.onCompleted: syncRaiseSlider()
                    }

                    Connections {
                        target: game_controls
                        function onFacingMinRaiseChipsChanged() {
                            raiseSlider.syncRaiseSlider()
                        }
                        function onFacingMaxChipsChanged() {
                            raiseSlider.syncRaiseSlider()
                        }
                        function onRaisePanelOpenChanged() {
                            if (game_controls.raisePanelOpen)
                                raiseSlider.syncRaiseSlider()
                        }
                    }

                    readonly property int raiseSliderEffective: Math.round(raiseSlider.value)

                    Text {
                        text: qsTr("Raise — chips to add: %1").arg(raiseSizerCol.raiseSliderEffective)
                        color: "#c5cad8"
                        font.pointSize: 11
                    }

                    Row {
                        id: raisePresetRow
                        spacing: 6

                        function applyRaise(v) {
                            var lo = raiseSlider.from
                            var hi = raiseSlider.to
                            v = Math.max(v, game_controls.facingMinRaiseChips)
                            raiseSlider.value = Math.min(Math.max(v, lo), hi)
                        }

                        Rectangle {
                            color: "#3a4555"
                            radius: 6
                            width: 44
                            height: 28
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Min")
                                color: "#e4e8f0"
                                font.pointSize: 10
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: raisePresetRow.applyRaise(game_controls.facingMinRaiseChips)
                                onPressed: parent.opacity = 0.85
                                onReleased: parent.opacity = 1
                            }
                        }
                        Rectangle {
                            color: "#3a4555"
                            radius: 6
                            width: 44
                            height: 28
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("½")
                                color: "#e4e8f0"
                                font.pointSize: 10
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: raisePresetRow.applyRaise(
                                    game_controls.facingNeedChips
                                    + Math.floor(game_controls.facingPotAmount / 2))
                                onPressed: parent.opacity = 0.85
                                onReleased: parent.opacity = 1
                            }
                        }
                        Rectangle {
                            color: "#3a4555"
                            radius: 6
                            width: 44
                            height: 28
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Pot")
                                color: "#e4e8f0"
                                font.pointSize: 10
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: raisePresetRow.applyRaise(
                                    game_controls.facingNeedChips + game_controls.facingPotAmount)
                                onPressed: parent.opacity = 0.85
                                onReleased: parent.opacity = 1
                            }
                        }
                        Rectangle {
                            color: "#3a4555"
                            radius: 6
                            width: 44
                            height: 28
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("All")
                                color: "#e4e8f0"
                                font.pointSize: 10
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: raisePresetRow.applyRaise(raiseSlider.to)
                                onPressed: parent.opacity = 0.85
                                onReleased: parent.opacity = 1
                            }
                        }

                        Item { width: 12; height: 1 }

                        Rectangle {
                            color: "#4a5568"
                            radius: 6
                            width: 72
                            height: 28
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Cancel")
                                color: "#f0f4ff"
                                font.pointSize: 10
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: game_controls.raisePanelOpen = false
                            }
                        }

                        Rectangle {
                            color: "#1a6b45"
                            radius: 6
                            width: 80
                            height: 28
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Raise")
                                color: "white"
                                font.pointSize: 10
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (pokerGame)
                                        pokerGame.submitFacingAction(2, raiseSizerCol.raiseSliderEffective)
                                    game_controls.raisePanelOpen = false
                                }
                                onPressed: parent.opacity = 0.88
                                onReleased: parent.opacity = 1
                            }
                        }
                    }
                }
            }

            // Open bet sizing (check / bet street)
            Rectangle {
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && game_controls.betPanelOpen
                        && game_controls.canOpenBet
                width: parent.width
                height: visible ? betSizerCol.implicitHeight + 16 : 0
                color: "#22262f"
                border.color: "#3d4555"
                border.width: 1
                clip: true

                Column {
                    id: betSizerCol
                    width: parent.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    spacing: 6

                    Slider {
                        id: betSlider
                        width: parent.width
                        from: game_controls.openBetSafeMin()
                        to: game_controls.openBetSafeMax()
                        stepSize: 1
                        snapMode: Slider.SnapAlways
                        value: from

                        function syncBetSlider() {
                            betSlider.from = game_controls.openBetSafeMin()
                            betSlider.to = game_controls.openBetSafeMax()
                            if (betSlider.to < betSlider.from) {
                                betSlider.value = betSlider.from
                                return
                            }
                            betSlider.value = Math.min(
                                Math.max(game_controls.openBetMinChips, betSlider.from),
                                betSlider.to)
                        }

                        Component.onCompleted: syncBetSlider()
                    }

                    Connections {
                        target: game_controls
                        function onOpenBetMinChipsChanged() {
                            betSlider.syncBetSlider()
                        }
                        function onOpenBetMaxChipsChanged() {
                            betSlider.syncBetSlider()
                        }
                        function onBetPanelOpenChanged() {
                            if (game_controls.betPanelOpen)
                                betSlider.syncBetSlider()
                        }
                    }

                    readonly property int betSliderEffective: Math.round(betSlider.value)

                    Text {
                        text: qsTr("Bet size: %1").arg(betSizerCol.betSliderEffective)
                        color: "#c5cad8"
                        font.pointSize: 11
                    }

                    Row {
                        id: betPresetRow
                        spacing: 6

                        function applyBet(v) {
                            var lo = betSlider.from
                            var hi = betSlider.to
                            v = Math.max(v, game_controls.openBetMinChips)
                            betSlider.value = Math.min(Math.max(v, lo), hi)
                        }

                        Rectangle {
                            color: "#3a4555"
                            radius: 6
                            width: 44
                            height: 28
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Min")
                                color: "#e4e8f0"
                                font.pointSize: 10
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: betPresetRow.applyBet(game_controls.openBetMinChips)
                                onPressed: parent.opacity = 0.85
                                onReleased: parent.opacity = 1
                            }
                        }
                        Rectangle {
                            color: "#3a4555"
                            radius: 6
                            width: 44
                            height: 28
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Pot")
                                color: "#e4e8f0"
                                font.pointSize: 10
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: betPresetRow.applyBet(
                                    Math.min(game_controls.facingPotAmount, betSlider.to))
                                onPressed: parent.opacity = 0.85
                                onReleased: parent.opacity = 1
                            }
                        }
                        Rectangle {
                            color: "#3a4555"
                            radius: 6
                            width: 44
                            height: 28
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("All")
                                color: "#e4e8f0"
                                font.pointSize: 10
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: betPresetRow.applyBet(betSlider.to)
                                onPressed: parent.opacity = 0.85
                                onReleased: parent.opacity = 1
                            }
                        }

                        Item { width: 12; height: 1 }

                        Rectangle {
                            color: "#4a5568"
                            radius: 6
                            width: 72
                            height: 28
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Cancel")
                                color: "#f0f4ff"
                                font.pointSize: 10
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: game_controls.betPanelOpen = false
                            }
                        }

                        Rectangle {
                            color: "#1a6b45"
                            radius: 6
                            width: 72
                            height: 28
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Bet")
                                color: "white"
                                font.pointSize: 10
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (pokerGame)
                                        pokerGame.submitCheckOrBet(false, betSizerCol.betSliderEffective)
                                    game_controls.betPanelOpen = false
                                }
                                onPressed: parent.opacity = 0.88
                                onReleased: parent.opacity = 1
                            }
                        }
                    }
                }
            }

            // Facing a bet: fold / call / raise
            Row {
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && game_controls.facingBet
                width: parent.width - 12
                x: 6
                spacing: 6

                Rectangle {
                    color: "#6b3030"
                    width: 76
                    height: 32
                    radius: 6
                    opacity: game_controls.facingBet ? 1.0 : 0.42
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("FOLD")
                        color: "#f5e0e0"
                        font.pointSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: game_controls.facingBet
                        onClicked: {
                            if (pageRoot && game_controls.facingBet)
                                pageRoot.buttonClicked("FOLD")
                        }
                        onPressed: parent.opacity = 0.88
                        onReleased: parent.opacity = 1
                    }
                }

                Rectangle {
                    visible: game_controls.canFacingCall
                    color: "#c9a227"
                    width: 108
                    height: 32
                    radius: 6
                    Text {
                        anchors.centerIn: parent
                        text: game_controls.facingNeedChips > 0
                              ? qsTr("Call %1").arg(game_controls.facingNeedChips)
                              : qsTr("CALL")
                        color: "#222"
                        font.pointSize: 11
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pageRoot && game_controls.facingBet)
                                pageRoot.buttonClicked("CALL")
                        }
                        onPressed: parent.opacity = 0.88
                        onReleased: parent.opacity = 1
                    }
                }

                Rectangle {
                    visible: game_controls.canRaiseFacing
                    color: game_controls.raisePanelOpen ? "#2d5a45" : "#1a6b45"
                    width: 84
                    height: 32
                    radius: 6
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Raise")
                        color: "white"
                        font.pointSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            game_controls.raisePanelOpen = !game_controls.raisePanelOpen
                            if (game_controls.raisePanelOpen)
                                game_controls.betPanelOpen = false
                        }
                        onPressed: parent.opacity = 0.88
                        onReleased: parent.opacity = 1
                    }
                }
            }

            // BB preflop option
            Row {
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && game_controls.humanDecisionActive
                        && game_controls.humanBbPreflopOption
                width: parent.width - 12
                x: 6
                spacing: 6

                Rectangle {
                    color: "#4a5568"
                    width: 96
                    height: 32
                    radius: 6
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("CHECK")
                        color: "#f0f4ff"
                        font.pointSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pageRoot)
                                pageRoot.buttonClicked("CHECK")
                        }
                        onPressed: parent.opacity = 0.88
                        onReleased: parent.opacity = 1
                    }
                }

                Rectangle {
                    visible: game_controls.humanBbCanRaise && game_controls.humanHasChips
                    color: "#1a6b45"
                    width: 96
                    height: 32
                    radius: 6
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Raise")
                        color: "white"
                        font.pointSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pageRoot)
                                pageRoot.buttonClicked("RAISE")
                        }
                        onPressed: parent.opacity = 0.88
                        onReleased: parent.opacity = 1
                    }
                }
            }

            // Check or open bet (post-flop streets)
            Row {
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && game_controls.checkOrBetSized
                width: parent.width - 12
                x: 6
                spacing: 6

                Rectangle {
                    color: "#4a5568"
                    width: 88
                    height: 32
                    radius: 6
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("CHECK")
                        color: "#f0f4ff"
                        font.pointSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pokerGame)
                                pokerGame.submitCheckOrBet(true, 0)
                        }
                        onPressed: parent.opacity = 0.88
                        onReleased: parent.opacity = 1
                    }
                }

                Rectangle {
                    visible: game_controls.canOpenBet
                    color: game_controls.betPanelOpen ? "#2d5a45" : "#1a6b45"
                    width: 84
                    height: 32
                    radius: 6
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Bet")
                        color: "white"
                        font.pointSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            game_controls.betPanelOpen = !game_controls.betPanelOpen
                            if (game_controls.betPanelOpen)
                                game_controls.raisePanelOpen = false
                        }
                        onPressed: parent.opacity = 0.88
                        onReleased: parent.opacity = 1
                    }
                }
            }

            Item {
                width: 1
                height: 2
            }
        }
    }
}
