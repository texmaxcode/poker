import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

Page {
    id: setup
    padding: 0

    BotNames {
        id: botNames
    }

    background: BrandedBackground {
        anchors.fill: parent
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

    Component.onCompleted: {
        sbSpin.value = pokerGame.configuredSmallBlind()
        bbSpin.value = pokerGame.configuredBigBlind()
        streetSpin.value = pokerGame.configuredStreetBet()
        stackSpin.value = pokerGame.configuredStartStack()
        slowBotsCheck.checked = pokerGame.botSlowActions()
        Qt.callLater(reloadSeatEditor)
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        leftPadding: 14
        rightPadding: 14
        topPadding: 12
        bottomPadding: 12

        ColumnLayout {
            id: setupColumn
            width: Math.max(300, scrollView.width > 0 ? scrollView.width - 28 : setup.width - 28)
            spacing: 12

            Label {
                Layout.fillWidth: true
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                text: qsTr("Turn bots on or off by name, pick a tab to edit that player’s full settings, then play from the table.")
                font.pixelSize: 12
                color: Theme.textSecondary
            }

            GroupBox {
                title: qsTr("Bots at table")
                Layout.fillWidth: true
                padding: 8
                topPadding: 22
                font.bold: true
                font.pointSize: 11

                ColumnLayout {
                    width: parent.width - 8
                    spacing: 8

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: 10
                        color: Theme.textMuted
                        text: qsTr("When a bot is off, they sit out (not dealt in) until you turn them back on.")
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 12

                        Repeater {
                            model: 5

                            ColumnLayout {
                                spacing: 4
                                required property int index

                                Label {
                                    text: botNames.displayName(index + 1)
                                    font.pixelSize: 9
                                    color: Theme.hudActionLabel
                                }
                                Switch {
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

                TabButton {
                    text: qsTr("You")
                    font.bold: true
                }
                Repeater {
                    model: 5
                    TabButton {
                        required property int index
                        text: botNames.displayName(index + 1)
                        font.bold: true
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
                title: qsTr("Strategy presets (reference)")
                Layout.fillWidth: true
                padding: 8
                topPadding: 22
                font.bold: true
                font.pointSize: 11

                ColumnLayout {
                    width: parent.width - 8
                    spacing: 8

                    Label {
                        Layout.fillWidth: true
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        text: qsTr("Reference: archetype chart and engine strategy blurb. Choosing a preset for a player loads that chart there.")
                        font.pixelSize: 10
                        color: Theme.textMuted

                        HoverHandler {
                            id: presetBlurbHover
                        }
                        ToolTip.visible: presetBlurbHover.hovered
                        ToolTip.delay: 400
                        ToolTip.text: qsTr(
                            "Pick a bot archetype to see its default 13×13 chart and full in-engine strategy "
                            + "(preflop/postflop exponents and aggression). Choosing a strategy for a player loads "
                            + "that preset chart; you can still edit cells or paste range text.")
                    }

                    ComboBox {
                        id: previewStrat
                        model: strategyNames
                        Layout.fillWidth: true
                    }

                    Label {
                        Layout.fillWidth: true
                        Layout.maximumHeight: 56
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 3
                        color: Theme.textSecondary
                        font.pixelSize: 10
                        text: pokerGame.getStrategySummary(previewStrat.currentIndex)

                        HoverHandler {
                            id: refSummaryHover
                        }
                        ToolTip.visible: refSummaryHover.hovered
                        ToolTip.delay: 450
                        ToolTip.text: pokerGame.getStrategySummary(previewStrat.currentIndex)
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
                padding: 8
                topPadding: 20
                font.bold: true
                font.pointSize: 11

                ColumnLayout {
                    width: parent.width - 8
                    spacing: 10

                    GridLayout {
                        width: parent.width
                        columns: 4
                        rowSpacing: 6
                        columnSpacing: 10

                        Label {
                            text: qsTr("SB")
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
                        }
                        SpinBox {
                            id: streetSpin
                            from: 1
                            to: 200
                            value: 9
                            editable: true
                        }
                        Label {
                            text: qsTr("Stack")
                        }
                        SpinBox {
                            id: stackSpin
                            from: 20
                            to: 10000
                            value: 100
                            editable: true
                        }
                        Button {
                            text: qsTr("Apply stakes")
                            Layout.columnSpan: 4
                            onClicked: {
                                pokerGame.configure(sbSpin.value, bbSpin.value, streetSpin.value, stackSpin.value)
                                pokerGame.savePersistedSettings()
                                reloadAllGrids()
                            }
                        }
                    }

                    CheckBox {
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
                padding: 8
                topPadding: 22
                font.bold: true
                font.pointSize: 11

                ColumnLayout {
                    width: parent.width - 4
                    spacing: 8

                    Label {
                        visible: selectedSeat === 0
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: qsTr("Use a preset for your default opening chart. Enable the full editor only if you want to edit cells or paste range text.")
                        font.pixelSize: 10
                        color: Theme.textMuted
                    }

                    Label {
                        text: qsTr("Archetype")
                        font.bold: true
                        font.pixelSize: 10
                    }
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

                    Label {
                        Layout.fillWidth: true
                        Layout.maximumHeight: 52
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 3
                        color: Theme.textSecondary
                        font.pixelSize: 9
                        text: pokerGame.getStrategySummary(stratCombo.currentIndex)

                        HoverHandler {
                            id: seatStratHover
                        }
                        ToolTip.visible: seatStratHover.hovered
                        ToolTip.delay: 450
                        ToolTip.text: pokerGame.getStrategySummary(stratCombo.currentIndex)
                    }

                    GroupBox {
                        title: qsTr("Engine parameters (bots)")
                        visible: selectedSeat >= 1
                        Layout.fillWidth: true
                        padding: 8
                        topPadding: 20
                        font.bold: true
                        font.pointSize: 10

                        ColumnLayout {
                            width: parent.width - 8
                            spacing: 6

                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                font.pixelSize: 9
                                color: Theme.textMuted
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
                                    font.pixelSize: 9
                                }
                                TextField {
                                    id: strat_pf_pre
                                    font.pixelSize: 10
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 120
                                }
                                Label {
                                    text: qsTr("Postflop exponent")
                                    font.pixelSize: 9
                                }
                                TextField {
                                    id: strat_pf_post
                                    font.pixelSize: 10
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 120
                                }
                                Label {
                                    text: qsTr("Facing raise bonus")
                                    font.pixelSize: 9
                                }
                                TextField {
                                    id: strat_fr_bonus
                                    font.pixelSize: 10
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 120
                                }
                                Label {
                                    text: qsTr("Facing raise tight ×")
                                    font.pixelSize: 9
                                }
                                TextField {
                                    id: strat_fr_tight
                                    font.pixelSize: 10
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 120
                                }
                                Label {
                                    text: qsTr("Open raise bonus")
                                    font.pixelSize: 9
                                }
                                TextField {
                                    id: strat_ob_bonus
                                    font.pixelSize: 10
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 120
                                }
                                Label {
                                    text: qsTr("Open raise tight ×")
                                    font.pixelSize: 9
                                }
                                TextField {
                                    id: strat_ob_tight
                                    font.pixelSize: 10
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 120
                                }
                                Label {
                                    text: qsTr("BB check-raise bonus")
                                    font.pixelSize: 9
                                }
                                TextField {
                                    id: strat_bb_bonus
                                    font.pixelSize: 10
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 120
                                }
                                Label {
                                    text: qsTr("BB check-raise tight ×")
                                    font.pixelSize: 9
                                }
                                TextField {
                                    id: strat_bb_tight
                                    font.pixelSize: 10
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 120
                                }
                            }

                            RowLayout {
                                spacing: 8
                                Button {
                                    text: qsTr("Apply parameters")
                                    font.pixelSize: 10
                                    onClicked: setup.applyParamFields()
                                }
                                Button {
                                    text: qsTr("Reset to archetype")
                                    font.pixelSize: 10
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

                    CheckBox {
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
                        TabButton {
                            text: qsTr("Call")
                            font.pixelSize: 10
                            font.bold: true
                        }
                        TabButton {
                            text: qsTr("Raise")
                            font.pixelSize: 10
                            font.bold: true
                        }
                        TabButton {
                            text: qsTr("Open / lead")
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    Label {
                        visible: showFullRangeEditor
                        wrapMode: Text.WordWrap
                        font.pixelSize: 9
                        color: Theme.textMuted
                        text: qsTr(
                            "Stacked colors: green = call, orange = raise, blue = open / lead. "
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
                        font.pixelSize: 10
                        font.bold: true
                    }
                    TextArea {
                        id: textArea
                        visible: showFullRangeEditor
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        wrapMode: TextArea.Wrap
                        font.pixelSize: 11
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
