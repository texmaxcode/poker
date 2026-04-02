import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

/// Bottom HUD (full width) or floating panel beside the human seat (`embeddedMode`).
Item {
    id: game_controls
    width: game_controls.embeddedMode
          ? (game_controls.panelWidth > 0 ? game_controls.panelWidth : implicitWidth)
          : (parent ? parent.width : implicitWidth)
    height: mainCol.height + 12

    /// When true, use compact timer row instead of full-width status row.
    property bool embeddedMode: false
    /// Used when `embeddedMode` is true; set from `Game.qml` so the panel does not span the table width.
    property real panelWidth: 0

    property var pageRoot: null
    property var pokerGame: null
    property bool humanSitOut: false
    property string statusText: ""
    /// Trainer / HUD: secondary line (e.g. “Next hand in N s”) shown beside the timer strip, not merged into `statusText`.
    property string statusSubText: ""
    /// Table only: `qrc:/assets/cards/*.svg` names for the winning hand (hole cards only).
    property var resultBannerCardAssets: []
    property string humanHandText: ""
    property int decisionSecondsLeft: 0
    /// For progress bar scaling (table = 20s; trainers may use `trainingStore.trainerDecisionSeconds`).
    property int decisionTimeTotal: 20
    property bool humanMoreTimeAvailable: false
    property bool humanCanCheck: false
    property bool humanBbPreflopOption: false
    property bool humanCanRaiseFacing: false
    property bool humanBbCanRaise: false
    property int facingNeedChips: 0
    property int facingMinRaiseChips: 0
    property int facingMaxChips: 0
    property int facingPotAmount: 0
    property int openRaiseMinChips: 0
    property int openRaiseMaxChips: 0
    property int bbPreflopMinChips: 0
    property int bbPreflopMaxChips: 0
    property int humanStackChips: 0
    property bool humanCanBuyBackIn: false
    property int buyInChips: 100

    /// When true, FOLD/CALL/RAISE + raise sizing emit `trainerAction` instead of `pokerGame`.
    property bool trainerMode: false
    /// With `trainerMode`, use flop drill actions (CHECK / Bet 33% / Bet 75%) instead of FOLD/CALL/RAISE.
    property bool trainerFlopStreet: false
    /// Disables actions (e.g. trainer auto-advance) while keeping the HUD visible.
    property bool trainerInputLocked: false

    signal trainerAction(string action, int amountChips)

    readonly property bool humanDecisionActive: trainerMode
            ? (!trainerInputLocked && decisionSecondsLeft > 0)
            : (decisionSecondsLeft > 0 && humanStackChips > 0)
    readonly property bool humanHasChips: humanStackChips > 0
    /// Busted (0 stack) players watch but do not get the action UI.
    readonly property bool showWagerUi: !humanSitOut && humanStackChips > 0
    readonly property bool facingRaise: !humanCanCheck && !humanBbPreflopOption
            && (trainerMode ? (!trainerInputLocked && decisionSecondsLeft > 0) : humanDecisionActive)
    readonly property bool checkOrRaiseSized: humanDecisionActive && humanCanCheck && !humanBbPreflopOption
    readonly property bool canFacingCall: facingRaise && (facingNeedChips <= 0 || humanHasChips)
    readonly property bool canRaiseFacing: facingRaise && humanCanRaiseFacing && humanHasChips
    readonly property bool canOpenRaise: checkOrRaiseSized && humanHasChips && openRaiseMinChips > 0
            && openRaiseMaxChips >= openRaiseMinChips

    readonly property bool showHumanActions: !humanSitOut

    /// Table: hand strength is shown in the dedicated row above; banner is status / showdown only.
    readonly property string statusFullDisplay: {
        if (humanSitOut)
            return (statusText.length > 0) ? statusText : qsTr("Watching — next hand you skip.")
        var base = statusText.length > 0 ? statusText : qsTr("Ready.")
        if (trainerMode) {
            var hand = humanHandText.length > 0 ? humanHandText : ""
            if (hand.length > 0 && base.length > 0)
                return hand + "\n" + base
            return hand.length > 0 ? hand : base
        }
        return base
    }

    /// Show raise slider + presets only after the user taps RAISE (facing a raise).
    property bool raiseSizingExpanded: false
    /// Show open-raise slider + presets only after Raise (first in on the street).
    property bool openRaiseSizingExpanded: false
    /// BB preflop: choose amount to add over the big blind.
    property bool bbPreflopSizingExpanded: false

    readonly property bool sizingDialogOpen: raiseSizingExpanded || openRaiseSizingExpanded
            || bbPreflopSizingExpanded

    function raiseSpinSafeMin() {
        return Math.min(facingMinRaiseChips, facingMaxChips)
    }

    function raiseSpinSafeMax() {
        return Math.max(facingMinRaiseChips, facingMaxChips)
    }

    function openRaiseSafeMin() {
        return Math.min(openRaiseMinChips, openRaiseMaxChips)
    }

    function openRaiseSafeMax() {
        return Math.max(openRaiseMinChips, openRaiseMaxChips)
    }

    function bbPreflopSpinSafeMin() {
        return Math.min(bbPreflopMinChips, bbPreflopMaxChips)
    }

    function bbPreflopSpinSafeMax() {
        return Math.max(bbPreflopMinChips, bbPreflopMaxChips)
    }

    function submitBbPreflopRaise() {
        if (trainerMode)
            return
        if (!pokerGame || !game_controls.bbPreflopSizingExpanded || !game_controls.humanBbPreflopOption
                || !game_controls.humanBbCanRaise)
            return
        pokerGame.submitBbPreflopRaise(Math.round(bbPreflopSlider.value))
    }

    function submitFacingRaise() {
        if (trainerMode) {
            if (!game_controls.raiseSizingExpanded || !game_controls.canRaiseFacing
                    || !game_controls.facingRaise)
                return
            game_controls.trainerAction("raise", Math.round(raiseSlider.value))
            game_controls.raiseSizingExpanded = false
            return
        }
        if (!pokerGame || !game_controls.raiseSizingExpanded || !game_controls.canRaiseFacing
                || !game_controls.facingRaise)
            return
        pokerGame.submitFacingAction(2, Math.round(raiseSlider.value))
    }

    function submitOpenRaise() {
        if (trainerMode)
            return
        if (!pokerGame || !game_controls.openRaiseSizingExpanded || !game_controls.canOpenRaise
                || !game_controls.checkOrRaiseSized)
            return
        pokerGame.submitCheckOrBet(false, Math.round(openRaiseSlider.value))
    }

    Connections {
        target: raiseSlider
        function onPressedChanged() {
            if (!raiseSlider.pressed)
                game_controls.submitFacingRaise()
        }
    }

    Connections {
        target: openRaiseSlider
        function onPressedChanged() {
            if (!openRaiseSlider.pressed)
                game_controls.submitOpenRaise()
        }
    }

    Connections {
        target: game_controls
        function onFacingRaiseChanged() {
            if (!game_controls.facingRaise)
                game_controls.raiseSizingExpanded = false
        }
        function onHumanDecisionActiveChanged() {
            if (!game_controls.humanDecisionActive) {
                game_controls.raiseSizingExpanded = false
                game_controls.openRaiseSizingExpanded = false
                game_controls.bbPreflopSizingExpanded = false
            }
        }
        function onCheckOrRaiseSizedChanged() {
            if (!game_controls.checkOrRaiseSized)
                game_controls.openRaiseSizingExpanded = false
        }
        function onCanRaiseFacingChanged() {
            if (!game_controls.canRaiseFacing)
                game_controls.raiseSizingExpanded = false
        }
        function onCanOpenRaiseChanged() {
            if (!game_controls.canOpenRaise)
                game_controls.openRaiseSizingExpanded = false
        }
        function onHumanBbPreflopOptionChanged() {
            if (!game_controls.humanBbPreflopOption)
                game_controls.bbPreflopSizingExpanded = false
        }
    }

    Rectangle {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        height: mainCol.height + 12
        radius: 10
        color: Theme.headerBg
        border.width: 1
        border.color: Qt.alpha(Theme.gold, 0.25)

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            radius: 10
            color: Qt.alpha(Theme.gold, 0.12)
        }

        Column {
            id: mainCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 6
            spacing: 10

            Text {
                id: trainerMessageLine
                visible: game_controls.trainerMode && game_controls.showHumanActions
                        && game_controls.showWagerUi
                width: parent.width - 16
                x: 8
                text: game_controls.statusText.length > 0 ? game_controls.statusText : qsTr("Ready.")
                color: Theme.textPrimary
                font.family: Theme.fontFamilyUi
                font.pixelSize: Theme.uiBodyPx
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }

            Column {
                id: decisionChrome
                width: parent.width - 16
                x: 8
                spacing: 8
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && (!game_controls.embeddedMode || game_controls.humanDecisionActive
                            || (game_controls.trainerMode && game_controls.statusSubText.length > 0))

                RowLayout {
                    width: parent.width
                    spacing: game_controls.embeddedMode ? 12 : 8

                    Text {
                        visible: game_controls.humanDecisionActive
                        text: qsTr("Act")
                        color: Theme.hudActionLabel
                        font.family: Theme.fontFamilyUi
                        font.pixelSize: Theme.uiMicroPx
                        font.bold: true
                        Layout.preferredWidth: visible ? implicitWidth : 0
                    }

                    Text {
                        visible: game_controls.humanDecisionActive
                        text: qsTr("%1s").arg(game_controls.decisionSecondsLeft)
                        color: Theme.seatBorderAct
                        font.family: Theme.fontFamilyUi
                        font.pointSize: Theme.uiSmallPx
                        font.bold: true
                        Layout.preferredWidth: visible ? implicitWidth : 0
                    }

                    HudButton {
                        visible: !game_controls.trainerMode && game_controls.humanDecisionActive
                                && game_controls.humanMoreTimeAvailable
                        pillWidth: 76
                        horizontalPadding: 14
                        fontSize: Theme.uiHudButtonPt
                        label: qsTr("More")
                        buttonColor: Theme.hudActionPanel
                        textColor: Theme.hudActionBright
                        implicitHeight: 34
                        Layout.preferredWidth: visible ? 76 : 0
                        onClicked: {
                            if (pageRoot)
                                pageRoot.buttonClicked("MORE_TIME")
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        height: 1
                    }

                    Label {
                        visible: game_controls.statusSubText.length > 0
                        text: game_controls.statusSubText
                        color: Theme.textSecondary
                        font.family: Theme.fontFamilyUi
                        font.pixelSize: Theme.uiMicroPx
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                        Layout.maximumWidth: Math.min(200, parent.width * 0.55)
                    }
                }

                ProgressBar {
                    id: embeddedDecisionBar
                    visible: game_controls.embeddedMode
                            && (game_controls.humanDecisionActive
                                || (game_controls.trainerMode && game_controls.statusSubText.length > 0))
                    width: parent.width
                    height: 6
                    padding: 2
                    from: 0
                    to: 1
                    value: Math.max(0, Math.min(1,
                            game_controls.decisionSecondsLeft / Math.max(1, game_controls.decisionTimeTotal)))
                    background: Rectangle {
                        implicitHeight: 6
                        implicitWidth: 200
                        radius: 3
                        color: Theme.progressTrack
                    }
                    contentItem: Item {
                        implicitHeight: 6
                        Rectangle {
                            width: embeddedDecisionBar.visualPosition * parent.width
                            height: parent.height
                            radius: 3
                            color: Theme.seatBorderAct
                        }
                    }
                }
            }

            // Raise sizing (facing a raise): above FOLD / CALL / RAISE
            Rectangle {
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && game_controls.facingRaise
                        && game_controls.canRaiseFacing
                        && game_controls.raiseSizingExpanded
                        && !(game_controls.trainerMode && game_controls.trainerFlopStreet)
                width: parent.width
                height: visible ? raiseSizerCol.implicitHeight + 16 : 0
                color: Theme.panelElevated
                border.color: Theme.inputBorder
                border.width: 1
                clip: true

                Column {
                    id: raiseSizerCol
                    width: parent.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    spacing: 8

                    RowLayout {
                        width: parent.width
                        spacing: 8
                        Slider {
                            id: raiseSlider
                            Layout.fillWidth: true
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
                        Text {
                            Layout.preferredWidth: 52
                            text: Math.round(raiseSlider.value)
                            color: Theme.focusGold
                            font.family: Theme.fontFamilyUi
                            font.pixelSize: Theme.uiBodyPx
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Connections {
                        target: game_controls
                        function onFacingMinRaiseChipsChanged() {
                            raiseSlider.syncRaiseSlider()
                        }
                        function onFacingMaxChipsChanged() {
                            raiseSlider.syncRaiseSlider()
                        }
                        function onFacingRaiseChanged() {
                            if (game_controls.facingRaise)
                                raiseSlider.syncRaiseSlider()
                        }
                    }

                    SizingPresetBar {
                        id: raisePresetRow
                        width: parent.width
                        hud: game_controls
                        slider: raiseSlider
                        flavor: "raise"
                        afterPreset: game_controls.submitFacingRaise
                    }
                }
            }

            // Facing a raise: fold / call / raise (table + preflop drill), or flop drill check / bets — one row, same geometry as preflop.
            Row {
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && game_controls.facingRaise
                width: parent.width - 16
                x: 8
                spacing: 12

                HudButton {
                    visible: !game_controls.trainerMode || !game_controls.trainerFlopStreet
                    label: qsTr("FOLD")
                    pillWidth: 76
                    buttonColor: Theme.dangerBg
                    textColor: Theme.dangerText
                    fontSize: Theme.uiHudButtonPt
                    clickEnabled: game_controls.trainerMode
                            ? (!game_controls.trainerInputLocked && game_controls.facingRaise
                                    && game_controls.decisionSecondsLeft > 0)
                            : game_controls.facingRaise
                    opacity: game_controls.facingRaise ? 1.0 : 0.42
                    onClicked: {
                        if (game_controls.trainerMode) {
                            game_controls.trainerAction("FOLD", 0)
                            return
                        }
                        if (pageRoot && game_controls.facingRaise)
                            pageRoot.buttonClicked("FOLD")
                    }
                }

                HudButton {
                    visible: game_controls.canFacingCall
                            && (!game_controls.trainerMode || !game_controls.trainerFlopStreet)
                    label: game_controls.facingNeedChips > 0
                          ? qsTr("Call %1").arg(game_controls.facingNeedChips)
                          : qsTr("CALL")
                    pillWidth: 108
                    buttonColor: Theme.focusGold
                    textColor: Theme.insetDark
                    fontSize: Theme.uiHudButtonPt
                    clickEnabled: game_controls.trainerMode
                            ? (!game_controls.trainerInputLocked && game_controls.facingRaise
                                    && game_controls.decisionSecondsLeft > 0)
                            : true
                    onClicked: {
                        if (game_controls.trainerMode) {
                            game_controls.trainerAction("CALL", 0)
                            return
                        }
                        if (pageRoot && game_controls.facingRaise)
                            pageRoot.buttonClicked("CALL")
                    }
                }

                HudButton {
                    visible: game_controls.canRaiseFacing && !game_controls.raiseSizingExpanded
                            && (!game_controls.trainerMode || !game_controls.trainerFlopStreet)
                    label: qsTr("RAISE")
                    pillWidth: 88
                    buttonColor: Theme.successGreen
                    textColor: Theme.onAccentText
                    fontSize: Theme.uiHudButtonPt
                    clickEnabled: game_controls.trainerMode
                            ? (!game_controls.trainerInputLocked && game_controls.facingRaise
                                    && game_controls.decisionSecondsLeft > 0)
                            : true
                    onClicked: {
                        if (game_controls.trainerMode && game_controls.trainerInputLocked)
                            return
                        if (game_controls.trainerMode && game_controls.decisionSecondsLeft <= 0)
                            return
                        game_controls.raiseSizingExpanded = true
                    }
                }

                HudButton {
                    visible: game_controls.trainerMode && game_controls.trainerFlopStreet
                    label: qsTr("CHECK")
                    pillWidth: 76
                    buttonColor: Theme.panelBorder
                    textColor: Theme.textPrimary
                    fontSize: Theme.uiHudButtonPt
                    clickEnabled: !game_controls.trainerInputLocked && game_controls.facingRaise
                            && game_controls.decisionSecondsLeft > 0
                    opacity: game_controls.facingRaise ? 1.0 : 0.42
                    onClicked: {
                        if (game_controls.trainerMode)
                            game_controls.trainerAction("CHECK", 0)
                    }
                }

                HudButton {
                    visible: game_controls.trainerMode && game_controls.trainerFlopStreet
                    label: qsTr("Bet 33%")
                    pillWidth: 108
                    buttonColor: Theme.focusGold
                    textColor: Theme.insetDark
                    fontSize: Theme.uiHudButtonPt
                    clickEnabled: !game_controls.trainerInputLocked && game_controls.facingRaise
                            && game_controls.decisionSecondsLeft > 0
                    opacity: game_controls.facingRaise ? 1.0 : 0.42
                    onClicked: {
                        if (game_controls.trainerMode)
                            game_controls.trainerAction("BET33", 0)
                    }
                }

                HudButton {
                    visible: game_controls.trainerMode && game_controls.trainerFlopStreet
                    label: qsTr("Bet 75%")
                    pillWidth: 88
                    buttonColor: Theme.successGreen
                    textColor: Theme.onAccentText
                    fontSize: Theme.uiHudButtonPt
                    clickEnabled: !game_controls.trainerInputLocked && game_controls.facingRaise
                            && game_controls.decisionSecondsLeft > 0
                    opacity: game_controls.facingRaise ? 1.0 : 0.42
                    onClicked: {
                        if (game_controls.trainerMode)
                            game_controls.trainerAction("BET75", 0)
                    }
                }
            }

            // BB preflop raise sizing (chips to add on top of posting BB)
            Rectangle {
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && game_controls.humanDecisionActive
                        && game_controls.humanBbPreflopOption
                        && game_controls.humanBbCanRaise
                        && game_controls.bbPreflopSizingExpanded
                        && game_controls.bbPreflopMaxChips >= game_controls.bbPreflopMinChips
                width: parent.width
                height: visible ? bbPreflopSizerCol.implicitHeight + 16 : 0
                color: Theme.panelElevated
                border.color: Theme.inputBorder
                border.width: 1
                clip: true

                Column {
                    id: bbPreflopSizerCol
                    width: parent.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    spacing: 8

                    RowLayout {
                        width: parent.width
                        spacing: 8
                        Slider {
                            id: bbPreflopSlider
                            Layout.fillWidth: true
                            from: game_controls.bbPreflopSpinSafeMin()
                            to: game_controls.bbPreflopSpinSafeMax()
                            stepSize: 1
                            snapMode: Slider.SnapAlways
                            value: from

                        function syncBbPreflopSlider() {
                            bbPreflopSlider.from = game_controls.bbPreflopSpinSafeMin()
                            bbPreflopSlider.to = game_controls.bbPreflopSpinSafeMax()
                            if (bbPreflopSlider.to < bbPreflopSlider.from) {
                                bbPreflopSlider.value = bbPreflopSlider.from
                                return
                            }
                            bbPreflopSlider.value = Math.min(
                                Math.max(game_controls.bbPreflopMinChips, bbPreflopSlider.from),
                                bbPreflopSlider.to)
                        }

                        Component.onCompleted: syncBbPreflopSlider()
                        }
                        Text {
                            Layout.preferredWidth: 52
                            text: Math.round(bbPreflopSlider.value)
                            color: Theme.focusGold
                            font.family: Theme.fontFamilyUi
                            font.pixelSize: Theme.uiBodyPx
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Connections {
                        target: bbPreflopSlider
                        function onPressedChanged() {
                            if (!bbPreflopSlider.pressed)
                                game_controls.submitBbPreflopRaise()
                        }
                    }

                    Connections {
                        target: game_controls
                        function onBbPreflopMinChipsChanged() {
                            bbPreflopSlider.syncBbPreflopSlider()
                        }
                        function onBbPreflopMaxChipsChanged() {
                            bbPreflopSlider.syncBbPreflopSlider()
                        }
                    }

                    SizingPresetBar {
                        width: parent.width
                        hud: game_controls
                        slider: bbPreflopSlider
                        flavor: "bb"
                        afterPreset: game_controls.submitBbPreflopRaise
                    }
                }
            }

            // BB preflop option
            Row {
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && game_controls.humanDecisionActive
                        && game_controls.humanBbPreflopOption
                width: parent.width - 16
                x: 8
                spacing: 12

                HudButton {
                    label: qsTr("CHECK")
                    pillWidth: 96
                    buttonColor: Theme.panelBorder
                    textColor: Theme.textPrimary
                    onClicked: {
                        if (game_controls.trainerMode)
                            return
                        if (pageRoot)
                            pageRoot.buttonClicked("CHECK")
                    }
                }

                HudButton {
                    visible: game_controls.humanBbCanRaise && game_controls.humanHasChips
                            && !game_controls.bbPreflopSizingExpanded
                    label: qsTr("Raise")
                    pillWidth: 96
                    buttonColor: Theme.successGreen
                    textColor: Theme.onAccentText
                    onClicked: {
                        if (game_controls.trainerMode)
                            return
                        game_controls.bbPreflopSizingExpanded = true
                    }
                }
            }

            // Open raise sizing (checked to you): above CHECK / FOLD / RAISE
            Rectangle {
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && game_controls.checkOrRaiseSized
                        && game_controls.canOpenRaise
                        && game_controls.openRaiseSizingExpanded
                width: parent.width
                height: visible ? openRaiseSizerCol.implicitHeight + 16 : 0
                color: Theme.panelElevated
                border.color: Theme.inputBorder
                border.width: 1
                clip: true

                Column {
                    id: openRaiseSizerCol
                    width: parent.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    spacing: 8

                    RowLayout {
                        width: parent.width
                        spacing: 8
                        Slider {
                            id: openRaiseSlider
                            Layout.fillWidth: true
                            from: game_controls.openRaiseSafeMin()
                            to: game_controls.openRaiseSafeMax()
                            stepSize: 1
                            snapMode: Slider.SnapAlways
                            value: from

                        function syncOpenRaiseSlider() {
                            openRaiseSlider.from = game_controls.openRaiseSafeMin()
                            openRaiseSlider.to = game_controls.openRaiseSafeMax()
                            if (openRaiseSlider.to < openRaiseSlider.from) {
                                openRaiseSlider.value = openRaiseSlider.from
                                return
                            }
                            openRaiseSlider.value = Math.min(
                                Math.max(game_controls.openRaiseMinChips, openRaiseSlider.from),
                                openRaiseSlider.to)
                        }

                        Component.onCompleted: syncOpenRaiseSlider()
                        }
                        Text {
                            Layout.preferredWidth: 52
                            text: Math.round(openRaiseSlider.value)
                            color: Theme.focusGold
                            font.family: Theme.fontFamilyUi
                            font.pixelSize: Theme.uiBodyPx
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Connections {
                        target: game_controls
                        function onOpenRaiseMinChipsChanged() {
                            openRaiseSlider.syncOpenRaiseSlider()
                        }
                        function onOpenRaiseMaxChipsChanged() {
                            openRaiseSlider.syncOpenRaiseSlider()
                        }
                        function onCheckOrRaiseSizedChanged() {
                            if (game_controls.checkOrRaiseSized)
                                openRaiseSlider.syncOpenRaiseSlider()
                        }
                    }

                    SizingPresetBar {
                        id: openRaisePresetRow
                        width: parent.width
                        hud: game_controls
                        slider: openRaiseSlider
                        flavor: "open"
                        afterPreset: game_controls.submitOpenRaise
                    }
                }
            }

            // Check or fold (post-flop) + open raise trigger
            Row {
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && game_controls.checkOrRaiseSized
                width: parent.width - 16
                x: 8
                spacing: 12

                HudButton {
                    label: qsTr("CHECK")
                    pillWidth: 88
                    buttonColor: Theme.panelBorder
                    textColor: Theme.textPrimary
                    onClicked: {
                        if (game_controls.trainerMode)
                            return
                        if (pokerGame)
                            pokerGame.submitCheckOrBet(true, 0)
                    }
                }

                HudButton {
                    label: qsTr("FOLD")
                    pillWidth: 76
                    buttonColor: Theme.dangerBg
                    textColor: Theme.dangerText
                    onClicked: {
                        if (game_controls.trainerMode)
                            return
                        if (pokerGame)
                            pokerGame.submitFoldFromCheck()
                    }
                }

                HudButton {
                    visible: game_controls.canOpenRaise && !game_controls.openRaiseSizingExpanded
                    label: qsTr("Raise")
                    pillWidth: 88
                    buttonColor: Theme.successGreen
                    textColor: Theme.onAccentText
                    onClicked: {
                        if (game_controls.trainerMode)
                            return
                        game_controls.openRaiseSizingExpanded = true
                    }
                }
            }

            RowLayout {
                id: sitOutRow
                visible: !game_controls.trainerMode
                width: parent.width - 16
                x: 8
                spacing: 10

                ThemedCheckBox {
                    id: sitOutCheck
                    text: qsTr("Sit out")
                    font.family: Theme.fontFamilyUi
                    font.pixelSize: Theme.uiMicroPx
                    padding: 2
                    checked: game_controls.humanSitOut
                    onToggled: {
                        if (pokerGame) {
                            pokerGame.setHumanSitOut(sitOutCheck.checked)
                            pokerGame.savePersistedSettings()
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    height: 1
                }
            }

            RowLayout {
                id: buyBackRow
                visible: !game_controls.trainerMode && game_controls.embeddedMode
                        && game_controls.humanCanBuyBackIn && game_controls.showHumanActions
                width: parent.width - 16
                x: 8
                spacing: 10

                HudButton {
                    label: qsTr("Buy back in (%1)").arg(game_controls.buyInChips)
                    fontSize: Theme.uiHudButtonPt
                    pillWidth: 0
                    horizontalPadding: 16
                    implicitHeight: 30
                    buttonColor: Theme.focusGold
                    textColor: Theme.insetDark
                    clickEnabled: game_controls.pokerGame !== null
                    onClicked: {
                        if (game_controls.pokerGame)
                            game_controls.pokerGame.tryBuyBackIn(0)
                    }
                }

                Item {
                    Layout.fillWidth: true
                    height: 1
                }
            }

            Rectangle {
                visible: !game_controls.trainerMode && game_controls.humanHandText.length > 0
                        && game_controls.showHumanActions && !game_controls.humanSitOut
                width: parent.width - 16
                x: 8
                implicitHeight: Math.max(40, yourHandLabel.contentHeight + 14)
                radius: 6
                color: Theme.panelElevated
                border.width: 1
                border.color: Qt.alpha(Theme.gold, 0.42)
                clip: true

                Text {
                    id: yourHandLabel
                    anchors.fill: parent
                    anchors.margins: 8
                    wrapMode: Text.WordWrap
                    text: game_controls.humanHandText
                    color: Theme.focusGold
                    font.family: Theme.fontFamilyUi
                    font.pixelSize: Theme.uiBodyPx
                    font.bold: true
                    lineHeight: 1.2
                }
            }

            Rectangle {
                id: statusBanner
                visible: !game_controls.trainerMode
                width: parent.width - 16
                x: 8
                implicitHeight: statusTableColumn.implicitHeight + 12
                radius: 6
                color: Theme.inputBg
                border.color: Theme.inputBorder
                border.width: 1
                clip: true

                Column {
                    id: statusTableColumn
                    visible: !game_controls.trainerMode
                    width: parent.width - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    spacing: 8

                    Row {
                        id: winHandVizRow
                        visible: (game_controls.resultBannerCardAssets || []).length > 0
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: (game_controls.resultBannerCardAssets || []).length
                            delegate: Card {
                                width: Theme.resultBannerCardW
                                height: Theme.resultBannerCardH
                                card: (game_controls.resultBannerCardAssets || [])[index]
                                tableCard: true
                                instantFace: true
                                flipped: true
                            }
                        }
                    }

                    Text {
                        id: statusBannerTableText
                        width: parent.width
                        text: game_controls.statusFullDisplay
                        color: Theme.textPrimary
                        font.family: Theme.fontFamilyUi
                        font.pixelSize: Theme.uiBodyPx
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Item {
                width: 1
                height: 4
            }
        }
    }
}
