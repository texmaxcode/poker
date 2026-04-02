import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

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
        if (visible)
            seatBankSpin.refreshFromGame()
    }

    Connections {
        target: pokerGame
        function onSessionStatsChanged() {
            seatBankSpin.refreshFromGame()
        }
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        leftPadding: Theme.uiPagePadding
        rightPadding: Theme.uiPagePadding
        topPadding: Theme.uiPagePadding
        bottomPadding: Theme.uiPagePadding

        ColumnLayout {
            id: setupColumn
            width: Math.max(300, scrollView.width > 0 ? scrollView.width - 2 * Theme.uiPagePadding : setup.width - 2 * Theme.uiPagePadding)
            spacing: Theme.uiPageColumnSpacing

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr(
                    "Turn bots on or off by name, pick a tab to edit that player’s settings, then play from the table. "
                    + "On the “You” tab, the 13×13 range grid is hidden until you enable “Full range editor” below; "
                    + "until then the archetype preset is applied without cell editing. Bot tabs always show the full grid.")
                font.pixelSize: Theme.trainerBodyPx
                lineHeight: 1.25
                color: Theme.textSecondary
            }

            GroupBox {
                title: qsTr("Bots at table")
                Layout.fillWidth: true
                padding: Theme.uiGroupedPanelPadding
                topPadding: Theme.uiGroupedPanelTopPadding
                font.bold: true
                font.pointSize: Theme.uiGroupTitlePt

                ColumnLayout {
                    width: parent.width - 2 * Theme.uiGroupedPanelPadding
                    spacing: Theme.uiGroupInnerSpacing

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.uiGroupBoxTitleBodyGap
                    }

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
                                    color: Theme.hudActionLabel
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
                    }
                }
            }

            Connections {
                target: seatTabBar
                function onCurrentIndexChanged() {
                    setup.reloadSeatEditor()
                }
            }

            GroupBox {
                title: qsTr("Strategy presets (reference only)")
                Layout.fillWidth: true
                padding: Theme.uiGroupedPanelPadding
                topPadding: Theme.uiGroupedPanelTopPadding
                font.bold: true
                font.pointSize: Theme.uiGroupTitlePt

                ColumnLayout {
                    width: parent.width - 2 * Theme.uiGroupedPanelPadding
                    spacing: Theme.uiGroupInnerSpacing

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.uiGroupBoxTitleBodyGap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: qsTr(
                                "Browse archetypes here without changing any player. The chart is read-only. "
                                + "To actually assign Rock / LAG / etc. to a seat, use Archetype on that player’s tab.")
                            font.pixelSize: Theme.trainerBodyPx
                            lineHeight: 1.25
                            color: Theme.textSecondary
                        }

                        ToolButton {
                            text: qsTr("?")
                            font.bold: true
                            font.pixelSize: Theme.trainerSectionPx
                            flat: true
                            padding: 8
                            focusPolicy: Qt.NoFocus
                            Accessible.name: qsTr("Full description")
                            Accessible.description: qsTr("Opens the full help text in a scrollable window")

                            onClicked: setup.openStrategyLogPopup(
                                    qsTr("Strategy presets (reference)"),
                                    qsTr(
                                        "This block is a library preview: default 13×13 weights and strategy notes. "
                                        + "It does not edit saved ranges. On each seat tab, the Archetype control loads that preset into that player; "
                                        + "you can then customize cells or text (for yourself, enable “Full range editor” first)."))
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        ComboBox {
                            id: previewStrat
                            model: strategyNames
                            Layout.fillWidth: true
                        }

                        ToolButton {
                            text: qsTr("?")
                            font.bold: true
                            font.pixelSize: Theme.trainerSectionPx
                            flat: true
                            padding: 8
                            focusPolicy: Qt.NoFocus
                            Accessible.name: qsTr("Full strategy log")
                            Accessible.description: qsTr("Opens the full strategy description for the selected preset")

                            onClicked: setup.openStrategyLogPopup(
                                    qsTr("%1 — strategy").arg(setup.strategyNames[previewStrat.currentIndex]),
                                    pokerGame.getStrategySummary(previewStrat.currentIndex))
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
                        text: pokerGame.getStrategySummary(previewStrat.currentIndex)
                    }

                    RangeGrid {
                        readOnly: true
                        seatIndex: 0
                        Layout.fillWidth: true
                        weights: pokerGame.getPresetRangeGrid(previewStrat.currentIndex)
                    }
                }
            }

            GroupBox {
                title: qsTr("Table stakes & pacing")
                Layout.fillWidth: true
                padding: Theme.uiGroupedPanelPadding
                topPadding: Theme.uiGroupedPanelTopPadding
                font.bold: true
                font.pointSize: Theme.uiGroupTitlePt

                ColumnLayout {
                    width: parent.width - 2 * Theme.uiGroupedPanelPadding
                    spacing: Theme.uiGroupInnerSpacing

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.uiGroupBoxTitleBodyGap
                    }

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

            GroupBox {
                title: botNames.displayName(selectedSeat)
                Layout.fillWidth: true
                padding: Theme.uiGroupedPanelPadding
                topPadding: Theme.uiGroupedPanelTopPadding
                font.bold: true
                font.pointSize: Theme.uiGroupTitlePt

                ColumnLayout {
                    width: parent.width - 2 * Theme.uiGroupedPanelPadding
                    spacing: Theme.uiGroupInnerSpacing

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.uiGroupBoxTitleBodyGap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Label {
                            text: qsTr("Bankroll (buy-in)")
                            font.bold: true
                            font.pixelSize: Theme.trainerSectionPx
                        }
                        SpinBox {
                            id: seatBankSpin
                            from: 1
                            to: setup.buyInCapChips
                            stepSize: 1
                            editable: true
                            Layout.fillWidth: true

                            function refreshFromGame() {
                                value = Math.min(pokerGame.seatBuyIn(setup.selectedSeat), setup.buyInCapChips)
                            }

                            Component.onCompleted: refreshFromGame()

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

                            onValueModified: {
                                pokerGame.setSeatBuyIn(setup.selectedSeat, value)
                                if (!pokerGame.gameInProgress()) {
                                    pokerGame.applySeatBuyInsToStacks()
                                    pokerGame.savePersistedSettings()
                                } else {
                                    pokerGame.savePersistedSettings()
                                }
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: qsTr(
                            "Starting stack and rebuy unit for this seat (saved per player). "
                            + "You cannot buy in for more than 100 big blinds (%1 chips at this BB); anything above that stays off the table as the rest of your bankroll. "
                            + "Table stacks update when no hand is in progress; if a hand is running, the new amount is stored for the next apply.")
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

                        ToolButton {
                            text: qsTr("?")
                            font.bold: true
                            font.pixelSize: Theme.trainerSectionPx
                            flat: true
                            padding: 8
                            focusPolicy: Qt.NoFocus
                            Accessible.name: qsTr("Full strategy log")
                            Accessible.description: qsTr("Opens the full strategy description for the selected archetype")

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

                    GroupBox {
                        title: qsTr("Engine parameters (bots)")
                        visible: selectedSeat >= 1
                        Layout.fillWidth: true
                        padding: Theme.uiGroupedPanelPadding
                        topPadding: Theme.uiGroupedPanelTopPadding
                        font.bold: true
                        font.pointSize: Theme.uiGroupTitlePt

                        ColumnLayout {
                            width: parent.width - 2 * Theme.uiGroupedPanelPadding
                            spacing: Theme.uiGroupInnerSpacing

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.uiGroupBoxTitleBodyGap
                            }

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
                            if (setup.showFullRangeEditor)
                                textArea.text = pokerGame.exportSeatRangeText(setup.selectedSeat, rangeLayerTab.currentIndex)
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
                        placeholderText: "AA,AKs,AKo,TT+"
                    }
                    RowLayout {
                        visible: showFullRangeEditor
                        spacing: 4
                        Button {
                            text: qsTr("Apply")
                            flat: true
                            onClicked: {
                                pokerGame.applySeatRangeText(setup.selectedSeat, textArea.text, rangeLayerTab.currentIndex)
                                pokerGame.savePersistedSettings()
                                setup.refreshRangeGrids()
                            }
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
    }
}
