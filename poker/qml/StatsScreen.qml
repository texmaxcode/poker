import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

/// Session bankroll, leaderboard, training progress, and bankroll-over-time chart.
Page {
    id: statsPage
    padding: 0
    font.family: Theme.fontFamilyUi

    BotNames {
        id: botNames
    }

    background: BrandedBackground {
        anchors.fill: parent
    }

    readonly property var lineColors: Theme.chartLineColors
    readonly property int chartPadL: 44
    readonly property int chartPadR: 12
    readonly property int chartPadT: 10
    readonly property int chartPadB: 36

    property var snapTimes: []
    property int chartHoverIndex: -1
    property real chartTipX: 0
    property real chartTipY: 0
    property var trainingProgress: ({})
    /// Rows from `seatRankings()` sorted by seat index 0–5 (on table / off-table bankroll / total).
    property var seatBankrollDetail: []
    property bool pendingApplyBuyIns: false

    function formatTimeMs(ms) {
        if (ms === undefined || ms === null || ms <= 0)
            return ""
        var d = new Date(ms)
        return Qt.formatDateTime(d, "yyyy-MM-dd hh:mm:ss")
    }

    function formatTimeShort(ms) {
        if (ms === undefined || ms === null || ms <= 0)
            return ""
        var d = new Date(ms)
        return Qt.formatDateTime(d, "hh:mm:ss")
    }

    function refreshTrainingProgress() {
        trainingProgress = trainingStore.loadProgress()
    }

    function refreshSeatBankrollTables() {
        var list = pokerGame.seatRankings()
        var map = {}
        for (var i = 0; i < list.length; i++)
            map[list[i].seat] = list[i]
        var out = []
        for (var s = 0; s < 6; s++) {
            if (map[s] !== undefined)
                out.push(map[s])
        }
        seatBankrollDetail = out
        pendingApplyBuyIns = pokerGame.pendingSeatBuyInsApply()
    }

    function refreshChartData() {
        snapTimes = pokerGame.bankrollSnapshotTimesMs()
        var n = pokerGame.bankrollSnapshotCount()
        if (n < 1)
            chartHoverIndex = -1
        else if (chartHoverIndex >= n)
            chartHoverIndex = n - 1
        refreshChart()
    }

    function refreshChart() {
        bankCanvas.requestPaint()
    }

    function updateChartHover(mx, my) {
        var nSnap = pokerGame.bankrollSnapshotCount()
        if (nSnap < 1) {
            chartHoverIndex = -1
            return
        }
        var padL = statsPage.chartPadL
        var plotW = bankCanvas.width - padL - statsPage.chartPadR
        if (plotW < 1)
            plotW = 1
        var rel = (mx - padL) / plotW
        if (rel < 0)
            rel = 0
        if (rel > 1)
            rel = 1
        var idx
        if (nSnap <= 1) {
            idx = 0
        } else {
            idx = Math.round(rel * (nSnap - 1))
        }
        if (idx < 0)
            idx = 0
        if (idx > nSnap - 1)
            idx = nSnap - 1
        chartHoverIndex = idx
        chartTipX = mx
        chartTipY = my
        bankCanvas.requestPaint()
    }

    function bankrollValueAt(seat, snapIdx) {
        if (snapIdx < 0)
            return "—"
        var ser = pokerGame.bankrollSeries(seat)
        if (ser.length <= snapIdx)
            return "—"
        return "$" + ser[snapIdx]
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
            width: Math.max(320, scrollView.width > 0 ? scrollView.width - 2 * Theme.uiPagePadding : statsPage.width - 2 * Theme.uiPagePadding)
            spacing: Theme.uiPageColumnSpacing

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr(
                    "Tables below list each seat’s chips on the table, bankroll off the table, and total bankroll, plus configured buy-in and blinds. "
                    + "The leaderboard ranks by total; the chart plots bankroll over time after each hand (bubbles per snapshot). "
                    + "Set each seat’s bankroll (buy-in) under Bots & ranges — if you change it during a hand, apply when idle (button below) or at the next hand.")
                font.pixelSize: Theme.trainerBodyPx
                lineHeight: 1.25
                color: Theme.textSecondary
            }

            GroupBox {
                title: qsTr("Seat bankrolls")
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
                        Label {
                            text: qsTr("Player")
                            font.bold: true
                            font.pixelSize: Theme.trainerCaptionPx
                            Layout.preferredWidth: 120
                        }
                        Label {
                            text: qsTr("On table")
                            font.bold: true
                            font.pixelSize: Theme.trainerCaptionPx
                            Layout.preferredWidth: 88
                            horizontalAlignment: Text.AlignRight
                        }
                        Label {
                            text: qsTr("Off table")
                            font.bold: true
                            font.pixelSize: Theme.trainerCaptionPx
                            Layout.preferredWidth: 88
                            horizontalAlignment: Text.AlignRight
                        }
                        Label {
                            text: qsTr("Total")
                            font.bold: true
                            font.pixelSize: Theme.trainerCaptionPx
                            Layout.preferredWidth: 88
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Repeater {
                        model: statsPage.seatBankrollDetail

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8

                            Label {
                                text: botNames.displayName(modelData.seat)
                                Layout.preferredWidth: 120
                                color: Theme.colorForSeat(modelData.seat)
                                font.pixelSize: Theme.trainerCaptionPx
                                font.bold: true
                            }
                            Label {
                                text: "$" + modelData.stack
                                Layout.preferredWidth: 88
                                color: Theme.textSecondary
                                font.pixelSize: Theme.trainerCaptionPx
                                horizontalAlignment: Text.AlignRight
                            }
                            Label {
                                text: "$" + modelData.wallet
                                Layout.preferredWidth: 88
                                color: Theme.textSecondary
                                font.pixelSize: Theme.trainerCaptionPx
                                horizontalAlignment: Text.AlignRight
                            }
                            Label {
                                text: "$" + modelData.total
                                Layout.preferredWidth: 88
                                color: Theme.gold
                                font.bold: true
                                font.pixelSize: Theme.trainerCaptionPx
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }

            GroupBox {
                title: qsTr("Stakes & buy-ins")
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
                        text: qsTr("Blinds: $%1 / $%2").arg(pokerGame.configuredSmallBlind()).arg(pokerGame.configuredBigBlind())
                        font.pixelSize: Theme.trainerCaptionPx
                        color: Theme.textSecondary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: qsTr("Player")
                            font.bold: true
                            font.pixelSize: Theme.trainerCaptionPx
                            Layout.preferredWidth: 120
                        }
                        Label {
                            text: qsTr("Buy-in (rebuy)")
                            font.bold: true
                            font.pixelSize: Theme.trainerCaptionPx
                            Layout.fillWidth: true
                        }
                    }

                    Repeater {
                        model: 6

                        RowLayout {
                            required property int index
                            Layout.fillWidth: true
                            spacing: 8

                            Label {
                                text: botNames.displayName(index)
                                Layout.preferredWidth: 120
                                color: Theme.colorForSeat(index)
                                font.pixelSize: Theme.trainerCaptionPx
                                font.bold: true
                            }
                            Label {
                                text: "$" + pokerGame.seatBuyIn(index)
                                Layout.fillWidth: true
                                color: Theme.textSecondary
                                font.pixelSize: Theme.trainerCaptionPx
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: statsPage.pendingApplyBuyIns

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: qsTr("Buy-in amounts were edited in Bots & ranges and are waiting to be pushed to the table stacks.")
                            font.pixelSize: Theme.trainerCaptionPx
                            color: Theme.textPrimary
                        }
                        Button {
                            text: qsTr("Apply buy-ins")
                            enabled: !pokerGame.gameInProgress()
                            onClicked: {
                                pokerGame.applySeatBuyInsToStacks()
                                pokerGame.savePersistedSettings()
                                statsPage.refreshSeatBankrollTables()
                                rankRepeater.model = pokerGame.seatRankings()
                            }
                        }
                    }
                }
            }

            GroupBox {
                title: qsTr("Leaderboard")
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
                        Label {
                            text: qsTr("Rank")
                            font.bold: true
                            font.pixelSize: Theme.trainerCaptionPx
                            Layout.preferredWidth: 44
                        }
                        Label {
                            text: qsTr("Player")
                            font.bold: true
                            font.pixelSize: Theme.trainerCaptionPx
                            Layout.preferredWidth: 120
                        }
                        Label {
                            text: qsTr("Total")
                            font.bold: true
                            font.pixelSize: Theme.trainerCaptionPx
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                        }
                        Label {
                            text: qsTr("P/L")
                            font.bold: true
                            font.pixelSize: Theme.trainerCaptionPx
                            Layout.preferredWidth: 72
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Repeater {
                        id: rankRepeater
                        model: pokerGame.seatRankings()

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8

                            Label {
                                text: "#" + modelData.rank
                                Layout.preferredWidth: 44
                                color: Theme.gold
                                font.bold: true
                                font.pixelSize: Theme.trainerCaptionPx
                            }
                            Label {
                                text: botNames.displayName(modelData.seat)
                                Layout.preferredWidth: 120
                                color: Theme.colorForSeat(modelData.seat)
                                font.pixelSize: Theme.trainerCaptionPx
                                font.bold: true
                            }
                            Label {
                                text: "$" + (modelData.total !== undefined ? modelData.total : modelData.stack)
                                Layout.fillWidth: true
                                color: Theme.textSecondary
                                font.pixelSize: Theme.trainerCaptionPx
                                horizontalAlignment: Text.AlignRight
                            }
                            Label {
                                text: (modelData.profit >= 0 ? "+" : "") + modelData.profit
                                Layout.preferredWidth: 72
                                color: modelData.profit >= 0 ? Theme.profitUp : Theme.profitDown
                                font.pixelSize: Theme.trainerCaptionPx
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }

            GroupBox {
                title: qsTr("Training session")
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
                        text: qsTr("Drill decisions recorded from Preflop / Flop trainers (persisted in settings).")
                        font.pixelSize: Theme.trainerCaptionPx
                        color: Theme.textMuted
                    }

                    Label {
                        text: qsTr("Decisions: %1 · Correct: %2 · Acc: %3% · Σ EV loss: %4 bb")
                                .arg(trainingProgress.totalDecisions !== undefined ? trainingProgress.totalDecisions : 0)
                                .arg(trainingProgress.totalCorrect !== undefined ? trainingProgress.totalCorrect : 0)
                                .arg((trainingProgress.totalDecisions > 0)
                                     ? (Math.round(1000 * trainingProgress.totalCorrect / trainingProgress.totalDecisions) / 10).toFixed(1)
                                     : "0.0")
                                .arg((trainingProgress.totalEvLossBb !== undefined ? trainingProgress.totalEvLossBb : 0).toFixed(3))
                        font.pixelSize: Theme.trainerBodyPx
                        color: Theme.textSecondary
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            GroupBox {
                title: qsTr("Bankroll over time")
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
                        Repeater {
                            model: 6
                            RowLayout {
                                spacing: 4
                                required property int index
                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: statsPage.lineColors[index]
                                }
                                Label {
                                    text: botNames.displayName(index)
                                    font.pixelSize: Theme.trainerCaptionPx
                                    font.bold: true
                                    color: Theme.colorForSeat(index)
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item {
                            id: chartPanelItem
                            Layout.fillWidth: true
                            Layout.preferredHeight: 340

                            Label {
                                anchors.centerIn: parent
                                visible: pokerGame.bankrollSnapshotCount() < 1
                                text: qsTr("No data yet — play a hand to see your bankroll chart.")
                                color: Theme.textMuted
                                font.pixelSize: Theme.trainerBodyPx
                            }

                            Canvas {
                                id: bankCanvas
                                anchors.fill: parent
                                renderTarget: Canvas.FramebufferObject
                                renderStrategy: Canvas.Immediate

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    var w = width
                                    var h = height
                                    ctx.fillStyle = Theme.chartPlotFill
                                    ctx.fillRect(0, 0, w, h)

                                    var nSnap = pokerGame.bankrollSnapshotCount()
                                    if (nSnap < 1)
                                        return

                                    var maxY = 0
                                    var s
                                    for (s = 0; s < 6; s++) {
                                        var ser = pokerGame.bankrollSeries(s)
                                        for (var j = 0; j < ser.length; j++) {
                                            var v = ser[j]
                                            if (v > maxY)
                                                maxY = v
                                        }
                                    }
                                    if (maxY < 1)
                                        maxY = 1

                                    var padL = statsPage.chartPadL
                                    var padR = statsPage.chartPadR
                                    var padT = statsPage.chartPadT
                                    var padB = statsPage.chartPadB
                                    if (nSnap > 4)
                                        padB = Math.max(padB, 48)
                                    var plotW = w - padL - padR
                                    var plotH = h - padT - padB

                                    function xAt(i) {
                                        if (nSnap <= 1)
                                            return padL + plotW * 0.5
                                        return padL + i * plotW / (nSnap - 1)
                                    }
                                    function yAt(stack) {
                                        return padT + plotH - stack / maxY * plotH
                                    }

                                    ctx.strokeStyle = Theme.chartGridLine
                                    ctx.lineWidth = 1
                                    ctx.globalAlpha = 0.45
                                    for (var g = 1; g <= 3; g++) {
                                        var gy = padT + plotH * g / 4
                                        ctx.beginPath()
                                        ctx.moveTo(padL, gy)
                                        ctx.lineTo(padL + plotW, gy)
                                        ctx.stroke()
                                    }
                                    ctx.globalAlpha = 1
                                    ctx.beginPath()
                                    ctx.moveTo(padL, padT)
                                    ctx.lineTo(padL, padT + plotH)
                                    ctx.lineTo(padL + plotW, padT + plotH)
                                    ctx.stroke()

                                    ctx.fillStyle = Theme.chartAxisText
                                    ctx.font = (Theme.uiChartCanvasPx + 3) + "px \"" + Theme.fontFamilyUi + "\""
                                    ctx.fillText("0", 4, padT + plotH + 4)
                                    ctx.fillText(String(maxY), 4, padT + 10)

                                    var times = statsPage.snapTimes
                                    var nticks = Math.min(5, nSnap)
                                    ctx.textAlign = "center"
                                    ctx.font = (Theme.uiChartCanvasPx + 2) + "px \"" + Theme.fontFamilyUi + "\""
                                    var timeY = h - 8
                                    if (nSnap > 4)
                                        timeY = h - 22
                                    for (var ti = 0; ti < nticks; ti++) {
                                        var ii = nSnap <= 1 ? 0 : Math.round(ti * (nSnap - 1) / Math.max(1, nticks - 1))
                                        if (times.length <= ii)
                                            continue
                                        if (nSnap > 2 && (ii === 0 || ii === nSnap - 1))
                                            continue
                                        var tx = xAt(ii)
                                        ctx.fillText(statsPage.formatTimeShort(times[ii]), tx, timeY)
                                    }
                                    if (times.length >= 1) {
                                        ctx.textAlign = "left"
                                        ctx.font = (Theme.uiChartCanvasPx + 1) + "px \"" + Theme.fontFamilyUi + "\""
                                        ctx.fillText(statsPage.formatTimeMs(times[0]), padL, h - 6)
                                    }
                                    if (times.length >= 2) {
                                        ctx.textAlign = "right"
                                        ctx.fillText(statsPage.formatTimeMs(times[times.length - 1]), padL + plotW, h - 6)
                                        ctx.textAlign = "left"
                                    }

                                    var bubbleR = nSnap > 24 ? 3.2 : (nSnap > 12 ? 3.8 : 4.5)
                                    for (s = 0; s < 6; s++) {
                                        ser = pokerGame.bankrollSeries(s)
                                        if (ser.length < 1)
                                            continue
                                        var col = statsPage.lineColors[s]
                                        ctx.strokeStyle = col
                                        ctx.globalAlpha = 0.2
                                        ctx.lineWidth = 1
                                        ctx.beginPath()
                                        for (var i = 0; i < ser.length; i++) {
                                            var px = xAt(i)
                                            var py = yAt(ser[i])
                                            if (i === 0)
                                                ctx.moveTo(px, py)
                                            else
                                                ctx.lineTo(px, py)
                                        }
                                        ctx.stroke()
                                        ctx.globalAlpha = 1
                                        for (i = 0; i < ser.length; i++) {
                                            px = xAt(i)
                                            py = yAt(ser[i])
                                            ctx.beginPath()
                                            ctx.arc(px, py, bubbleR, 0, 2 * Math.PI)
                                            ctx.fillStyle = col
                                            ctx.globalAlpha = 0.88
                                            ctx.fill()
                                            ctx.globalAlpha = 1
                                            ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.4)
                                            ctx.lineWidth = 1
                                            ctx.stroke()
                                        }
                                    }

                                    var hi = statsPage.chartHoverIndex
                                    if (hi >= 0 && hi < nSnap) {
                                        var hx = xAt(hi)
                                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.22)
                                        ctx.lineWidth = 1
                                        ctx.setLineDash([4, 4])
                                        ctx.beginPath()
                                        ctx.moveTo(hx, padT)
                                        ctx.lineTo(hx, padT + plotH)
                                        ctx.stroke()
                                        ctx.setLineDash([])
                                        var hoverR = bubbleR + 2
                                        for (s = 0; s < 6; s++) {
                                            ser = pokerGame.bankrollSeries(s)
                                            if (ser.length <= hi)
                                                continue
                                            var cx = xAt(hi)
                                            var cy = yAt(ser[hi])
                                            var hc = statsPage.lineColors[s]
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, hoverR, 0, 2 * Math.PI)
                                            ctx.fillStyle = Qt.alpha(hc, 0.38)
                                            ctx.fill()
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, bubbleR, 0, 2 * Math.PI)
                                            ctx.fillStyle = hc
                                            ctx.globalAlpha = 0.95
                                            ctx.fill()
                                            ctx.globalAlpha = 1
                                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.55)
                                            ctx.lineWidth = 1
                                            ctx.stroke()
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: chartHitArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.CrossCursor
                                acceptedButtons: Qt.NoButton
                                onPositionChanged: function (mouse) {
                                    statsPage.updateChartHover(mouse.x, mouse.y)
                                }
                                onEntered: {
                                    statsPage.updateChartHover(chartHitArea.mouseX, chartHitArea.mouseY)
                                }
                            }

                            Popup {
                                id: chartHoverBubble
                                parent: chartPanelItem
                                z: 100
                                padding: 10
                                modal: false
                                focus: false
                                closePolicy: Popup.CloseOnEscape
                                visible: chartHitArea.containsMouse
                                        && pokerGame.bankrollSnapshotCount() >= 1
                                        && statsPage.chartHoverIndex >= 0
                                        && statsPage.snapTimes.length > statsPage.chartHoverIndex

                                x: Math.max(4, Math.min(statsPage.chartTipX + 14,
                                                        chartPanelItem.width - chartHoverBubble.width - 4))
                                y: Math.max(4, Math.min(statsPage.chartTipY + 14,
                                                        chartPanelItem.height - chartHoverBubble.height - 4))

                                background: Rectangle {
                                    radius: 10
                                    color: Theme.panelElevated
                                    border.width: 1
                                    border.color: Theme.panelBorder
                                }

                                ColumnLayout {
                                    id: chartBubbleCol
                                    spacing: 8
                                    width: Math.min(340, chartPanelItem.width - 24)

                                    Label {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: Theme.trainerCaptionPx + 1
                                        font.bold: true
                                        color: Theme.textPrimary
                                        text: {
                                            var t = statsPage.formatTimeMs(
                                                    statsPage.snapTimes[statsPage.chartHoverIndex])
                                            return qsTr("Hand #%1 · %2").arg(statsPage.chartHoverIndex + 1).arg(t)
                                        }
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        rowSpacing: 4
                                        columnSpacing: 12
                                        columns: 3

                                        Repeater {
                                            model: 6

                                            RowLayout {
                                                required property int index
                                                spacing: 6
                                                Layout.fillWidth: true

                                                Rectangle {
                                                    width: 10
                                                    height: 10
                                                    radius: 5
                                                    color: statsPage.lineColors[index]
                                                }
                                                ColumnLayout {
                                                    spacing: 0
                                                    Label {
                                                        text: botNames.displayName(index)
                                                        font.pixelSize: Theme.trainerCaptionPx
                                                        font.bold: true
                                                        color: Theme.colorForSeat(index)
                                                    }
                                                    Label {
                                                        font.pixelSize: Theme.trainerCaptionPx + 1
                                                        font.bold: true
                                                        color: Theme.textPrimary
                                                        text: statsPage.bankrollValueAt(index,
                                                                statsPage.chartHoverIndex)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            visible: pokerGame.bankrollSnapshotCount() >= 1
                            font.pixelSize: Theme.trainerCaptionPx
                            color: Theme.textMuted
                            wrapMode: Text.WordWrap
                            text: qsTr("Hover the chart to see bankroll at each hand in a popup.")
                        }
                    }

                    RowLayout {
                        spacing: Theme.uiGroupInnerSpacing
                        Button {
                            text: qsTr("Reset chart & profit baseline")
                            flat: true
                            onClicked: {
                                pokerGame.resetBankrollSession()
                                statsPage.refreshChartData()
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: pokerGame
        function onSessionStatsChanged() {
            rankRepeater.model = pokerGame.seatRankings()
            statsPage.refreshChartData()
            statsPage.refreshSeatBankrollTables()
        }
        function onPot_changed() {
            statsPage.refreshSeatBankrollTables()
        }
    }

    Connections {
        target: trainingStore
        function onProgressChanged() {
            statsPage.refreshTrainingProgress()
        }
    }

    onVisibleChanged: {
        if (visible)
            statsPage.refreshSeatBankrollTables()
    }

    Component.onCompleted: {
        statsPage.refreshTrainingProgress()
        statsPage.refreshSeatBankrollTables()
        Qt.callLater(statsPage.refreshChartData)
    }
}
