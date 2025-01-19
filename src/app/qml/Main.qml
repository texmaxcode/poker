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
        text: "Copy bucks image to starry night."
        background: Rectangle {
            implicitWidth: 100
            implicitHeight: 40
            color: button.down ? "#ffffff" : "#000000"
            border.color: "#26282a"
            border.width: 1
            radius: 4
        }

        onClicked: {
            reader.show_image()
            console.log("Test message")
        }
    }
}