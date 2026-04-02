import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

Page {
    id: solverPage
    padding: 0

    property bool simRunning: false
    /// Full text from last run (equity block + detailText); shown in the log dialog.
    property string lastFullLog: ""
    /// Short lines for the main panel (spot + key numbers).
    property string summaryText: qsTr("Run a simulation for a brief summary. Open Full log for the complete output.")

    function applySavedSolver(m) {
        if (m.hero1 !== undefined && m.hero1.length > 0)
            h1.text = m.hero1
        if (m.hero2 !== undefined && m.hero2.length > 0)
            h2.text = m.hero2
        if (m.board !== undefined)
            brd.text = m.board
        if (m.villainRange !== undefined && m.villainRange.length > 0)
            vrange.text = m.villainRange
        if (m.villainE1 !== undefined)
            ve1.text = m.villainE1
        if (m.villainE2 !== undefined)
            ve2.text = m.villainE2
        if (m.iterations !== undefined)
            iters.value = m.iterations
        if (m.potBeforeCall !== undefined)
            potSpin.value = m.potBeforeCall
        if (m.toCall !== undefined)
            callSpin.value = m.toCall
    }

    Component.onCompleted: Qt.callLater(function () {
        applySavedSolver(sessionStore.loadSolverFields())
    })

    TextEdit {
        id: clipBuffer
        visible: false
        height: 1
        width: 1
        text: ""
    }

    Popup {
        id: fullLogPopup
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
            anchors.margins: 10
            spacing: 8

            Label {
                text: qsTr("Simulation log")
                font.bold: true
                font.pointSize: 12
                color: Theme.gold
            }

            ScrollView {
                id: logScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 200
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                TextArea {
                    id: logTextArea
                    width: logScroll.availableWidth
                    readOnly: true
                    wrapMode: TextArea.Wrap
                    font.family: "monospace"
                    font.pixelSize: 10
                    color: Theme.textPrimary
                    text: solverPage.lastFullLog
                    padding: 10
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
                onClicked: fullLogPopup.close()
            }
        }
    }

    background: BrandedBackground {
        anchors.fill: parent
    }

    palette {
        base: Theme.panelElevated
        alternateBase: Theme.panel
        text: Theme.textPrimary
        window: Theme.headerBg
        button: Theme.inputBg
    }

    Connections {
        target: ApplicationWindow.window
        function onClosing(close) {
            sessionStore.saveSolverFields({
                "hero1": h1.text,
                "hero2": h2.text,
                "board": brd.text,
                "villainRange": vrange.text,
                "villainE1": ve1.text,
                "villainE2": ve2.text,
                "iterations": iters.value,
                "potBeforeCall": potSpin.value,
                "toCall": callSpin.value
            })
        }
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: solverCol
            width: Math.max(280, scroll.width - 24)
            spacing: 10

            Connections {
                target: pokerSolver
                function onEquityComputationFinished(m) {
                    solverPage.simRunning = false
                    if (m["error"] !== undefined && String(m["error"]).length > 0) {
                        const err = String(m["error"])
                        solverPage.lastFullLog = err
                        solverPage.summaryText = err
                        return
                    }
                    let t = ""
                    t += qsTr("Equity: ") + m.equityPct.toFixed(2) + " %"
                    t += "  (± ~" + m.stdErrPct.toFixed(2) + " % 1σ)\n"
                    t += qsTr("Iterations: ") + m.iterations + "\n"
                    if (m.breakEvenPct !== undefined) {
                        t += qsTr("Break-even equity to call: ") + m.breakEvenPct.toFixed(2) + " %\n"
                        t += qsTr("EV of call: ") + m.evCall.toFixed(3) + "\n"
                        t += qsTr("Suggestion: ") + m.recommendation + "\n"
                    }
                    if (m.mdfPct !== undefined)
                        t += qsTr("MDF heuristic (~defense freq vs this raise): ") + m.mdfPct.toFixed(1) + " %\n"
                    t += "\n" + m.detailText
                    solverPage.lastFullLog = t

                    let s = ""
                    s += h1.text + " " + h2.text
                    if (brd.text.trim().length > 0)
                        s += " · " + brd.text.trim()
                    s += "\n"
                    s += qsTr("Equity ") + m.equityPct.toFixed(2) + "% (±" + m.stdErrPct.toFixed(2) + "%) · "
                            + m.iterations + " " + qsTr("iters")
                    if (m.breakEvenPct !== undefined) {
                        s += "\n" + qsTr("BE ") + m.breakEvenPct.toFixed(1) + "% · EV " + m.evCall.toFixed(3)
                                + " · " + m.recommendation
                    }
                    if (m.mdfPct !== undefined)
                        s += "\n" + qsTr("MDF ~") + m.mdfPct.toFixed(1) + "%"
                    solverPage.summaryText = s
                }
            }

                Label {
                    Layout.topMargin: 8
                    Layout.fillWidth: true
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    text: qsTr("Monte Carlo equity vs range or exact cards — pot odds & chip-EV (not full GTO).")
                    font.pixelSize: 12
                    color: Theme.textSecondary

                    HoverHandler {
                        id: solverIntroHover
                    }
                    ToolTip.visible: solverIntroHover.hovered
                    ToolTip.delay: 400
                    ToolTip.text: qsTr(
                        "Monte Carlo estimates equity against a villain range (or two exact hole cards). "
                        + "Pot odds and chip-EV lines are study aids for calling decisions — not a multi-street "
                        + "Nash solution; use dedicated solvers (Pio, GTO+, etc.) for full GTO trees.")
                }

                GroupBox {
                    title: qsTr("Hand & board")
                    Layout.fillWidth: true
                    padding: 8
                    topPadding: 20
                    font.bold: true
                    font.pointSize: 11

                    GridLayout {
                        width: parent.width - 16
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 6

                        Label {
                            text: qsTr("Hero card 1")
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.maximumWidth: 120
                        }
                        TextField {
                            id: h1
                            placeholderText: "Ah"
                            text: "Ah"
                            Layout.maximumWidth: 100
                            implicitWidth: 100
                        }
                        Label {
                            text: qsTr("Hero card 2")
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        }
                        TextField {
                            id: h2
                            placeholderText: "Kd"
                            text: "Kd"
                            Layout.maximumWidth: 100
                            implicitWidth: 100
                        }
                        Label {
                            text: qsTr("Board (optional)")
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        }
                        TextField {
                            id: brd
                            placeholderText: "Qs Jh 2c or empty"
                            Layout.fillWidth: true
                            Layout.maximumWidth: 560
                        }
                        Label {
                            text: qsTr("Villain range")
                            Layout.alignment: Qt.AlignRight | Qt.AlignTop
                        }
                        TextField {
                            id: vrange
                            placeholderText: "AA,AKs,QQ+"
                            text: "AA,TT+,AKs,AKo"
                            Layout.fillWidth: true
                            Layout.maximumWidth: 560
                        }
                        Label {
                            text: qsTr("Villain exact")
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        }
                        RowLayout {
                            spacing: 8
                            TextField {
                                id: ve1
                                placeholderText: "Qs"
                                Layout.preferredWidth: 88
                                implicitWidth: 88
                            }
                            TextField {
                                id: ve2
                                placeholderText: "Jh"
                                Layout.preferredWidth: 88
                                implicitWidth: 88
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                GroupBox {
                    title: qsTr("Simulation & pot odds")
                    Layout.fillWidth: true
                    padding: 8
                    topPadding: 20
                    font.bold: true
                    font.pointSize: 11

                    GridLayout {
                        width: parent.width - 16
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 6

                        Label {
                            text: qsTr("Iterations")
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        }
                        SpinBox {
                            id: iters
                            from: 1000
                            to: 2000000
                            value: 40000
                            stepSize: 1000
                            editable: true
                            Layout.maximumWidth: 200
                            implicitWidth: 200
                        }
                        Label {
                            text: qsTr("Pot before call")
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        }
                        SpinBox {
                            id: potSpin
                            from: 0
                            to: 100000
                            value: 100
                            editable: true
                            Layout.maximumWidth: 200
                            implicitWidth: 200
                        }
                        Label {
                            text: qsTr("To call")
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        }
                        SpinBox {
                            id: callSpin
                            from: 0
                            to: 100000
                            value: 50
                            editable: true
                            Layout.maximumWidth: 200
                            implicitWidth: 200
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Button {
                        id: runSimBtn
                        text: qsTr("Run simulation")
                        Layout.preferredWidth: 200
                        highlighted: true
                        enabled: !solverPage.simRunning
                        onClicked: {
                            solverPage.simRunning = true
                            solverPage.summaryText = qsTr("Running simulation on a background thread…")
                            solverPage.lastFullLog = ""
                            pokerSolver.computeEquityAsync(
                                h1.text,
                                h2.text,
                                brd.text,
                                vrange.text,
                                ve1.text,
                                ve2.text,
                                iters.value,
                                potSpin.value,
                                callSpin.value
                            )
                        }
                    }

                    BusyIndicator {
                        visible: solverPage.simRunning
                        running: solverPage.simRunning
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                    }

                    Label {
                        visible: solverPage.simRunning
                        text: qsTr("Working…")
                        color: Theme.focusGold
                        font.pixelSize: 12
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                GroupBox {
                    title: qsTr("Results")
                    Layout.fillWidth: true
                    padding: 8
                    topPadding: 20
                    font.bold: true
                    font.pointSize: 11

                    ColumnLayout {
                        width: parent.width - 8
                        spacing: 8

                        Text {
                            id: summaryLabel
                            Layout.fillWidth: true
                            text: solverPage.summaryText
                            wrapMode: Text.Wrap
                            color: Theme.textPrimary
                            font.pixelSize: 11
                            font.family: "monospace"
                            HoverHandler {
                                id: summaryHover
                            }
                            ToolTip.visible: summaryHover.hovered && solverPage.lastFullLog.length > 0
                            ToolTip.delay: 400
                            ToolTip.text: qsTr("Summary only. Open Full log for equity details, combos, and notes.")
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Button {
                                text: qsTr("Full log…")
                                enabled: solverPage.lastFullLog.length > 0
                                onClicked: fullLogPopup.open()
                            }

                            Button {
                                text: qsTr("Copy log")
                                enabled: solverPage.lastFullLog.length > 0
                                onClicked: {
                                    clipBuffer.text = solverPage.lastFullLog
                                    clipBuffer.forceActiveFocus()
                                    clipBuffer.selectAll()
                                    clipBuffer.copy()
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
}
