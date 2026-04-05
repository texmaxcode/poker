import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0
import PokerUi 1.0

Page {
    id: page
    padding: 0
    font.family: Theme.fontFamilyUi

    property StackLayout stackLayout: null

    readonly property int trainerControlColumns: scrollView.availableWidth < 480 ? 2 : 4

    property string statusLine: qsTr("Starting…")
    property string board0: ""
    property string board1: ""
    property string board2: ""
    property string board3: ""
    property string board4: ""
    property string hero1: ""
    property string hero2: ""
    property string spotId: ""
    property bool inputLocked: false
    property int secLeft: 0
    property int decisionSecLeft: 0
    property real decisionDeadlineMs: 0
    property real advanceDeadlineMs: 0
    property int seatVisualEpoch: 0
    property bool _returningFromHidden: false
    property bool _drillSurfaceShown: false
    property bool assetLoadFailed: false
    readonly property real flopSpotPotBb: 5.5
    /// $2 BB → chip pot for display (matches ~5.5 bb spot).
    readonly property int trainerPotChips: Math.round(page.flopSpotPotBb * 2)
    property int trainerPotShown: trainerPotChips

    function resetTrainerPotDisplay() {
        trainerPotCountAnim.stop()
        trainerPotShown = trainerPotChips
    }

    function bumpTrainerPot(delta) {
        const d = Math.round(Number(delta))
        if (!isFinite(d) || d <= 0)
            return
        trainerPotCountAnim.stop()
        trainerPotCountAnim.from = trainerPotShown
        trainerPotCountAnim.to = trainerPotShown + d
        trainerPotCountAnim.restart()
        trainerPotBumpAnim.restart()
    }

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
            submit("check")
        }
    }

    function tickAdvanceTimer() {
        const left = Math.max(0, Math.ceil((advanceDeadlineMs - Date.now()) / 1000))
        secLeft = left
        if (left <= 0) {
            secTimer.stop()
            advanceDeadlineMs = 0
            inputLocked = false
            next()
        }
    }

    function syncTrainerClocks() {
        if (inputLocked && advanceDeadlineMs <= 0 && decisionDeadlineMs <= 0) {
            secTimer.stop()
            inputLocked = false
            next()
            return
        }
        if (!inputLocked && decisionDeadlineMs > 0) {
            const left = Math.max(0, Math.ceil((decisionDeadlineMs - Date.now()) / 1000))
            decisionSecLeft = left
            if (left <= 0) {
                decisionTimer.stop()
                decisionSecLeft = 0
                decisionDeadlineMs = 0
                submit("check")
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
                next()
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

    function stopDrillWhileAway() {
        cancelPendingAdvance()
    }

    function restartDrillAfterReturn() {
        if (page.assetLoadFailed)
            return
        trainer.startRiverDrill("srp_btn_bb")
        next()
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
        const ok = trainer.loadRiverSpots("qrc:/assets/training/spots_river_v1.json")
        page.assetLoadFailed = !ok
        if (!ok) {
            statusLine = qsTr("Could not load river spots.")
            return
        }
        trainer.startRiverDrill("srp_btn_bb")
        next()
    }

    function next() {
        cancelPendingAdvance()
        const q = trainer.nextRiverQuestion()
        if (q.error !== undefined) {
            statusLine = String(q.error)
            return
        }
        spotId = String(q.spotId)
        hero1 = String(q.hero1)
        hero2 = String(q.hero2)
        board0 = String(q.board0)
        board1 = String(q.board1)
        board2 = String(q.board2)
        board3 = String(q.board3)
        board4 = String(q.board4)
        seatVisualEpoch++
        resetTrainerPotDisplay()
        statusLine = qsTr("Spot %1").arg(spotId)
        startDecisionClock()
    }

    function submit(a) {
        decisionTimer.stop()
        decisionSecLeft = 0
        decisionDeadlineMs = 0
        const r = trainer.submitRiverAnswer(a)
        if (r.error !== undefined) {
            statusLine = String(r.error)
            startAutoAdvance()
            return
        }
        statusLine = qsTr("%1 — %2 (freq %3%) · EV loss %4 bb")
                .arg(spotId)
                .arg(String(r.grade))
                .arg(Math.round(Number(r.chosenFreq) * 100))
                .arg(Number(r.evLossBb).toFixed(3))
        startAutoAdvance()
    }

    function scrollMainToTop() {
        var flick = scrollView.contentItem
        if (flick) {
            flick.contentY = 0
            flick.contentX = 0
        }
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true
        topPadding: Theme.uiScrollViewTopPadding

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

                Text {
                    Layout.fillWidth: true
                    visible: page.assetLoadFailed
                    wrapMode: Text.WordWrap
                    text: qsTr("River spots failed to load. The bundled JSON asset may be missing or invalid.")
                    color: Theme.dangerText
                    font.pixelSize: Theme.trainerBodyPx
                    lineHeight: Theme.bodyLineHeight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    GameButton {
                        style: "form"
                        formFlat: true
                        text: qsTr("Training picks")
                        formFontPixelSize: Theme.trainerToolButtonPx
                        textColor: Theme.textPrimary
                        horizontalPadding: 14
                        onClicked: page.goTrainingHome()
                    }

                    Item { Layout.fillWidth: true }
                }

                GridLayout {
                    Layout.fillWidth: true
                    rowSpacing: 10
                    columnSpacing: 12
                    columns: page.trainerControlColumns

                    Label {
                        text: qsTr("Delay")
                        color: Theme.textMuted
                        font.pixelSize: Theme.trainerCaptionPx
                    }
                    SpinBox {
                        id: delaySecSpin
                        font.pixelSize: Theme.trainerCaptionPx
                        Layout.fillWidth: page.trainerControlColumns <= 2
                        Layout.preferredWidth: page.trainerControlColumns >= 4 ? Theme.trainerSpinBoxWidth : implicitWidth
                        from: 1
                        to: 120
                        editable: true
                        enabled: !page.assetLoadFailed
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
                        font.pixelSize: Theme.trainerCaptionPx
                        Layout.fillWidth: page.trainerControlColumns <= 2
                        Layout.preferredWidth: page.trainerControlColumns >= 4 ? Theme.trainerSpinBoxWidth : implicitWidth
                        from: 5
                        to: 120
                        editable: true
                        enabled: !page.assetLoadFailed
                        stepSize: 1
                        textFromValue: function (v) { return v + qsTr(" s") }
                        valueFromText: function (t) { return parseInt(t, 10) }
                        onValueModified: trainingStore.trainerDecisionSeconds = value
                    }
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

                Rectangle {
                    id: drillPanel
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.trainerDrillPanelHeight(scrollView.availableHeight)
                    radius: Theme.trainerPanelRadius
                    color: Qt.alpha(Theme.panel, 0.35)
                    border.width: 1
                    border.color: Qt.alpha(Theme.chromeLine, 0.55)
                    clip: true

                    Item {
                        id: drillArea
                        anchors.fill: parent
                        anchors.margins: 2

                        readonly property int seatReserve: 280
                        readonly property real seatScale: {
                            var h = drillPanel.height
                            if (h <= 0)
                                return 1.0
                            return Math.min(1.0, Math.max(0.48, (h - seatReserve) / 300))
                        }

                        readonly property int riverStripIntrinsic: 5 * Theme.trainerFlopBoardCardWidth
                                + 4 * Theme.trainerDrillHudSpacing
                        readonly property real boardStripScale: Math.min(1.0, Math.max(0.24,
                                (drillArea.width - 20) / Math.max(1, riverStripIntrinsic)))
                        readonly property int drillCardW: Math.max(28, Math.round(Theme.trainerFlopBoardCardWidth * boardStripScale))
                        readonly property int drillCardH: Math.max(44, Math.round(Theme.trainerFlopBoardCardHeight * boardStripScale))
                        readonly property int drillCardGap: Math.max(3, Math.round(Theme.trainerDrillHudSpacing * boardStripScale))
                        readonly property int riverBoardStripWidth: 5 * drillCardW + 4 * drillCardGap

                        readonly property Item humanSeat: trainerSeatWrap
                        /// Same formula as `Game.qml` table HUD (seat is nested in a layout — use `mapFromItem` below).
                        readonly property real hudPanelW: Math.min(400, Math.max(Theme.trainerEmbeddedHudMinWidth,
                                drillArea.width * 0.36))

                        ColumnLayout {
                            id: flopDrillStack
                            anchors.fill: parent
                            spacing: 10

                            Column {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 0
                                spacing: 8
                                width: drillArea.riverBoardStripWidth

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: flopPotBanner.implicitWidth + 22
                                    height: flopPotBanner.implicitHeight + 12
                                    radius: 8
                                    color: Theme.hudBg1
                                    border.color: Theme.hudBorder
                                    border.width: 2

                                    Text {
                                        id: flopPotBanner
                                        anchors.centerIn: parent
                                        text: qsTr("Pot $%1").arg(Math.round(page.trainerPotShown))
                                        color: Theme.gold
                                        font.family: Theme.fontFamilyMono
                                        font.pixelSize: Math.max(10, Math.round(Theme.trainerCaptionPx
                                                * Math.max(0.82, drillArea.boardStripScale)))
                                        font.bold: true

                                        transform: Scale {
                                            id: flopTrainerPotValueScale
                                            origin.x: flopPotBanner.width * 0.5
                                            origin.y: flopPotBanner.height * 0.5
                                            xScale: 1
                                            yScale: 1
                                        }
                                    }
                                }

                                Row {
                                    id: flopBoardRow
                                    spacing: drillArea.drillCardGap
                                    width: drillArea.riverBoardStripWidth
                                    Card {
                                        width: drillArea.drillCardW
                                        height: drillArea.drillCardH
                                        displayScaleFactor: drillArea.boardStripScale
                                        card: board0
                                        flipped: true
                                        tableCard: true
                                        instantFace: true
                                    }
                                    Card {
                                        width: drillArea.drillCardW
                                        height: drillArea.drillCardH
                                        displayScaleFactor: drillArea.boardStripScale
                                        card: board1
                                        flipped: true
                                        tableCard: true
                                        instantFace: true
                                    }
                                    Card {
                                        width: drillArea.drillCardW
                                        height: drillArea.drillCardH
                                        displayScaleFactor: drillArea.boardStripScale
                                        card: board2
                                        flipped: true
                                        tableCard: true
                                        instantFace: true
                                    }
                                    Card {
                                        width: drillArea.drillCardW
                                        height: drillArea.drillCardH
                                        displayScaleFactor: drillArea.boardStripScale
                                        card: board3
                                        flipped: true
                                        tableCard: true
                                        instantFace: true
                                    }
                                    Card {
                                        width: drillArea.drillCardW
                                        height: drillArea.drillCardH
                                        displayScaleFactor: drillArea.boardStripScale
                                        card: board4
                                        flipped: true
                                        tableCard: true
                                        instantFace: true
                                    }
                                }
                            }

                            Item {
                                Layout.fillHeight: true
                                Layout.minimumHeight: 16
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(180, Math.round(312 * drillArea.seatScale))
                                Layout.minimumHeight: Math.max(160, Math.round(200 * drillArea.seatScale))
                                Layout.bottomMargin: 4

                                Item {
                                    id: trainerSeatWrap
                                    width: Math.round(218 * drillArea.seatScale)
                                    height: Math.round(312 * drillArea.seatScale)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.horizontalCenterOffset: Math.round(Theme.trainerDrillSeatCenterOffset * drillArea.seatScale)

                                Player {
                                    anchors.fill: parent
                                    uiScale: drillArea.seatScale
                                    seatIndex: 0
                                    name: qsTr("You")
                                    position: "BTN"
                                    first_card: page.hero1
                                    second_card: page.hero2
                                    show_cards: true
                                    inHand: true
                                    seatAtTable: true
                                    stackChips: 200
                                    streetActionText: page.spotId.length ? page.spotId : qsTr("River")
                                    handEpoch: page.seatVisualEpoch
                                    instantHoleCards: true
                                    isHumanSeat: true
                                    isActing: page.decisionSecLeft > 0 && !page.inputLocked
                                    decisionSecondsLeft: page.decisionSecLeft
                                }
                                }
                            }
                        }

                        GameControls {
                            id: flopExerciseHud
                            z: 20
                            trainerMode: true
                            trainerFlopStreet: true
                            pokerGame: null
                            embeddedMode: true
                            panelWidth: drillArea.hudPanelW
                            x: {
                                var hs = drillArea.humanSeat
                                if (!hs)
                                    return 8
                                var gap = Theme.trainerDrillHudSpacing
                                var w = flopExerciseHud.width
                                var pos = drillArea.mapFromItem(hs, 0, 0)
                                var placeRight = pos.x + hs.width + gap
                                if (placeRight + w <= drillArea.width - 6)
                                    return placeRight
                                return Math.max(6, pos.x - w - gap)
                            }
                            y: {
                                var hs = drillArea.humanSeat
                                if (!hs)
                                    return 8
                                var pos = drillArea.mapFromItem(hs, 0, 0)
                                var ideal = pos.y + hs.height - flopExerciseHud.height
                                return Math.min(Math.max(6, ideal), drillArea.height - flopExerciseHud.height - 6)
                            }
                            trainerInputLocked: page.inputLocked || page.assetLoadFailed
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
                            facingNeedChips: 0
                            facingMinRaiseChips: 6
                            facingMaxChips: 200
                            facingPotAmount: page.trainerPotChips
                            humanStackChips: 200
                            humanBbCanRaise: false
                            humanCanBuyBackIn: false
                        }

                        Connections {
                            target: flopExerciseHud
                            function onTrainerAction(action, amount) {
                                const u = String(action).toUpperCase()
                                if (u === "CHECK")
                                    page.submit("check")
                                else if (u === "BET33") {
                                    page.bumpTrainerPot(Number(amount))
                                    page.submit("bet33")
                                } else if (u === "BET75") {
                                    page.bumpTrainerPot(Number(amount))
                                    page.submit("bet75")
                                }
                            }
                        }

                        MouseArea {
                            z: 19
                            anchors.fill: parent
                            visible: flopExerciseHud.sizingDialogOpen
                            onClicked: {
                                flopExerciseHud.raiseSizingExpanded = false
                                flopExerciseHud.openRaiseSizingExpanded = false
                                flopExerciseHud.bbPreflopSizingExpanded = false
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

    Item {
        id: trainerPotAnimHost
        width: 0
        height: 0
        opacity: 0

        NumberAnimation {
            id: trainerPotCountAnim
            target: page
            property: "trainerPotShown"
            duration: 320
            easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            id: trainerPotBumpAnim
            ParallelAnimation {
                NumberAnimation {
                    target: flopTrainerPotValueScale
                    property: "xScale"
                    to: 1.08
                    duration: 95
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: flopTrainerPotValueScale
                    property: "yScale"
                    to: 1.08
                    duration: 95
                    easing.type: Easing.OutCubic
                }
            }
            ParallelAnimation {
                NumberAnimation {
                    target: flopTrainerPotValueScale
                    property: "xScale"
                    to: 1.0
                    duration: 160
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: flopTrainerPotValueScale
                    property: "yScale"
                    to: 1.0
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
