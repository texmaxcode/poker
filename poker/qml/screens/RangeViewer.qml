import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0
import PokerUi 1.0

/// Read-only 13×13 opening-range reference from `preflop_ranges_v1.json` (mode `open`).
Page {
    id: page
    padding: 0
    font.family: Theme.fontFamilyUi

    property StackLayout stackLayout: null

    readonly property var kPositions: ["UTG", "HJ", "CO", "BTN", "SB"]
    readonly property string rangeMode: "open"

    property string position: "BTN"
    property var scenariosRoot: null
    property bool loadFailed: false
    property string loadError: ""

    property var foldW: []
    property var callW: []
    property var raiseW: []
    property bool hasScenario: false

    readonly property var rankLabels: ["A", "K", "Q", "J", "T", "9", "8", "7", "6", "5", "4", "3", "2"]
    readonly property int gridGap: 2
    readonly property real labelColW: Math.max(Theme.uiRangeGridCornerW, Theme.uiRangeGridRowHeaderW)

    readonly property real layoutWidth: {
        const w = gridHost.width
        if (w > 1)
            return w
        const pw = gridHost.parent ? gridHost.parent.width : 0
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

    readonly property color actRaise: Theme.successGreen
    readonly property color actCall: Theme.accentBlue
    readonly property color actFold: Theme.textMuted

    background: BrandedBackground { anchors.fill: parent }

    function goTrainingHome() {
        if (stackLayout)
            stackLayout.currentIndex = 5
    }

    function scrollMainToTop() {
        var flick = scrollView.contentItem
        if (flick) {
            flick.contentY = 0
            flick.contentX = 0
        }
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
        const n = Number(i)
        const j = Number.isFinite(n) ? Math.max(0, Math.min(m.length - 1, Math.floor(n))) : 0
        return m[j]
    }

    function cardFileName(rankIdx, suit) {
        return suit + "_" + rankIndexToSvgRank(rankIdx) + ".svg"
    }

    function cardFileNamesForCell(row, col) {
        const r = Math.max(0, Math.min(12, Math.floor(Number(row))))
        const c = Math.max(0, Math.min(12, Math.floor(Number(col))))
        if (r === c)
            return [cardFileName(r, "spades"), cardFileName(r, "hearts")]
        if (r < c)
            return [cardFileName(r, "spades"), cardFileName(c, "spades")]
        return [cardFileName(c, "spades"), cardFileName(r, "hearts")]
    }

    function cellFreqs(idx) {
        const f = (foldW.length > idx) ? Number(foldW[idx]) : 0
        const c = (callW.length > idx) ? Number(callW[idx]) : 0
        const r = (raiseW.length > idx) ? Number(raiseW[idx]) : 0
        return { f: f, c: c, r: r }
    }

    function dominantKind(idx) {
        const t = cellFreqs(idx)
        let best = "fold"
        let v = t.f
        if (t.c > v) {
            best = "call"
            v = t.c
        }
        if (t.r > v) {
            best = "raise"
            v = t.r
        }
        if (v < 1e-9)
            return "none"
        return best
    }

    function actionFillColor(kind) {
        if (kind === "raise")
            return Qt.tint(Theme.panel, Qt.alpha(actRaise, 0.62))
        if (kind === "call")
            return Qt.tint(Theme.panel, Qt.alpha(actCall, 0.58))
        if (kind === "fold")
            return Qt.tint(Theme.panel, Qt.alpha(actFold, 0.72))
        return Qt.tint(Theme.panel, Qt.alpha(Theme.textMuted, 0.35))
    }

    function findScenarioForPosition() {
        hasScenario = false
        foldW = []
        callW = []
        raiseW = []
        if (!scenariosRoot)
            return
        const arr = scenariosRoot.scenarios
        if (!arr || !arr.length)
            return
        const want = String(position).trim().toUpperCase()
        for (let i = 0; i < arr.length; ++i) {
            const s = arr[i]
            if (!s)
                continue
            const p = String(s.position || "").trim().toUpperCase()
            const m = String(s.mode || "open").trim()
            if (p !== want || m !== page.rangeMode)
                continue
            const a = s.actions
            if (!a)
                continue
            const fa = a.fold
            const ca = a.call
            const ra = a.raise
            if (!fa || !ca || !ra || fa.length !== 169 || ca.length !== 169 || ra.length !== 169)
                continue
            foldW = fa
            callW = ca
            raiseW = ra
            hasScenario = true
            return
        }
    }

    function loadRangesAsset() {
        loadFailed = false
        loadError = ""
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            if (xhr.status !== 200 && xhr.status !== 0) {
                loadFailed = true
                loadError = qsTr("Could not load file (HTTP %1).").arg(xhr.status)
                return
            }
            try {
                scenariosRoot = JSON.parse(xhr.responseText)
                findScenarioForPosition()
            } catch (e) {
                loadFailed = true
                loadError = qsTr("Invalid range file.")
            }
        }
        xhr.open("GET", "qrc:/assets/training/preflop_ranges_v1.json")
        xhr.send()
    }

    onPositionChanged: findScenarioForPosition()

    Component.onCompleted: loadRangesAsset()

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
        const margin = 10
        const edge = 12
        const aboveY = p.y - h - margin
        const maxY = target.height - h - edge
        if (aboveY >= edge)
            return Math.max(edge, Math.min(maxY, aboveY))
        const belowY = p.y + anchor.height + margin
        if (belowY <= maxY)
            return Math.max(edge, belowY)
        return Math.max(edge, Math.min(maxY, belowY))
    }

    function syncTipPopupPos() {
        if (!tipAnchor)
            return
        tipPopupX = cellTipPopupX(tipAnchor, rangeCellTip)
        tipPopupY = cellTipPopupY(tipAnchor, rangeCellTip)
    }

    Timer {
        id: tipShowTimer
        interval: 220
        repeat: false
        onTriggered: {
            if (page.tipRow >= 0 && page.tipAnchor) {
                rangeCellTip.parent = Overlay.overlay || page
                rangeCellTip.open()
                Qt.callLater(page.syncTipPopupPos)
            }
        }
    }

    Timer {
        id: tipFollowTimer
        interval: 32
        repeat: true
        running: false
        onTriggered: page.syncTipPopupPos()
    }

    Popup {
        id: rangeCellTip
        parent: page
        modal: false
        focus: false
        padding: 12
        closePolicy: Popup.NoAutoClose
        x: page.tipPopupX
        y: page.tipPopupY
        onOpened: {
            Qt.callLater(page.syncTipPopupPos)
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
            spacing: 8
            width: Math.min(300, Math.max(160, page.width - 24))

            Row {
                spacing: 8
                /// Integer `model` + index lookup — Qt 6 `modelData` from JS arrays is unreliable in delegates.
                Repeater {
                    model: page.tipRow >= 0 && page.tipCol >= 0
                            ? page.cardFileNamesForCell(page.tipRow, page.tipCol).length : 0
                    Image {
                        required property int index
                        readonly property var tipCardNames: page.cardFileNamesForCell(page.tipRow, page.tipCol)
                        width: 56
                        height: 80
                        fillMode: Image.Stretch
                        sourceSize.width: 56
                        sourceSize.height: 80
                        asynchronous: true
                        source: {
                            if (index < 0 || index >= tipCardNames.length)
                                return ""
                            const fn = tipCardNames[index]
                            return fn ? ("qrc:/assets/cards/" + fn) : ""
                        }
                    }
                }
            }

            Label {
                visible: page.tipRow >= 0
                text: page.tipRow >= 0 ? page.handNotation(page.tipRow, page.tipCol) : ""
                font.family: Theme.fontFamilyUi
                font.bold: true
                font.pixelSize: Math.max(Theme.uiRangeGridAxisPx, 14)
                color: Theme.textPrimary
            }

            Label {
                visible: page.tipRow >= 0
                text: page.tipRow >= 0 ? page.cellRegionName(page.tipRow, page.tipCol) : ""
                font.pixelSize: Theme.uiRangeGridLegendPx
                color: Theme.textMuted
            }

            Label {
                visible: page.tipRow >= 0 && page.hasScenario
                text: {
                    if (page.tipRow < 0)
                        return ""
                    const idx = page.tipRow * 13 + page.tipCol
                    const t = page.cellFreqs(idx)
                    return qsTr("Fold %1% · Call %2% · Raise %3%")
                            .arg(Math.round(t.f * 100))
                            .arg(Math.round(t.c * 100))
                            .arg(Math.round(t.r * 100))
                }
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamilyUi
                font.pixelSize: Theme.uiRangeGridLegendPx
                color: Theme.textSecondary
            }
        }
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true
        topPadding: Theme.uiScrollViewTopPadding

        RowLayout {
            width: scrollView.availableWidth
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }

            ColumnLayout {
                Layout.preferredWidth: Math.min(Theme.trainerContentMaxWidth, Math.max(280, scrollView.availableWidth - 40))
                Layout.maximumWidth: Theme.trainerContentMaxWidth
                spacing: Theme.trainerColumnSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    GameButton {
                        style: "form"
                        formFlat: true
                        text: qsTr("Training picks")
                        formFontPixelSize: Theme.trainerToolButtonPx
                        textColor: Theme.textPrimary
                        horizontalPadding: 14
                        onClicked: page.goTrainingHome()
                    }

                    Label {
                        text: qsTr("Opening ranges")
                        font.pointSize: Theme.trainerPageHeadlinePt
                        font.bold: true
                        font.capitalization: Font.AllUppercase
                        color: Theme.gold
                    }

                    Item { Layout.fillWidth: true }
                }

                Text {
                    Layout.fillWidth: true
                    visible: page.loadFailed
                    wrapMode: Text.WordWrap
                    text: page.loadError.length ? page.loadError : qsTr("Could not load range data.")
                    color: Theme.dangerText
                    font.pixelSize: Theme.trainerBodyPx
                    lineHeight: 1.25
                }

                ThemedPanel {
                    Layout.fillWidth: true
                    panelTitle: qsTr("Position")
                    panelOpacity: 0.5
                    borderOpacity: 0.5

                    Flow {
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: page.kPositions
                            GameButton {
                                required property var modelData
                                text: modelData
                                pillWidth: 64
                                overrideHeight: 34
                                fontSize: Theme.uiHudButtonPt
                                buttonColor: page.position === modelData ? Theme.successGreen : Theme.panelBorder
                                textColor: Theme.onAccentText
                                onClicked: page.position = modelData
                            }
                        }
                    }
                }

                ThemedPanel {
                    Layout.fillWidth: true
                    panelTitle: qsTr("13×13 chart (open)")
                    panelOpacity: 0.5
                    borderOpacity: 0.5

                    Label {
                        Layout.fillWidth: true
                        visible: !page.loadFailed && !page.hasScenario
                        wrapMode: Text.WordWrap
                        text: qsTr("No “open” range for %1 in the bundled JSON. Add a scenario or pick another seat.")
                                .arg(page.position)
                        color: Theme.textSecondary
                        font.pixelSize: Theme.trainerBodyPx
                        lineHeight: 1.25
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        visible: page.hasScenario

                        Row {
                            spacing: 8
                            Rectangle { width: 10; height: 10; radius: 2; color: page.actRaise }
                            Label { text: qsTr("Raise"); color: Theme.textMuted; font.pixelSize: Theme.uiRangeGridLegendPx }
                        }
                        Row {
                            spacing: 8
                            Rectangle { width: 10; height: 10; radius: 2; color: page.actCall }
                            Label { text: qsTr("Call"); color: Theme.textMuted; font.pixelSize: Theme.uiRangeGridLegendPx }
                        }
                        Row {
                            spacing: 8
                            Rectangle { width: 10; height: 10; radius: 2; color: page.actFold }
                            Label { text: qsTr("Fold"); color: Theme.textMuted; font.pixelSize: Theme.uiRangeGridLegendPx }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Item {
                        id: gridHost
                        Layout.fillWidth: true
                        implicitHeight: gridBody.implicitHeight

                        ColumnLayout {
                            id: gridBody
                            anchors.left: parent.left
                            anchors.right: parent.right
                            visible: page.hasScenario
                            spacing: 2

                            RowLayout {
                                spacing: page.gridGap
                                Item {
                                    Layout.preferredWidth: page.labelColW
                                    Layout.preferredHeight: page.cornerH
                                }
                                Repeater {
                                    model: 13
                                    Label {
                                        text: page.rankLabels[index]
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.preferredWidth: page.cellW
                                        font.family: Theme.fontFamilyUi
                                        font.bold: true
                                        font.pixelSize: page.axisPx
                                    }
                                }
                            }

                            Repeater {
                                model: 13
                                RowLayout {
                                    id: rowItem
                                    property int row: index
                                    spacing: page.gridGap
                                    Label {
                                        text: page.rankLabels[rowItem.row]
                                        Layout.preferredWidth: page.labelColW
                                        font.family: Theme.fontFamilyUi
                                        font.bold: true
                                        font.pixelSize: page.axisPx
                                    }
                                    Repeater {
                                        model: 13
                                        Item {
                                            id: cellItem
                                            Layout.preferredWidth: page.cellW
                                            Layout.preferredHeight: page.cellH
                                            property int col: index
                                            property int idx: rowItem.row * 13 + col

                                            Rectangle {
                                                anchors.fill: parent
                                                color: page.cellRegionColor(rowItem.row, col)
                                                border.color: Qt.alpha(Theme.chromeLine, 0.35)
                                                border.width: 1
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                color: page.actionFillColor(page.dominantKind(idx))
                                                opacity: 0.92
                                                border.width: 0
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
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: function (mouse) {
                                                    page.tipRow = rowItem.row
                                                    page.tipCol = col
                                                    page.tipAnchor = cellItem
                                                    tipShowTimer.stop()
                                                    rangeCellTip.parent = Overlay.overlay || page
                                                    rangeCellTip.open()
                                                    Qt.callLater(page.syncTipPopupPos)
                                                }
                                            }

                                            Connections {
                                                target: cellMa
                                                function onContainsMouseChanged() {
                                                    if (cellMa.containsMouse) {
                                                        page.tipRow = rowItem.row
                                                        page.tipCol = col
                                                        page.tipAnchor = cellItem
                                                        tipShowTimer.restart()
                                                    } else if (page.tipAnchor === cellItem) {
                                                        tipShowTimer.stop()
                                                        rangeCellTip.close()
                                                        page.tipRow = -1
                                                        page.tipCol = -1
                                                        page.tipAnchor = null
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr("Frequencies sum to 100% per combo. Colors follow the strongest action; hover or tap a cell for split.")
                    color: Theme.textMuted
                    font.pixelSize: Theme.trainerCaptionPx
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
        }
    }
}
