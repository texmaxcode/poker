import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Theme 1.0
import PokerUi 1.0

/// Root window — pages live under `screens/`; shared UI in `components/` (`PokerUi` module).
ApplicationWindow {
    id: win
    /// Open maximized immediately. `showMaximized()` in `Component.onCompleted` ran *after* the first
    /// paint at `width`/`height`, which caused a visible resize jump on startup.
    visibility: Window.Maximized
    /// Show immediately — avoids a frame at implicit size before `visibility` applies on some platforms.
    visible: true

    function syncTrainerClocksOnResume() {
        if (preflopTrainerPage.visible)
            preflopTrainerPage.syncTrainerClocks()
        if (flopTrainerPage.visible)
            flopTrainerPage.syncTrainerClocks()
        if (turnTrainerPage.visible)
            turnTrainerPage.syncTrainerClocks()
        if (riverTrainerPage.visible)
            riverTrainerPage.syncTrainerClocks()
    }

    onActiveChanged: function () {
        if (win.active)
            syncTrainerClocksOnResume()
    }

    onVisibilityChanged: function () {
        if (win.visibility !== Window.Hidden && win.visibility !== Window.Minimized)
            syncTrainerClocksOnResume()
    }

    width: Metrics.windowWidthDefault
    height: Metrics.windowHeightDefault
    minimumWidth: Metrics.windowMinWidth
    minimumHeight: Metrics.windowMinHeight

    title: qsTr("Texas Hold'em Gym")
    color: Theme.bgWindow

    // GroupBox titles, ComboBox, SpinBox, and other Controls read palette roles; defaults are light-theme (black text).
    palette: Palette {
        window: Theme.bgWindow
        windowText: Theme.textPrimary
        base: Theme.inputBg
        alternateBase: Theme.panelElevated
        text: Theme.textPrimary
        button: Theme.panel
        buttonText: Theme.textPrimary
        highlight: Theme.panelBorder
        highlightedText: Theme.textPrimary
        toolTipBase: Theme.panelElevated
        toolTipText: Theme.textPrimary
        // Fusion/GroupBox frames use mid/shadow/light; without these, borders vanish on dark window.
        mid: Theme.panelBorder
        dark: Theme.panelBorderMuted
        light: Theme.chromeLine
        shadow: Theme.insetDark
    }

    BrandedBackground {
        z: -1
        anchors.fill: parent
    }

    font.family: Theme.fontFamilyUi
    font.pointSize: Theme.uiBasePt

    header: ToolBar {
        visible: stack.currentIndex > 0
        implicitHeight: Metrics.toolbarHeight

        background: Rectangle {
            color: Theme.headerBg
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.headerRule
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Metrics.toolbarMarginH
            anchors.rightMargin: Metrics.toolbarMarginH
            anchors.topMargin: Metrics.toolbarMarginV
            anchors.bottomMargin: Metrics.toolbarMarginV
            spacing: 6

            GameButton {
                id: backBtn
                Layout.alignment: Qt.AlignVCenter
                style: "chrome"
                text: qsTr("Lobby")
                iconSource: "qrc:/assets/icons/home.svg"
                chromeFontFamily: Theme.fontFamilyUi
                clickEnabled: true
                onClicked: stack.currentIndex = 0
            }

            Label {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: Theme.fontFamilyUi
                font.bold: true
                font.capitalization: Font.AllUppercase
                font.pointSize: Theme.uiToolBarTitlePt
                color: Theme.gold
                text: headerTitleForIndex(stack.currentIndex)
            }

            Item {
                width: backBtn.width
            }
        }
    }

    /// Ephemeral toast (top-right). No reserved space when empty — only the bubble is shown.
    property string appToastText: ""
    function showAppToast(msg) {
        win.appToastText = msg
        appToastTimer.restart()
    }

    Timer {
        id: appToastTimer
        interval: 2600
        repeat: false
        onTriggered: win.appToastText = ""
    }

    /// Above page content, under the toolbar when it is visible.
    Rectangle {
        parent: win.contentItem
        z: 10000
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 10
        anchors.topMargin: win.header.visible ? win.header.height + 2 : 6
        width: 400
        height: visible ? toastLabel.implicitHeight + 14 : 0
        visible: win.appToastText.length > 0
        radius: 8
        color: Theme.panelElevated
        border.width: 1
        border.color: Theme.headerRule
        Label {
            id: toastLabel
            anchors.centerIn: parent
            width: 380
            wrapMode: Text.WordWrap
            text: win.appToastText
            color: Theme.textPrimary
            font.family: Theme.fontFamilyUi
            font.pixelSize: Theme.trainerCaptionPx
        }
    }

    function headerTitleForIndex(idx) {
        switch (idx) {
        case 1:
            return qsTr("Texas Hold'em")
        case 2:
            return qsTr("Bots & ranges")
        case 3:
            return qsTr("Solver & equity")
        case 4:
            return qsTr("Stats")
        case 5:
            return qsTr("Training")
        case 6:
            return qsTr("Preflop trainer")
        case 7:
            return qsTr("Flop trainer")
        case 8:
            return qsTr("Turn trainer")
        case 9:
            return qsTr("River trainer")
        case 10:
            return qsTr("Opening ranges")
        default:
            return ""
        }
    }

    StackLayout {
        id: stack
        anchors.fill: parent
        currentIndex: 0

        /// Previous stack index — used to scroll content to top when returning from the lobby.
        property int _prevIndex: 0

        onCurrentIndexChanged: {
            const cur = stack.currentIndex
            const prev = stack._prevIndex
            if (cur > 0 && prev === 0) {
                Qt.callLater(function () {
                    switch (cur) {
                    case 2:
                        setupPage.scrollMainToTop()
                        break
                    case 3:
                        solverPage.scrollMainToTop()
                        break
                    case 4:
                        statsPage.scrollMainToTop()
                        break
                    case 5:
                        trainerHomePage.scrollMainToTop()
                        break
                    case 6:
                        preflopTrainerPage.scrollMainToTop()
                        break
                    case 7:
                        flopTrainerPage.scrollMainToTop()
                        break
                    case 8:
                        turnTrainerPage.scrollMainToTop()
                        break
                    case 9:
                        riverTrainerPage.scrollMainToTop()
                        break
                    case 10:
                        rangeViewerPage.scrollMainToTop()
                        break
                    }
                })
            }
            stack._prevIndex = cur
        }

        Component.onCompleted: stack._prevIndex = stack.currentIndex

        LobbyScreen {
            stackLayout: stack
        }

        GameScreen {
            pokerGameAccess: pokerGame
        }

        SetupScreen {
            id: setupPage
        }

        SolverScreen {
            id: solverPage
        }

        StatsScreen {
            id: statsPage
        }

        TrainerHome {
            id: trainerHomePage
            stackLayout: stack
        }

        PreflopTrainer {
            id: preflopTrainerPage
            stackLayout: stack
        }

        FlopTrainer {
            id: flopTrainerPage
            stackLayout: stack
        }

        TurnTrainer {
            id: turnTrainerPage
            stackLayout: stack
        }

        RiverTrainer {
            id: riverTrainerPage
            stackLayout: stack
        }

        RangeViewer {
            id: rangeViewerPage
            stackLayout: stack
        }
    }
}
