import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

Page {
    id: page
    padding: 0
    font.family: Theme.fontFamilyUi

    property StackLayout stackLayout: null
    property var trainingProgress: ({})

    background: BrandedBackground { anchors.fill: parent }

    function refreshTraining() {
        trainingProgress = trainingStore.loadProgress()
    }

    Connections {
        target: trainingStore
        function onProgressChanged() {
            page.refreshTraining()
        }
        function onTrainerAutoAdvanceMsChanged() {
            delaySecSpin.value = Math.round(trainingStore.trainerAutoAdvanceMs / 1000)
        }
    }

    function go(idx) {
        if (stackLayout)
            stackLayout.currentIndex = idx
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
                id: mainCol
                Layout.preferredWidth: Math.min(Theme.trainerContentMaxWidth, Math.max(280, scrollView.availableWidth - 40))
                Layout.maximumWidth: Theme.trainerContentMaxWidth
                spacing: Theme.trainerColumnSpacing

                Label {
                    Layout.fillWidth: true
                    text: qsTr("Training")
                    font.pointSize: Theme.trainerTitlePt
                    font.bold: true
                    color: Theme.gold
                    horizontalAlignment: Text.AlignHCenter
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr(
                        "You get a random hand (preflop) or a fixed flop spot. Choose an action; the app compares it to the loaded strategy and shows a grade. "
                        + "After a short pause the next question appears (delay is configurable below). Decisions, accuracy, and flop EV loss roll up in Training progress below.")
                    color: Theme.textSecondary
                    font.pixelSize: Theme.trainerBodyPx
                    lineHeight: 1.25
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: progressCol.implicitHeight + 2 * Theme.trainerPanelPadding
                    radius: Theme.trainerPanelRadius
                    color: Qt.alpha(Theme.panel, 0.5)
                    border.width: 1
                    border.color: Qt.alpha(Theme.chromeLine, 0.5)

                    ColumnLayout {
                        id: progressCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.trainerPanelPadding
                        spacing: Theme.uiGroupInnerSpacing

                        Label {
                            Layout.fillWidth: true
                            text: qsTr("Training progress")
                            font.bold: true
                            font.pixelSize: Theme.trainerSectionPx
                            color: Theme.textPrimary
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: qsTr(
                                "Counts every trainer answer. Accuracy is the share graded “Correct” (frequency ≥70% in the loaded strategy). "
                                + "EV lost adds flop EV gaps in big blinds vs the best line; preflop rows add 0 EV here. Reset clears stats but keeps your auto-advance delay.")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.trainerBodyPx
                            lineHeight: 1.25
                        }

                        readonly property int totalD: Number(page.trainingProgress.totalDecisions || 0)
                        readonly property int totalC: Number(page.trainingProgress.totalCorrect || 0)
                        readonly property real totalEv: Number(page.trainingProgress.totalEvLossBb || 0)
                        readonly property real accPct: totalD > 0 ? (100.0 * totalC / totalD) : 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.uiGroupInnerSpacing

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
                                    Text { text: String(progressCol.totalD); color: Theme.textPrimary; font.bold: true; font.pixelSize: Theme.trainerMetricValuePx }
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
                                    Text { text: progressCol.accPct.toFixed(1) + "%"; color: Theme.textPrimary; font.bold: true; font.pixelSize: Theme.trainerMetricValuePx }
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
                                    Text { text: progressCol.totalEv.toFixed(3) + " bb"; color: Theme.textPrimary; font.bold: true; font.pixelSize: Theme.trainerMetricValuePx }
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

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: scoringCol.implicitHeight + 2 * Theme.trainerPanelPadding
                    radius: Theme.trainerPanelRadius
                    color: Qt.alpha(Theme.panel, 0.45)
                    border.width: 1
                    border.color: Qt.alpha(Theme.chromeLine, 0.45)

                    ColumnLayout {
                        id: scoringCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.trainerPanelPadding
                        spacing: 8

                        Label {
                            Layout.fillWidth: true
                            text: qsTr("How scoring works")
                            font.bold: true
                            font.pixelSize: Theme.trainerSectionPx
                            color: Theme.textPrimary
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: qsTr(
                                "Each action has a target frequency for that exact hand or spot (from the JSON strategy). Your pick is graded from that frequency:\n"
                                + "• Correct — frequency is at least 70%\n"
                                + "• Mix — between 5% and 70% (reasonable part of a mixed strategy)\n"
                                + "• Wrong — below 5%\n\n"
                                + "Preflop: weights come from the 13×13 chart for your position and mode. The “best” line is whichever action has the highest weight for this hand.\n\n"
                                + "Flop: each option has a model EV in big blinds; EV loss is how far below the best EV your choice is. That loss is summed in your progress.")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.trainerBodyPx
                            lineHeight: 1.25
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 14

                    Label {
                        text: qsTr("Delay after answer")
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
                        onValueModified: trainingStore.trainerAutoAdvanceMs = value * 1000
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.trainerDrillHudSpacing
                        HudButton {
                            label: qsTr("Preflop")
                            pillWidth: 100
                            buttonColor: Theme.successGreen
                            textColor: "white"
                            fontSize: Theme.uiHudButtonPt
                            onClicked: page.go(6)
                        }
                        HudButton {
                            label: qsTr("Flop")
                            pillWidth: 88
                            buttonColor: Theme.successGreen
                            textColor: "white"
                            fontSize: Theme.uiHudButtonPt
                            onClicked: page.go(7)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: comingCol.implicitHeight + 2 * Theme.trainerPanelPadding
                    radius: Theme.trainerPanelRadius
                    color: Qt.alpha(Theme.panel, 0.55)
                    border.width: 1
                    border.color: Qt.alpha(Theme.chromeLine, 0.55)

                    ColumnLayout {
                        id: comingCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.trainerPanelPadding
                        spacing: 8

                        Label {
                            Layout.fillWidth: true
                            text: qsTr("Coming next")
                            color: Theme.textPrimary
                            font.bold: true
                            font.pixelSize: Theme.trainerSectionPx
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: qsTr(
                                "Roadmap: more positions and sizings, turn/river spots, range viewer, and optional play vs a bot. "
                                + "Current drills use bundled example strategies — replace the JSON to train your own charts.")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.trainerBodyPx
                            lineHeight: 1.25
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

    Component.onCompleted: {
        delaySecSpin.value = Math.round(trainingStore.trainerAutoAdvanceMs / 1000)
        page.refreshTraining()
    }
}
