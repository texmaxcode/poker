import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0
import PokerUi 1.0

/// Read-only 13×13 opening-range reference from `preflop_ranges_v1.json` (mode `open`).
/// Uses the same `RangeGrid` component as Setup so layout and composite layers match.
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

    /// Stable empty binding for unused composite layers (avoid `[]` in bindings each frame).
    readonly property var _emptyLayer: []
    /// Align JSON actions with Setup layers: first-in “raise” → Open layer; other modes use Raise.
    readonly property var gridWRaise: page.rangeMode === "open" ? page._emptyLayer : page.raiseW
    readonly property var gridWBet: page.rangeMode === "open" ? page.raiseW : page._emptyLayer

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

                    Item { Layout.fillWidth: true }
                }

                Text {
                    Layout.fillWidth: true
                    visible: page.loadFailed
                    wrapMode: Text.WordWrap
                    text: page.loadError.length ? page.loadError : qsTr("Could not load range data.")
                    color: Theme.dangerText
                    font.pixelSize: Theme.trainerBodyPx
                    lineHeight: Theme.bodyLineHeight
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
                        lineHeight: Theme.bodyLineHeight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        visible: page.hasScenario

                        Row {
                            spacing: 8
                            Rectangle { width: 10; height: 10; radius: 2; color: Theme.rangeLayerCallSubdued }
                            Label { text: qsTr("Call"); font.family: Theme.fontFamilyDisplay; color: Theme.textMuted; font.pixelSize: Theme.uiRangeGridLegendPx }
                        }
                        Row {
                            spacing: 8
                            Rectangle { width: 10; height: 10; radius: 2; color: Theme.rangeLayerRaiseSubdued }
                            Label { text: qsTr("Raise"); font.family: Theme.fontFamilyDisplay; color: Theme.textMuted; font.pixelSize: Theme.uiRangeGridLegendPx }
                        }
                        Row {
                            spacing: 8
                            Rectangle { width: 10; height: 10; radius: 2; color: Theme.rangeLayerOpenSubdued }
                            Label { text: qsTr("Open"); font.family: Theme.fontFamilyDisplay; color: Theme.textMuted; font.pixelSize: Theme.uiRangeGridLegendPx }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    RangeGrid {
                        id: rng
                        visible: page.hasScenario
                        readOnly: true
                        composite: true
                        bindToGame: false
                        seatIndex: 0
                        wCall: page.callW
                        wRaise: page.gridWRaise
                        wBet: page.gridWBet
                        wFold: page.foldW
                        Layout.fillWidth: true
                    }
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr("Frequencies sum to 100% per combo. Same composite chart as Setup (Call / Raise / Open). Hover a cell for fold share and layer weights.")
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
