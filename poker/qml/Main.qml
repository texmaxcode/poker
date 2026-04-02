import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme 1.0

ApplicationWindow {
    id: win
    visible: true
    width: 1400
    height: 900
    minimumWidth: 720
    minimumHeight: 560
    title: qsTr("Texas Hold'em Gym")
    color: Theme.bgWindow

    BrandedBackground {
        z: -1
        anchors.fill: parent
    }

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
    font.pointSize: Theme.uiBasePt

    Component.onCompleted: showMaximized()

    header: ToolBar {
        visible: stack.currentIndex > 0
        implicitHeight: 48

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
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 5
            anchors.bottomMargin: 5
            spacing: 8

            ToolButton {
                id: backBtn
                text: qsTr("Lobby")
                font.family: win.fontUiBold
                font.bold: true
                font.pointSize: Theme.uiToolBarBackPt
                icon.source: "qrc:/assets/icons/home.svg"
                icon.width: 18
                icon.height: 18
                display: AbstractButton.TextBesideIcon
                padding: 4
                flat: false
                hoverEnabled: true
                Accessible.role: Accessible.Button
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.NoButton
                }
                background: Rectangle {
                    anchors.fill: parent
                    radius: 8
                    clip: true
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.lighter(Theme.hudBg0, 1.06)
                        }
                        GradientStop {
                            position: 1
                            color: Theme.hudBg1
                        }
                    }
                    border.color: backBtn.down ? Theme.fireDeep
                            : (backBtn.hovered ? Theme.chromeLineGold : Qt.alpha(Theme.chromeLine, 0.88))
                    border.width: 1
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 1
                        radius: 8
                        color: Qt.alpha(Theme.gold, 0.22)
                    }
                }
                contentItem: RowLayout {
                    spacing: 4
                    Image {
                        width: 18
                        height: 18
                        source: backBtn.icon.source
                        opacity: backBtn.enabled ? 1 : 0.45
                    }
                    Label {
                        text: backBtn.text
                        font: backBtn.font
                        color: backBtn.down ? Theme.fire : (backBtn.hovered ? Theme.gold : Theme.textPrimary)
                        elide: Text.ElideRight
                    }
                }
                onClicked: stack.currentIndex = 0
            }

            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.family: win.fontUiBold
                font.bold: true
                font.pointSize: Theme.uiToolBarTitlePt
                color: Theme.gold
                text: {
                    switch (stack.currentIndex) {
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

        StatsScreen {
        }

        TrainerHome {
            stackLayout: stack
        }

        PreflopTrainer {
            stackLayout: stack
        }

        FlopTrainer {
            stackLayout: stack
        }
    }
}
