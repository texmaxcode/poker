import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ApplicationWindow {
    id: win
    visible: true
    width: 1400
    height: 900
    minimumWidth: 720
    minimumHeight: 520
    title: qsTr("Texas Hold'em — table")

    Component.onCompleted: showMaximized()

    header: TabBar {
        id: tabs
        width: win.width

        TabButton {
            text: qsTr("Table")
        }
        TabButton {
            text: qsTr("Bots & ranges")
        }
        TabButton {
            text: qsTr("Solver & equity")
        }
    }

    StackLayout {
        id: stack
        anchors.fill: parent
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        anchors.bottomMargin: 0
        anchors.topMargin: 0
        currentIndex: tabs.currentIndex

        Game {
        }

        SetupScreen {
        }

        SolverScreen {
        }
    }
}
