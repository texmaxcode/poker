import QtQuick

/// Dark room, suit texture, racetrack oval. Size comes from Game.qml so seats sit outside the rail.
Item {
    id: root
    anchors.fill: parent

    /// Synced from Game.qml (caps oval so seats fit on the carpet).
    property real feltOvalW: Math.min(parent.width - 8, parent.height * 1.42)
    property real feltOvalH: Math.min(parent.height - 8, parent.width * 0.58)

    Rectangle {
        anchors.fill: parent
        color: "#0a1f16"
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#0d281c"
            }
            GradientStop {
                position: 0.45
                color: "#081812"
            }
            GradientStop {
                position: 1
                color: "#050f0c"
            }
        }
    }

    // Light suit texture (sparse grid — cheap vs full window tiles)
    Grid {
        id: suitGrid
        anchors.fill: parent
        columns: 18
        rows: 12
        opacity: 0.055

        Repeater {
            model: 216
            delegate: Text {
                width: suitGrid.width / 18
                height: suitGrid.height / 12
                text: {
                    var s = index % 4
                    if (s === 0)
                        return "♠"
                    if (s === 1)
                        return "♥"
                    if (s === 2)
                        return "♦"
                    return "♣"
                }
                color: "#7dffb8"
                font.pixelSize: Math.max(10, Math.min(16, root.width / 64))
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // Soft shadow under the table (drawn first, below oval)
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

    // Stadium oval — rail + felt (size = feltOvalW/H from Game)
    Item {
        id: ovalHost
        anchors.centerIn: parent
        width: Math.min(root.feltOvalW, parent.width - 4)
        height: Math.min(root.feltOvalH, parent.height - 4)
        property real cr: height / 2
        z: 0

        // Outer bumper
        Rectangle {
            anchors.fill: parent
            radius: parent.cr
            color: "#15151a"
            border.width: 2
            border.color: "#050508"
        }

        // Wood rail
        Rectangle {
            anchors.fill: parent
            anchors.margins: 7
            radius: Math.max(4, parent.cr - 7)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#4a3020"
                }
                GradientStop {
                    position: 0.5
                    color: "#3d2818"
                }
                GradientStop {
                    position: 1
                    color: "#2a1a12"
                }
            }
            border.width: 2
            border.color: "#d4a060"
        }

        // Felt
        Rectangle {
            anchors.fill: parent
            anchors.margins: 16
            radius: Math.max(4, parent.cr - 16)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#25965e"
                }
                GradientStop {
                    position: 0.42
                    color: "#1d7d4e"
                }
                GradientStop {
                    position: 1
                    color: "#124832"
                }
            }
            border.width: 1
            border.color: "#0a3220"
        }

        // Inner betting ring (subtle)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 22
            radius: Math.max(4, parent.cr - 22)
            color: "transparent"
            border.width: 1
            border.color: "#ffffff18"
        }

        // Felt sheen
        Rectangle {
            anchors.fill: parent
            anchors.margins: 28
            radius: Math.max(4, parent.cr - 28)
            color: "transparent"
            border.width: 1
            border.color: "#ffffff08"
        }
    }
}
