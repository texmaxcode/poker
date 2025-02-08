import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    Image {
        id: poker_table
        fillMode: Image.PreserveAspectCrop
        anchors.fill: parent
        source: "assets/images/poker_table.jpg"
    }

    RowLayout {
        anchors.fill: parent
        ColumnLayout {
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    radius: 30
                    opacity: 0.3
                    color: "black"
                    width: 230
                    height: 230
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    radius: 30
                    opacity: 0.3
                    color: "black"
                    width: 230
                    height: 230
                }
            }
        }
        ColumnLayout {
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Rectangle {
                    anchors.centerIn: parent
                    radius: 30
                    opacity: 0.3
                    color: "black"
                    width: 230
                    height: 230
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Rectangle {
                    anchors.fill: parent
                    opacity: 0.2
                    color: "black"
                }

                Button {
                    anchors.centerIn: parent
                    text: "About"
                    onClicked: stackView.push("About.qml")
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Rectangle {
                    anchors.centerIn: parent
                    radius: 30
                    opacity: 0.3
                    color: "black"
                    width: 230
                    height: 230
                }
            }
        }
        ColumnLayout {
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    radius: 30
                    opacity: 0.3
                    color: "black"
                    width: 230
                    height: 230
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Rectangle {
                    anchors.fill: parent
                    opacity: 0.1
                    color: "black"
                }
            }
        }
    }
}