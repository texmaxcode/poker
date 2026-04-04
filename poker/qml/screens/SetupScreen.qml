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
    /// True while `playAsBotCheck.checked` is assigned from the engine — `toggled` must not write back.
    property bool _syncingPlayAsBot: false
    /// True while `slowBotsCheck.checked` is assigned from `pokerGame.botSlowActions` — avoid spurious writes.
    /// Must start **true**: `StackLayout` builds Setup before `Component.onCompleted`, and the checkbox defaults
    /// to `checked: false`; an early `checkedChanged` would otherwise call `setBotSlowActions(false)` and wipe
    /// the value restored by `loadPersistedSettings()` (main runs load **before** QML loads).
    property bool _syncingSlowBots: true
    /// False until first frame after sync so `onCheckedChanged` does not overwrite `interactiveHuman` on startup.
    property bool playAsBotUserInputEnabled: false
    /// Collapsed: “Range text…” only; expanded: compact row (textarea + Apply/Full), then hide after apply.
    property bool rangeTextEditorOpen: false

    function persistSave() {
        pokerGame.savePersistedSettings()
        const w = ApplicationWindow.window
        if (w && typeof w.showAppToast === "function")
            w.showAppToast(qsTr("Settings saved."))
    }

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
                font.capitalization: Font.AllUppercase
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
    readonly property bool humanSeatAutoplay: selectedSeat === 0 && playAsBotCheck.checked
    /// Seat 0: show 13×13 + text when a named bot tab is selected, “Full range editor” is on, or “Play as bot” is on.
    readonly property bool showFullRangeEditor: selectedSeat > 0 || humanSeatAutoplay
    /// Seat 0: engine parameter fields apply when autoplaying as a bot.
    readonly property bool canEditHumanEngineParams: humanSeatAutoplay

    readonly property var strategyNames: pokerGame.strategyDisplayNames()

    function formatParamNum(x) {
        if (x === undefined || x === null || isNaN(x))
            return ""
        return Number(x).toFixed(3)
    }

    function loadParamFields() {
        if (setup.selectedSeat < 1 && !setup.canEditHumanEngineParams)
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
        if (setup.selectedSeat < 1 && !setup.canEditHumanEngineParams)
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
        setup.persistSave()
        loadParamFields()
    }

    function refreshRangeGrids() {
        rng.refreshFromGame()
    }

    function applyRangeTextFromField() {
        if (!setup.showFullRangeEditor)
            return
        const t = textArea.text.trim()
        const ok = pokerGame.applySeatRangeText(setup.selectedSeat, t, rangeLayerTab.currentIndex)
        setup.persistSave()
        setup.refreshRangeGrids()
        if (ok)
            textArea.text = pokerGame.exportSeatRangeText(setup.selectedSeat, rangeLayerTab.currentIndex)
    }

    function reloadSeatEditor() {
        stratCombo._stratSyncFromEngine = true
        stratCombo.currentIndex = pokerGame.seatStrategyIndex(setup.selectedSeat)
        stratCombo._stratSyncFromEngine = false
        textArea.text = pokerGame.exportSeatRangeText(setup.selectedSeat, rangeLayerTab.currentIndex)
        refreshRangeGrids()
        loadParamFields()
        rangeTextEditorOpen = false
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
        setup._syncingSlowBots = true
        slowBotsCheck.checked = pokerGame.botSlowActions
        setup._syncingSlowBots = false
        syncPlayAsBotCheckboxFromEngine()
        /// After sync’s deferred `_syncing` clear; avoids `toggled` applying stale engine state on startup.
        Qt.callLater(function () {
            setup.playAsBotUserInputEnabled = true
        })
        Qt.callLater(reloadSeatEditor)
    }

    onVisibleChanged: {
        if (visible) {
            /// Re-read stakes from the engine whenever Setup is shown (persisted values load before QML binds).
            sbSpin.value = pokerGame.configuredSmallBlind()
            bbSpin.value = pokerGame.configuredBigBlind()
            streetSpin.value = pokerGame.configuredStreetBet()
            setup._syncingSlowBots = true
            slowBotsCheck.checked = pokerGame.botSlowActions
            setup._syncingSlowBots = false
            totalBankSpin.refreshFromGame()
            seatBankSpin.refreshFromGame()
            syncPlayAsBotCheckboxFromEngine()
            reloadSeatEditor()
        }
    }

    function syncPlayAsBotCheckboxFromEngine() {
        setup._syncingPlayAsBot = true
        const wantChecked = !pokerGame.interactiveHuman
        if (playAsBotCheck.checked !== wantChecked)
            playAsBotCheck.checked = wantChecked
        /// Defer clearing so any asynchronously delivered `toggled` from the assignment still sees `_syncing`.
        Qt.callLater(function () {
            setup._syncingPlayAsBot = false
        })
    }

    Connections {
        target: pokerGame
        function onSessionStatsChanged() {
            totalBankSpin.refreshFromGame()
            seatBankSpin.refreshFromGame()
        }
    }

    Connections {
        target: pokerGame
        function onRangeRevisionChanged() {
            if (!setup.showFullRangeEditor)
                return
            /// Grid edits emit this; keep the text field in sync (export lists any cell with weight > 0).
            textArea.text = pokerGame.exportSeatRangeText(setup.selectedSeat, rangeLayerTab.currentIndex)
        }
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
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        topPadding: Theme.uiScrollViewTopPadding

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

            ThemedPanel {
                panelTitle: qsTr("Bots and pricing")
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
                                    font.weight: Font.ExtraBold
                                    color: Theme.colorForSeat(index + 1)
                                }
                                ThemedSwitch {
                                    checked: pokerGame.seatParticipating(index + 1)
                                    onToggled: {
                                        pokerGame.setSeatParticipating(index + 1, checked)
                                        setup.persistSave()
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        text: qsTr("Game settings")
                        font.bold: true
                        font.capitalization: Font.AllUppercase
                        font.pixelSize: Theme.trainerCaptionPx
                        color: Theme.textPrimary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 18

                        RowLayout {
                            spacing: 4
                            Label {
                                text: qsTr("SB")
                                font.pixelSize: Theme.trainerCaptionPx
                                font.bold: true
                            }
                            SpinBox {
                                id: sbSpin
                                from: 1
                                to: 50
                                value: 1
                                editable: true
                                Layout.preferredWidth: 104
                                Layout.maximumWidth: 120
                            }
                        }
                        RowLayout {
                            spacing: 4
                            Label {
                                text: qsTr("BB")
                                font.pixelSize: Theme.trainerCaptionPx
                                font.bold: true
                            }
                            SpinBox {
                                id: bbSpin
                                from: 1
                                to: 100
                                value: 3
                                editable: true
                                Layout.preferredWidth: 104
                                Layout.maximumWidth: 120
                            }
                        }
                        RowLayout {
                            spacing: 4
                            Label {
                                text: qsTr("Min raise")
                                font.pixelSize: Theme.trainerCaptionPx
                                font.bold: true
                            }
                            SpinBox {
                                id: streetSpin
                                from: 1
                                to: 200
                                value: 9
                                editable: true
                                Layout.preferredWidth: 104
                                Layout.maximumWidth: 120
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 8
                        }
                        RangeActionButton {
                            text: qsTr("Apply stakes")
                            fillCol: Qt.tint(Theme.panelElevated, "#42c9a227")
                            borderCol: Theme.goldMuted
                            onClicked: {
                                pokerGame.configure(sbSpin.value, bbSpin.value, streetSpin.value,
                                        pokerGame.configuredStartStack())
                                setup.persistSave()
                                reloadAllGrids()
                            }
                        }
                    }

                    ThemedCheckBox {
                        id: slowBotsCheck
                        text: qsTr("Slow down bot actions (longer pauses between bot decisions)")
                        /// Use `onCheckedChanged` (fires after `checked` updates). `toggled` / stale `checked`
                        /// in `onToggled` can race and write the wrong value; early emissions before sync must
                        /// be ignored via `_syncingSlowBots` (defaults true until `Component.onCompleted`).
                        onCheckedChanged: {
                            if (setup._syncingSlowBots)
                                return
                            pokerGame.setBotSlowActions(slowBotsCheck.checked)
                            setup.persistSave()
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
                    font.weight: Font.ExtraBold
                    topPadding: 10
                    bottomPadding: 10
                    leftPadding: 14
                    rightPadding: 14
                    contentItem: Label {
                        text: parent.text
                        font.family: parent.font.family
                        font.pixelSize: parent.font.pixelSize
                        font.weight: parent.font.weight
                        font.bold: parent.font.bold
                        font.italic: parent.font.italic
                        font.capitalization: Font.AllUppercase
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
                        font.weight: Font.ExtraBold
                        topPadding: 10
                        bottomPadding: 10
                        leftPadding: 14
                        rightPadding: 14
                        contentItem: Label {
                            text: parent.text
                            font.family: parent.font.family
                            font.pixelSize: parent.font.pixelSize
                            font.weight: parent.font.weight
                            font.bold: parent.font.bold
                            font.italic: parent.font.italic
                            font.capitalization: Font.AllUppercase
                            color: Theme.colorForSeat(index + 1)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            ThemedPanel {
                Layout.fillWidth: true
                panelTitle: ""

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Label {
                        Layout.fillWidth: true
                        text: botNames.displayName(setup.selectedSeat)
                        font.weight: Font.ExtraBold
                        font.capitalization: Font.AllUppercase
                        font.pixelSize: Theme.trainerSectionPx
                        color: Theme.colorForSeat(setup.selectedSeat)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Label {
                            text: qsTr("Wallet")
                            font.bold: true
                            font.pixelSize: Theme.trainerCaptionPx
                        }
                        SpinBox {
                            id: totalBankSpin
                            from: 1
                            to: 100000000
                            stepSize: 100
                            editable: true
                            Layout.fillWidth: false
                            Layout.preferredWidth: 160
                            Layout.maximumWidth: 200

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
                        Label {
                            text: qsTr("On the table")
                            font.bold: true
                            font.pixelSize: Theme.trainerCaptionPx
                            Layout.leftMargin: 8
                        }
                        SpinBox {
                            id: seatBankSpin
                            from: 1
                            to: setup.buyInCapChips
                            stepSize: 1
                            editable: true
                            Layout.fillWidth: false
                            Layout.preferredWidth: 160
                            Layout.maximumWidth: 200

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
                                    setup.persistSave()
                                } else {
                                    setup.persistSave()
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
                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    Label {
                        text: qsTr("Strategy selection")
                        font.bold: true
                        font.capitalization: Font.AllUppercase
                        font.pixelSize: Theme.trainerSectionPx
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        ComboBox {
                            id: stratCombo
                            /// While syncing from `reloadSeatEditor` — do not call `setSeatStrategy` (would wipe loaded ranges).
                            property bool _stratSyncFromEngine: false
                            model: strategyNames
                            currentIndex: 0
                            Layout.fillWidth: true
                            onCurrentIndexChanged: {
                                if (stratCombo._stratSyncFromEngine)
                                    return
                                pokerGame.setSeatStrategy(setup.selectedSeat, currentIndex)
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
                            formFontPixelSize: Theme.trainerCaptionPx
                            textColor: Theme.textPrimary
                            padH: 10
                            overrideHeight: 30
                            onClicked: setup.openStrategyLogPopup(
                                    qsTr("%1 — strategy").arg(setup.strategyNames[stratCombo.currentIndex]),
                                    pokerGame.getStrategySummary(stratCombo.currentIndex))
                        }
                    }

                    ThemedCheckBox {
                        id: playAsBotCheck
                        visible: selectedSeat === 0
                        Layout.fillWidth: true
                        text: qsTr("Play as bot (autoplay my seat with the strategy above)")
                        /// Update the engine in this signal (sync), not in Qt.callLater — deferred updates race
                        /// `syncPlayAsBotCheckboxFromEngine()` and can re-apply stale `interactiveHuman` to the checkbox.
                        onToggled: function (checked) {
                            if (!setup.playAsBotUserInputEnabled || setup._syncingPlayAsBot)
                                return
                            const playAsBotOn = (checked !== undefined) ? checked : playAsBotCheck.checked
                            pokerGame.setInteractiveHuman(!playAsBotOn)
                            setup.persistSave()
                            setup.refreshRangeGrids()
                            setup.loadParamFields()
                        }
                    }

                    ThemedPanel {
                        panelTitle: qsTr("Engine parameters")
                        visible: selectedSeat >= 1 || setup.humanSeatAutoplay
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.uiGroupInnerSpacing

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

                            Button {
                                text: qsTr("Apply parameters")
                                font.pixelSize: Theme.trainerCaptionPx
                                onClicked: setup.applyParamFields()
                            }
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
                            contentItem: Label {
                                text: parent.text
                                font.family: parent.font.family
                                font.pixelSize: parent.font.pixelSize
                                font.weight: parent.font.weight
                                font.bold: parent.font.bold
                                font.italic: parent.font.italic
                                font.capitalization: Font.AllUppercase
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        TabButton {
                            text: qsTr("Raise")
                            font.bold: true
                            contentItem: Label {
                                text: parent.text
                                font.family: parent.font.family
                                font.pixelSize: parent.font.pixelSize
                                font.weight: parent.font.weight
                                font.bold: parent.font.bold
                                font.italic: parent.font.italic
                                font.capitalization: Font.AllUppercase
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        TabButton {
                            text: qsTr("Open")
                            font.bold: true
                            contentItem: Label {
                                text: parent.text
                                font.family: parent.font.family
                                font.pixelSize: parent.font.pixelSize
                                font.weight: parent.font.weight
                                font.bold: parent.font.bold
                                font.italic: parent.font.italic
                                font.capitalization: Font.AllUppercase
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
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

                    RangeGrid {
                        id: rng
                        visible: showFullRangeEditor
                        seatIndex: setup.selectedSeat
                        composite: true
                        editLayer: rangeLayerTab.currentIndex
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                    }

                    RangeActionButton {
                        visible: showFullRangeEditor && !setup.rangeTextEditorOpen
                        Layout.topMargin: 4
                        compact: true
                        text: qsTr("Range text…")
                        fillCol: Qt.tint(Theme.panelElevated, "#32c9a21a")
                        borderCol: Theme.goldMuted
                        onClicked: setup.rangeTextEditorOpen = true
                    }

                    Item {
                        id: rangeTextExpandHost
                        visible: showFullRangeEditor
                        Layout.fillWidth: true
                        implicitHeight: setup.rangeTextEditorOpen ? rangeTextEditRow.implicitHeight : 0
                        clip: true

                        Behavior on implicitHeight {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                        }

                        ColumnLayout {
                            id: rangeTextEditRow
                            width: parent.width
                            spacing: 10

                            TextArea {
                                id: textArea
                                Layout.fillWidth: true
                                Layout.minimumHeight: 120
                                Layout.preferredHeight: 156
                                Layout.maximumHeight: 280
                                wrapMode: TextArea.Wrap
                                font.family: Theme.fontFamilyUi
                                font.pixelSize: Theme.trainerBodyPx
                                color: Theme.textPrimary
                                placeholderText: "AA,AKs,AKo,TT+"
                                placeholderTextColor: Theme.textSecondary
                                onEditingFinished: setup.applyRangeTextFromField()
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                RangeActionButton {
                                    compact: true
                                    text: qsTr("Apply")
                                    fillCol: Qt.tint(Theme.panelElevated, "#42c9a227")
                                    borderCol: Theme.goldMuted
                                    onClicked: {
                                        setup.applyRangeTextFromField()
                                        setup.rangeTextEditorOpen = false
                                    }
                                }
                                RangeActionButton {
                                    compact: true
                                    text: qsTr("Full")
                                    fillCol: Qt.tint(Theme.panelElevated, "#38dc2626")
                                    borderCol: Theme.ember
                                    onClicked: {
                                        pokerGame.resetSeatRangeFull(setup.selectedSeat)
                                        setup.persistSave()
                                        setup.refreshRangeGrids()
                                        textArea.text = pokerGame.exportSeatRangeText(setup.selectedSeat, rangeLayerTab.currentIndex)
                                        setup.rangeTextEditorOpen = false
                                    }
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }

            Button {
                text: qsTr("Reload from engine")
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

    Connections {
        target: seatTabBar
        function onCurrentIndexChanged() {
            setup.syncPlayAsBotCheckboxFromEngine()
            setup.reloadSeatEditor()
        }
    }

    /// Setup action chips (Apply / Full / Range text…).
    component RangeActionButton: Button {
        id: rangeActBtn
        property color fillCol: Theme.panelElevated
        property color borderCol: Theme.chromeLineGold
        property bool compact: false

        flat: false
        focusPolicy: Qt.NoFocus
        font.pixelSize: compact ? Theme.trainerCaptionPx : Theme.trainerButtonLabelPx
        font.bold: true
        leftPadding: compact ? 14 : 22
        rightPadding: compact ? 14 : 22
        topPadding: compact ? 6 : 12
        bottomPadding: compact ? 6 : 12

        background: Rectangle {
            implicitWidth: rangeActBtn.contentItem.implicitWidth + rangeActBtn.leftPadding + rangeActBtn.rightPadding
            implicitHeight: rangeActBtn.contentItem.implicitHeight + rangeActBtn.topPadding + rangeActBtn.bottomPadding
            radius: rangeActBtn.compact ? 7 : 9
            color: rangeActBtn.pressed ? Qt.darker(rangeActBtn.fillCol, 1.14)
                    : (rangeActBtn.hovered ? Qt.lighter(rangeActBtn.fillCol, 1.06) : rangeActBtn.fillCol)
            border.width: 1
            border.color: rangeActBtn.hovered ? Qt.lighter(rangeActBtn.borderCol, 1.12) : rangeActBtn.borderCol
        }

        contentItem: Label {
            text: rangeActBtn.text
            font: rangeActBtn.font
            color: Theme.textPrimary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
