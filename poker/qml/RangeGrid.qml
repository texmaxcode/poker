import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/// 13×13 weight matrix: row/col 0 = Ace … 12 = Two
Item {
    id: root
    property int seatIndex: 0
    property var weights: []
    property var rankLabels: ["A", "K", "Q", "J", "T", "9", "8", "7", "6", "5", "4", "3", "2"]

    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight

    function cellColor(w) {
        const v = (w === undefined || w === null) ? 0 : w
        return Qt.rgba(0.15 + 0.85 * v, 0.2, 0.25 + 0.5 * v, 1)
    }

    function cycleWeight(row, col) {
        if (typeof pokerGame === "undefined")
            return
        const idx = row * 13 + col
        const cur = (weights.length > idx) ? weights[idx] : 0
        const steps = [0, 0.33, 0.66, 1.0]
        let i = 0
        for (; i < steps.length; ++i) {
            if (Math.abs(cur - steps[i]) < 0.05)
                break
        }
        const next = steps[(i + 1) % steps.length]
        pokerGame.setRangeCell(seatIndex, row, col, next)
        weights = pokerGame.getRangeGrid(seatIndex)
    }

    ColumnLayout {
        id: body
        spacing: 2

        RowLayout {
            spacing: 2
            Item {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 22
            }
            Repeater {
                model: 13
                Label {
                    text: rankLabels[index]
                    horizontalAlignment: Text.AlignHCenter
                    Layout.preferredWidth: 28
                    font.bold: true
                    font.pixelSize: 11
                }
            }
        }

        Repeater {
            model: 13
            RowLayout {
                id: rowItem
                property int row: index
                spacing: 2
                Label {
                    text: rankLabels[rowItem.row]
                    Layout.preferredWidth: 24
                    font.bold: true
                    font.pixelSize: 11
                }
                Repeater {
                    model: 13
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 24
                        property int col: index
                        color: root.cellColor((weights.length > (rowItem.row * 13 + col)) ? weights[rowItem.row * 13 + col] : 0)
                        border.color: "#333"
                        border.width: 1

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.cycleWeight(rowItem.row, col)
                        }
                    }
                }
            }
        }
    }
}
