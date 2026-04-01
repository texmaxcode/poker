import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/// Full-width bottom bar: status + actions (human HUD).
Item {
    id: game_controls
    width: parent ? parent.width : implicitWidth
    height: bar.height

    property var pageRoot: null
    property string statusText: ""
    property int decisionSecondsLeft: 0
    property bool humanMoreTimeAvailable: false
    property bool humanCanCheck: false

    readonly property bool humanDecisionActive: decisionSecondsLeft > 0
    readonly property bool facingBet: humanDecisionActive && !humanCanCheck
    readonly property bool checkOrBet: humanDecisionActive && humanCanCheck

    Rectangle {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        height: row.implicitHeight + 20
        color: "#1a1d26"
        border.width: 0

        RowLayout {
            id: row
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 16

            Text {
                text: qsTr("Actions")
                color: "#8b93a8"
                font.pointSize: 11
                font.bold: true
            }

            Text {
                visible: game_controls.humanDecisionActive
                text: qsTr("%1 s").arg(game_controls.decisionSecondsLeft)
                color: "#7ec8ff"
                font.pointSize: 14
                font.bold: true
                Layout.minimumWidth: 44
            }

            Rectangle {
                id: moreTimeBtn
                visible: game_controls.humanDecisionActive && game_controls.humanMoreTimeAvailable
                color: "#3a4a6a"
                implicitWidth: 120
                implicitHeight: 40
                radius: 8

                Text {
                    anchors.centerIn: parent
                    text: qsTr("More time")
                    color: "#d0e4ff"
                    font.pointSize: 12
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
                    onPressed: parent.opacity = 0.85
                    onReleased: parent.opacity = 1
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                implicitHeight: Math.max(44, statusLabel.implicitHeight + 16)
                radius: 8
                color: "#252a36"
                border.color: "#3d4555"
                border.width: 1

                Text {
                    id: statusLabel
                    anchors.fill: parent
                    anchors.margins: 10
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: game_controls.statusText.length > 0 ? game_controls.statusText : qsTr("Ready.")
                    color: "#e4e8f0"
                    font.pointSize: 13
                }
            }

            RowLayout {
                spacing: 10
                visible: game_controls.facingBet

                Rectangle {
                    id: callBtn
                    color: "#c9a227"
                    readonly property real baseOpacity: game_controls.facingBet ? 1.0 : 0.42
                    opacity: baseOpacity
                    implicitWidth: 96
                    implicitHeight: 46
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("CALL")
                        color: "#222"
                        font.pointSize: 15
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: game_controls.facingBet ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        enabled: game_controls.facingBet
                        onClicked: {
                            if (pageRoot && game_controls.facingBet)
                                pageRoot.buttonClicked("CALL")
                        }
                        onPressed: parent.opacity = parent.baseOpacity * 0.88
                        onReleased: parent.opacity = parent.baseOpacity
                    }
                }

                Rectangle {
                    id: foldBtn
                    color: "#6b3030"
                    readonly property real baseOpacity: game_controls.facingBet ? 1.0 : 0.42
                    opacity: baseOpacity
                    implicitWidth: 96
                    implicitHeight: 46
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("FOLD")
                        color: "#f5e0e0"
                        font.pointSize: 15
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: game_controls.facingBet ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        enabled: game_controls.facingBet
                        onClicked: {
                            if (pageRoot && game_controls.facingBet)
                                pageRoot.buttonClicked("FOLD")
                        }
                        onPressed: parent.opacity = parent.baseOpacity * 0.88
                        onReleased: parent.opacity = parent.baseOpacity
                    }
                }

                Rectangle {
                    id: raiseBtn
                    color: "#1a6b45"
                    readonly property real baseOpacity: game_controls.facingBet ? 1.0 : 0.42
                    opacity: baseOpacity
                    implicitWidth: 96
                    implicitHeight: 46
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("RAISE")
                        color: "white"
                        font.pointSize: 15
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: game_controls.facingBet ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        enabled: game_controls.facingBet
                        onClicked: {
                            if (pageRoot && game_controls.facingBet)
                                pageRoot.buttonClicked("RAISE")
                        }
                        onPressed: parent.opacity = parent.baseOpacity * 0.88
                        onReleased: parent.opacity = parent.baseOpacity
                    }
                }
            }

            RowLayout {
                spacing: 10
                visible: game_controls.checkOrBet

                Rectangle {
                    id: checkBtn
                    color: "#4a5568"
                    readonly property real baseOpacity: game_controls.checkOrBet ? 1.0 : 0.42
                    opacity: baseOpacity
                    implicitWidth: 110
                    implicitHeight: 46
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("CHECK")
                        color: "#f0f4ff"
                        font.pointSize: 15
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: game_controls.checkOrBet ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        enabled: game_controls.checkOrBet
                        onClicked: {
                            if (pageRoot && game_controls.checkOrBet)
                                pageRoot.buttonClicked("CHECK")
                        }
                        onPressed: parent.opacity = parent.baseOpacity * 0.88
                        onReleased: parent.opacity = parent.baseOpacity
                    }
                }

                Rectangle {
                    id: openBetBtn
                    color: "#1a6b45"
                    readonly property real baseOpacity: game_controls.checkOrBet ? 1.0 : 0.42
                    opacity: baseOpacity
                    implicitWidth: 110
                    implicitHeight: 46
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Bet")
                        color: "white"
                        font.pointSize: 15
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: game_controls.checkOrBet ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        enabled: game_controls.checkOrBet
                        onClicked: {
                            if (pageRoot && game_controls.checkOrBet)
                                pageRoot.buttonClicked("RAISE")
                        }
                        onPressed: parent.opacity = parent.baseOpacity * 0.88
                        onReleased: parent.opacity = parent.baseOpacity
                    }
                }
            }
        }
    }
}
