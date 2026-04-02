import QtQuick
import QtQuick.Controls
import Theme 1.0

/// Shared Min / ⅓ / ½ / ⅔ / Pot / All chips for raise (facing) vs open-raise sliders.
Row {
    id: root
    spacing: 5

    required property var hud
    required property Slider slider
    /// `"raise"` = facing a raise; `"open"` = first raise on a street.
    property string flavor: "raise"
    /// Called after a preset updates the slider (e.g. submit bet/raise in the parent HUD).
    property var afterPreset: null

    function clampToSlider(v) {
        var lo = slider.from
        var hi = slider.to
        return Math.min(Math.max(v, lo), hi)
    }

    function applyRaiseTotal(v) {
        v = Math.max(v, hud.facingMinRaiseChips)
        slider.value = clampToSlider(v)
    }

    function applyOpenRaise(v) {
        v = Math.max(v, hud.openRaiseMinChips)
        slider.value = clampToSlider(v)
    }

    function applyPotFrac(num, den) {
        if (root.flavor === "raise")
            applyRaiseTotal(hud.facingNeedChips + Math.floor(hud.facingPotAmount * num / den))
        else
            applyOpenRaise(Math.floor(hud.facingPotAmount * num / den))
        if (root.afterPreset)
            root.afterPreset()
    }

    Rectangle {
        color: Theme.hudActionPanel
        radius: 6
        width: 40
        height: 28
        Text {
            anchors.centerIn: parent
            text: qsTr("Min")
            color: Theme.textPrimary
            font.pointSize: 9
            font.bold: true
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.flavor === "raise")
                    applyRaiseTotal(hud.facingMinRaiseChips)
                else
                    applyOpenRaise(hud.openRaiseMinChips)
                if (root.afterPreset)
                    root.afterPreset()
            }
            onPressed: parent.opacity = 0.85
            onReleased: parent.opacity = 1
        }
    }

    Rectangle {
        color: Theme.hudActionPanel
        radius: 6
        width: 34
        height: 28
        Text {
            anchors.centerIn: parent
            text: qsTr("⅓")
            color: Theme.textPrimary
            font.pointSize: 10
            font.bold: true
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.applyPotFrac(1, 3)
            onPressed: parent.opacity = 0.85
            onReleased: parent.opacity = 1
        }
    }

    Rectangle {
        color: Theme.hudActionPanel
        radius: 6
        width: 34
        height: 28
        Text {
            anchors.centerIn: parent
            text: qsTr("½")
            color: Theme.textPrimary
            font.pointSize: 10
            font.bold: true
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.applyPotFrac(1, 2)
            onPressed: parent.opacity = 0.85
            onReleased: parent.opacity = 1
        }
    }

    Rectangle {
        color: Theme.hudActionPanel
        radius: 6
        width: 34
        height: 28
        Text {
            anchors.centerIn: parent
            text: qsTr("⅔")
            color: Theme.textPrimary
            font.pointSize: 10
            font.bold: true
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.applyPotFrac(2, 3)
            onPressed: parent.opacity = 0.85
            onReleased: parent.opacity = 1
        }
    }

    Rectangle {
        color: Theme.hudActionPanel
        radius: 6
        width: 40
        height: 28
        Text {
            anchors.centerIn: parent
            text: qsTr("Pot")
            color: Theme.textPrimary
            font.pointSize: 9
            font.bold: true
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.flavor === "raise")
                    applyRaiseTotal(hud.facingNeedChips + hud.facingPotAmount)
                else
                    applyOpenRaise(Math.min(hud.facingPotAmount, slider.to))
                if (root.afterPreset)
                    root.afterPreset()
            }
            onPressed: parent.opacity = 0.85
            onReleased: parent.opacity = 1
        }
    }

    Rectangle {
        color: Theme.hudActionPanel
        radius: 6
        width: 40
        height: 28
        Text {
            anchors.centerIn: parent
            text: qsTr("All")
            color: Theme.textPrimary
            font.pointSize: 9
            font.bold: true
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.flavor === "raise")
                    applyRaiseTotal(slider.to)
                else
                    applyOpenRaise(slider.to)
                if (root.afterPreset)
                    root.afterPreset()
            }
            onPressed: parent.opacity = 0.85
            onReleased: parent.opacity = 1
        }
    }
}
