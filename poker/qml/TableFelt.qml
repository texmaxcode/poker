import QtQuick

/// Vector-only table playfield (no bitmaps): dark room + oval rail + felt.
Item {
    id: root
    anchors.fill: parent

    property real feltOvalW: Math.min(parent.width - 8, parent.height * 1.42)
    property real feltOvalH: Math.min(parent.height - 8, parent.width * 0.58)

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#0c0808"
            }
            GradientStop {
                position: 0.5
                color: "#060608"
            }
            GradientStop {
                position: 1
                color: "#08040a"
            }
        }
    }

    Item {
        id: shadowHost
        anchors.centerIn: parent
        width: Math.min(root.feltOvalW, parent.width - 4) + 10
        height: Math.min(root.feltOvalH, parent.height - 4) + 10
        property real scr: height / 2

        Rectangle {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 5
            anchors.verticalCenterOffset: 7
            width: parent.width - 10
            height: parent.height - 10
            radius: parent.scr
            color: "#80000000"
        }
    }

    Item {
        id: ovalHost
        anchors.centerIn: parent
        width: Math.min(root.feltOvalW, parent.width - 4)
        height: Math.min(root.feltOvalH, parent.height - 4)
        property real cr: height / 2
        z: 0

        Rectangle {
            anchors.fill: parent
            radius: parent.cr
            color: "#121018"
            border.width: 2
            border.color: "#1a1018"
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 7
            radius: Math.max(4, parent.cr - 7)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#3d2820"
                }
                GradientStop {
                    position: 0.5
                    color: "#2a1810"
                }
                GradientStop {
                    position: 1
                    color: "#1a1008"
                }
            }
            border.width: 2
            border.color: "#8a5030"
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 16
            radius: Math.max(4, parent.cr - 16)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#1a4a32"
                }
                GradientStop {
                    position: 0.45
                    color: "#123828"
                }
                GradientStop {
                    position: 1
                    color: "#0a2018"
                }
            }
            border.width: 1
            border.color: "#0a2818"
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 22
            radius: Math.max(4, parent.cr - 22)
            color: "transparent"
            border.width: 1
            border.color: "#ffffff14"
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 28
            radius: Math.max(4, parent.cr - 28)
            color: "transparent"
            border.width: 1
            border.color: "#ffffff06"
        }
    }
}
