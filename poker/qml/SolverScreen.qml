import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: solverPage
    padding: 16

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Equity simulator: Monte Carlo showdown equity vs a villain range or exact cards. Pot-odds / chip-EV compares your equity to the break-even threshold for calling. Full no-limit GTO for arbitrary trees requires CFR-based solvers (Pio, GTO+, etc.); this panel is a study aid, not a replacement.")
            font.pixelSize: 12
            bottomPadding: 4
        }

        GroupBox {
            title: qsTr("Hand & board")
            Layout.fillWidth: true
            padding: 14
            topPadding: 28

            GridLayout {
                id: inputGrid
                width: parent.width
                columns: 2
                columnSpacing: 16
                rowSpacing: 12

                Label {
                    text: qsTr("Hero card 1")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                TextField {
                    id: h1
                    placeholderText: "Ah"
                    text: "Ah"
                    Layout.fillWidth: true
                }
                Label {
                    text: qsTr("Hero card 2")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                TextField {
                    id: h2
                    placeholderText: "Kd"
                    text: "Kd"
                    Layout.fillWidth: true
                }
                Label {
                    text: qsTr("Board (optional)")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                TextField {
                    id: brd
                    placeholderText: "Qs Jh 2c or empty"
                    Layout.fillWidth: true
                }
                Label {
                    text: qsTr("Villain range")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                TextField {
                    id: vrange
                    placeholderText: "AA,AKs,QQ+"
                    text: "AA,TT+,AKs,AKo"
                    Layout.fillWidth: true
                }
                Label {
                    text: qsTr("Villain exact (optional)")
                    Layout.alignment: Qt.AlignRight | Qt.AlignTop
                    Layout.topMargin: 6
                }
                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true
                    TextField {
                        id: ve1
                        placeholderText: "Qs"
                        Layout.fillWidth: true
                    }
                    TextField {
                        id: ve2
                        placeholderText: "Jh"
                        Layout.fillWidth: true
                    }
                }
            }
        }

        GroupBox {
            title: qsTr("Simulation & pot odds")
            Layout.fillWidth: true
            padding: 14
            topPadding: 28

            GridLayout {
                width: parent.width
                columns: 2
                columnSpacing: 16
                rowSpacing: 12

                Label {
                    text: qsTr("Iterations")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                SpinBox {
                    id: iters
                    from: 1000
                    to: 2000000
                    value: 40000
                    stepSize: 1000
                    editable: true
                    Layout.fillWidth: true
                }
                Label {
                    text: qsTr("Pot before your call")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                SpinBox {
                    id: potSpin
                    from: 0
                    to: 100000
                    value: 100
                    editable: true
                    Layout.fillWidth: true
                }
                Label {
                    text: qsTr("To call")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                SpinBox {
                    id: callSpin
                    from: 0
                    to: 100000
                    value: 50
                    editable: true
                    Layout.fillWidth: true
                }
            }
        }

        Button {
            text: qsTr("Run simulation")
            Layout.preferredWidth: 200
            onClicked: {
                resultArea.text = qsTr("Running…")
                const m = pokerSolver.computeEquity(
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

        TextArea {
            id: resultArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 180
            readOnly: true
            wrapMode: TextArea.Wrap
            font.family: "monospace"
            font.pixelSize: 11
            text: qsTr('Set cards and click "Run simulation". Use Ah Kd Th style (T = ten).')
            padding: 12
            background: Rectangle {
                color: "#fafafa"
                border.color: "#ddd"
                radius: 8
            }
        }
    }
}
