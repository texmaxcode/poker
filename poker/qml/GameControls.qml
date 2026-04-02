import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

/// Bottom HUD (full width) or floating panel beside the human seat (`embeddedMode`).
Item {
    id: game_controls
    width: game_controls.embeddedMode
          ? (game_controls.panelWidth > 0 ? game_controls.panelWidth : implicitWidth)
          : (parent ? parent.width : implicitWidth)
    height: mainCol.height + 8

    /// When true, use compact timer row instead of full-width status row.
    property bool embeddedMode: false
    /// Used when `embeddedMode` is true; set from `Game.qml` so the panel does not span the table width.
    property real panelWidth: 0

    property var pageRoot: null
    property var pokerGame: null
    property bool humanSitOut: false
    property string statusText: ""
    property string humanHandText: ""
    property int decisionSecondsLeft: 0
    property bool humanMoreTimeAvailable: false
    property bool humanCanCheck: false
    property bool humanBbPreflopOption: false
    property bool humanCanRaiseFacing: false
    property bool humanBbCanRaise: false
    property int facingNeedChips: 0
    property int facingMinRaiseChips: 0
    property int facingMaxChips: 0
    property int facingPotAmount: 0
    property int openRaiseMinChips: 0
    property int openRaiseMaxChips: 0
    property int humanStackChips: 0
    property bool humanCanBuyBackIn: false
    property int buyInChips: 100

    readonly property bool humanDecisionActive: decisionSecondsLeft > 0
    readonly property bool humanHasChips: humanStackChips > 0
    /// Busted (0 stack) players watch but do not get the action UI.
    readonly property bool showWagerUi: !humanSitOut && humanStackChips > 0
    readonly property bool facingRaise: humanDecisionActive && !humanCanCheck && !humanBbPreflopOption
    readonly property bool checkOrRaiseSized: humanDecisionActive && humanCanCheck && !humanBbPreflopOption
    readonly property bool canFacingCall: facingRaise && (facingNeedChips <= 0 || humanHasChips)
    readonly property bool canRaiseFacing: facingRaise && humanCanRaiseFacing && humanHasChips
    readonly property bool canOpenRaise: checkOrRaiseSized && humanHasChips && openRaiseMinChips > 0
            && openRaiseMaxChips >= openRaiseMinChips

    readonly property bool showHumanActions: !humanSitOut

    readonly property string statusFullDisplay: {
        var hand = humanHandText.length > 0 ? humanHandText : ""
        var base
        if (humanSitOut)
            base = (statusText.length > 0) ? statusText : qsTr("Watching — next hand you skip.")
        else
            base = statusText.length > 0 ? statusText : qsTr("Ready.")
        if (hand.length > 0 && base.length > 0)
            return hand + "\n" + base
        return hand.length > 0 ? hand : base
    }

    /// Show raise slider + presets only after the user taps RAISE (facing a raise).
    property bool raiseSizingExpanded: false
    /// Show open-raise slider + presets only after Raise (first in on the street).
    property bool openRaiseSizingExpanded: false

    readonly property bool sizingDialogOpen: raiseSizingExpanded || openRaiseSizingExpanded

    function raiseSpinSafeMin() {
        return Math.min(facingMinRaiseChips, facingMaxChips)
    }

    function raiseSpinSafeMax() {
        return Math.max(facingMinRaiseChips, facingMaxChips)
    }

    function openRaiseSafeMin() {
        return Math.min(openRaiseMinChips, openRaiseMaxChips)
    }

    function openRaiseSafeMax() {
        return Math.max(openRaiseMinChips, openRaiseMaxChips)
    }

    function submitFacingRaise() {
        if (!pokerGame || !game_controls.raiseSizingExpanded || !game_controls.canRaiseFacing
                || !game_controls.facingRaise)
            return
        pokerGame.submitFacingAction(2, Math.round(raiseSlider.value))
    }

    function submitOpenRaise() {
        if (!pokerGame || !game_controls.openRaiseSizingExpanded || !game_controls.canOpenRaise
                || !game_controls.checkOrRaiseSized)
            return
        pokerGame.submitCheckOrBet(false, Math.round(openRaiseSlider.value))
    }

    Connections {
        target: raiseSlider
        function onPressedChanged() {
            if (!raiseSlider.pressed)
                game_controls.submitFacingRaise()
        }
    }

    Connections {
        target: openRaiseSlider
        function onPressedChanged() {
            if (!openRaiseSlider.pressed)
                game_controls.submitOpenRaise()
        }
    }

    Connections {
        target: game_controls
        function onFacingRaiseChanged() {
            if (!game_controls.facingRaise)
                game_controls.raiseSizingExpanded = false
        }
        function onHumanDecisionActiveChanged() {
            if (!game_controls.humanDecisionActive) {
                game_controls.raiseSizingExpanded = false
                game_controls.openRaiseSizingExpanded = false
            }
        }
        function onCheckOrRaiseSizedChanged() {
            if (!game_controls.checkOrRaiseSized)
                game_controls.openRaiseSizingExpanded = false
        }
        function onCanRaiseFacingChanged() {
            if (!game_controls.canRaiseFacing)
                game_controls.raiseSizingExpanded = false
        }
        function onCanOpenRaiseChanged() {
            if (!game_controls.canOpenRaise)
                game_controls.openRaiseSizingExpanded = false
        }
    }

    Rectangle {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        height: mainCol.height + 8
        radius: 10
        color: Theme.headerBg
        border.width: 1
        border.color: Qt.alpha(Theme.gold, 0.25)

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            radius: 10
            color: Qt.alpha(Theme.gold, 0.12)
        }

        Column {
            id: mainCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 4
            spacing: 6

            RowLayout {
                id: statusRow
                visible: !game_controls.embeddedMode
                width: parent.width - 12
                x: 6
                spacing: 6

                Text {
                    id: actionsHdr
                    visible: game_controls.showHumanActions && game_controls.showWagerUi
                    text: qsTr("Act")
                    color: Theme.hudActionLabel
                    font.pointSize: 9
                    font.bold: true
                }

                Text {
                    id: timerLbl
                    visible: game_controls.showHumanActions && game_controls.showWagerUi
                            && game_controls.humanDecisionActive
                    text: qsTr("%1s").arg(game_controls.decisionSecondsLeft)
                    color: Theme.seatBorderAct
                    font.pointSize: 10
                    font.bold: true
                    Layout.preferredWidth: visible ? implicitWidth : 0
                }

                Rectangle {
                    id: moreTimeBtn
                    visible: game_controls.showHumanActions && game_controls.showWagerUi
                            && game_controls.humanDecisionActive
                            && game_controls.humanMoreTimeAvailable
                    color: Theme.hudActionPanel
                    implicitWidth: visible ? 76 : 0
                    implicitHeight: 26
                    radius: 6
                    Layout.preferredWidth: visible ? 76 : 0

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("More")
                        color: Theme.hudActionBright
                        font.pointSize: 9
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pageRoot)
                                pageRoot.buttonClicked("MORE_TIME")
                        }
                        onEntered: parent.opacity = 0.92
                        onExited: parent.opacity = 1
                        onPressed: parent.opacity = 0.80
                        onReleased: parent.opacity = containsMouse ? 0.92 : 1
                    }
                }

                Item {
                    Layout.fillWidth: true
                    height: 1
                }
            }

            Column {
                id: embeddedChromeCol
                visible: game_controls.embeddedMode && game_controls.showHumanActions
                        && game_controls.humanDecisionActive
                width: parent.width - 12
                x: 6
                spacing: 6

                RowLayout {
                    width: parent.width
                    spacing: 10

                    Text {
                        text: qsTr("Act")
                        color: Theme.hudActionLabel
                        font.pointSize: 9
                        font.bold: true
                    }

                    Text {
                        text: qsTr("%1s").arg(game_controls.decisionSecondsLeft)
                        color: Theme.seatBorderAct
                        font.pointSize: 10
                        font.bold: true
                    }

                    Rectangle {
                        visible: game_controls.humanMoreTimeAvailable
                        color: Theme.hudActionPanel
                        implicitWidth: 76
                        implicitHeight: 26
                        radius: 6

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("More")
                            color: Theme.hudActionBright
                            font.pointSize: 9
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (pageRoot)
                                    pageRoot.buttonClicked("MORE_TIME")
                            }
                            onEntered: parent.opacity = 0.92
                            onExited: parent.opacity = 1
                            onPressed: parent.opacity = 0.80
                            onReleased: parent.opacity = containsMouse ? 0.92 : 1
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        height: 1
                    }
                }

                ProgressBar {
                    id: embeddedDecisionBar
                    width: parent.width
                    height: 6
                    padding: 2
                    from: 0
                    to: 1
                    value: Math.max(0, Math.min(1, game_controls.decisionSecondsLeft / 20))
                    background: Rectangle {
                        implicitHeight: 6
                        implicitWidth: 200
                        radius: 3
                        color: Theme.progressTrack
                    }
                    contentItem: Item {
                        implicitHeight: 6
                        Rectangle {
                            width: embeddedDecisionBar.visualPosition * parent.width
                            height: parent.height
                            radius: 3
                            color: Theme.seatBorderAct
                        }
                    }
                }
            }

            // Raise sizing (facing a raise): above FOLD / CALL / RAISE
            Rectangle {
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && game_controls.facingRaise
                        && game_controls.canRaiseFacing
                        && game_controls.raiseSizingExpanded
                width: parent.width
                height: visible ? raiseSizerCol.implicitHeight + 16 : 0
                color: Theme.panelElevated
                border.color: Theme.inputBorder
                border.width: 1
                clip: true

                Column {
                    id: raiseSizerCol
                    width: parent.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    spacing: 6

                    Slider {
                        id: raiseSlider
                        width: parent.width
                        from: game_controls.raiseSpinSafeMin()
                        to: game_controls.raiseSpinSafeMax()
                        stepSize: 1
                        snapMode: Slider.SnapAlways
                        value: from

                        function syncRaiseSlider() {
                            raiseSlider.from = game_controls.raiseSpinSafeMin()
                            raiseSlider.to = game_controls.raiseSpinSafeMax()
                            if (raiseSlider.to < raiseSlider.from) {
                                raiseSlider.value = raiseSlider.from
                                return
                            }
                            raiseSlider.value = Math.min(
                                Math.max(game_controls.facingMinRaiseChips, raiseSlider.from),
                                raiseSlider.to)
                        }

                        Component.onCompleted: syncRaiseSlider()
                    }

                    Connections {
                        target: game_controls
                        function onFacingMinRaiseChipsChanged() {
                            raiseSlider.syncRaiseSlider()
                        }
                        function onFacingMaxChipsChanged() {
                            raiseSlider.syncRaiseSlider()
                        }
                        function onFacingRaiseChanged() {
                            if (game_controls.facingRaise)
                                raiseSlider.syncRaiseSlider()
                        }
                    }

                    SizingPresetBar {
                        id: raisePresetRow
                        width: parent.width
                        hud: game_controls
                        slider: raiseSlider
                        flavor: "raise"
                        afterPreset: game_controls.submitFacingRaise
                    }
                }
            }

            // Facing a raise: fold / call / raise
            Row {
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && game_controls.facingRaise
                width: parent.width - 12
                x: 6
                spacing: 10

                Rectangle {
                    color: Theme.dangerBg
                    width: 76
                    height: 32
                    radius: 6
                    opacity: game_controls.facingRaise ? 1.0 : 0.42
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("FOLD")
                        color: Theme.dangerText
                        font.pointSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: game_controls.facingRaise
                        onClicked: {
                            if (pageRoot && game_controls.facingRaise)
                                pageRoot.buttonClicked("FOLD")
                        }
                        onEntered: parent.opacity = 0.92
                        onExited: parent.opacity = 1
                        onPressed: parent.opacity = 0.80
                        onReleased: parent.opacity = containsMouse ? 0.92 : 1
                    }
                }

                Rectangle {
                    visible: game_controls.canFacingCall
                    color: Theme.focusGold
                    width: 108
                    height: 32
                    radius: 6
                    Text {
                        anchors.centerIn: parent
                        text: game_controls.facingNeedChips > 0
                              ? qsTr("Call %1").arg(game_controls.facingNeedChips)
                              : qsTr("CALL")
                        color: Theme.insetDark
                        font.pointSize: 11
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pageRoot && game_controls.facingRaise)
                                pageRoot.buttonClicked("CALL")
                        }
                        onEntered: parent.opacity = 0.92
                        onExited: parent.opacity = 1
                        onPressed: parent.opacity = 0.80
                        onReleased: parent.opacity = containsMouse ? 0.92 : 1
                    }
                }

                Rectangle {
                    visible: game_controls.canRaiseFacing && !game_controls.raiseSizingExpanded
                    color: Theme.successGreen
                    width: 88
                    height: 32
                    radius: 6
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("RAISE")
                        color: "white"
                        font.pointSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: game_controls.raiseSizingExpanded = true
                        onEntered: parent.opacity = 0.92
                        onExited: parent.opacity = 1
                        onPressed: parent.opacity = 0.80
                        onReleased: parent.opacity = containsMouse ? 0.92 : 1
                    }
                }
            }

            // BB preflop option
            Row {
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && game_controls.humanDecisionActive
                        && game_controls.humanBbPreflopOption
                width: parent.width - 12
                x: 6
                spacing: 10

                Rectangle {
                    color: Theme.panelBorder
                    width: 96
                    height: 32
                    radius: 6
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("CHECK")
                        color: Theme.textPrimary
                        font.pointSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pageRoot)
                                pageRoot.buttonClicked("CHECK")
                        }
                        onEntered: parent.opacity = 0.92
                        onExited: parent.opacity = 1
                        onPressed: parent.opacity = 0.80
                        onReleased: parent.opacity = containsMouse ? 0.92 : 1
                    }
                }

                Rectangle {
                    visible: game_controls.humanBbCanRaise && game_controls.humanHasChips
                    color: Theme.successGreen
                    width: 96
                    height: 32
                    radius: 6
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Raise")
                        color: "white"
                        font.pointSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pageRoot)
                                pageRoot.buttonClicked("RAISE")
                        }
                        onEntered: parent.opacity = 0.92
                        onExited: parent.opacity = 1
                        onPressed: parent.opacity = 0.80
                        onReleased: parent.opacity = containsMouse ? 0.92 : 1
                    }
                }
            }

            // Open raise sizing (checked to you): above CHECK / FOLD / RAISE
            Rectangle {
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && game_controls.checkOrRaiseSized
                        && game_controls.canOpenRaise
                        && game_controls.openRaiseSizingExpanded
                width: parent.width
                height: visible ? openRaiseSizerCol.implicitHeight + 16 : 0
                color: Theme.panelElevated
                border.color: Theme.inputBorder
                border.width: 1
                clip: true

                Column {
                    id: openRaiseSizerCol
                    width: parent.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    spacing: 6

                    Slider {
                        id: openRaiseSlider
                        width: parent.width
                        from: game_controls.openRaiseSafeMin()
                        to: game_controls.openRaiseSafeMax()
                        stepSize: 1
                        snapMode: Slider.SnapAlways
                        value: from

                        function syncOpenRaiseSlider() {
                            openRaiseSlider.from = game_controls.openRaiseSafeMin()
                            openRaiseSlider.to = game_controls.openRaiseSafeMax()
                            if (openRaiseSlider.to < openRaiseSlider.from) {
                                openRaiseSlider.value = openRaiseSlider.from
                                return
                            }
                            openRaiseSlider.value = Math.min(
                                Math.max(game_controls.openRaiseMinChips, openRaiseSlider.from),
                                openRaiseSlider.to)
                        }

                        Component.onCompleted: syncOpenRaiseSlider()
                    }

                    Connections {
                        target: game_controls
                        function onOpenRaiseMinChipsChanged() {
                            openRaiseSlider.syncOpenRaiseSlider()
                        }
                        function onOpenRaiseMaxChipsChanged() {
                            openRaiseSlider.syncOpenRaiseSlider()
                        }
                        function onCheckOrRaiseSizedChanged() {
                            if (game_controls.checkOrRaiseSized)
                                openRaiseSlider.syncOpenRaiseSlider()
                        }
                    }

                    SizingPresetBar {
                        id: openRaisePresetRow
                        width: parent.width
                        hud: game_controls
                        slider: openRaiseSlider
                        flavor: "open"
                        afterPreset: game_controls.submitOpenRaise
                    }
                }
            }

            // Check or fold (post-flop) + open raise trigger
            Row {
                visible: game_controls.showHumanActions && game_controls.showWagerUi
                        && game_controls.checkOrRaiseSized
                width: parent.width - 12
                x: 6
                spacing: 10

                Rectangle {
                    color: Theme.panelBorder
                    width: 88
                    height: 32
                    radius: 6
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("CHECK")
                        color: Theme.textPrimary
                        font.pointSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pokerGame)
                                pokerGame.submitCheckOrBet(true, 0)
                        }
                        onEntered: parent.opacity = 0.92
                        onExited: parent.opacity = 1
                        onPressed: parent.opacity = 0.80
                        onReleased: parent.opacity = containsMouse ? 0.92 : 1
                    }
                }

                Rectangle {
                    color: Theme.dangerBg
                    width: 76
                    height: 32
                    radius: 6
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("FOLD")
                        color: Theme.dangerText
                        font.pointSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pokerGame)
                                pokerGame.submitFoldFromCheck()
                        }
                        onEntered: parent.opacity = 0.92
                        onExited: parent.opacity = 1
                        onPressed: parent.opacity = 0.80
                        onReleased: parent.opacity = containsMouse ? 0.92 : 1
                    }
                }

                Rectangle {
                    visible: game_controls.canOpenRaise && !game_controls.openRaiseSizingExpanded
                    color: Theme.successGreen
                    width: 88
                    height: 32
                    radius: 6
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Raise")
                        color: "white"
                        font.pointSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: game_controls.openRaiseSizingExpanded = true
                        onEntered: parent.opacity = 0.92
                        onExited: parent.opacity = 1
                        onPressed: parent.opacity = 0.80
                        onReleased: parent.opacity = containsMouse ? 0.92 : 1
                    }
                }
            }

            RowLayout {
                id: sitOutRow
                width: parent.width - 12
                x: 6
                spacing: 6

                CheckBox {
                    id: sitOutCheck
                    text: qsTr("Sit out")
                    font.pointSize: 9
                    padding: 2
                    checked: game_controls.humanSitOut
                    onToggled: {
                        if (pokerGame) {
                            pokerGame.setHumanSitOut(sitOutCheck.checked)
                            pokerGame.savePersistedSettings()
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    height: 1
                }
            }

            RowLayout {
                id: buyBackRow
                visible: game_controls.embeddedMode && game_controls.humanCanBuyBackIn
                width: parent.width - 12
                x: 6
                spacing: 6

                Button {
                    text: qsTr("Buy back in (%1)").arg(game_controls.buyInChips)
                    font.pointSize: 9
                    padding: 8
                    onClicked: {
                        if (game_controls.pokerGame)
                            game_controls.pokerGame.tryBuyBackIn(0)
                    }
                }

                Item {
                    Layout.fillWidth: true
                    height: 1
                }
            }

            Rectangle {
                id: statusBanner
                width: parent.width - 12
                x: 6
                implicitHeight: Math.max(40, statusBannerLabel.implicitHeight + 12)
                radius: 6
                color: Theme.inputBg
                border.color: Theme.inputBorder
                border.width: 1

                HoverHandler {
                    id: statusBannerHover
                }
                ToolTip.visible: statusBannerHover.hovered && game_controls.statusFullDisplay.length > 0
                ToolTip.delay: 350
                ToolTip.text: game_controls.statusFullDisplay

                Text {
                    id: statusBannerLabel
                    anchors.fill: parent
                    anchors.margins: 8
                    wrapMode: Text.WordWrap
                    maximumLineCount: game_controls.embeddedMode ? 4 : 5
                    elide: Text.ElideRight
                    text: game_controls.statusFullDisplay
                    color: Theme.textPrimary
                    font.pixelSize: game_controls.embeddedMode ? 12 : 13
                    lineHeight: 1.12
                }
            }

            Item {
                width: 1
                height: 2
            }
        }
    }
}
