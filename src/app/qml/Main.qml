import QtQuick
import QtQuick.Controls
import com.musclecomputing 1.0

ApplicationWindow {
    width: 1400
    height: 900
    minimumWidth: 1400
    minimumHeight: 900
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
