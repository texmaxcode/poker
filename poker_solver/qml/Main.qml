import QtQuick
import QtQuick.Controls
import com.musclecomputing 1.0

ApplicationWindow {
    width: 1700
    height: 1000
    minimumWidth: 1700
    minimumHeight: 1000
    visible: true

    Simulator {
        id: simulator
    }

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: "Dashboard.qml"
    }
}
