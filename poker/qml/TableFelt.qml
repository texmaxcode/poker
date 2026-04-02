import QtQuick
import Theme 1.0

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
                color: Theme.bgGradientTop
            }
            GradientStop {
                position: 0.5
                color: Theme.bgGradientMid
            }
            GradientStop {
                position: 1
                color: Theme.bgGradientBottom
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
            color: Theme.railOuter
            border.width: 2
            border.color: Theme.railBezel
        }

        /// Wood rail / armrest band (wider than a thin bezel — like a real table ramp).
        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            radius: Math.max(4, parent.cr - 10)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.railWood0
                }
                GradientStop {
                    position: 0.5
                    color: Theme.railWood1
                }
                GradientStop {
                    position: 1
                    color: Theme.railWood2
                }
            }
            border.width: 2
            border.color: Theme.railEdge
        }

        Rectangle {
            id: feltFace
            anchors.fill: parent
            anchors.margins: 34
            radius: Math.max(4, parent.cr - 34)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.feltHighlight
                }
                GradientStop {
                    position: 0.45
                    color: Theme.feltMid
                }
                GradientStop {
                    position: 1
                    color: Theme.feltShadow
                }
            }
            border.width: 1
            border.color: Theme.feltBorder
            clip: true

            Canvas {
                id: feltGrain
                anchors.fill: parent
                opacity: 0.14
                onPaint: {
                    if (width < 4 || height < 4)
                        return
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    const n = Math.min(8000, Math.floor(width * height * 0.015))
                    for (var i = 0; i < n; ++i) {
                        const x = Math.random() * width
                        const y = Math.random() * height
                        ctx.fillStyle = Qt.rgba(0.05, 0.12, 0.1, 0.12 + Math.random() * 0.18)
                        ctx.fillRect(x, y, 1, 1)
                    }
                    for (var j = 0; j < Math.floor(n * 0.2); ++j) {
                        const x2 = Math.random() * width
                        const y2 = Math.random() * height
                        ctx.fillStyle = Qt.rgba(0.9, 0.95, 0.85, 0.04 + Math.random() * 0.06)
                        ctx.fillRect(x2, y2, 2, 1)
                    }
                }
                onWidthChanged: Qt.callLater(requestPaint)
                onHeightChanged: Qt.callLater(requestPaint)
                Component.onCompleted: Qt.callLater(requestPaint)
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 40
            radius: Math.max(4, parent.cr - 40)
            color: "transparent"
            border.width: 1
            border.color: "#ffffff14"
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 46
            radius: Math.max(4, parent.cr - 46)
            color: "transparent"
            border.width: 1
            border.color: "#ffffff06"
        }
    }
}
