 import QtQuick
 import QtQuick.Layouts

 Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        radius: 30
        opacity: 0.3
        color: "black"
        width: 20
        height: 20
        PropertyAnimation on width { to: 230}
        PropertyAnimation on height { to: 230}
    }
}