import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

/// Session bankroll, leaderboard, and stack-over-time chart.
Page {
    id: statsPage
    padding: 0

    BotNames {
        id: botNames
    }

    background: BrandedBackground {
        anchors.fill: parent
    }

    readonly property var lineColors: Theme.chartLineColors
    property var trainingProgress: ({})

    function refreshChart() {
        bankCanvas.requestPaint()
    }

    function refreshTraining() {
        trainingProgress = trainingStore.loadProgress()
    }

    Connections {
        target: trainingStore
        function onProgressChanged() {
            statsPage.refreshTraining()
        }
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
            width: Math.max(320, scrollView.width > 0 ? scrollView.width - 28 : statsPage.width - 28)
            spacing: 14

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr(
                    "Starting bankroll applies to everyone when you apply settings (same as Bots & ranges). "
                    + "The chart records stack size after each completed hand. Reset session re-baselines profit from current stacks.")
                font.pixelSize: Theme.uiBodyPx
                color: Theme.textSecondary
            }

            GroupBox {
                title: qsTr("Session bankroll (starting stack)")
                Layout.fillWidth: true
                padding: 8
                topPadding: 22
                font.bold: true
                font.pointSize: Theme.uiGroupTitlePt

                RowLayout {
                    width: parent.width - 8
                    spacing: 12

                    Label {
                        text: qsTr("Chips per player")
                    }
                    SpinBox {
                        id: bankSpin
                        from: 20
                        to: 1000000
                        value: 100
                        editable: true
                    }
                    Button {
                        text: qsTr("Apply bankroll")
                        onClicked: {
                            pokerGame.configure(
                                pokerGame.configuredSmallBlind(),
                                pokerGame.configuredBigBlind(),
                                pokerGame.configuredStreetBet(),
                                bankSpin.value)
                            pokerGame.savePersistedSettings()
                            statsPage.refreshChart()
                        }
                    }
                }
            }

            GroupBox {
                title: qsTr("Leaderboard")
                Layout.fillWidth: true
                padding: 8
                topPadding: 22
                font.bold: true
                font.pointSize: Theme.uiGroupTitlePt

                ColumnLayout {
                    width: parent.width - 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: qsTr("Rank")
                            font.bold: true
                            Layout.preferredWidth: 44
                        }
                        Label {
                            text: qsTr("Player")
                            font.bold: true
                            Layout.preferredWidth: 120
                        }
                        Label {
                            text: qsTr("Total")
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Label {
                            text: qsTr("P/L")
                            font.bold: true
                            Layout.preferredWidth: 72
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
                            }
                            Label {
                                text: botNames.displayName(modelData.seat)
                                Layout.preferredWidth: 120
                                color: Theme.textPrimary
                            }
                            Label {
                                text: "$" + (modelData.total !== undefined ? modelData.total : modelData.stack)
                                Layout.fillWidth: true
                                color: Theme.textSecondary
                            }
                            Label {
                                text: (modelData.profit >= 0 ? "+" : "") + modelData.profit
                                Layout.preferredWidth: 72
                                color: modelData.profit >= 0 ? Theme.profitUp : Theme.profitDown
                            }
                        }
                    }
                }
            }

            GroupBox {
                title: qsTr("Bankroll over hands")
                Layout.fillWidth: true
                padding: 8
                topPadding: 22
                font.bold: true
                font.pointSize: Theme.uiGroupTitlePt

                ColumnLayout {
                    width: parent.width - 8
                    spacing: 8

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
                                    radius: 2
                                    color: statsPage.lineColors[index]
                                }
                                Label {
                                    text: botNames.displayName(index)
                                    font.pixelSize: Theme.uiChartLegendPx
                                    color: Theme.textMuted
                                }
                            }
                        }
                    }

                    Canvas {
                        id: bankCanvas
                        Layout.fillWidth: true
                        Layout.preferredHeight: 320
                        renderTarget: Canvas.FramebufferObject
                        renderStrategy: Canvas.Cooperative

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

                            var padL = 38
                            var padR = 12
                            var padT = 10
                            var padB = 28
                            var plotW = w - padL - padR
                            var plotH = h - padT - padB

                            ctx.strokeStyle = Theme.chartGridLine
                            ctx.lineWidth = 1
                            ctx.beginPath()
                            ctx.moveTo(padL, padT)
                            ctx.lineTo(padL, padT + plotH)
                            ctx.lineTo(padL + plotW, padT + plotH)
                            ctx.stroke()

                            ctx.fillStyle = Theme.chartAxisText
                            ctx.font = Theme.uiChartCanvasPx + "px sans-serif"
                            ctx.fillText("0", 4, padT + plotH + 4)
                            ctx.fillText(String(maxY), 4, padT + 10)

                            function xAt(i) {
                                if (nSnap <= 1)
                                    return padL + plotW * 0.5
                                return padL + i * plotW / (nSnap - 1)
                            }
                            function yAt(stack) {
                                return padT + plotH - stack / maxY * plotH
                            }

                            for (s = 0; s < 6; s++) {
                                var series = pokerGame.bankrollSeries(s)
                                if (series.length < 1)
                                    continue
                                ctx.strokeStyle = statsPage.lineColors[s]
                                ctx.lineWidth = 2
                                ctx.beginPath()
                                for (var i = 0; i < series.length; i++) {
                                    var px = xAt(i)
                                    var py = yAt(series[i])
                                    if (i === 0)
                                        ctx.moveTo(px, py)
                                    else
                                        ctx.lineTo(px, py)
                                }
                                ctx.stroke()
                            }
                        }
                    }

                    Button {
                        text: qsTr("Reset chart & profit baseline")
                        flat: true
                        onClicked: {
                            pokerGame.resetBankrollSession()
                            statsPage.refreshChart()
                        }
                    }
                }
            }

            GroupBox {
                title: qsTr("Training progress")
                Layout.fillWidth: true
                padding: 10
                topPadding: 24
                font.bold: true
                font.pointSize: Theme.trainerGroupTitlePt

                ColumnLayout {
                    id: trainingProgressCol
                    width: parent.width - 8
                    spacing: 12

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: qsTr(
                            "Counts every trainer answer. Accuracy is the share graded “Correct” (frequency ≥70% in the loaded strategy). "
                            + "EV lost adds flop EV gaps in big blinds vs the best line; preflop rows add 0 EV here. Reset clears stats but keeps your auto-advance delay.")
                        color: Theme.textSecondary
                        font.pixelSize: Theme.trainerBodyPx
                        lineHeight: 1.3
                    }

                    readonly property int totalD: Number(statsPage.trainingProgress.totalDecisions || 0)
                    readonly property int totalC: Number(statsPage.trainingProgress.totalCorrect || 0)
                    readonly property real totalEv: Number(statsPage.trainingProgress.totalEvLossBb || 0)
                    readonly property real accPct: totalD > 0 ? (100.0 * totalC / totalD) : 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: trainingMetricsCol.implicitHeight + 22
                            radius: 10
                            color: Theme.panelElevated
                            border.width: 1
                            border.color: Qt.alpha(Theme.chromeLine, 0.55)
                            Column {
                                id: trainingMetricsCol
                                x: 10
                                y: 10
                                width: parent.width - 20
                                spacing: 4
                                Text { text: qsTr("Decisions"); color: Theme.textMuted; font.pixelSize: Theme.trainerMetricLabelPx }
                                Text { text: String(trainingProgressCol.totalD); color: Theme.textPrimary; font.bold: true; font.pixelSize: Theme.trainerMetricValuePx }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: trainingAccCol.implicitHeight + 22
                            radius: 10
                            color: Theme.panelElevated
                            border.width: 1
                            border.color: Qt.alpha(Theme.chromeLine, 0.55)
                            Column {
                                id: trainingAccCol
                                x: 10
                                y: 10
                                width: parent.width - 20
                                spacing: 4
                                Text { text: qsTr("Accuracy"); color: Theme.textMuted; font.pixelSize: Theme.trainerMetricLabelPx }
                                Text { text: trainingProgressCol.accPct.toFixed(1) + "%"; color: Theme.textPrimary; font.bold: true; font.pixelSize: Theme.trainerMetricValuePx }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: trainingEvCol.implicitHeight + 22
                            radius: 10
                            color: Theme.panelElevated
                            border.width: 1
                            border.color: Qt.alpha(Theme.chromeLine, 0.55)
                            Column {
                                id: trainingEvCol
                                x: 10
                                y: 10
                                width: parent.width - 20
                                spacing: 4
                                Text { text: qsTr("EV lost"); color: Theme.textMuted; font.pixelSize: Theme.trainerMetricLabelPx }
                                Text { text: trainingProgressCol.totalEv.toFixed(3) + " bb"; color: Theme.textPrimary; font.bold: true; font.pixelSize: Theme.trainerMetricValuePx }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Button {
                            text: qsTr("Reset training progress")
                            font.pixelSize: Theme.trainerCaptionPx
                            padding: Theme.trainerButtonPadding
                            onClicked: trainingStore.resetProgress()
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }

    Connections {
        target: pokerGame
        function onSessionStatsChanged() {
            rankRepeater.model = pokerGame.seatRankings()
            statsPage.refreshChart()
        }
    }

    Component.onCompleted: {
        refreshTraining()
        bankSpin.value = pokerGame.configuredStartStack()
        Qt.callLater(refreshChart)
    }
}
