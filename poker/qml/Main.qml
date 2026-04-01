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
    title: qsTr("Texas Hold'em Gym")
    color: "#08080a"

    FontLoader {
        id: oswaldRegular
        source: "qrc:/assets/fonts/Oswald-Regular.ttf"
    }
    FontLoader {
        id: oswaldBold
        source: "qrc:/assets/fonts/Oswald-Bold.ttf"
    }

    readonly property string fontUi: oswaldRegular.status === FontLoader.Ready ? oswaldRegular.name : "sans-serif"
    readonly property string fontUiBold: oswaldBold.status === FontLoader.Ready ? oswaldBold.name : fontUi

    font.family: fontUi
    font.pointSize: 11

    Component.onCompleted: showMaximized()

    header: ToolBar {
        visible: stack.currentIndex > 0
        implicitHeight: 52

        background: Rectangle {
            color: "#12121a"
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: "#3d2818"
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 14

            ToolButton {
                id: backBtn
                text: qsTr("Lobby")
                font.family: win.fontUiBold
                font.bold: true
                icon.source: "qrc:/assets/icons/home.svg"
                icon.width: 22
                icon.height: 22
                display: AbstractButton.TextBesideIcon
                onClicked: stack.currentIndex = 0
            }

            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.family: win.fontUiBold
                font.bold: true
                font.pointSize: 15
                color: "#d4af37"
                text: {
                    switch (stack.currentIndex) {
                    case 1:
                        return qsTr("Poker table")
                    case 2:
                        return qsTr("Bots & ranges")
                    case 3:
                        return qsTr("Solver & equity")
                    default:
                        return ""
                    }
                }
            }

            Item {
                width: backBtn.width
            }
        }
    }

    StackLayout {
        id: stack
        anchors.fill: parent
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        anchors.bottomMargin: 0
        anchors.topMargin: 0
        currentIndex: 0

        Lobby {
            stackLayout: stack
        }

        Game {
            pokerGameAccess: pokerGame
        }

        SetupScreen {
        }

        SolverScreen {
        }
    }
}
