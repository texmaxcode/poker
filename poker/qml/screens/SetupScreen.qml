import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0
import PokerUi 1.0

Page {
    id: setup
    padding: 0
    font.family: Theme.fontFamilyUi

    BotNames {
        id: botNames
    }

    background: BrandedBackground {
        anchors.fill: parent
    }

    property string strategyPopupTitle: ""
    property string strategyPopupBody: ""

    function openStrategyLogPopup(title, body) {
        strategyPopupTitle = title
        strategyPopupBody = body
        strategyLogPopup.open()
    }

    Popup {
        id: strategyLogPopup
        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(720, Overlay.overlay ? Overlay.overlay.width - 32 : 640)
        height: Math.min(520, Overlay.overlay ? Overlay.overlay.height - 48 : 480)
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        padding: 0

        background: Rectangle {
            color: Theme.panel
            border.color: Theme.headerRule
            border.width: 1
            radius: 10
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.uiGroupedPanelPadding
            spacing: Theme.uiGroupInnerSpacing

            Label {
                text: setup.strategyPopupTitle
                font.bold: true
                font.pointSize: Theme.trainerSectionPx
                color: Theme.gold
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            ScrollView {
                id: strategyLogScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 200
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                TextArea {
                    width: strategyLogScroll.availableWidth
                    readOnly: true
                    wrapMode: TextArea.Wrap
                    font.family: "monospace"
                    font.pixelSize: Theme.uiMonoPx
                    color: Theme.textPrimary
                    text: setup.strategyPopupBody
                    padding: 10
                    selectByMouse: true
                    background: Rectangle {
                        color: Theme.bgGradientMid
                        border.color: Theme.headerRule
                        border.width: 1
                        radius: 8
                    }
                }
            }

            Button {
                text: qsTr("Close")
                Layout.alignment: Qt.AlignRight
                onClicked: strategyLogPopup.close()
            }
        }
    }

    readonly property int selectedSeat: seatTabBar.currentIndex
    readonly property bool showFullRangeEditor: selectedSeat > 0 || humanRangeAdvanced.checked

    readonly property var strategyNames: [
        "Always call (test)",
        "Rock",
        "Nit",
        "Tight–aggressive",
        "Loose–passive",
        "Loose–aggressive",
        "Balanced",
        "Maniac",
        "GTO (heuristic)"
    ]

    function formatParamNum(x) {
        if (x === undefined || x === null || isNaN(x))
            return ""
        return Number(x).toFixed(3)
    }

    function loadParamFields() {
        if (setup.selectedSeat < 1)
            return
        var m = pokerGame.seatStrategyParams(setup.selectedSeat)
        strat_pf_pre.text = formatParamNum(m.preflopExponent)
        strat_pf_post.text = formatParamNum(m.postflopExponent)
        strat_fr_bonus.text = formatParamNum(m.facingRaiseBonus)
        strat_fr_tight.text = formatParamNum(m.facingRaiseTightMul)
        strat_ob_bonus.text = formatParamNum(m.openBetBonus)
        strat_ob_tight.text = formatParamNum(m.openBetTightMul)
        strat_bb_bonus.text = formatParamNum(m.bbCheckraiseBonus)
        strat_bb_tight.text = formatParamNum(m.bbCheckraiseTightMul)
    }

    function applyParamFields() {
        if (setup.selectedSeat < 1)
            return
        var m = {}
        function put(key, v) {
            var x = parseFloat(v)
            if (isFinite(x))
                m[key] = x
        }
        put("preflopExponent", strat_pf_pre.text)
        put("postflopExponent", strat_pf_post.text)
        put("facingRaiseBonus", strat_fr_bonus.text)
        put("facingRaiseTightMul", strat_fr_tight.text)
        put("openBetBonus", strat_ob_bonus.text)
        put("openBetTightMul", strat_ob_tight.text)
        put("bbCheckraiseBonus", strat_bb_bonus.text)
        put("bbCheckraiseTightMul", strat_bb_tight.text)
        if (Object.keys(m).length < 1)
            return
        pokerGame.setSeatStrategyParams(setup.selectedSeat, m)
        pokerGame.savePersistedSettings()
        loadParamFields()
    }

    function refreshRangeGrids() {
        rng.refreshFromGame()
    }

    function applyRangeTextFromField() {
        if (!setup.showFullRangeEditor)
            return
        pokerGame.applySeatRangeText(setup.selectedSeat, textArea.text, rangeLayerTab.currentIndex)
        pokerGame.savePersistedSettings()
        setup.refreshRangeGrids()
    }

    function reloadSeatEditor() {
        stratCombo.currentIndex = pokerGame.seatStrategyIndex(setup.selectedSeat)
        textArea.text = pokerGame.exportSeatRangeText(setup.selectedSeat, rangeLayerTab.currentIndex)
        refreshRangeGrids()
        loadParamFields()
    }

    function reloadAllGrids() {
        reloadSeatEditor()
    }

    /// Matches engine `maxBuyInChips()` (100× BB); use before stakes are applied so the cap tracks the BB spin.
    readonly property int buyInCapChips: Math.max(1, bbSpin.value * 100)

    Component.onCompleted: {
        sbSpin.value = pokerGame.configuredSmallBlind()
        bbSpin.value = pokerGame.configuredBigBlind()
        streetSpin.value = pokerGame.configuredStreetBet()
        slowBotsCheck.checked = pokerGame.botSlowActions()
        Qt.callLater(reloadSeatEditor)
    }

    onVisibleChanged: {
        if (visible) {
            totalBankSpin.refreshFromGame()
            seatBankSpin.refreshFromGame()
        }
    }

    Connections {
        target: pokerGame
        function onSessionStatsChanged() {
            totalBankSpin.refreshFromGame()
            seatBankSpin.refreshFromGame()
        }
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        RowLayout {
            width: scrollView.availableWidth
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }

            ColumnLayout {
                id: setupColumn
                Layout.preferredWidth: Math.min(Theme.trainerContentMaxWidth, Math.max(300, scrollView.availableWidth - 40))
                Layout.maximumWidth: Theme.trainerContentMaxWidth
                spacing: Theme.trainerColumnSpacing

            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr(
                    "Turn bots on or off by name, pick a tab to edit that player’s settings, then play from the table. "
                    + "On the “You” tab, the 13×13 range grid is hidden until you enable “Full range editor” below; "
                    + "until then the archetype preset is applied without cell editing. Bot tabs always show the full grid.")
                font.pixelSize: Theme.trainerBodyPx
                lineHeight: 1.25
                color: Theme.textSecondary
            }

            ThemedPanel {
                panelTitle: qsTr("Bots at table")
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.uiGroupInnerSpacing

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: Theme.trainerBodyPx
                        lineHeight: 1.25
                        color: Theme.textSecondary
                        text: qsTr("When a bot is off, they sit out (not dealt in) until you turn them back on.")
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.uiGroupInnerSpacing

                        Repeater {
                            model: 5

                            ColumnLayout {
                                spacing: 4
                                required property int index

                                Label {
                                    text: botNames.displayName(index + 1)
                                    font.pixelSize: Theme.trainerCaptionPx
                                    font.bold: true
                                    color: Theme.colorForSeat(index + 1)
                                }
                                ThemedSwitch {
                                    checked: pokerGame.seatParticipating(index + 1)
                                    onToggled: {
                                        pokerGame.setSeatParticipating(index + 1, checked)
                                        pokerGame.savePersistedSettings()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            TabBar {
                id: seatTabBar
                Layout.fillWidth: true
                font.pixelSize: Theme.trainerCaptionPx

                TabButton {
                    text: qsTr("You")
                    font.bold: true
                    topPadding: 10
                    bottomPadding: 10
                    leftPadding: 14
                    rightPadding: 14
                    contentItem: Label {
                        text: parent.text
                        font: parent.font
                        color: Theme.colorForSeat(0)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
                Repeater {
                    model: 5
                    TabButton {
                        required property int index
                        text: botNames.displayName(index + 1)
                        font.bold: true
                        topPadding: 10
                        bottomPadding: 10
                        leftPadding: 14
                        rightPadding: 14
                        contentItem: Label {
                            text: parent.text
                            font: parent.font
                            color: Theme.colorForSeat(index + 1)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Connections {
                target: seatTabBar
                function onCurrentIndexChanged() {
                    setup.reloadSeatEditor()
                }
            }

            ThemedPanel {
                panelTitle: qsTr("Table stakes & pacing")
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.uiGroupInnerSpacing

                    GridLayout {
                        width: parent.width
                        columns: 4
                        rowSpacing: 8
                        columnSpacing: 12

                        Label {
                            text: qsTr("SB")
                            font.pixelSize: Theme.trainerCaptionPx
                        }
                        SpinBox {
                            id: sbSpin
                            from: 1
                            to: 50
                            value: 1
                            editable: true
                        }
                        Label {
                            text: qsTr("BB")
                            font.pixelSize: Theme.trainerCaptionPx
                        }
                        SpinBox {
                            id: bbSpin
                            from: 1
                            to: 100
                            value: 3
                            editable: true
                        }
                        Label {
                            text: qsTr("Min raise")
                            font.pixelSize: Theme.trainerCaptionPx
                        }
                        SpinBox {
                            id: streetSpin
                            from: 1
                            to: 200
                            value: 9
                            editable: true
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Button {
                            text: qsTr("Apply stakes")
                            Layout.columnSpan: 4
                            onClicked: {
                                pokerGame.configure(sbSpin.value, bbSpin.value, streetSpin.value,
                                        pokerGame.configuredStartStack())
                                pokerGame.savePersistedSettings()
                                reloadAllGrids()
                            }
                        }
                    }

                    ThemedCheckBox {
                        id: slowBotsCheck
                        text: qsTr("Slow down bot actions (longer pauses between bot decisions)")
                        onToggled: {
                            pokerGame.setBotSlowActions(checked)
                            pokerGame.savePersistedSettings()
                        }
                    }
                }
            }

            ThemedPanel {
                Layout.fillWidth: true
                panelTitle: ""

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.uiGroupInnerSpacing

                    Label {
                        Layout.fillWidth: true
                        text: botNames.displayName(setup.selectedSeat)
                        font.bold: true
                        font.pixelSize: Theme.trainerSectionPx
                        color: Theme.colorForSeat(setup.selectedSeat)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Label {
                            text: qsTr("Total bankroll")
                            font.bold: true
                            font.pixelSize: Theme.trainerSectionPx
                        }
                        SpinBox {
                            id: totalBankSpin
                            from: 1
                            to: 100000000
                            stepSize: 100
                            editable: true
                            Layout.fillWidth: false
                            Layout.preferredWidth: 200
                            Layout.maximumWidth: 280

                            property bool _applyingFromGame: false
                            property bool _ready: false

                            function refreshFromGame() {
                                _applyingFromGame = true
                                value = Math.max(1, pokerGame.seatBankrollTotal(setup.selectedSeat))
                                _applyingFromGame = false
                            }

                            function pushTotalToEngine() {
                                pokerGame.setSeatBankrollTotal(setup.selectedSeat, value)
                            }

                            Component.onCompleted: {
                                refreshFromGame()
                                _ready = true
                            }

                            Connections {
                                target: seatTabBar
                                function onCurrentIndexChanged() {
                                    totalBankSpin.refreshFromGame()
                                }
                            }

                            onValueChanged: {
                                if (!totalBankSpin._ready || totalBankSpin._applyingFromGame)
                                    return
                                totalBankSpin.pushTotalToEngine()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Label {
                            text: qsTr("Table buy-in (target stack)")
                            font.bold: true
                            font.pixelSize: Theme.trainerSectionPx
                        }
                        SpinBox {
                            id: seatBankSpin
                            from: 1
                            to: setup.buyInCapChips
                            stepSize: 1
                            editable: true
                            Layout.fillWidth: false
                            Layout.preferredWidth: 200
                            Layout.maximumWidth: 280

                            /// Skip pushing to the engine when syncing from `pokerGame` (tab change / init).
                            property bool _applyingFromGame: false
                            /// Avoid applying default `SpinBox` value before the first `refreshFromGame()`.
                            property bool _ready: false

                            function refreshFromGame() {
                                _applyingFromGame = true
                                value = Math.min(pokerGame.seatBuyIn(setup.selectedSeat), setup.buyInCapChips)
                                _applyingFromGame = false
                            }

                            function pushBuyInToEngine() {
                                pokerGame.setSeatBuyIn(setup.selectedSeat, value)
                                if (!pokerGame.gameInProgress()) {
                                    pokerGame.applySeatBuyInsToStacks()
                                    pokerGame.savePersistedSettings()
                                } else {
                                    pokerGame.savePersistedSettings()
                                }
                            }

                            Component.onCompleted: {
                                refreshFromGame()
                                _ready = true
                            }

                            Connections {
                                target: seatTabBar
                                function onCurrentIndexChanged() {
                                    seatBankSpin.refreshFromGame()
                                }
                            }

                            Connections {
                                target: bbSpin
                                function onValueChanged() {
                                    if (seatBankSpin.value > setup.buyInCapChips)
                                        seatBankSpin.value = setup.buyInCapChips
                                }
                            }

                            Connections {
                                target: pokerGame
                                function onSessionStatsChanged() {
                                    if (seatBankSpin._ready)
                                        seatBankSpin.refreshFromGame()
                                }
                            }

                            /// Use `valueChanged`, not only `valueModified`: the latter can miss updates for
                            /// editable SpinBox / focus edge cases; `value` is the source of truth.
                            onValueChanged: {
                                if (!seatBankSpin._ready || seatBankSpin._applyingFromGame)
                                    return
                                seatBankSpin.pushBuyInToEngine()
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: qsTr(
                            "Total bankroll adds or removes chips for this seat (play money). "
                            + "Table buy-in is how many chips you want on the felt up to 100 big blinds (%1 at this BB); the rest stays off-table. "
                            + "Changing only buy-in moves chips between table and wallet without changing total. "
                            + "When a hand is running, edits apply after the hand.")
                                .arg(setup.buyInCapChips)
                        font.pixelSize: Theme.trainerCaptionPx
                        lineHeight: 1.25
                        color: Theme.textMuted
                    }

                    Label {
                        visible: selectedSeat === 0
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: qsTr(
                            "Archetype below loads that strategy’s default chart into the engine. "
                            + "To edit cells, paste range text, or see the 13×13 grid, check “Full range editor” at the bottom of this section.")
                        font.pixelSize: Theme.trainerBodyPx
                        lineHeight: 1.25
                        color: Theme.textSecondary
                    }

                    Label {
                        text: qsTr("Archetype")
                        font.bold: true
                        font.pixelSize: Theme.trainerSectionPx
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        ComboBox {
                            id: stratCombo
                            model: strategyNames
                            currentIndex: 0
                            Layout.fillWidth: true
                            onActivated: function (i) {
                                pokerGame.setSeatStrategy(setup.selectedSeat, i)
                                pokerGame.savePersistedSettings()
                                setup.refreshRangeGrids()
                                textArea.text = pokerGame.exportSeatRangeText(setup.selectedSeat, rangeLayerTab.currentIndex)
                                setup.loadParamFields()
                            }
                        }

                        GameButton {
                            style: "form"
                            formFlat: true
                            text: qsTr("?")
                            formBold: true
                            formFontPixelSize: Theme.trainerSectionPx
                            textColor: Theme.textPrimary
                            horizontalPadding: 8
                            onClicked: setup.openStrategyLogPopup(
                                    qsTr("%1 — strategy").arg(setup.strategyNames[stratCombo.currentIndex]),
                                    pokerGame.getStrategySummary(stratCombo.currentIndex))
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        Layout.maximumHeight: 120
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 8
                        color: Theme.textSecondary
                        font.pixelSize: Theme.trainerBodyPx
                        lineHeight: 1.25
                        text: pokerGame.getStrategySummary(stratCombo.currentIndex)
                    }

                    ThemedPanel {
                        panelTitle: qsTr("Engine parameters (bots)")
                        visible: selectedSeat >= 1
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.uiGroupInnerSpacing

                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                font.pixelSize: Theme.trainerBodyPx
                                lineHeight: 1.25
                                color: Theme.textSecondary
                                text: qsTr(
                                    "Preflop/postflop exponents shape how chart weight and hand strength map to "
                                    + "continue frequencies. Bonuses add to base aggression; tight multipliers "
                                    + "reduce it (nit-style). Applies to this bot only.")
                            }

                            GridLayout {
                                columns: 2
                                columnSpacing: 10
                                rowSpacing: 4
                                Layout.fillWidth: true

                                Label {
                                    text: qsTr("Preflop exponent")
                                    font.pixelSize: Theme.trainerCaptionPx
                                }
                                TextField {
                                    id: strat_pf_pre
                                    font.pixelSize: Theme.trainerBodyPx
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 120
                                }
                                Label {
                                    text: qsTr("Postflop exponent")
                                    font.pixelSize: Theme.trainerCaptionPx
                                }
                                TextField {
                                    id: strat_pf_post
                                    font.pixelSize: Theme.trainerBodyPx
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 120
                                }
                                Label {
                                    text: qsTr("Facing raise bonus")
                                    font.pixelSize: Theme.trainerCaptionPx
                                }
                                TextField {
                                    id: strat_fr_bonus
                                    font.pixelSize: Theme.trainerBodyPx
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 120
                                }
                                Label {
                                    text: qsTr("Facing raise tight ×")
                                    font.pixelSize: Theme.trainerCaptionPx
                                }
                                TextField {
                                    id: strat_fr_tight
                                    font.pixelSize: Theme.trainerBodyPx
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 120
                                }
                                Label {
                                    text: qsTr("Open raise bonus")
                                    font.pixelSize: Theme.trainerCaptionPx
                                }
                                TextField {
                                    id: strat_ob_bonus
                                    font.pixelSize: Theme.trainerBodyPx
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 120
                                }
                                Label {
                                    text: qsTr("Open raise tight ×")
                                    font.pixelSize: Theme.trainerCaptionPx
                                }
                                TextField {
                                    id: strat_ob_tight
                                    font.pixelSize: Theme.trainerBodyPx
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 120
                                }
                                Label {
                                    text: qsTr("BB check-raise bonus")
                                    font.pixelSize: Theme.trainerCaptionPx
                                }
                                TextField {
                                    id: strat_bb_bonus
                                    font.pixelSize: Theme.trainerBodyPx
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 120
                                }
                                Label {
                                    text: qsTr("BB check-raise tight ×")
                                    font.pixelSize: Theme.trainerCaptionPx
                                }
                                TextField {
                                    id: strat_bb_tight
                                    font.pixelSize: Theme.trainerBodyPx
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 120
                                }
                            }

                            RowLayout {
                                spacing: Theme.uiGroupInnerSpacing
                                Button {
                                    text: qsTr("Apply parameters")
                                    font.pixelSize: Theme.trainerCaptionPx
                                    onClicked: setup.applyParamFields()
                                }
                                Button {
                                    text: qsTr("Reset to archetype")
                                    font.pixelSize: Theme.trainerCaptionPx
                                    flat: true
                                    onClicked: {
                                        pokerGame.setSeatStrategy(setup.selectedSeat, stratCombo.currentIndex)
                                        pokerGame.savePersistedSettings()
                                        setup.refreshRangeGrids()
                                        textArea.text = pokerGame.exportSeatRangeText(setup.selectedSeat, rangeLayerTab.currentIndex)
                                        setup.loadParamFields()
                                    }
                                }
                            }
                        }
                    }

                    ThemedCheckBox {
                        id: humanRangeAdvanced
                        visible: selectedSeat === 0
                        text: qsTr("Full range editor (13×13 grid & text)")
                        onToggled: {
                            if (checked)
                                setup.refreshRangeGrids()
                        }
                    }

                    TabBar {
                        id: rangeLayerTab
                        visible: showFullRangeEditor
                        Layout.fillWidth: true
                        font.pixelSize: Theme.trainerCaptionPx
                        TabButton {
                            text: qsTr("Call")
                            font.bold: true
                        }
                        TabButton {
                            text: qsTr("Raise")
                            font.bold: true
                        }
                        TabButton {
                            text: qsTr("Open / lead")
                            font.bold: true
                        }
                    }

                    Label {
                        visible: showFullRangeEditor
                        wrapMode: Text.WordWrap
                        font.pixelSize: Theme.trainerBodyPx
                        lineHeight: 1.25
                        color: Theme.textSecondary
                        text: qsTr(
                            "Stacked colors: gold = call, fire = raise, burgundy = open / lead. "
                            + "Pick a tab to edit that layer (click cells to cycle weights).")
                    }

                    Connections {
                        target: rangeLayerTab
                        function onCurrentIndexChanged() {
                            if (setup.showFullRangeEditor) {
                                textArea.text = pokerGame.exportSeatRangeText(setup.selectedSeat, rangeLayerTab.currentIndex)
                                setup.refreshRangeGrids()
                            }
                        }
                    }

                    Label {
                        visible: showFullRangeEditor
                        text: qsTr("Range text")
                        font.pixelSize: Theme.trainerSectionPx
                        font.bold: true
                    }
                    TextArea {
                        id: textArea
                        visible: showFullRangeEditor
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        wrapMode: TextArea.Wrap
                        font.family: Theme.fontFamilyUi
                        font.pixelSize: Theme.trainerBodyPx
                        color: Theme.textPrimary
                        placeholderText: "AA,AKs,AKo,TT+"
                        placeholderTextColor: Theme.textSecondary
                        onEditingFinished: setup.applyRangeTextFromField()
                    }
                    RowLayout {
                        visible: showFullRangeEditor
                        spacing: 4
                        Button {
                            text: qsTr("Apply")
                            flat: true
                            onClicked: setup.applyRangeTextFromField()
                        }
                        Button {
                            text: qsTr("Export")
                            flat: true
                            onClicked: textArea.text = pokerGame.exportSeatRangeText(setup.selectedSeat, rangeLayerTab.currentIndex)
                        }
                        Button {
                            text: qsTr("Full")
                            flat: true
                            onClicked: {
                                pokerGame.resetSeatRangeFull(setup.selectedSeat)
                                pokerGame.savePersistedSettings()
                                setup.refreshRangeGrids()
                                textArea.text = pokerGame.exportSeatRangeText(setup.selectedSeat, rangeLayerTab.currentIndex)
                            }
                        }
                    }
                    RangeGrid {
                        id: rng
                        visible: showFullRangeEditor
                        seatIndex: setup.selectedSeat
                        composite: true
                        editLayer: rangeLayerTab.currentIndex
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                    }
                }
            }

            Button {
                text: qsTr("Reload current player from engine")
                Layout.alignment: Qt.AlignLeft
                flat: true
                onClicked: reloadSeatEditor()
            }
            }

            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
        }
    }
}
