import QtQuick

/// Community card: staggered deal-in, then flip from back to face (natural pace).
Item {
    id: root
    width: 100
    height: 148

    property string card: ""
    property int staggerIndex: 0

    property bool faceVisible: false

    opacity: 0

    Card {
        id: inner
        anchors.fill: parent
        card: root.card
        tableCard: root.faceVisible
    }

    transform: Scale {
        id: sc
        origin.x: 50
        origin.y: 74
        xScale: 0.88
        yScale: 0.88
    }

    SequentialAnimation {
        id: enterAnim
        PauseAnimation {
            duration: staggerIndex * 110
        }
        ScriptAction {
            script: {
                root.opacity = 0
                root.faceVisible = false
                sc.xScale = 0.88
                sc.yScale = 0.88
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 1
                duration: 300
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: sc
                property: "xScale"
                to: 1
                duration: 420
                easing.type: Easing.OutBack
            }
            NumberAnimation {
                target: sc
                property: "yScale"
                to: 1
                duration: 420
                easing.type: Easing.OutBack
            }
        }
        PauseAnimation {
            duration: 90
        }
        ScriptAction {
            script: root.faceVisible = true
        }
    }

    onCardChanged: {
        if (card.length > 0) {
            enterAnim.restart()
        } else {
            enterAnim.stop()
            root.opacity = 0
            root.faceVisible = false
            sc.xScale = 0.88
            sc.yScale = 0.88
        }
    }
}
