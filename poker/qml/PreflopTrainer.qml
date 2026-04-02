import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

Page {
    id: page
    padding: 0

    property StackLayout stackLayout: null

    property string position: "BTN"
    property string mode: "open"
    property string card1: ""
    property string card2: ""
    property string statusLine: qsTr("Load ranges and start a drill.")
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
                page.nextQuestion()
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
        const ok = trainer.loadPreflopRanges("qrc:/assets/training/preflop_ranges_v1.json")
        statusLine = ok ? qsTr("Ready.") : qsTr("Could not load ranges.")
        trainer.startPreflopDrill(position, mode)
        nextQuestion()
    }

    function nextQuestion() {
        cancelPendingAdvance()
        const q = trainer.nextPreflopQuestion()
        if (q.error !== undefined) {
            statusLine = String(q.error)
            return
        }
        position = String(q.position)
        mode = String(q.mode)
        card1 = String(q.card1)
        card2 = String(q.card2)
        statusLine = qsTr("%1 (%2)").arg(position).arg(mode)
    }

    function submit(a) {
        const r = trainer.submitPreflopAnswer(a, 0)
        if (r.error !== undefined) {
            statusLine = String(r.error)
            return
        }
        const grade = String(r.grade)
        const freq = Number(r.chosenFreq)
        const best = String(r.bestAction)
        statusLine = qsTr("%1 — %2 (%3%) · best: %4").arg(position).arg(grade).arg(Math.round(freq * 100)).arg(best)
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
                        text: qsTr("Preflop")
                        font.pointSize: Theme.trainerPageHeadlinePt
                        font.bold: true
                        color: Theme.gold
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

                    Label {
                        text: qsTr("Pos")
                        color: Theme.textMuted
                        font.pixelSize: Theme.trainerCaptionPx
                    }
                    ComboBox {
                        id: posPick
                        font.pixelSize: Theme.trainerCaptionPx
                        Layout.preferredWidth: 100
                        enabled: !page.inputLocked
                        model: ["UTG", "CO", "BTN", "SB", "BB"]
                        currentIndex: model.indexOf(page.position)
                        onActivated: function (index) {
                            cancelPendingAdvance()
                            page.position = String(model[index])
                            trainer.startPreflopDrill(page.position, page.mode)
                            page.nextQuestion()
                        }
                    }

                    ComboBox {
                        id: modePick
                        font.pixelSize: Theme.trainerCaptionPx
                        Layout.preferredWidth: 96
                        model: ["open"]
                        currentIndex: 0
                        enabled: false
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
                        "Random two cards each hand. Your choice is scored against the 13×13 weights for the position/mode (see JSON). "
                        + "Grade uses that action’s frequency: ≥70% Correct, ≥5% Mix, else Wrong. Feedback shows the highest-weight action as “best”. "
                        + "Changing position reloads the scenario; use Training picks to leave.")
                    color: Theme.textSecondary
                    font.pixelSize: Theme.trainerBodyMutedPx
                    lineHeight: 1.3
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: drillCol.implicitHeight + 2 * Theme.trainerPanelPadding
                    radius: Theme.trainerPanelRadius
                    color: Qt.alpha(Theme.panel, 0.6)
                    border.width: 1
                    border.color: Qt.alpha(Theme.chromeLine, 0.55)

                    ColumnLayout {
                        id: drillCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.trainerPanelPadding
                        spacing: 10

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8

                            Card {
                                width: Theme.boardCardWidth
                                height: Theme.boardCardHeight
                                card: page.card1
                                flipped: true
                            }
                            Card {
                                width: Theme.boardCardWidth
                                height: Theme.boardCardHeight
                                card: page.card2
                                flipped: true
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
                                text: qsTr("Fold")
                                padding: Theme.trainerButtonPadding
                                font.pixelSize: Theme.trainerCaptionPx
                                onClicked: page.submit("fold")
                            }
                            Button {
                                enabled: !page.inputLocked
                                text: qsTr("Call")
                                padding: Theme.trainerButtonPadding
                                font.pixelSize: Theme.trainerCaptionPx
                                onClicked: page.submit("call")
                            }
                            Button {
                                enabled: !page.inputLocked
                                text: qsTr("Raise")
                                highlighted: true
                                padding: Theme.trainerButtonPadding
                                font.pixelSize: Theme.trainerCaptionPx
                                onClicked: page.submit("raise")
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
