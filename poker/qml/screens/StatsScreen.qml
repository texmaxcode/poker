import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0
import PokerUi 1.0

/// Session bankroll tables, leaderboard, and bankroll-over-time chart.
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
    readonly property int chartPadL: 28
    readonly property int chartPadR: 8
    readonly property int chartPadT: 10
    readonly property int chartPadB: 36

    property var snapTimes: []
    property int chartHoverIndex: -1
    property real chartTipX: 0
    property real chartTipY: 0
    /// Rows from `seatRankings()` sorted by seat index 0–5 (on table / off-table bankroll / total).
    property var seatBankrollDetail: []
    property bool pendingApplyBuyIns: false
    /// Bumped whenever tables refresh so `seatBuyIn()` / blinds labels re-bind (invokables have no NOTIFY).
    property int uiRevision: 0
    /// Bound to C++ `statsSeq` so leaderboard / chart refresh when bankroll snapshots update (not only on restart).
    property int statsSeq: pokerGame.statsSeq
    /// Same height as the “Blinds” line in Stakes & buy-ins so the three table header rows line up.
    readonly property int statsTablePx: 22
    readonly property int statsTableHeaderPx: 23
    readonly property int statsTableTopSlotH: statsTableHeaderPx + 14
    readonly property int statsTableRowSpacing: 2
    /// Extra inset inside framed panels so table text sits farther from the border.
    readonly property int statsPanelPadding: Theme.trainerPanelPadding + 18
    readonly property int statsTableColSpacing: 14
    readonly property int statsPanelsSpacing: 20

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

    function refreshSeatBankrollTables() {
        var list = pokerGame.seatRankings()
        rankRepeater.model = list
        var map = {}
        for (var i = 0; i < list.length; i++)
            map[list[i].seat] = list[i]
        var out = []
        for (var s = 0; s < 6; s++) {
            if (map[s] !== undefined)
                out.push(map[s])
        }
        seatBankrollDetail = out
        pendingApplyBuyIns = pokerGame.pendingSeatBuyInsApply() || pokerGame.pendingSeatBankrollApply()
        uiRevision = (uiRevision + 1) % 2000000000
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
        leftPadding: Theme.uiPagePadding + 8
        rightPadding: Theme.uiPagePadding + 8
        topPadding: Theme.uiScrollViewTopPadding
        bottomPadding: Theme.uiPagePadding + 6

        RowLayout {
            width: scrollView.availableWidth
            spacing: 0

            ColumnLayout {
                id: statsMainCol
                Layout.fillWidth: true
                Layout.minimumWidth: 320
                spacing: Theme.trainerColumnSpacing

            /// Plain row (no nested ScrollView): a horizontal ScrollView was stealing vertical wheel from the page scroll.
            RowLayout {
                id: statsTablesRow
                Layout.fillWidth: true
                spacing: statsPage.statsPanelsSpacing

                    ThemedPanel {
                        panelTitle: qsTr("Seat bankrolls")
                        panelPadding: statsPage.statsPanelPadding
                        panelTitlePixelSize: Theme.trainerSectionPx + 2
                        Layout.alignment: Qt.AlignTop
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 200

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: statsPage.statsTableRowSpacing

                            // Match vertical offset of “Stakes & buy-ins” blinds line so header rows align.
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: statsPage.statsTableTopSlotH
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: statsPage.statsTableColSpacing
                                Label {
                                    text: qsTr("Player")
                                    font.bold: true
                                    font.pixelSize: statsPage.statsTableHeaderPx
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 88
                                    elide: Text.ElideRight
                                }
                                Label {
                                    text: qsTr("Table")
                                    font.bold: true
                                    font.pixelSize: statsPage.statsTableHeaderPx
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 56
                                    horizontalAlignment: Text.AlignRight
                                }
                                Label {
                                    text: qsTr("Off")
                                    font.bold: true
                                    font.pixelSize: statsPage.statsTableHeaderPx
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 56
                                    horizontalAlignment: Text.AlignRight
                                }
                                Label {
                                    text: qsTr("Tot")
                                    font.bold: true
                                    font.pixelSize: statsPage.statsTableHeaderPx
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 56
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            Repeater {
                                model: statsPage.seatBankrollDetail

                                RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: statsPage.statsTableColSpacing

                                    Label {
                                        text: botNames.displayName(modelData.seat)
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 88
                                        color: Theme.colorForSeat(modelData.seat)
                                        font.pixelSize: statsPage.statsTablePx
                                        font.weight: Font.Black
                                        elide: Text.ElideRight
                                    }
                                    Label {
                                        text: "$" + modelData.stack
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 56
                                        color: Theme.textSecondary
                                        font.pixelSize: statsPage.statsTablePx
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    Label {
                                        text: "$" + modelData.wallet
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 56
                                        color: Theme.textSecondary
                                        font.pixelSize: statsPage.statsTablePx
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    Label {
                                        text: "$" + modelData.total
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 56
                                        color: Theme.gold
                                        font.bold: true
                                        font.pixelSize: statsPage.statsTablePx
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }

                    ThemedPanel {
                        panelTitle: qsTr("Stakes & buy-ins")
                        panelPadding: statsPage.statsPanelPadding
                        panelTitlePixelSize: Theme.trainerSectionPx + 2
                        Layout.alignment: Qt.AlignTop
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 200

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: statsPage.statsTableRowSpacing

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: statsPage.statsTableTopSlotH
                                Label {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    wrapMode: Text.WordWrap
                                    text: qsTr("Blinds: $%1 / $%2").arg(pokerGame.configuredSmallBlind()).arg(pokerGame.configuredBigBlind())
                                            + (statsPage.uiRevision * 0)
                                    font.pixelSize: statsPage.statsTablePx
                                    color: Theme.textSecondary
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: statsPage.statsTableColSpacing
                                Label {
                                    text: qsTr("Player")
                                    font.bold: true
                                    font.pixelSize: statsPage.statsTableHeaderPx
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 88
                                }
                                Label {
                                    text: qsTr("Buy-in")
                                    font.bold: true
                                    font.pixelSize: statsPage.statsTableHeaderPx
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 72
                                }
                            }

                            Repeater {
                                model: 6

                                RowLayout {
                                    required property int index
                                    Layout.fillWidth: true
                                    spacing: statsPage.statsTableColSpacing

                                    Label {
                                        text: botNames.displayName(index)
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 88
                                        color: Theme.colorForSeat(index)
                                        font.pixelSize: statsPage.statsTablePx
                                        font.weight: Font.Black
                                        elide: Text.ElideRight
                                    }
                                    Label {
                                        text: "$" + pokerGame.seatBuyIn(index) + (statsPage.uiRevision * 0)
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 72
                                        color: Theme.textSecondary
                                        font.pixelSize: statsPage.statsTablePx
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                visible: statsPage.pendingApplyBuyIns

                                Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: qsTr("Pending buy-in edits — apply when table is idle.")
                                    font.pixelSize: statsPage.statsTablePx
                                    color: Theme.textPrimary
                                }
                                Button {
                                    text: qsTr("Apply")
                                    font.pixelSize: statsPage.statsTablePx
                                    enabled: !pokerGame.gameInProgress()
                                    onClicked: {
                                        pokerGame.applyPendingBankrollTotals()
                                        pokerGame.applySeatBuyInsToStacks()
                                        pokerGame.savePersistedSettings()
                                        statsPage.refreshSeatBankrollTables()
                                    }
                                }
                            }
                        }
                    }

                    ThemedPanel {
                        panelTitle: qsTr("Leaderboard")
                        panelPadding: statsPage.statsPanelPadding
                        panelTitlePixelSize: Theme.trainerSectionPx + 2
                        Layout.alignment: Qt.AlignTop
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 200

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: statsPage.statsTableRowSpacing

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: statsPage.statsTableTopSlotH
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: statsPage.statsTableColSpacing
                                Label {
                                    text: qsTr("#")
                                    font.bold: true
                                    font.pixelSize: statsPage.statsTableHeaderPx
                                    Layout.preferredWidth: 40
                                    horizontalAlignment: Text.AlignLeft
                                }
                                Label {
                                    text: qsTr("Player")
                                    font.bold: true
                                    font.pixelSize: statsPage.statsTableHeaderPx
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 88
                                }
                                Label {
                                    text: qsTr("Total")
                                    font.bold: true
                                    font.pixelSize: statsPage.statsTableHeaderPx
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 64
                                    horizontalAlignment: Text.AlignRight
                                }
                                Label {
                                    text: qsTr("P/L")
                                    font.bold: true
                                    font.pixelSize: statsPage.statsTableHeaderPx
                                    Layout.preferredWidth: 56
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            Repeater {
                                id: rankRepeater
                                model: []

                                RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: statsPage.statsTableColSpacing

                                    Label {
                                        text: "#" + modelData.rank
                                        Layout.preferredWidth: 40
                                        color: Theme.gold
                                        font.bold: true
                                        font.pixelSize: statsPage.statsTablePx
                                    }
                                    Label {
                                        text: botNames.displayName(modelData.seat)
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 88
                                        color: Theme.colorForSeat(modelData.seat)
                                        font.pixelSize: statsPage.statsTablePx
                                        font.weight: Font.Black
                                        elide: Text.ElideRight
                                    }
                                    Label {
                                        text: "$" + (modelData.total !== undefined ? modelData.total : modelData.stack)
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 64
                                        color: Theme.textSecondary
                                        font.pixelSize: statsPage.statsTablePx
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    Label {
                                        text: (modelData.profit >= 0 ? "+" : "") + modelData.profit
                                        Layout.preferredWidth: 56
                                        color: modelData.profit >= 0 ? Theme.profitUp : Theme.profitDown
                                        font.pixelSize: statsPage.statsTablePx
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }
                }

            ThemedPanel {
                Layout.fillWidth: true
                panelTitle: qsTr("Bankroll over time")
                panelPadding: statsPage.statsPanelPadding

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.uiGroupInnerSpacing

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
                                    font.weight: Font.Black
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
                            Layout.preferredHeight: 380

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
                                                        font.weight: Font.Black
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
                    }

                    RowLayout {
                        spacing: Theme.uiGroupInnerSpacing
                        ResetButton {
                            text: qsTr("Reset chart & profit baseline")
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
    }

    Connections {
        target: pokerGame
        function onPot_changed() {
            statsPage.refreshSeatBankrollTables()
        }
        function onSessionStatsChanged() {
            statsPage.refreshChartData()
            statsPage.refreshSeatBankrollTables()
        }
    }

    onVisibleChanged: {
        if (visible)
            statsPage.refreshSeatBankrollTables()
    }

    Component.onCompleted: {
        statsPage.refreshSeatBankrollTables()
        Qt.callLater(statsPage.refreshChartData)
    }
}
