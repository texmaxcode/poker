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

    readonly property bool humanDecisionActive: decisionSecondsLeft > 0

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

                Rectangle {
                    id: newHandBtn
                    color: "#c42d2d"
                    readonly property real baseOpacity: game_controls.humanDecisionActive ? 0.45 : 1.0
                    opacity: baseOpacity
                    implicitWidth: 128
                    implicitHeight: 46
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("New hand")
                        color: "white"
                        font.pointSize: 14
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: game_controls.humanDecisionActive ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                        enabled: !game_controls.humanDecisionActive
                        onClicked: {
                            if (pageRoot && !game_controls.humanDecisionActive)
                                pageRoot.buttonClicked("DEAL")
                        }
                        onPressed: parent.opacity = parent.baseOpacity * 0.88
                        onReleased: parent.opacity = parent.baseOpacity
                    }
                }

                Rectangle {
                    id: callBtn
                    color: "#c9a227"
                    readonly property real baseOpacity: game_controls.humanDecisionActive ? 1.0 : 0.42
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
                        cursorShape: game_controls.humanDecisionActive ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        enabled: game_controls.humanDecisionActive
                        onClicked: {
                            if (pageRoot && game_controls.humanDecisionActive)
                                pageRoot.buttonClicked("CALL")
                        }
                        onPressed: parent.opacity = parent.baseOpacity * 0.88
                        onReleased: parent.opacity = parent.baseOpacity
                    }
                }

                Rectangle {
                    id: foldBtn
                    color: "#6b3030"
                    readonly property real baseOpacity: game_controls.humanDecisionActive ? 1.0 : 0.42
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
                        cursorShape: game_controls.humanDecisionActive ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        enabled: game_controls.humanDecisionActive
                        onClicked: {
                            if (pageRoot && game_controls.humanDecisionActive)
                                pageRoot.buttonClicked("FOLD")
                        }
                        onPressed: parent.opacity = parent.baseOpacity * 0.88
                        onReleased: parent.opacity = parent.baseOpacity
                    }
                }

                Rectangle {
                    id: raiseBtn
                    color: "#1a6b45"
                    readonly property real baseOpacity: game_controls.humanDecisionActive ? 1.0 : 0.42
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
                        cursorShape: game_controls.humanDecisionActive ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        enabled: game_controls.humanDecisionActive
                        onClicked: {
                            if (pageRoot && game_controls.humanDecisionActive)
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
