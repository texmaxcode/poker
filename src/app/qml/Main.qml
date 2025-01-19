import QtQuick
import QtQuick.Controls
import com.musclecomputing 1.0

ApplicationWindow {
    width: 900
    height: 900
    visible: true

    ImageReader {
        id: reader
    }

    Button {
        id: button
        text: "A Special Button"
        background: Rectangle {
            implicitWidth: 100
            implicitHeight: 40
            color: button.down ? "#d6d6d6" : "#f6f6f6"
            border.color: "#26282a"
            border.width: 1
            radius: 4
        }

        onClicked: reader.show_image()
    }
}