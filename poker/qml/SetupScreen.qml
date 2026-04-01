import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: setup
    padding: 0

    background: Rectangle {
        color: "#08080a"
    }

    readonly property int seatColumns: setup.width > 1180 ? 3 : (setup.width > 720 ? 2 : 1)

    readonly property var strategyNames: [
        "Always call (test)",
        "Rock",
        "Nit",
        "Tight–aggressive",
        "Loose–passive",
        "Loose–aggressive",
        "Balanced",
        "Maniac"
    ]

    function reloadGrids() {
        for (var i = 0; i < 6; i++) {
            var box = seatRepeater.itemAt(i)
            if (box && box.rangeGridRef)
                box.rangeGridRef.weights = pokerGame.getRangeGrid(i)
        }
    }

    Component.onCompleted: {
        for (var s = 0; s < 6; s++)
            pokerGame.setSeatStrategy(s, 0)
        reloadGrids()
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
            id: setupColumn
            width: Math.max(300, scrollView.width > 0 ? scrollView.width - 28 : setup.width - 28)
            spacing: 12

            Label {
                Layout.fillWidth: true
                maximumLineCount: 1
                elide: Text.ElideRight
                text: qsTr("Configure stakes, bot strategies, and per-seat ranges.")
                font.pixelSize: 12
                color: "#a8aab8"

                HoverHandler {
                    id: setupIntroHover
                }
                ToolTip.visible: setupIntroHover.hovered
                ToolTip.delay: 400
                ToolTip.text: qsTr(
                    "Six seats: you at seat 1, bots at seats 2–6. Set stakes (SB/BB/street bet/stack), "
                    + "pick a bot archetype per seat, edit range grids or paste range text, then play from the table.")
            }

            GroupBox {
                title: qsTr("Strategy presets (reference)")
                Layout.fillWidth: true
                padding: 8
                topPadding: 22
                font.bold: true
                font.pointSize: 11

                ColumnLayout {
                    width: parent.width - 8
                    spacing: 8

                    Label {
                        Layout.fillWidth: true
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        text: qsTr("Reference: pick an archetype for preset chart & strategy text. Loading a bot type applies that chart to the seat.")
                        font.pixelSize: 10
                        color: "#8a8c98"

                        HoverHandler {
                            id: presetBlurbHover
                        }
                        ToolTip.visible: presetBlurbHover.hovered
                        ToolTip.delay: 400
                        ToolTip.text: qsTr(
                            "Pick a bot archetype to see its default 13×13 chart and full in-engine strategy "
                            + "(preflop/postflop exponents and aggression). Choosing a strategy on a bot seat loads "
                            + "that preset chart into the seat; you can still edit cells or paste range text.")
                    }

                    ComboBox {
                        id: previewStrat
                        model: strategyNames
                        Layout.fillWidth: true
                    }

                    Label {
                        Layout.fillWidth: true
                        Layout.maximumHeight: 56
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 3
                        color: "#c8cad4"
                        font.pixelSize: 10
                        text: pokerGame.getStrategySummary(previewStrat.currentIndex)

                        HoverHandler {
                            id: refSummaryHover
                        }
                        ToolTip.visible: refSummaryHover.hovered
                        ToolTip.delay: 450
                        ToolTip.text: pokerGame.getStrategySummary(previewStrat.currentIndex)
                    }

                    RangeGrid {
                        readOnly: true
                        seatIndex: 0
                        Layout.fillWidth: true
                        weights: pokerGame.getPresetRangeGrid(previewStrat.currentIndex)
                    }
                }
            }

            GroupBox {
                title: qsTr("Table stakes")
                Layout.fillWidth: true
                padding: 8
                topPadding: 20
                font.bold: true
                font.pointSize: 11

                GridLayout {
                    width: parent.width - 8
                    columns: 4
                    rowSpacing: 6
                    columnSpacing: 10

                    Label {
                        text: qsTr("SB")
                    }
                    SpinBox {
                        id: sbSpin
                        from: 1
                        to: 50
                        value: 1
                        editable: true
                    }
                    Label {
                        text: qsTr("BB")
                    }
                    SpinBox {
                        id: bbSpin
                        from: 1
                        to: 100
                        value: 3
                        editable: true
                    }
                    Label {
                        text: qsTr("Street")
                    }
                    SpinBox {
                        id: streetSpin
                        from: 1
                        to: 200
                        value: 9
                        editable: true
                    }
                    Label {
                        text: qsTr("Stack")
                    }
                    SpinBox {
                        id: stackSpin
                        from: 20
                        to: 10000
                        value: 100
                        editable: true
                    }
                    Button {
                        text: qsTr("Apply stakes")
                        Layout.columnSpan: 4
                        onClicked: {
                            pokerGame.configure(sbSpin.value, bbSpin.value, streetSpin.value, stackSpin.value)
                            reloadGrids()
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: setup.seatColumns
                rowSpacing: 10
                columnSpacing: 10

                Repeater {
                    id: seatRepeater
                    model: 6

                    GroupBox {
                        required property int index
                        readonly property RangeGrid rangeGridRef: rng

                        title: index === 0 ? qsTr("Seat 1 — You") : qsTr("Seat %1").arg(index + 1)
                        Layout.fillWidth: true
                        Layout.minimumWidth: 280
                        padding: 8
                        topPadding: 22
                        font.bold: true
                        font.pointSize: 10

                        ColumnLayout {
                            width: parent.width - 4
                            spacing: 6

                            Label {
                                visible: index === 0
                                maximumLineCount: 1
                                elide: Text.ElideRight
                                text: qsTr("Human: play from the table HUD.")
                                Layout.fillWidth: true
                                font.pixelSize: 10
                                color: "#8a8c98"

                                HoverHandler {
                                    id: humanSeatHover
                                }
                                ToolTip.visible: humanSeatHover.hovered
                                ToolTip.delay: 400
                                ToolTip.text: qsTr("Human seat — use the table screen for fold/call/raise and sizing; this grid is optional.")
                            }

                            Label {
                                visible: index > 0
                                text: qsTr("Strategy")
                                font.bold: true
                                font.pixelSize: 10
                            }
                            ComboBox {
                                id: stratCombo
                                visible: index > 0
                                model: strategyNames
                                currentIndex: 0
                                Layout.fillWidth: true
                                onActivated: function (i) {
                                    pokerGame.setSeatStrategy(index, i)
                                    reloadGrids()
                                }
                            }

                            Label {
                                visible: index > 0
                                Layout.fillWidth: true
                                Layout.maximumHeight: 52
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                                maximumLineCount: 3
                                color: "#b8bac8"
                                font.pixelSize: 9
                                text: pokerGame.getStrategySummary(stratCombo.currentIndex)

                                HoverHandler {
                                    id: seatStratHover
                                }
                                ToolTip.visible: seatStratHover.hovered
                                ToolTip.delay: 450
                                ToolTip.text: pokerGame.getStrategySummary(stratCombo.currentIndex)
                            }
                            Label {
                                text: qsTr("Range text")
                                font.pixelSize: 10
                                font.bold: true
                            }
                            TextArea {
                                id: textArea
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                wrapMode: TextArea.Wrap
                                font.pixelSize: 11
                                placeholderText: "AA,AKs,AKo,TT+"
                            }
                            RowLayout {
                                spacing: 4
                                Button {
                                    text: qsTr("Apply")
                                    flat: true
                                    onClicked: {
                                        pokerGame.applySeatRangeText(index, textArea.text)
                                        reloadGrids()
                                    }
                                }
                                Button {
                                    text: qsTr("Export")
                                    flat: true
                                    onClicked: textArea.text = pokerGame.exportSeatRangeText(index)
                                }
                                Button {
                                    text: qsTr("Full")
                                    flat: true
                                    onClicked: {
                                        pokerGame.resetSeatRangeFull(index)
                                        reloadGrids()
                                    }
                                }
                            }
                            RangeGrid {
                                id: rng
                                seatIndex: index
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                            }
                        }
                    }
                }
            }

            Button {
                text: qsTr("Reload grids from engine")
                Layout.alignment: Qt.AlignLeft
                flat: true
                onClicked: reloadGrids()
            }
        }
    }
}
