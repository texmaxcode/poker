import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

Page {
    id: page
    padding: 0

    property StackLayout stackLayout: null

    property string statusLine: qsTr("Starting…")
    property string board0: ""
    property string board1: ""
    property string board2: ""
    property string hero1: ""
    property string hero2: ""
    property string spotId: ""
    property bool inputLocked: false
    property int secLeft: 0

    background: BrandedBackground { anchors.fill: parent }

    Timer {
        id: secTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            secLeft--
            if (secLeft <= 0) {
                running = false
                page.inputLocked = false
                page.next()
            }
        }
    }

    function cancelPendingAdvance() {
        secTimer.stop()
        secLeft = 0
        inputLocked = false
    }

    function startAutoAdvance() {
        secTimer.stop()
        inputLocked = true
        const ms = trainingStore.trainerAutoAdvanceMs
        secLeft = Math.max(1, Math.ceil(ms / 1000))
        secTimer.start()
    }

    function goTrainingHome() {
        cancelPendingAdvance()
        if (stackLayout)
            stackLayout.currentIndex = 5
    }

    Component.onCompleted: {
        delaySecSpin.value = Math.round(trainingStore.trainerAutoAdvanceMs / 1000)
        const ok = trainer.loadFlopSpots("qrc:/assets/training/spots_v1.json")
        trainer.startFlopDrill("srp_btn_bb")
        if (!ok) {
            statusLine = qsTr("Could not load flop spots.")
            return
        }
        next()
    }

    function next() {
        cancelPendingAdvance()
        const q = trainer.nextFlopQuestion()
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
        statusLine = qsTr("Spot %1").arg(spotId)
    }

    function submit(a) {
        const r = trainer.submitFlopAnswer(a)
        if (r.error !== undefined) {
            statusLine = String(r.error)
            return
        }
        statusLine = qsTr("%1 — %2 (freq %3%) · EV loss %4 bb")
                .arg(spotId)
                .arg(String(r.grade))
                .arg(Math.round(Number(r.chosenFreq) * 100))
                .arg(Number(r.evLossBb).toFixed(3))
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
                Layout.preferredWidth: Math.min(Theme.trainerContentMaxWidth, Math.max(280, scrollView.availableWidth - 32))
                Layout.maximumWidth: Theme.trainerContentMaxWidth
                spacing: Theme.trainerColumnSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ToolButton {
                        text: qsTr("Training picks")
                        flat: true
                        font.pixelSize: Theme.trainerToolButtonPx
                        leftPadding: 8
                        rightPadding: 12
                        onClicked: page.goTrainingHome()
                    }

                    Label {
                        text: qsTr("Flop (BTN vs BB)")
                        color: Theme.gold
                        font.pointSize: Theme.trainerPageHeadlinePt
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

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
                        onValueModified: trainingStore.setTrainerAutoAdvanceMs(value * 1000)
                    }

                    Item { Layout.fillWidth: true }
                }

                Connections {
                    target: trainingStore
                    function onTrainerAutoAdvanceMsChanged() {
                        delaySecSpin.value = Math.round(trainingStore.trainerAutoAdvanceMs / 1000)
                    }
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr(
                        "Single raised pot, flop only. Spots cycle in file order. Check, or bet 33% / 75% pot — same grading bands from strategy frequency; "
                        + "EV loss (bb) vs the best option is tracked in progress. Bundled EVs are illustrative; edit spots JSON to match your study material.")
                    color: Theme.textSecondary
                    font.pixelSize: Theme.trainerBodyMutedPx
                    lineHeight: 1.3
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: flopCol.implicitHeight + 2 * Theme.trainerPanelPadding
                    radius: Theme.trainerPanelRadius
                    color: Qt.alpha(Theme.panel, 0.6)
                    border.width: 1
                    border.color: Qt.alpha(Theme.chromeLine, 0.55)

                    ColumnLayout {
                        id: flopCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.trainerPanelPadding
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 10

                            Card {
                                width: Theme.boardCardWidth
                                height: Theme.boardCardHeight
                                card: hero1
                                flipped: true
                            }
                            Card {
                                width: Theme.boardCardWidth
                                height: Theme.boardCardHeight
                                card: hero2
                                flipped: true
                            }

                            Rectangle {
                                width: 2
                                height: Theme.boardCardHeight
                                color: Qt.alpha(Theme.chromeLine, 0.35)
                            }

                            Card {
                                width: Theme.boardCardWidth
                                height: Theme.boardCardHeight
                                card: board0
                                flipped: true
                                tableCard: true
                            }
                            Card {
                                width: Theme.boardCardWidth
                                height: Theme.boardCardHeight
                                card: board1
                                flipped: true
                                tableCard: true
                            }
                            Card {
                                width: Theme.boardCardWidth
                                height: Theme.boardCardHeight
                                card: board2
                                flipped: true
                                tableCard: true
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: page.secLeft > 0
                                    ? page.statusLine + "\n" + qsTr("Next hand in %1 s").arg(page.secLeft)
                                    : page.statusLine
                            color: Theme.textPrimary
                            font.pixelSize: Theme.trainerStatusPx
                            lineHeight: 1.25
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 10

                            Button {
                                enabled: !page.inputLocked
                                text: qsTr("Check")
                                padding: Theme.trainerButtonPadding
                                font.pixelSize: Theme.trainerCaptionPx
                                onClicked: page.submit("check")
                            }
                            Button {
                                enabled: !page.inputLocked
                                text: qsTr("Bet 33%")
                                highlighted: true
                                padding: Theme.trainerButtonPadding
                                font.pixelSize: Theme.trainerCaptionPx
                                onClicked: page.submit("bet33")
                            }
                            Button {
                                enabled: !page.inputLocked
                                text: qsTr("Bet 75%")
                                padding: Theme.trainerButtonPadding
                                font.pixelSize: Theme.trainerCaptionPx
                                onClicked: page.submit("bet75")
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
