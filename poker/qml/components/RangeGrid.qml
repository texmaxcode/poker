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

    /// Gap between grid cells (matches `RowLayout` `spacing` below).
    readonly property int gridGap: 2
    /// Row/column header width — align top-left corner with row labels.
    readonly property real labelColW: Math.max(Theme.uiRangeGridCornerW, Theme.uiRangeGridRowHeaderW)
    /// Cell size grows with available width so the matrix spans the parent when `Layout.fillWidth` is set.
    /// Prefer laid-out width; during the first frames `width` can be 0 while the parent row already has width.
    readonly property real layoutWidth: {
        const w = root.width
        if (w > 1)
            return w
        const pw = parent ? parent.width : 0
        return pw > 1 ? pw : w
    }
    readonly property real cellW: {
        const w = layoutWidth
        const g = gridGap
        const lw = labelColW
        if (!w || w < lw + 13 * 20 + 13 * g)
            return Theme.uiRangeGridCellW
        return Math.max(18, Math.floor((w - lw - 13 * g) / 13))
    }
    readonly property real cellH: Math.max(20, cellW * (Theme.uiRangeGridCellH / Theme.uiRangeGridCellW))
    readonly property real cornerH: Theme.uiRangeGridCornerH * (cellW / Theme.uiRangeGridCellW)
    readonly property int axisPx: Math.max(10, Math.round(Theme.uiRangeGridAxisPx * Math.min(1.15, cellW / Theme.uiRangeGridCellW)))

    implicitWidth: labelColW + 13 * Theme.uiRangeGridCellW + 13 * gridGap
    implicitHeight: body.implicitHeight

    readonly property color layerCallColor: Theme.rangeLayerCallSubdued
    readonly property color layerRaiseColor: Theme.rangeLayerRaiseSubdued
    readonly property color layerBetColor: Theme.rangeLayerOpenSubdued

    function cellWeight(idx) {
        const w = (weights.length > idx) ? weights[idx] : 0
        return (w === undefined || w === null) ? 0 : w
    }

    function cellColor(w) {
        const v = (w === undefined || w === null) ? 0 : w
        const base = Qt.color(Theme.rangeHeatLo)
        const hi = Qt.color(Theme.rangeHeatHiSubdued)
        return Qt.rgba(
            base.r + (hi.r - base.r) * v,
            base.g + (hi.g - base.g) * v,
            base.b + (hi.b - base.b) * v,
            1)
    }

    function handNotation(row, col) {
        if (row === col)
            return rankLabels[row] + rankLabels[row]
        if (row < col)
            return rankLabels[row] + rankLabels[col] + "s"
        return rankLabels[col] + rankLabels[row] + "o"
    }

    function cellRegionColor(row, col) {
        if (row === col)
            return Theme.rangeGridPairTint
        if (row < col)
            return Theme.rangeGridSuitedTint
        return Theme.rangeGridOffsuitTint
    }

    function cellRegionName(row, col) {
        if (row === col)
            return qsTr("Pair")
        if (row < col)
            return qsTr("Suited")
        return qsTr("Offsuit")
    }

    function rankIndexToSvgRank(i) {
        const m = ["ace", "king", "queen", "jack", "10", "9", "8", "7", "6", "5", "4", "3", "2"]
        return m[i]
    }

    function cardFileName(rankIdx, suit) {
        return suit + "_" + rankIndexToSvgRank(rankIdx) + ".svg"
    }

    /// Two `qrc:/assets/cards/*.svg` names for the hovered cell (spades+hearts pairs; spades suited; spades+hearts offsuit).
    function cardFileNamesForCell(row, col) {
        if (row === col)
            return [cardFileName(row, "spades"), cardFileName(row, "hearts")]
        if (row < col)
            return [cardFileName(row, "spades"), cardFileName(col, "spades")]
        return [cardFileName(col, "spades"), cardFileName(row, "hearts")]
    }

    /// Hover card popup (single instance); `tipAnchor` is the hovered cell `Item`.
    property int tipRow: -1
    property int tipCol: -1
    property Item tipAnchor: null
    property real tipPopupX: 0
    property real tipPopupY: 0

    function cellTipPopupX(anchor, popup) {
        if (!anchor || !popup)
            return 0
        const target = popup.parent
        if (!target)
            return 0
        const p = anchor.mapToItem(target, 0, 0)
        const w = popup.width > 2 ? popup.width : Math.max(popup.implicitWidth, 200)
        const cx = p.x + anchor.width / 2 - w / 2
        return Math.min(target.width - w - 12, Math.max(12, cx))
    }

    function cellTipPopupY(anchor, popup) {
        if (!anchor || !popup)
            return 0
        const target = popup.parent
        if (!target)
            return 0
        const p = anchor.mapToItem(target, 0, 0)
        const h = popup.height > 2 ? popup.height : Math.max(popup.implicitHeight, 120)
        return Math.max(12, p.y - h - 10)
    }

    function syncTipPopupPos() {
        if (!tipAnchor)
            return
        tipPopupX = cellTipPopupX(tipAnchor, rangeCellTip)
        tipPopupY = cellTipPopupY(tipAnchor, rangeCellTip)
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
        anchors.left: parent.left
        anchors.right: parent.right
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
                        border.width: root.editLayer === index ? 1 : 0
                        border.color: Qt.alpha(Theme.chromeLineGold, 0.75)
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

        Label {
            visible: root.composite
            font.family: Theme.fontFamilyUi
            font.pixelSize: Theme.uiRangeGridLegendPx
            color: Theme.textMuted
            opacity: 0.9
            text: qsTr("Above diagonal: suited · on diagonal: pairs · below: offsuit")
        }

        RowLayout {
            spacing: gridGap
            Item {
                Layout.preferredWidth: labelColW
                Layout.preferredHeight: cornerH
            }
            Repeater {
                model: 13
                Label {
                    text: rankLabels[index]
                    horizontalAlignment: Text.AlignHCenter
                    Layout.preferredWidth: cellW
                    font.family: Theme.fontFamilyUi
                    font.bold: true
                    font.pixelSize: axisPx
                }
            }
        }

        Repeater {
            model: 13
            RowLayout {
                id: rowItem
                property int row: index
                spacing: gridGap
                Label {
                    text: rankLabels[rowItem.row]
                    Layout.preferredWidth: labelColW
                    font.family: Theme.fontFamilyUi
                    font.bold: true
                    font.pixelSize: axisPx
                }
                Repeater {
                    model: 13
                    Item {
                        id: cellItem
                        Layout.preferredWidth: cellW
                        Layout.preferredHeight: cellH
                        property int col: index
                        property int idx: rowItem.row * 13 + col

                        Rectangle {
                            anchors.fill: parent
                            visible: !root.composite
                            color: root.cellRegionColor(rowItem.row, col)
                            border.color: Qt.alpha(Theme.chromeLine, 0.35)
                            border.width: 1
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: !root.composite
                            color: root.cellColor(root.cellWeight(idx))
                            opacity: 0.9
                            border.width: 0
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: root.composite
                            color: root.cellRegionColor(rowItem.row, col)
                            border.color: Qt.alpha(Theme.chromeLine, 0.35)
                            border.width: 1

                            Column {
                                id: stackCol
                                anchors.fill: parent
                                anchors.margins: 2
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
                                    border.color: Qt.alpha(Theme.focusGold, 0.45)
                                }
                                Rectangle {
                                    width: parent.width
                                    height: parent.height * (stackCol.r / stackCol.t)
                                    visible: height > 0.2
                                    color: root.layerRaiseColor
                                    border.width: (root.editLayer === 1) ? 1 : 0
                                    border.color: Qt.alpha(Theme.focusGold, 0.45)
                                }
                                Rectangle {
                                    width: parent.width
                                    height: parent.height * (stackCol.b / stackCol.t)
                                    visible: height > 0.2
                                    color: root.layerBetColor
                                    border.width: (root.editLayer === 2) ? 1 : 0
                                    border.color: Qt.alpha(Theme.focusGold, 0.45)
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            z: 1
                            visible: cellMa.containsMouse
                            color: Qt.rgba(1, 1, 1, 0.06)
                        }

                        MouseArea {
                            id: cellMa
                            z: 2
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: root.readOnly ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: function (mouse) {
                                if (!root.readOnly)
                                    root.cycleWeight(rowItem.row, col)
                            }
                        }

                        Connections {
                            target: cellMa
                            function onContainsMouseChanged() {
                                if (cellMa.containsMouse) {
                                    root.tipRow = rowItem.row
                                    root.tipCol = col
                                    root.tipAnchor = cellItem
                                    tipShowTimer.restart()
                                } else if (root.tipAnchor === cellItem) {
                                    tipShowTimer.stop()
                                    rangeCellTip.close()
                                    root.tipRow = -1
                                    root.tipCol = -1
                                    root.tipAnchor = null
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: tipShowTimer
        interval: 280
        repeat: false
        onTriggered: {
            if (root.tipRow >= 0 && root.tipAnchor) {
                rangeCellTip.parent = Overlay.overlay || root
                rangeCellTip.open()
                Qt.callLater(root.syncTipPopupPos)
            }
        }
    }

    /// Keeps the overlay popup aligned while scrolling (scene position changes without `tipAnchor.x` changing).
    Timer {
        id: tipFollowTimer
        interval: 32
        repeat: true
        running: false
        onTriggered: root.syncTipPopupPos()
    }

    Popup {
        id: rangeCellTip
        parent: root
        modal: false
        focus: false
        padding: 12
        closePolicy: Popup.NoAutoClose

        x: root.tipPopupX
        y: root.tipPopupY

        onOpened: {
            Qt.callLater(root.syncTipPopupPos)
            tipFollowTimer.start()
        }
        onClosed: tipFollowTimer.stop()

        background: Rectangle {
            color: Theme.panelElevated
            border.color: Theme.panelBorder
            border.width: 1
            radius: 8
        }

        contentItem: Column {
            id: tipColumn
            spacing: 8
            width: Math.min(300, Math.max(160, root.width - 24))

            Row {
                spacing: 8
                Repeater {
                    model: root.tipRow >= 0 ? root.cardFileNamesForCell(root.tipRow, root.tipCol) : []
                    Image {
                        required property var modelData
                        width: 56
                        height: 80
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        source: "qrc:/assets/cards/" + modelData
                    }
                }
            }

            Label {
                visible: root.tipRow >= 0
                text: root.tipRow >= 0 ? root.handNotation(root.tipRow, root.tipCol) : ""
                font.family: Theme.fontFamilyUi
                font.bold: true
                font.pixelSize: Math.max(Theme.uiRangeGridAxisPx, 14)
                color: Theme.textPrimary
            }

            Label {
                visible: root.tipRow >= 0
                text: root.tipRow >= 0 ? root.cellRegionName(root.tipRow, root.tipCol) : ""
                font.pixelSize: Theme.uiRangeGridLegendPx
                color: Theme.textMuted
            }

            Label {
                visible: root.tipRow >= 0 && !root.composite
                text: {
                    if (root.tipRow < 0)
                        return ""
                    const idx = root.tipRow * 13 + root.tipCol
                    const w = root.cellWeight(idx)
                    return qsTr("Weight %1").arg(Number(w).toFixed(2))
                }
                font.family: Theme.fontFamilyUi
                font.pixelSize: Theme.uiRangeGridLegendPx
                color: Theme.textSecondary
            }

            Column {
                visible: root.tipRow >= 0 && root.composite
                spacing: 4
                width: parent.width

                RowLayout {
                    spacing: 6
                    width: parent.width
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 2
                        color: root.layerCallColor
                    }
                    Label {
                        Layout.fillWidth: true
                        text: {
                            if (root.tipRow < 0)
                                return ""
                            const idx = root.tipRow * 13 + root.tipCol
                            const c = (root.wCall.length > idx) ? root.wCall[idx] : 0
                            return qsTr("Call %1").arg(Number(c).toFixed(2))
                        }
                        font.family: Theme.fontFamilyUi
                        font.pixelSize: Theme.uiRangeGridLegendPx
                        color: Theme.textSecondary
                    }
                }
                RowLayout {
                    spacing: 6
                    width: parent.width
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 2
                        color: root.layerRaiseColor
                    }
                    Label {
                        Layout.fillWidth: true
                        text: {
                            if (root.tipRow < 0)
                                return ""
                            const idx = root.tipRow * 13 + root.tipCol
                            const r = (root.wRaise.length > idx) ? root.wRaise[idx] : 0
                            return qsTr("Raise %1").arg(Number(r).toFixed(2))
                        }
                        font.family: Theme.fontFamilyUi
                        font.pixelSize: Theme.uiRangeGridLegendPx
                        color: Theme.textSecondary
                    }
                }
                RowLayout {
                    spacing: 6
                    width: parent.width
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 2
                        color: root.layerBetColor
                    }
                    Label {
                        Layout.fillWidth: true
                        text: {
                            if (root.tipRow < 0)
                                return ""
                            const idx = root.tipRow * 13 + root.tipCol
                            const b = (root.wBet.length > idx) ? root.wBet[idx] : 0
                            return qsTr("Open %1").arg(Number(b).toFixed(2))
                        }
                        font.family: Theme.fontFamilyUi
                        font.pixelSize: Theme.uiRangeGridLegendPx
                        color: Theme.textSecondary
                    }
                }
            }
        }
    }
}
