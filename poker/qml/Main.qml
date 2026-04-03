import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Theme 1.0
import PokerUi 1.0

/// Root window — pages live under `screens/`; shared UI in `components/` (`PokerUi` module).
ApplicationWindow {
    id: win
    visible: true

    function syncTrainerClocksOnResume() {
        if (preflopTrainerPage.visible)
            preflopTrainerPage.syncTrainerClocks()
        if (flopTrainerPage.visible)
            flopTrainerPage.syncTrainerClocks()
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

    Component.onCompleted: showMaximized()

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
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.fontFamilyUi
                font.bold: true
                font.pointSize: Theme.uiToolBarTitlePt
                color: Theme.gold
                text: headerTitleForIndex(stack.currentIndex)
            }

            Item {
                width: backBtn.width
            }
        }
    }

    function headerTitleForIndex(idx) {
        switch (idx) {
        case 1:
            return qsTr("Poker table")
        case 2:
            return qsTr("Bots & ranges")
        case 3:
            return qsTr("Solver & equity")
        case 4:
            return qsTr("Bankroll & stats")
        case 5:
            return qsTr("Training")
        case 6:
            return qsTr("Preflop trainer")
        case 7:
            return qsTr("Flop trainer")
        default:
            return ""
        }
    }

    StackLayout {
        id: stack
        anchors.fill: parent
        currentIndex: 0

        LobbyScreen {
            stackLayout: stack
        }

        GameScreen {
            pokerGameAccess: pokerGame
        }

        SetupScreen {
        }

        SolverScreen {
        }

        StatsScreen {
        }

        TrainerHome {
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
    }
}
