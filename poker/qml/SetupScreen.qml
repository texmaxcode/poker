import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: setup
    padding: 16

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

        ColumnLayout {
            id: setupColumn
            width: Math.max(320, scrollView.width > 0 ? scrollView.width - 16 : setup.width - 32)
            spacing: 20

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Six seats: you at seat 1, bots at seats 2–6. Configure blinds, per-street bet size, starting stack, bot strategy, and preflop ranges (text or grid). Click cells to cycle weight 0 → ⅓ → ⅔ → 1.")
                bottomPadding: 4
            }

            GroupBox {
                title: qsTr("Table stakes")
                Layout.fillWidth: true
                padding: 14
                topPadding: 28

                GridLayout {
                    width: parent.width
                    columns: 3
                    rowSpacing: 12
                    columnSpacing: 16

                    Label {
                        text: qsTr("Small blind")
                    }
                    SpinBox {
                        id: sbSpin
                        from: 1
                        to: 50
                        value: 1
                        editable: true
                    }
                    Item {
                        Layout.fillWidth: true
                    }

                    Label {
                        text: qsTr("Big blind")
                    }
                    SpinBox {
                        id: bbSpin
                        from: 1
                        to: 100
                        value: 3
                        editable: true
                    }
                    Item {
                        Layout.fillWidth: true
                    }

                    Label {
                        text: qsTr("Street bet")
                    }
                    SpinBox {
                        id: streetSpin
                        from: 1
                        to: 200
                        value: 9
                        editable: true
                    }
                    Item {
                        Layout.fillWidth: true
                    }

                    Label {
                        text: qsTr("Start stack")
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
                        onClicked: {
                            pokerGame.configure(sbSpin.value, bbSpin.value, streetSpin.value, stackSpin.value)
                            reloadGrids()
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 16
                columnSpacing: 16

                Repeater {
                    id: seatRepeater
                    model: 6

                    GroupBox {
                        required property int index
                        readonly property RangeGrid rangeGridRef: rng

                        title: index === 0 ? qsTr("Seat 1 — You (human)") : qsTr("Seat %1 — bot").arg(index + 1)
                        Layout.fillWidth: true
                        Layout.minimumWidth: 300
                        padding: 14
                        topPadding: 28

                        ColumnLayout {
                            width: parent.width
                            spacing: 10

                            Label {
                                visible: index === 0
                                text: qsTr("Actions are simulated: always call for now. Range grid is kept for future use.")
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                font.pixelSize: 12
                            }

                            Label {
                                visible: index > 0
                                text: qsTr("Strategy")
                                font.bold: true
                            }
                            ComboBox {
                                visible: index > 0
                                model: strategyNames
                                currentIndex: 0
                                Layout.fillWidth: true
                                onActivated: function (i) {
                                    pokerGame.setSeatStrategy(index, i)
                                }
                            }
                            Label {
                                text: qsTr("Range (comma-separated: AA,AKs,TT+,ATs+,22+)")
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            TextArea {
                                id: textArea
                                Layout.fillWidth: true
                                Layout.preferredHeight: 72
                                wrapMode: TextArea.Wrap
                                placeholderText: "AA,AKs,AKo,TT+"
                            }
                            RowLayout {
                                spacing: 8
                                Button {
                                    text: qsTr("Apply text")
                                    onClicked: {
                                        pokerGame.applySeatRangeText(index, textArea.text)
                                        reloadGrids()
                                    }
                                }
                                Button {
                                    text: qsTr("Export")
                                    onClicked: textArea.text = pokerGame.exportSeatRangeText(index)
                                }
                                Button {
                                    text: qsTr("Full range")
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
                                Layout.topMargin: 8
                            }
                        }
                    }
                }
            }

            Button {
                text: qsTr("Reload grids from engine")
                Layout.alignment: Qt.AlignLeft
                onClicked: reloadGrids()
            }
        }
    }
}
