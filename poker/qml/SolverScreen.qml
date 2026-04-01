import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: solverPage
    padding: 0

    property bool simRunning: false

    background: Rectangle {
        color: "#08080a"
    }

    palette {
        base: "#1a1c24"
        alternateBase: "#15161c"
        text: "#e4e6ee"
        window: "#12131a"
        button: "#2a2d38"
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
                        resultArea.text = m["error"]
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
                        t += qsTr("MDF heuristic (~defense freq vs this bet): ") + m.mdfPct.toFixed(1) + " %\n"
                    t += "\n" + m.detailText
                    resultArea.text = t
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
                    color: "#a8aab8"

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
                            resultArea.text = qsTr("Running simulation on a background thread…")
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
                        color: "#c9a227"
                        font.pixelSize: 12
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                TextArea {
                    id: resultArea
                    Layout.fillWidth: true
                    Layout.minimumHeight: 200
                    Layout.preferredHeight: 260
                    readOnly: true
                    wrapMode: TextArea.Wrap
                    font.family: "monospace"
                    font.pixelSize: 11
                    color: "#e8ead8"
                    text: qsTr("Results appear here. Card tokens: Ah Kd Th (T = ten).")
                    padding: 12
                    background: Rectangle {
                        color: "#0e0f14"
                        border.color: "#3d2818"
                        border.width: 1
                        radius: 8
                    }

                    HoverHandler {
                        id: resultAreaHover
                    }
                    ToolTip.visible: resultAreaHover.hovered
                    ToolTip.delay: 500
                    ToolTip.text: qsTr(
                        "Enter hero cards, optional board, villain range text (same syntax as Bots & ranges) "
                        + "or two exact villain cards. Set iterations and pot / call for pot-odds. "
                        + "Click Run simulation — equity runs in the background; large runs may take a few seconds.")
                }
            }
        }
}
