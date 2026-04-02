import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

Page {
    id: page
    padding: 0
    font.family: Theme.fontFamilyUi

    property StackLayout stackLayout: null

    property string position: "BTN"
    property string mode: "open"
    property string card1: ""
    property string card2: ""
    property string statusLine: qsTr("Load ranges and start a drill.")
    property bool inputLocked: false
    property int secLeft: 0
    /// Seconds left to answer (mirrors table decision clock).
    property int decisionSecLeft: 0
    /// Wall-clock ms deadlines so timers stay correct after app background or tab switch.
    property real decisionDeadlineMs: 0
    property real advanceDeadlineMs: 0
    /// Bumps when the hand changes so `Player` hole cards re-deal like at the table.
    property int seatVisualEpoch: 0
    /// True after user navigates away so we start a new drill question when they come back.
    property bool _returningFromHidden: false
    /// Avoid treating initial `visible: false` at startup as "left the page".
    property bool _drillSurfaceShown: false
    /// Matches HUD pot / sizing context ($2 BB training table).
    readonly property int trainerPotChips: 12
    background: BrandedBackground { anchors.fill: parent }

    Timer {
        id: decisionTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: page.tickDecisionTimer()
    }

    Timer {
        id: secTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: page.tickAdvanceTimer()
    }

    function cancelPendingAdvance() {
        secTimer.stop()
        secLeft = 0
        inputLocked = false
        advanceDeadlineMs = 0
        decisionTimer.stop()
        decisionSecLeft = 0
        decisionDeadlineMs = 0
    }

    function tickDecisionTimer() {
        const left = Math.max(0, Math.ceil((decisionDeadlineMs - Date.now()) / 1000))
        decisionSecLeft = left
        if (left <= 0) {
            decisionTimer.stop()
            decisionSecLeft = 0
            decisionDeadlineMs = 0
            submit("fold")
        }
    }

    function tickAdvanceTimer() {
        const left = Math.max(0, Math.ceil((advanceDeadlineMs - Date.now()) / 1000))
        secLeft = left
        if (left <= 0) {
            secTimer.stop()
            advanceDeadlineMs = 0
            inputLocked = false
            nextQuestion()
        }
    }

    /// Resync after app resume or tab change. Wall-clock deadlines stay valid; QML `Timer` can stall
    /// after suspend while still reporting `running`, so always `restart()` when time remains.
    function syncTrainerClocks() {
        // Recover stuck "feedback / next hand" lock if deadlines were cleared without advancing (e.g. suspend).
        if (inputLocked && advanceDeadlineMs <= 0 && decisionDeadlineMs <= 0) {
            secTimer.stop()
            inputLocked = false
            nextQuestion()
            return
        }
        if (!inputLocked && decisionDeadlineMs > 0) {
            const left = Math.max(0, Math.ceil((decisionDeadlineMs - Date.now()) / 1000))
            decisionSecLeft = left
            if (left <= 0) {
                decisionTimer.stop()
                decisionSecLeft = 0
                decisionDeadlineMs = 0
                submit("fold")
            } else {
                decisionTimer.restart()
            }
        }
        if (inputLocked && advanceDeadlineMs > 0) {
            const left = Math.max(0, Math.ceil((advanceDeadlineMs - Date.now()) / 1000))
            secLeft = left
            if (left <= 0) {
                secTimer.stop()
                advanceDeadlineMs = 0
                inputLocked = false
                nextQuestion()
            } else {
                secTimer.restart()
            }
        }
    }

    function startDecisionClock() {
        decisionTimer.stop()
        const sec = Math.max(1, trainingStore.trainerDecisionSeconds)
        decisionDeadlineMs = Date.now() + sec * 1000
        decisionSecLeft = sec
        decisionTimer.start()
    }

    function startAutoAdvance() {
        secTimer.stop()
        inputLocked = true
        const ms = Math.max(1, trainingStore.trainerAutoAdvanceMs)
        advanceDeadlineMs = Date.now() + ms
        secLeft = Math.max(1, Math.ceil(ms / 1000))
        secTimer.start()
    }

    function goTrainingHome() {
        cancelPendingAdvance()
        if (stackLayout)
            stackLayout.currentIndex = 5
    }

    /// Stop timers when leaving this screen; stack may keep the page alive.
    function stopDrillWhileAway() {
        cancelPendingAdvance()
    }

    /// New question + clock after returning from another screen.
    function restartDrillAfterReturn() {
        statusLine = qsTr("Ready.")
        trainer.startPreflopDrill(position, mode)
        nextQuestion()
    }

    onVisibleChanged: {
        if (!visible) {
            if (_drillSurfaceShown) {
                stopDrillWhileAway()
                _returningFromHidden = true
            }
            return
        }
        _drillSurfaceShown = true
        if (_returningFromHidden) {
            _returningFromHidden = false
            restartDrillAfterReturn()
        } else {
            syncTrainerClocks()
        }
    }

    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive)
                page.syncTrainerClocks()
        }
    }

    Component.onCompleted: {
        delaySecSpin.value = Math.round(trainingStore.trainerAutoAdvanceMs / 1000)
        timeLimitSpin.value = trainingStore.trainerDecisionSeconds
        const ok = trainer.loadPreflopRanges("qrc:/assets/training/preflop_ranges_v1.json")
        statusLine = ok ? qsTr("Ready.") : qsTr("Could not load ranges.")
        trainer.startPreflopDrill(position, mode)
        nextQuestion()
    }

    function nextQuestion() {
        cancelPendingAdvance()
        const q = trainer.nextPreflopQuestion()
        if (q.error !== undefined) {
            statusLine = String(q.error)
            return
        }
        position = String(q.position)
        mode = String(q.mode)
        card1 = String(q.card1)
        card2 = String(q.card2)
        seatVisualEpoch++
        statusLine = qsTr("%1 (%2)").arg(position).arg(mode)
        startDecisionClock()
    }

    function submit(a) {
        decisionTimer.stop()
        decisionSecLeft = 0
        decisionDeadlineMs = 0
        const r = trainer.submitPreflopAnswer(a, 0)
        if (r.error !== undefined) {
            statusLine = String(r.error)
            startAutoAdvance()
            return
        }
        const grade = String(r.grade)
        const freq = Number(r.chosenFreq)
        const best = String(r.bestAction)
        statusLine = qsTr("%1 — %2 (%3%) · best: %4").arg(position).arg(grade).arg(Math.round(freq * 100)).arg(best)
        startAutoAdvance()
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true

        RowLayout {
            width: scrollView.availableWidth
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }

            ColumnLayout {
                Layout.preferredWidth: Math.min(Theme.trainerContentMaxWidth, Math.max(280, scrollView.availableWidth - 40))
                Layout.maximumWidth: Theme.trainerContentMaxWidth
                spacing: Theme.trainerColumnSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ToolButton {
                        text: qsTr("Training picks")
                        flat: true
                        font.pixelSize: Theme.trainerToolButtonPx
                        leftPadding: 10
                        rightPadding: 14
                        onClicked: page.goTrainingHome()
                    }

                    Label {
                        text: qsTr("Preflop")
                        font.pointSize: Theme.trainerPageHeadlinePt
                        font.bold: true
                        color: Theme.gold
                    }

                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Label {
                        text: qsTr("Delay")
                        color: Theme.textMuted
                        font.pixelSize: Theme.trainerCaptionPx
                    }
                    SpinBox {
                        id: delaySecSpin
                        Layout.preferredWidth: Theme.trainerSpinBoxWidth
                        font.pixelSize: Theme.trainerCaptionPx
                        from: 1
                        to: 120
                        editable: true
                        stepSize: 1
                        textFromValue: function (v) { return v + qsTr(" s") }
                        valueFromText: function (t) { return parseInt(t, 10) }
                        onValueModified: trainingStore.trainerAutoAdvanceMs = value * 1000
                    }

                    Label {
                        text: qsTr("Time limit")
                        color: Theme.textMuted
                        font.pixelSize: Theme.trainerCaptionPx
                    }
                    SpinBox {
                        id: timeLimitSpin
                        Layout.preferredWidth: Theme.trainerSpinBoxWidth
                        font.pixelSize: Theme.trainerCaptionPx
                        from: 5
                        to: 120
                        editable: true
                        stepSize: 1
                        textFromValue: function (v) { return v + qsTr(" s") }
                        valueFromText: function (t) { return parseInt(t, 10) }
                        onValueModified: trainingStore.trainerDecisionSeconds = value
                    }

                    Label {
                        text: qsTr("Pos")
                        color: Theme.textMuted
                        font.pixelSize: Theme.trainerCaptionPx
                    }
                    ComboBox {
                        id: posPick
                        font.pixelSize: Theme.trainerCaptionPx
                        Layout.preferredWidth: 112
                        enabled: !page.inputLocked
                        model: ["UTG", "CO", "BTN", "SB", "BB"]
                        currentIndex: model.indexOf(page.position)
                        onActivated: function (index) {
                            cancelPendingAdvance()
                            page.position = String(model[index])
                            trainer.startPreflopDrill(page.position, page.mode)
                            page.nextQuestion()
                        }
                    }

                    ComboBox {
                        id: modePick
                        font.pixelSize: Theme.trainerCaptionPx
                        Layout.preferredWidth: 104
                        model: ["open"]
                        currentIndex: 0
                        enabled: false
                    }

                    Item { Layout.fillWidth: true }
                }

                Connections {
                    target: trainingStore
                    function onTrainerAutoAdvanceMsChanged() {
                        delaySecSpin.value = Math.round(trainingStore.trainerAutoAdvanceMs / 1000)
                    }
                    function onTrainerDecisionSecondsChanged() {
                        timeLimitSpin.value = trainingStore.trainerDecisionSeconds
                    }
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr(
                        "Random two cards each hand. Your choice is scored against the 13×13 weights for the position/mode (see JSON). "
                        + "Grade uses that action’s frequency: ≥70% Correct, ≥5% Mix, else Wrong. Feedback shows the highest-weight action as “best”. "
                        + "Changing position reloads the scenario; use Training picks to leave.")
                    color: Theme.textSecondary
                    font.pixelSize: Theme.trainerBodyPx
                    lineHeight: 1.25
                }

                Rectangle {
                    id: drillPanel
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(Theme.trainerDrillPanelMinH,
                            Math.min(Theme.trainerDrillPanelMaxH,
                                scrollView.availableHeight > 0
                                    ? scrollView.availableHeight * Theme.trainerDrillPanelViewportFrac
                                    : Theme.trainerDrillPanelFallbackH))
                    radius: Theme.trainerPanelRadius
                    color: Qt.alpha(Theme.panel, 0.35)
                    border.width: 1
                    border.color: Qt.alpha(Theme.chromeLine, 0.55)
                    clip: true

                    Item {
                        id: drillArea
                        anchors.fill: parent
                        anchors.margins: 2

                        readonly property Item humanSeat: trainerSeatWrap
                        /// Same formula as `Game.qml` table HUD (seat is nested in a layout — use `mapFromItem` below).
                        readonly property real hudPanelW: Math.min(400, Math.max(Theme.trainerEmbeddedHudMinWidth,
                                drillArea.width * 0.36))

                        ColumnLayout {
                            id: preflopDrillStack
                            anchors.fill: parent
                            spacing: 10

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 6
                                width: trainerPotBanner.implicitWidth + 22
                                height: trainerPotBanner.implicitHeight + 12
                                radius: 8
                                color: Theme.hudBg1
                                border.color: Theme.hudBorder
                                border.width: 2

                                Label {
                                    id: trainerPotBanner
                                    anchors.centerIn: parent
                                    text: qsTr("Pot $%1").arg(page.trainerPotChips)
                                    color: Theme.gold
                                    font.family: Theme.fontFamilyUi
                                    font.pixelSize: Theme.trainerCaptionPx
                                    font.bold: true
                                }
                            }

                            Item {
                                Layout.fillHeight: true
                                Layout.minimumHeight: 16
                            }

                            Item {
                                id: trainerSeatWrap
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 218
                                Layout.preferredHeight: 312
                                Layout.bottomMargin: 4
                                width: 218
                                height: 312

                                Player {
                                    anchors.fill: parent
                                    name: qsTr("You")
                                    position: page.position
                                    first_card: page.card1
                                    second_card: page.card2
                                    show_cards: true
                                    inHand: true
                                    seatAtTable: true
                                    stackChips: 200
                                    streetActionText: page.position + " · " + page.mode
                                    handEpoch: page.seatVisualEpoch
                                    instantHoleCards: true
                                    isHumanSeat: true
                                    isActing: page.decisionSecLeft > 0 && !page.inputLocked
                                    decisionSecondsLeft: page.decisionSecLeft
                                }
                            }
                        }

                        GameControls {
                            id: exerciseHud
                            z: 20
                            trainerMode: true
                            trainerFlopStreet: false
                            pokerGame: null
                            embeddedMode: true
                            panelWidth: drillArea.hudPanelW
                            x: Math.max(6, drillArea.width - exerciseHud.width - Theme.trainerHudSeatMargin)
                            y: {
                                var hs = drillArea.humanSeat
                                if (!hs)
                                    return 8
                                var pos = drillArea.mapFromItem(hs, 0, 0)
                                var ideal = pos.y + hs.height - exerciseHud.height
                                return Math.min(Math.max(6, ideal), drillArea.height - exerciseHud.height - 6)
                            }
                            trainerInputLocked: page.inputLocked
                            humanSitOut: false
                            statusText: page.statusLine
                            statusSubText: page.secLeft > 0
                                    ? qsTr("Next hand in %1 s").arg(page.secLeft)
                                    : ""
                            humanHandText: ""
                            decisionSecondsLeft: page.inputLocked ? page.secLeft : page.decisionSecLeft
                            decisionTimeTotal: trainingStore.trainerDecisionSeconds
                            humanMoreTimeAvailable: false
                            humanCanCheck: false
                            humanBbPreflopOption: false
                            humanCanRaiseFacing: true
                            facingNeedChips: 3
                            facingMinRaiseChips: 6
                            facingMaxChips: 200
                            facingPotAmount: page.trainerPotChips
                            humanStackChips: 200
                            humanBbCanRaise: false
                            humanCanBuyBackIn: false
                        }

                        Connections {
                            target: exerciseHud
                            function onTrainerAction(action, amount) {
                                const u = String(action).toUpperCase()
                                if (u === "FOLD")
                                    page.submit("fold")
                                else if (u === "CALL")
                                    page.submit("call")
                                else if (u === "RAISE")
                                    page.submit("raise")
                            }
                        }

                        MouseArea {
                            z: 19
                            anchors.fill: parent
                            visible: exerciseHud.sizingDialogOpen
                            onClicked: {
                                exerciseHud.raiseSizingExpanded = false
                                exerciseHud.openRaiseSizingExpanded = false
                                exerciseHud.bbPreflopSizingExpanded = false
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
        }
    }
}
