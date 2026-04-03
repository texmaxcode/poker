import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

/// 13×13 weight matrix: row/col 0 = Ace … 12 = Two.
/// `composite`: three layers (call / raise / open) as stacked strips; click cycles the active `editLayer`.
Item {
    id: root
    property int seatIndex: 0
    property bool readOnly: false
    /// Single-layer weights (reference preset or simple mode).
    property var weights: []
    /// When true, show call / raise / open stacks from `wCall`, `wRaise`, `wBet`.
    property bool composite: false
    property var wCall: []
    property var wRaise: []
    property var wBet: []
    /// 0 = call, 1 = raise, 2 = open (first raise). Used when `composite` and not read-only.
    property int editLayer: 0
    property var rankLabels: ["A", "K", "Q", "J", "T", "9", "8", "7", "6", "5", "4", "3", "2"]

    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight

    readonly property color layerCallColor: Theme.rangeLayerCall
    readonly property color layerRaiseColor: Theme.rangeLayerRaise
    readonly property color layerBetColor: Theme.rangeLayerOpen

    function cellWeight(idx) {
        const w = (weights.length > idx) ? weights[idx] : 0
        return (w === undefined || w === null) ? 0 : w
    }

    function cellColor(w) {
        const v = (w === undefined || w === null) ? 0 : w
        const base = Qt.color(Theme.rangeHeatLo)
        const hi = Qt.color(Theme.rangeHeatHi)
        return Qt.rgba(
            base.r + (hi.r - base.r) * v,
            base.g + (hi.g - base.g) * v,
            base.b + (hi.b - base.b) * v,
            1)
    }

    function refreshFromGame() {
        if (!root.composite || typeof pokerGame === "undefined")
            return
        // Clear first so QML always sees a new assignment (avoids stale composite bindings).
        root.wCall = []
        root.wRaise = []
        root.wBet = []
        root.wCall = pokerGame.getRangeGrid(root.seatIndex, 0)
        root.wRaise = pokerGame.getRangeGrid(root.seatIndex, 1)
        root.wBet = pokerGame.getRangeGrid(root.seatIndex, 2)
    }

    function cycleWeight(row, col) {
        if (root.readOnly)
            return
        if (typeof pokerGame === "undefined")
            return
        const idx = row * 13 + col
        let cur = 0
        if (root.composite) {
            const layer = root.editLayer
            const arr = layer === 0 ? root.wCall : (layer === 1 ? root.wRaise : root.wBet)
            cur = (arr.length > idx) ? arr[idx] : 0
        } else {
            cur = root.cellWeight(idx)
        }
        const steps = [0, 0.33, 0.66, 1.0]
        let i = 0
        for (; i < steps.length; ++i) {
            if (Math.abs(cur - steps[i]) < 0.05)
                break
        }
        const next = steps[(i + 1) % steps.length]
        if (root.composite)
            pokerGame.setRangeCell(root.seatIndex, row, col, next, root.editLayer)
        else
            pokerGame.setRangeCell(root.seatIndex, row, col, next, 0)
        refreshFromGame()
        if (!root.composite)
            root.weights = pokerGame.getRangeGrid(root.seatIndex, 0)
    }

    onSeatIndexChanged: Qt.callLater(refreshFromGame)
    onCompositeChanged: {
        if (composite)
            Qt.callLater(refreshFromGame)
    }
    Component.onCompleted: Qt.callLater(refreshFromGame)

    Connections {
        target: pokerGame
        function onRangeRevisionChanged() {
            Qt.callLater(refreshFromGame)
        }
    }

    ColumnLayout {
        id: body
        spacing: 2

        RowLayout {
            visible: root.composite
            spacing: 10
            Repeater {
                model: [
                    { label: qsTr("Call"), c: root.layerCallColor },
                    { label: qsTr("Raise"), c: root.layerRaiseColor },
                    { label: qsTr("Open"), c: root.layerBetColor }
                ]
                RowLayout {
                    spacing: 4
                    Rectangle {
                        width: 10
                        height: 10
                        radius: 2
                        color: modelData.c
                        border.width: root.editLayer === index ? 2 : 0
                        border.color: Theme.focusGold
                    }
                    Label {
                        text: modelData.label
                        font.family: Theme.fontFamilyUi
                        font.pixelSize: Theme.uiRangeGridLegendPx
                        color: Theme.textMuted
                        font.bold: root.editLayer === index
                    }
                }
            }
        }

        RowLayout {
            spacing: 2
            Item {
                Layout.preferredWidth: Theme.uiRangeGridCornerW
                Layout.preferredHeight: Theme.uiRangeGridCornerH
            }
            Repeater {
                model: 13
                Label {
                    text: rankLabels[index]
                    horizontalAlignment: Text.AlignHCenter
                    Layout.preferredWidth: Theme.uiRangeGridCellW
                    font.family: Theme.fontFamilyUi
                    font.bold: true
                    font.pixelSize: Theme.uiRangeGridAxisPx
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
                    Layout.preferredWidth: Theme.uiRangeGridRowHeaderW
                    font.family: Theme.fontFamilyUi
                    font.bold: true
                    font.pixelSize: Theme.uiRangeGridAxisPx
                }
                Repeater {
                    model: 13
                    Item {
                        Layout.preferredWidth: Theme.uiRangeGridCellW
                        Layout.preferredHeight: Theme.uiRangeGridCellH
                        property int col: index
                        property int idx: rowItem.row * 13 + col

                        Rectangle {
                            anchors.fill: parent
                            visible: !root.composite
                            color: root.cellColor(root.cellWeight(idx))
                            border.color: Theme.panelBorderMuted
                            border.width: 1
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: root.composite
                            color: Theme.panel
                            border.color: Theme.panelBorderMuted
                            border.width: 1

                            Column {
                                id: stackCol
                                anchors.fill: parent
                                anchors.margins: 1
                                spacing: 0
                                property real c: {
                                    const v = (root.wCall.length > idx) ? root.wCall[idx] : 0
                                    return (v === undefined || v === null) ? 0 : v
                                }
                                property real r: {
                                    const v = (root.wRaise.length > idx) ? root.wRaise[idx] : 0
                                    return (v === undefined || v === null) ? 0 : v
                                }
                                property real b: {
                                    const v = (root.wBet.length > idx) ? root.wBet[idx] : 0
                                    return (v === undefined || v === null) ? 0 : v
                                }
                                // Must use `stackCol.c` etc.: bare `c+r+b` is not in scope in all Qt/QML builds.
                                property real t: Math.max(1e-9, stackCol.c + stackCol.r + stackCol.b)

                                Rectangle {
                                    width: parent.width
                                    height: parent.height * (stackCol.c / stackCol.t)
                                    visible: height > 0.2
                                    color: root.layerCallColor
                                    border.width: (root.editLayer === 0) ? 1 : 0
                                    border.color: Theme.focusGold
                                }
                                Rectangle {
                                    width: parent.width
                                    height: parent.height * (stackCol.r / stackCol.t)
                                    visible: height > 0.2
                                    color: root.layerRaiseColor
                                    border.width: (root.editLayer === 1) ? 1 : 0
                                    border.color: Theme.focusGold
                                }
                                Rectangle {
                                    width: parent.width
                                    height: parent.height * (stackCol.b / stackCol.t)
                                    visible: height > 0.2
                                    color: root.layerBetColor
                                    border.width: (root.editLayer === 2) ? 1 : 0
                                    border.color: Theme.focusGold
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            z: 1
                            visible: !root.readOnly && cellMa.containsMouse
                            color: Qt.rgba(1, 1, 1, 0.1)
                        }

                        MouseArea {
                            id: cellMa
                            z: 2
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.readOnly
                            cursorShape: root.readOnly ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: root.cycleWeight(rowItem.row, col)
                        }
                    }
                }
            }
        }
    }
}
